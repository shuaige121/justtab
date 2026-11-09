//
//  AppDelegate.swift
//  AltTab — Windows-style Window Switcher for macOS
//
//  Application lifecycle and orchestration. Sets up the menu bar status item,
//  manages permissions, and coordinates the hotkey manager, window model,
//  thumbnail capture, and switcher panel. Implements HotkeyDelegate to
//  respond to Option-Tab state machine transitions.
//
//  Author:  Sergio Farfan <sergio.farfan@gmail.com>
//  Version: 1.1.0
//  Date:    2026-03-17
//  License: MIT
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, HotkeyDelegate {

    private var statusItem: NSStatusItem!
    private var preferencesMenu: PreferencesMenu!
    private var hotkeyManager: HotkeyManager!
    private var windowModel: WindowModel!
    private var windowCapture: WindowCapture!
    private var switcherPanel: SwitcherPanel!
    private var permissionManager: PermissionManager!

    private var currentWindows: [WindowInfo] = []
    private var selectedIndex: Int = 0
    private var switcherActive: Bool = false
    /// Incremented on every activation so late thumbnail results from an earlier one are dropped.
    private var activationID: Int = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("AltTab: applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)

        permissionManager = PermissionManager()
        setupStatusItem()

        windowModel = WindowModel()
        windowCapture = WindowCapture()
        windowCapture.isAllowed = { [weak self] in self?.permissionManager.hasScreenRecording ?? false }
        switcherPanel = SwitcherPanel()

        hotkeyManager = HotkeyManager()
        hotkeyManager.delegate = self

        switcherPanel.onClick = { [weak self] index in
            guard let self = self, self.switcherActive, self.currentWindows.indices.contains(index) else { return }
            self.selectedIndex = index
            self.hotkeyManager.reset()
            self.hotkeyDidConfirm()
        }

        // The permission monitor runs for the app's lifetime: it starts the hotkey as soon
        // as Accessibility is granted (no relaunch), and recreates the event tap if the
        // permission is revoked and granted again.
        permissionManager.onAccessibilityChange = { [weak self] granted in
            guard let self = self else { return }
            self.updateStatusIcon(accessibilityGranted: granted)
            if granted {
                self.hotkeyManager.stop()
                self.hotkeyManager.start()
                self.windowModel.accessibilityGranted()
            } else {
                self.hotkeyManager.stop()
                self.hotkeyDidCancel()
            }
        }
        permissionManager.onScreenRecordingChange = { [weak self] granted in
            if granted { self?.windowCapture.prewarm() }
        }
        permissionManager.startMonitoring()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon(accessibilityGranted: AXIsProcessTrusted())
        preferencesMenu = PreferencesMenu(permissionManager: permissionManager)
        statusItem.menu = preferencesMenu.menu
        NSLog("JustTab: Status item installed")
    }

    /// Normal icon when the shortcut works; a warning triangle while Accessibility is missing.
    private func updateStatusIcon(accessibilityGranted: Bool) {
        guard let button = statusItem?.button else { return }
        let symbol = accessibilityGranted ? "rectangle.on.rectangle" : "exclamationmark.triangle"
        let label = accessibilityGranted ? "JustTab" : "JustTab needs Accessibility permission"
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: label) {
            img.isTemplate = true
            button.image = img
            button.title = ""
        } else {
            button.image = nil
            button.title = accessibilityGranted ? "⇥" : "⚠︎"
        }
        button.toolTip = label
    }

    // MARK: - HotkeyDelegate

    func hotkeyDidActivate(reverse: Bool, pressedAt: DispatchTime) {
        let started = DispatchTime.now()
        windowCapture.prefetchContent() // overlaps with building the list
        currentWindows = windowModel.enumerateWindows()
        let enumerated = DispatchTime.now()
        guard !currentWindows.isEmpty else {
            hotkeyManager.reset() // nothing to show: don't keep swallowing keys
            windowCapture.cancel()
            return
        }
        // Last known thumbnails first, so the panel opens with images instead of icons.
        currentWindows = windowCapture.applyCached(to: currentWindows)
        // Start on the second window (MRU), or on the last one for Shift+trigger.
        selectedIndex = reverse ? currentWindows.count - 1 : min(1, currentWindows.count - 1)
        switcherActive = true
        activationID &+= 1
        let thisActivation = activationID

        switcherPanel.show(windows: currentWindows, selectedIndex: selectedIndex)
        let cachedCount = currentWindows.filter { $0.thumbnail != nil }.count
        perfLog.info("""
            activate: \(self.currentWindows.count, privacy: .public) windows, \
            key→handler \(Self.ms(started, since: pressedAt), privacy: .public) ms, \
            list \(Self.ms(enumerated, since: started), privacy: .public) ms, \
            panel shown at \(Self.ms(since: pressedAt), privacy: .public) ms after key, \
            \(cachedCount, privacy: .public) cached thumbnails
            """)

        // Fresh thumbnails, selected window first, each shown as it arrives. A result for an
        // earlier activation is dropped: the panel may since show a different window list.
        var firstImageAt: String?
        windowCapture.captureThumbnails(
            for: currentWindows, first: selectedIndex, generation: thisActivation,
            onImage: { [weak self] index, image in
                guard let self = self, self.switcherActive, self.activationID == thisActivation,
                      self.currentWindows.indices.contains(index) else { return }
                if firstImageAt == nil { firstImageAt = Self.ms(since: pressedAt) }
                self.currentWindows[index].thumbnail = image
                self.switcherPanel.updateImage(at: index, image: image)
            },
            onDone: { captured in
                perfLog.info("""
                    thumbnails: \(captured, privacy: .public) captured, first shown at \
                    \(firstImageAt ?? "-", privacy: .public) ms, all done at \(Self.ms(since: pressedAt), privacy: .public) ms after key
                    """)
            })
    }

    private static func ms(_ end: DispatchTime = .now(), since start: DispatchTime) -> String {
        String(format: "%.1f", Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
    }

    func hotkeyDidCycleNext() {
        guard !currentWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % currentWindows.count
        switcherPanel.updateSelection(index: selectedIndex)
    }

    func hotkeyDidCyclePrevious() {
        guard !currentWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + currentWindows.count) % currentWindows.count
        switcherPanel.updateSelection(index: selectedIndex)
    }

    func hotkeyDidConfirm() {
        guard switcherActive, !currentWindows.isEmpty,
              selectedIndex < currentWindows.count else {
            dismissSwitcher()
            return
        }
        let window = currentWindows[selectedIndex]
        dismissSwitcher()
        WindowActivator.activate(window: window)
        windowModel.didSwitch(to: window)
    }

    func hotkeyDidCancel() {
        dismissSwitcher()
    }

    private func dismissSwitcher() {
        switcherActive = false
        windowCapture.cancel()
        switcherPanel.dismiss()
    }
}
