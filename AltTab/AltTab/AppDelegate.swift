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
import ServiceManagement

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

        NotificationCenter.default.addObserver(
            forName: .switcherClickedWindow, object: nil, queue: .main
        ) { [weak self] note in
            guard let self = self, self.switcherActive,
                  let index = note.userInfo?["index"] as? Int,
                  index >= 0, index < self.currentWindows.count else { return }
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
            } else {
                self.hotkeyManager.stop()
                self.hotkeyDidCancel()
            }
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

    func hotkeyDidActivate(reverse: Bool) {
        let started = DispatchTime.now()
        currentWindows = windowModel.enumerateWindows()
        let enumerated = DispatchTime.now()
        guard !currentWindows.isEmpty else { return }
        // Last known thumbnails first, so the panel opens with images instead of icons.
        currentWindows = windowCapture.applyCached(to: currentWindows)
        // Start on the second window (MRU), or on the last one for Shift+trigger.
        selectedIndex = reverse ? currentWindows.count - 1 : min(1, currentWindows.count - 1)
        switcherActive = true
        activationID &+= 1
        let thisActivation = activationID

        // Capture thumbnails asynchronously. Capture can take over a second, so the result
        // may arrive after this switcher was dismissed and a new one opened; applying it then
        // would replace the new window list with this stale one and switch to the wrong window.
        windowCapture.captureThumbnails(for: currentWindows) { [weak self] updatedWindows, captured in
            perfLog.info("thumbnails: \(captured, privacy: .public) captured in \(Self.ms(since: started), privacy: .public) ms")
            guard let self = self, self.switcherActive,
                  self.activationID == thisActivation else { return }
            self.currentWindows = updatedWindows
            self.switcherPanel.show(windows: self.currentWindows,
                                    selectedIndex: self.selectedIndex)
        }

        // Show immediately with cached thumbnails / icons
        switcherPanel.show(windows: currentWindows, selectedIndex: selectedIndex)
        let cachedCount = currentWindows.filter { $0.thumbnail != nil }.count
        perfLog.info("""
            activate: \(self.currentWindows.count, privacy: .public) windows, \
            list \(Self.ms(enumerated, since: started), privacy: .public) ms, \
            panel shown at \(Self.ms(since: started), privacy: .public) ms, \
            \(cachedCount, privacy: .public) cached thumbnails
            """)
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
        windowModel.promoteToFront(windowID: window.windowID)
    }

    func hotkeyDidCancel() {
        dismissSwitcher()
    }

    private func dismissSwitcher() {
        switcherActive = false
        switcherPanel.dismiss()
    }
}
