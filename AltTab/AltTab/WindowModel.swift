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
    var windowTitle: String
    let isMinimized: Bool
    /// Topmost window of its app on this Space; activating the app alone brings it up.
    var isFrontOfApp = false
    /// Its app is hidden (⌘H); the window must be unhidden before it can come forward.
    var isHidden = false
    /// Not on screen, not minimized and its app not hidden: on another Space.
    var isOnOtherSpace = false
    var thumbnail: NSImage?

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

    /// Per-PID AXObservers for intra-app window focus tracking.
    private var axObservers: [pid_t: AXObserver] = [:]

    /// Accessibility queries made outside the switcher (prewarm, app activation), kept off
    /// the main thread so a busy app can't delay the shortcut.
    private static let backgroundAX = DispatchQueue(label: "com.leonardchow.justtab.ax", qos: .utility)

    /// An app JustTab itself just activated; its activation notification is skipped because
    /// the chosen window was already moved to the front of the MRU list.
    private var expectedActivation: (pid: pid_t, until: DispatchTime)?

    init() {
        // Cap every Accessibility message this process sends (default is 6 s) so one
        // unresponsive app can't stall the switcher.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)
        observeAppActivation()
        observeAppLifecycle()
        prewarmIcons()
    }

    /// Called when Accessibility is (re)granted: install the focus observers that could not
    /// be registered before, and warm every app's Accessibility connection so the first
    /// switch after launch is as fast as later ones.
    func accessibilityGranted() {
        let apps = Self.regularApps()
        for app in apps { installAXObserver(for: app.pid) }
        Self.backgroundAX.async {
            DispatchQueue.concurrentPerform(iterations: apps.count) { i in
                _ = Self.scanApp(pid: apps[i].pid, name: apps[i].name, needTitle: [], alreadySeen: [])
            }
        }
    }

    private static func regularApps() -> [(pid: pid_t, name: String)] {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != selfPID }
            .map { ($0.processIdentifier, $0.localizedName ?? "Unknown") }
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
        var appsWithFront = Set<pid_t>()

        // 1. On-screen windows from CGWindowList (titles need Screen Recording).
        if let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                      kCGNullWindowID) as? [[String: Any]] {
            for info in infoList { // front to back
                guard var window = parseWindowInfo(info),
                      window.ownerPID != selfPID,
                      !seenIDs.contains(window.windowID) else { continue }
                seenIDs.insert(window.windowID)
                window.isFrontOfApp = appsWithFront.insert(window.ownerPID).inserted
                if window.windowTitle.isEmpty { untitled[window.windowID] = windows.count }
                windows.append(window)
            }
        }

        // 2. Accessibility pass: minimized windows (not in the CG list) and missing titles.
        //    Apps are queried in parallel, so the pass costs about as much as the slowest
        //    app instead of the sum of all of them.
        let apps = Self.regularApps()
        let needTitle = Set(untitled.keys)
        let alreadySeen = seenIDs
        var results = [AXAppScan](repeating: AXAppScan(), count: apps.count)
        results.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: apps.count) { i in
                buffer[i] = Self.scanApp(pid: apps[i].pid, name: apps[i].name,
                                         needTitle: needTitle, alreadySeen: alreadySeen)
            }
        }
        for scan in results {
            for (id, title) in scan.titles {
                if let index = untitled[id] { windows[index].windowTitle = title }
            }
            for window in scan.minimized where !seenIDs.contains(window.windowID) {
                seenIDs.insert(window.windowID)
                windows.append(window)
            }
        }

        // 3. Sort by MRU
        pruneMRU(ids: windows.map { $0.windowID })
        let rank = Dictionary(uniqueKeysWithValues: mruOrder.enumerated().map { ($1, $0) })
        windows.sort { (rank[$0.windowID] ?? Int.max) < (rank[$1.windowID] ?? Int.max) }

        return windows
    }

    /// What one app contributes to the list. Built on a worker thread; merged on main.
    struct AXAppScan {
        var titles: [CGWindowID: String] = [:]
        var minimized: [WindowInfo] = []
    }

    /// One Accessibility round-trip for a single app. Safe to run concurrently for different apps.
    private static func scanApp(pid: pid_t, name: String,
                                needTitle: Set<CGWindowID>, alreadySeen: Set<CGWindowID>) -> AXAppScan {
        var scan = AXAppScan()
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, axEnumerationTimeout)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else { return scan }
        for axWindow in axWindows {
            var windowID: CGWindowID = 0
            _ = _AXUIElementGetWindow(axWindow, &windowID)
            guard windowID != 0 else { continue }
            if needTitle.contains(windowID) {
                let title = axString(axWindow, kAXTitleAttribute)
                if !title.isEmpty { scan.titles[windowID] = title }
                continue
            }
            guard !alreadySeen.contains(windowID) else { continue }
            var minimizedRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
                  (minimizedRef as? Bool) == true else { continue }
            scan.minimized.append(WindowInfo(windowID: windowID, ownerPID: pid, ownerName: name,
                                             windowTitle: axString(axWindow, kAXTitleAttribute),
                                             isMinimized: true))
        }
        return scan
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

    /// The user picked this window in the switcher: it becomes the most recent, and the
    /// activation notification its app is about to send is ignored.
    func didSwitch(to window: WindowInfo) {
        promoteToFront(windowID: window.windowID)
        expectedActivation = (window.ownerPID, .now() + 1)
    }

    /// Drops closed windows and appends unseen ones in the given (stacking) order, so the
    /// first switch after launch follows what is on screen.
    private func pruneMRU(ids: [CGWindowID]) {
        let valid = Set(ids)
        mruOrder.removeAll { !valid.contains($0) }
        var known = Set(mruOrder)
        for id in ids where known.insert(id).inserted { mruOrder.append(id) }
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

    /// When an app is activated, promote its focused window in MRU. The Accessibility query
    /// runs off the main thread; an app whose focus observer failed to register earlier
    /// (e.g. it was still launching) gets another attempt here.
    private func promoteAppWindows(pid: pid_t) {
        if let expected = expectedActivation, expected.pid == pid, DispatchTime.now() < expected.until {
            expectedActivation = nil
            return
        }
        installAXObserver(for: pid)
        Self.backgroundAX.async { [weak self] in
            let axApp = AXUIElementCreateApplication(pid)
            var focusedRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
                  let ref = focusedRef, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return }
            var windowID: CGWindowID = 0
            guard _AXUIElementGetWindow(ref as! AXUIElement, &windowID) == .success, windowID != 0 else { return }
            DispatchQueue.main.async { self?.promoteToFront(windowID: windowID) }
        }
    }

    // MARK: - AXObserver (Intra-App Focus Tracking)

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
        // Not stored on failure (no permission yet, app still launching), so a later
        // attempt can register it.
        guard AXObserverAddNotification(observer, axApp, kAXFocusedWindowChangedNotification as CFString,
                                        Unmanaged.passUnretained(self).toOpaque()) == .success else { return }

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
            let pid = app.processIdentifier, name = app.localizedName ?? "Unknown"
            AppIconCache.shared.prewarm(pid: pid)
            // A just-launched app usually can't answer Accessibility yet; register and warm
            // it once it has had time to open its windows.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard AXIsProcessTrusted() else { return }
                self?.installAXObserver(for: pid)
                Self.backgroundAX.async { _ = Self.scanApp(pid: pid, name: name, needTitle: [], alreadySeen: []) }
            }
        }

        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                           object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.removeAXObserver(for: app.processIdentifier)
            AppIconCache.shared.evict(pid: app.processIdentifier)
        }
    }

    // MARK: - Helpers

    private func parseWindowInfo(_ info: [String: Any]) -> WindowInfo? {
        guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
              let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
              let ownerName = info[kCGWindowOwnerName as String] as? String,
              let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
              let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
              let w = boundsDict["Width"], let h = boundsDict["Height"],
              w > 0 && h > 0 else { return nil }

        // kCGWindowName needs Screen Recording; enumerateWindows() fills missing titles
        // from its single Accessibility pass.
        let title = info[kCGWindowName as String] as? String ?? ""
        return WindowInfo(windowID: windowID, ownerPID: ownerPID, ownerName: ownerName,
                          windowTitle: title, isMinimized: false)
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
