//
//  WindowActivator.swift
//  AltTab — Windows-style Window Switcher for macOS
//
//  Handles the actual window switching: unhides or unminimizes if needed, activates
//  the owning application, and raises the specific window via AXUIElement. Window
//  matching uses CGWindowID (via _AXUIElementGetWindow). Since macOS 14 `activate`
//  is only a request, so every switch is checked shortly afterwards and re-asserted
//  once if the window did not come forward.
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

    /// When to check a switch, counted from the confirm (or the re-assert). Owner logs: the
    /// app's front window was focused at 150 ms 5/5, and AX raises finish in 22-55 ms, so
    /// by then a raise has normally landed with about 100 ms to spare.
    private static let verifyDelay = 0.15
    /// A slow raise still gets this long to land before the check (a peer re-asserts at
    /// +80 ms, review/peers.md): a few frames for the app and the window server to apply it.
    private static let settleAfterRaise = 0.08
    /// Minimized and other-Space windows arrive through a system animation (unminimize,
    /// Space slide; roughly 0.3-0.5 s, not measured here). Checking during it would
    /// re-assert a switch that is still in progress.
    private static let animatedVerifyDelay = 0.7

    /// Counts switches (main thread), so a delayed check can tell a newer switch happened.
    private static var switchCount = 0
    /// The last switch's app (main thread); a late activation of it can beat a newer switch.
    private static var lastTargetPID: pid_t?

    /// One confirmed switch, carried through its steps and checks.
    private struct Switch {
        let window: WindowInfo
        let app: NSRunningApplication
        let number: Int
        /// The app frontmost at confirm and the previous switch's app. One of them still
        /// frontmost at the check means this activation did not take.
        let staleFront: Set<pid_t>
        let started = DispatchTime.now()

        var isCurrent: Bool { number == switchCount } // main thread
        var checkDelay: Double { window.isMinimized || window.isOnOtherSpace ? animatedVerifyDelay : verifyDelay }
        var kind: String {
            window.isMinimized ? "minimized" : window.isHidden ? "hidden"
                : window.isOnOtherSpace ? "other Space" : window.isFrontOfApp ? "front" : "window"
        }
    }

    /// Activates the given window: brings the owning app forward on the main thread, raises
    /// the specific window via AXUIElement off the main thread so confirm returns
    /// immediately, then checks the result once and re-asserts at most once.
    static func activate(window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            return perfLog.info("verify: failed, app quit (\(window.ownerName, privacy: .public))")
        }
        switchCount &+= 1
        let stale = Set([NSWorkspace.shared.frontmostApplication?.processIdentifier, lastTargetPID].compactMap { $0 })
        lastTargetPID = window.ownerPID
        bringForward(Switch(window: window, app: app, number: switchCount, staleFront: stale), firstMiss: nil)
    }

    /// One try (main thread). `firstMiss` is what the first check found; set on the re-assert.
    private static func bringForward(_ s: Switch, firstMiss: String?) {
        let tried = DispatchTime.now()
        if s.window.isOnOtherSpace {
            // Raise first so the target is the app's main window when the app activates:
            // macOS then switches to the target's Space ("When switching to an application,
            // switch to a Space with open windows"), not to the app's last-used window's.
            axQueue.async {
                raise(s, since: tried)
                DispatchQueue.main.async {
                    guard s.isCurrent else { return report(s, "superseded", "newer switch") }
                    activateApp(s)
                    verify(s, firstMiss: firstMiss, at: tried + s.checkDelay)
                }
            }
            return
        }
        activateApp(s)
        // The app's front window comes up with the app itself; only the re-assert raises it.
        if firstMiss == nil && s.window.isFrontOfApp && !s.window.isMinimized && !s.window.isHidden {
            verify(s, firstMiss: nil, at: tried + s.checkDelay)
            return
        }
        axQueue.async {
            raise(s, since: tried)
            verify(s, firstMiss: firstMiss, at: max(tried + s.checkDelay, .now() + settleAfterRaise))
        }
    }

    /// AppKit, main thread. A ⌘H-hidden app is unhidden first so its window can come forward.
    private static func activateApp(_ s: Switch) {
        if s.window.isHidden || s.app.isHidden { s.app.unhide() }
        s.app.activate(options: [.activateIgnoringOtherApps])
    }

    /// At `deadline`, checks that the app is frontmost and the target is its focused window
    /// and on screen. A miss is re-asserted once, unless another app has taken focus since
    /// (a click, a dialog): that one wins.
    private static func verify(_ s: Switch, firstMiss: String?, at deadline: DispatchTime) {
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            guard s.isCurrent else { return report(s, "superseded", "newer switch") }
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            axQueue.async {
                let pid = s.window.ownerPID, target = s.window.windowID
                let focused = focusedWindowID(pid: pid)
                let onScreen = isOnScreen(target)
                let stale = front.map { s.staleFront.contains($0) } ?? true
                let state = "front=\(front == pid ? "target" : front == nil ? "none" : stale ? "previous" : "other")"
                    + " focused=\(focused == target ? "target" : focused == nil ? "none" : "other") onScreen=\(onScreen)"
                if front == pid && focused == target && onScreen {
                    report(s, firstMiss == nil ? "ok" : "reasserted", firstMiss.map { "was " + $0 } ?? "")
                } else if front != pid && !stale {
                    report(s, "superseded", state)
                } else if firstMiss != nil {
                    report(s, "failed", state)
                } else {
                    DispatchQueue.main.async {
                        guard s.isCurrent else { return report(s, "superseded", "newer switch") }
                        bringForward(s, firstMiss: state)
                    }
                }
            }
        }
    }

    /// One line per switch, e.g. `verify: ok after 151.2 ms, front (Safari)`.
    private static func report(_ s: Switch, _ outcome: String, _ detail: String) {
        let info = detail.isEmpty ? s.kind : s.kind + ", " + detail
        perfLog.info("verify: \(outcome, privacy: .public) after \(ms(since: s.started), privacy: .public) ms, \(info, privacy: .public) (\(s.window.ownerName, privacy: .public))")
    }

    private static func ms(since start: DispatchTime) -> String {
        String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
    }

    /// Whether the window server shows the window on the current Space. No AX; ~0.1 ms.
    private static func isOnScreen(_ windowID: CGWindowID) -> Bool {
        let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]]
        return info?.first?[kCGWindowIsOnscreen as String] as? Bool ?? false
    }

    private static func focusedWindowID(pid: pid_t) -> CGWindowID? {
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, axMessagingTimeout)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let element = ref, CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
        let axWindow = element as! AXUIElement
        AXUIElementSetMessagingTimeout(axWindow, axMessagingTimeout)
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(axWindow, &windowID) == .success else { return nil }
        return windowID
    }

    /// axQueue only.
    private static func raise(_ s: Switch, since tried: DispatchTime) {
        let found = raiseWindow(s.window)
        perfLog.info("raise: \(ms(since: tried), privacy: .public) ms, found=\(found, privacy: .public) (\(s.window.ownerName, privacy: .public))")
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
            // Timeouts are per element; the app element's does not carry over to its windows.
            // Adapted from alttab-macos (MIT).
            AXUIElementSetMessagingTimeout(axWindow, axMessagingTimeout)
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
