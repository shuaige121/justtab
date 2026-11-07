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

        setupStatusItem()
        permissionManager = PermissionManager()

        windowModel = WindowModel()
        windowCapture = WindowCapture()
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

        if AXIsProcessTrusted() {
            hotkeyManager.start()
            NSLog("AltTab: Accessibility already granted, hotkey active")
        } else {
            // At login the TCC daemon may not be ready yet, causing a false negative.
            // Wait briefly and recheck before prompting the user.
            NSLog("AltTab: Accessibility not yet trusted, will recheck before prompting")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                if AXIsProcessTrusted() {
                    NSLog("AltTab: Accessibility granted after brief wait, hotkey active")
                    self.hotkeyManager.start()
                } else {
                    NSLog("AltTab: Accessibility still not trusted, prompting user")
                    self.permissionManager.ensureAccessibility()
                    NotificationCenter.default.addObserver(
                        forName: .accessibilityGranted, object: nil, queue: .main
                    ) { [weak self] _ in
                        NSLog("AltTab: Accessibility granted, starting hotkey manager")
                        self?.hotkeyManager.start()
                    }
                }
            }
        }
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "rectangle.on.rectangle",
                                  accessibilityDescription: "JustTab") {
                img.isTemplate = true
                button.image = img
            } else {
                // Fallback if SF Symbol unavailable
                button.title = "⌃⇥"
            }
        }
        preferencesMenu = PreferencesMenu()
        statusItem.menu = preferencesMenu.menu
        NSLog("JustTab: Status item installed")
    }

    // MARK: - HotkeyDelegate

    func hotkeyDidActivate(reverse: Bool) {
        currentWindows = windowModel.enumerateWindows()
        guard !currentWindows.isEmpty else { return }
        // Start on the second window (MRU), or on the last one for Shift+trigger.
        selectedIndex = reverse ? currentWindows.count - 1 : min(1, currentWindows.count - 1)
        switcherActive = true
        activationID &+= 1
        let thisActivation = activationID

        // Capture thumbnails asynchronously. Capture can take over a second, so the result
        // may arrive after this switcher was dismissed and a new one opened; applying it then
        // would replace the new window list with this stale one and switch to the wrong window.
        windowCapture.captureThumbnails(for: currentWindows) { [weak self] updatedWindows in
            guard let self = self, self.switcherActive,
                  self.activationID == thisActivation else { return }
            self.currentWindows = updatedWindows
            self.switcherPanel.show(windows: self.currentWindows,
                                    selectedIndex: self.selectedIndex)
        }

        // Show immediately with placeholder icons
        switcherPanel.show(windows: currentWindows, selectedIndex: selectedIndex)
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
