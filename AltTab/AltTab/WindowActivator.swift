//
//  WindowActivator.swift
//  AltTab — Windows-style Window Switcher for macOS
//
//  Handles the actual window switching: unminimizes if needed, activates the
//  owning application, and raises the specific window via AXUIElement. Window
//  matching uses CGWindowID (via _AXUIElementGetWindow).
//
//  Author:  Sergio Farfan <sergio.farfan@gmail.com>
//  Version: 1.1.0
//  Date:    2026-03-17
//  License: MIT
//

import Cocoa
import ApplicationServices

enum WindowActivator {

    /// Serial queue for the synchronous Accessibility IPC involved in raising a window.
    /// Kept off the main thread so a slow/busy target app can't freeze the switcher on
    /// confirm — profiled via `sample` as ~75% of main-thread activation cost, dominated
    /// by AXUIElementCopyAttributeValue(kAXWindows) blocking in mach_msg. Client-side AX
    /// queries against other apps are safe off-main; each call is additionally bounded by
    /// a messaging timeout (see below).
    private static let axQueue = DispatchQueue(label: "com.alttab.window-activator", qos: .userInitiated)

    /// Upper bound (seconds) on a single AX message. Long enough for a legitimately busy
    /// app to answer, short enough that a wedged app can't tie up the queue indefinitely.
    private static let axMessagingTimeout: Float = 1.0

    /// Counts switches (main thread), so a delayed check can tell a newer switch happened.
    private static var switchCount = 0

    /// Activates the given window: brings the owning app forward on the main thread, then
    /// unminimizes (if needed) and raises the specific window via AXUIElement off the main
    /// thread so confirm returns immediately and the UI never blocks.
    static func activate(window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else { return }

        // Bring the owning app forward on the main thread — this is an AppKit call and is
        // cheap (~1% of activation cost); AppKit is not safe to touch off the main thread.
        app.activate(options: [.activateIgnoringOtherApps])

        // The app's topmost window comes up with the app itself, so the Accessibility raise
        // is only needed for its other windows. Shortly after, check that the app really
        // focused that window, and raise it if not.
        switchCount &+= 1
        if window.isFrontOfApp && !window.isMinimized {
            let thisSwitch = switchCount
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                guard thisSwitch == switchCount else { return } // the user has switched again
                axQueue.async {
                    let focused = focusedWindowID(pid: window.ownerPID) == window.windowID
                    perfLog.info("raise: skipped, focused=\(focused, privacy: .public) (\(window.ownerName, privacy: .public))")
                    if !focused { _ = raiseWindow(window) }
                }
            }
            return
        }
        raise(window)
    }

    private static func focusedWindowID(pid: pid_t) -> CGWindowID? {
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, axMessagingTimeout)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let element = ref, CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(element as! AXUIElement, &windowID) == .success else { return nil }
        return windowID
    }

    private static func raise(_ window: WindowInfo) {
        let started = DispatchTime.now()
        axQueue.async {
            let found = raiseWindow(window)
            let ms = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000
            perfLog.info("raise: \(String(format: "%.1f", ms), privacy: .public) ms, found=\(found, privacy: .public) (\(window.ownerName, privacy: .public))")
        }
    }

    /// One window lookup for both steps. Matches by CGWindowID only: if the window is gone,
    /// the app has still been activated, which is better than raising a different window.
    private static func raiseWindow(_ window: WindowInfo) -> Bool {
        let axApp = AXUIElementCreateApplication(window.ownerPID)
        AXUIElementSetMessagingTimeout(axApp, axMessagingTimeout)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else { return false }

        for axWindow in axWindows {
            var windowID: CGWindowID = 0
            guard _AXUIElementGetWindow(axWindow, &windowID) == .success,
                  windowID == window.windowID else { continue }
            if window.isMinimized {
                AXUIElementSetAttributeValue(axWindow, kAXMinimizedAttribute as CFString, false as CFTypeRef)
            }
            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, true as CFTypeRef)
            return true
        }
        return false
    }
}
