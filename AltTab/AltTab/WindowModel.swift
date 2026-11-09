//
//  WindowModel.swift
//  AltTab — Windows-style Window Switcher for macOS
//
//  Window enumeration and MRU (most recently used) tracking. Discovers all
//  user windows via CGWindowListCopyWindowInfo for on-screen windows and
//  AXUIElement queries for minimized windows. Maintains MRU order using
//  NSWorkspace activation notifications and per-app AXObservers that track
//  intra-app focused-window changes (e.g., Cmd-` between two Terminal windows).
//  Uses the private _AXUIElementGetWindow SPI to bridge between AXUIElement
//  and CGWindowID — the standard approach for macOS window managers.
//
//  Author:  Sergio Farfan <sergio.farfan@gmail.com>
//  Version: 1.1.0
//  Date:    2026-03-17
//  License: MIT
//

import Cocoa
import ApplicationServices

// MARK: - WindowInfo

struct WindowInfo {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let windowTitle: String
    let bounds: CGRect
    let isMinimized: Bool
    var thumbnail: NSImage?

    func withTitle(_ title: String) -> WindowInfo {
        WindowInfo(windowID: windowID, ownerPID: ownerPID, ownerName: ownerName, windowTitle: title,
                   bounds: bounds, isMinimized: isMinimized, thumbnail: thumbnail)
    }

    /// Returns the app icon for this window's owner process, served from an in-memory
    /// cache so the switcher never hits LaunchServices/disk while building the panel.
    var appIcon: NSImage {
        AppIconCache.shared.icon(forPID: ownerPID)
    }
}

// MARK: - AppIconCache

/// Caches application icons by PID. `NSRunningApplication.icon` resolves a LaunchServices
/// binding and reads the icon file from disk on every access; doing that per cell on every
/// activation is what made the panel render before its icons appeared (profiled via
/// `sample`: ~6% of main-thread work plus synchronous `open()` calls). NSCache is
/// thread-safe, so main-thread reads and prewarming coexist safely.
final class AppIconCache {
    static let shared = AppIconCache()

    private let cache = NSCache<NSNumber, NSImage>()
    private let fallback = NSImage(named: NSImage.applicationIconName)!

    /// Returns a cached icon, resolving and caching it on first request.
    func icon(forPID pid: pid_t) -> NSImage {
        let key = NSNumber(value: pid)
        if let hit = cache.object(forKey: key) { return hit }
        let resolved = NSRunningApplication(processIdentifier: pid)?.icon ?? fallback
        cache.setObject(resolved, forKey: key)
        return resolved
    }

    /// Resolve and cache an icon ahead of time so the first switch is already warm.
    func prewarm(pid: pid_t) {
        let key = NSNumber(value: pid)
        guard cache.object(forKey: key) == nil else { return }
        if let resolved = NSRunningApplication(processIdentifier: pid)?.icon {
            cache.setObject(resolved, forKey: key)
        }
    }

    /// Drop an icon when its app quits so a recycled PID can't surface a stale icon.
    func evict(pid: pid_t) {
        cache.removeObject(forKey: NSNumber(value: pid))
    }
}

// MARK: - WindowModel

final class WindowModel {

    /// MRU-ordered list of window IDs. Front of array = most recently used.
    private var mruOrder: [CGWindowID] = []
    private let selfBundleID = Bundle.main.bundleIdentifier ?? ""

    /// Per-PID AXObservers for intra-app window focus tracking.
    private var axObservers: [pid_t: AXObserver] = [:]

    init() {
        // Cap every Accessibility message this process sends (default is 6 s) so one
        // unresponsive app can't stall the switcher.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)
        seedMRUFromStackingOrder()
        observeAppActivation()
        observeAppLifecycle()
        installAXObserversForRunningApps()
        prewarmIcons()
    }

    deinit {
        removeAllAXObservers()
    }

    // MARK: - Enumerate

    /// Upper bound for one Accessibility round-trip while building the list. A busy or hung
    /// app then costs at most this long instead of the 6 s system default.
    static let axEnumerationTimeout: Float = 0.25

    /// Returns all user windows, ordered by MRU. One Accessibility round-trip per app: the
    /// same window list provides minimized windows and any titles CGWindowList didn't give.
    func enumerateWindows() -> [WindowInfo] {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        var windows: [WindowInfo] = []
        var seenIDs = Set<CGWindowID>()
        var untitled: [CGWindowID: Int] = [:]   // CG windows still needing a title → index

        // 1. On-screen windows from CGWindowList (titles need Screen Recording).
        if let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                      kCGNullWindowID) as? [[String: Any]] {
            for info in infoList {
                guard let window = parseWindowInfo(info, isMinimized: false),
                      window.ownerPID != selfPID,
                      !seenIDs.contains(window.windowID) else { continue }
                seenIDs.insert(window.windowID)
                if window.windowTitle.isEmpty { untitled[window.windowID] = windows.count }
                windows.append(window)
            }
        }

        // 2. Accessibility pass: minimized windows (not in the CG list) and missing titles.
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != selfPID {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(axApp, Self.axEnumerationTimeout)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let axWindows = windowsRef as? [AXUIElement] else { continue }

            for axWindow in axWindows {
                var windowID: CGWindowID = 0
                _ = _AXUIElementGetWindow(axWindow, &windowID)
                guard windowID != 0 else { continue }

                if let index = untitled[windowID] {
                    let title = Self.axString(axWindow, kAXTitleAttribute)
                    if !title.isEmpty { windows[index] = windows[index].withTitle(title) }
                    continue
                }
                guard !seenIDs.contains(windowID) else { continue }
                var minimizedRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
                      (minimizedRef as? Bool) == true else { continue }
                seenIDs.insert(windowID)
                windows.append(WindowInfo(
                    windowID: windowID,
                    ownerPID: app.processIdentifier,
                    ownerName: app.localizedName ?? "Unknown",
                    windowTitle: Self.axString(axWindow, kAXTitleAttribute),
                    bounds: .zero,
                    isMinimized: true,
                    thumbnail: nil
                ))
            }
        }

        // 3. Sort by MRU
        pruneMRU(validIDs: Set(windows.map { $0.windowID }))
        let rank = Dictionary(uniqueKeysWithValues: mruOrder.enumerated().map { ($1, $0) })
        windows.sort { (rank[$0.windowID] ?? Int.max) < (rank[$1.windowID] ?? Int.max) }

        return windows
    }

    private static func axString(_ element: AXUIElement, _ attribute: String) -> String {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else { return "" }
        return (ref as? String) ?? ""
    }

    // MARK: - MRU Management

    func promoteToFront(windowID: CGWindowID) {
        mruOrder.removeAll { $0 == windowID }
        mruOrder.insert(windowID, at: 0)
    }

    private func seedMRUFromStackingOrder() {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                        kCGNullWindowID) as? [[String: Any]] else { return }
        mruOrder = infoList.compactMap { info -> CGWindowID? in
            guard let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let w = bounds["Width"], let h = bounds["Height"],
                  w > 0 && h > 0 else { return nil }
            return id
        }
    }

    private func pruneMRU(validIDs: Set<CGWindowID>) {
        mruOrder.removeAll { !validIDs.contains($0) }
        // Add any new windows not yet in MRU at the end
        for id in validIDs where !mruOrder.contains(id) {
            mruOrder.append(id)
        }
    }

    private func observeAppActivation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.promoteAppWindows(pid: app.processIdentifier)
        }
    }

    /// When an app is activated, promote its frontmost window in MRU.
    private func promoteAppWindows(pid: pid_t) {
        let axApp = AXUIElementCreateApplication(pid)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success else { return }
        let focusedWindow = focusedRef as! AXUIElement
        var windowID: CGWindowID = 0
        _ = _AXUIElementGetWindow(focusedWindow, &windowID)
        if windowID != 0 {
            promoteToFront(windowID: windowID)
        }
    }

    // MARK: - AXObserver (Intra-App Focus Tracking)

    /// Install AXObservers on all currently running regular apps.
    private func installAXObserversForRunningApps() {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        for app in apps {
            installAXObserver(for: app.processIdentifier)
        }
    }

    /// Warm the icon cache for currently-running apps shortly after launch. Deferred to the
    /// main run loop so it never blocks startup; subsequent launches are warmed via the
    /// didLaunch notification in observeAppLifecycle().
    private func prewarmIcons() {
        let pids = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { $0.processIdentifier }
        DispatchQueue.main.async {
            for pid in pids { AppIconCache.shared.prewarm(pid: pid) }
        }
    }

    /// Creates an AXObserver for a single app and watches for focused-window changes.
    private func installAXObserver(for pid: pid_t) {
        guard axObservers[pid] == nil else { return }

        var observer: AXObserver?
        let result = AXObserverCreate(pid, axObserverCallback, &observer)
        guard result == .success, let observer = observer else { return }

        let axApp = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(observer, axApp, kAXFocusedWindowChangedNotification as CFString,
                                  Unmanaged.passUnretained(self).toOpaque())

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        axObservers[pid] = observer
    }

    /// Remove observer for a terminated app.
    private func removeAXObserver(for pid: pid_t) {
        guard let observer = axObservers.removeValue(forKey: pid) else { return }
        let axApp = AXUIElementCreateApplication(pid)
        AXObserverRemoveNotification(observer, axApp, kAXFocusedWindowChangedNotification as CFString)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func removeAllAXObservers() {
        for pid in axObservers.keys {
            removeAXObserver(for: pid)
        }
    }

    /// Called from the AXObserver C callback when any app's focused window changes.
    fileprivate func handleFocusedWindowChanged(_ element: AXUIElement) {
        var windowID: CGWindowID = 0
        _ = _AXUIElementGetWindow(element, &windowID)
        if windowID != 0 {
            promoteToFront(windowID: windowID)
        }
    }

    /// Watch for app launches and terminations to manage observer lifecycle.
    private func observeAppLifecycle() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                           object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.activationPolicy == .regular else { return }
            self?.installAXObserver(for: app.processIdentifier)
            AppIconCache.shared.prewarm(pid: app.processIdentifier)
        }

        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                           object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.removeAXObserver(for: app.processIdentifier)
            AppIconCache.shared.evict(pid: app.processIdentifier)
        }
    }

    // MARK: - Helpers

    private func parseWindowInfo(_ info: [String: Any], isMinimized: Bool) -> WindowInfo? {
        guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
              let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
              let ownerName = info[kCGWindowOwnerName as String] as? String,
              let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
              let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
              let x = boundsDict["X"], let y = boundsDict["Y"],
              let w = boundsDict["Width"], let h = boundsDict["Height"],
              w > 0 && h > 0 else { return nil }

        // kCGWindowName needs Screen Recording; enumerateWindows() fills missing titles
        // from its single Accessibility pass.
        let title = info[kCGWindowName as String] as? String ?? ""
        let bounds = CGRect(x: x, y: y, width: w, height: h)

        return WindowInfo(
            windowID: windowID,
            ownerPID: ownerPID,
            ownerName: ownerName,
            windowTitle: title,
            bounds: bounds,
            isMinimized: isMinimized,
            thumbnail: nil
        )
    }
}

// Private SPI to get CGWindowID from AXUIElement
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

// C callback for AXObserver — bridges to WindowModel.handleFocusedWindowChanged
private func axObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo = userInfo else { return }
    let model = Unmanaged<WindowModel>.fromOpaque(userInfo).takeUnretainedValue()
    model.handleFocusedWindowChanged(element)
}
