//
//  PreferencesMenu.swift
//  JustTab — minimal window switcher for macOS
//
//  Status bar dropdown: permission shortcuts (shown only while something is
//  missing), "Change Shortcut…" (the only real setting), a "Launch at Login"
//  toggle (SMAppService, macOS 13+), About, and Quit.
//
//  Based on alttab-macos by Sergio Farfan (MIT).
//

import Cocoa
import Carbon.HIToolbox
import ServiceManagement

final class PreferencesMenu: NSObject, NSMenuDelegate {

    let menu: NSMenu
    private var recorderWC: ShortcutRecorderWindowController?
    private let permissionManager: PermissionManager
    private let accessibilityItem = NSMenuItem(title: "⚠︎ Grant Accessibility Permission…",
                                               action: nil, keyEquivalent: "")
    private let thumbnailsItem = NSMenuItem(title: "Enable Live Thumbnails (Screen Recording)…",
                                            action: nil, keyEquivalent: "")
    private let permissionSeparator = NSMenuItem.separator()
    private var launchItem: NSMenuItem!

    init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
        menu = NSMenu()
        super.init()
        menu.delegate = self

        accessibilityItem.action = #selector(grantAccessibility(_:))
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        thumbnailsItem.action = #selector(enableThumbnails(_:))
        thumbnailsItem.target = self
        menu.addItem(thumbnailsItem)
        menu.addItem(permissionSeparator)

        let changeShortcutItem = NSMenuItem(title: "Change Shortcut…",
                                            action: #selector(changeShortcut(_:)),
                                            keyEquivalent: "")
        changeShortcutItem.target = self
        menu.addItem(changeShortcutItem)

        menu.addItem(NSMenuItem.separator())

        launchItem = NSMenuItem(title: "Launch at Login",
                                action: #selector(toggleLaunchAtLogin(_:)),
                                keyEquivalent: "")
        launchItem.target = self
        menu.addItem(launchItem)
        menuNeedsUpdate(menu)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About JustTab",
                                   action: #selector(showAbout(_:)),
                                   keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit JustTab",
                                  action: #selector(quitApp(_:)),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Menu state

    /// Refreshed every time the menu opens, so it always reflects the live permission state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let accessibility = AXIsProcessTrusted()
        accessibilityItem.isHidden = accessibility
        thumbnailsItem.isHidden = !accessibility || permissionManager.hasScreenRecording
        permissionSeparator.isHidden = accessibilityItem.isHidden && thumbnailsItem.isHidden
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled: launchItem.state = .on; launchItem.title = "Launch at Login"
            case .requiresApproval: launchItem.state = .mixed; launchItem.title = "Launch at Login (needs approval)…"
            default: launchItem.state = .off; launchItem.title = "Launch at Login"
            }
        }
    }

    // MARK: - Permissions

    @objc private func grantAccessibility(_ sender: NSMenuItem) {
        permissionManager.promptForAccessibility()
    }

    @objc private func enableThumbnails(_ sender: NSMenuItem) {
        permissionManager.requestScreenRecording()
    }

    // MARK: - Shortcut

    @objc private func changeShortcut(_ sender: NSMenuItem) {
        if recorderWC == nil {
            recorderWC = ShortcutRecorderWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        recorderWC?.showWindow(nil)
        recorderWC?.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Launch at Login

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
                return
            }
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    sender.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    sender.state = .on
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to update Login Item"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    @objc private func showAbout(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "JustTab"
        alert.informativeText = "A minimal, free window switcher for macOS.\n"
            + "Shortcut: \(ShortcutSettings.shared.displayString)\n"
            + "Based on alttab-macos by Sergio Farfan (MIT)."
        alert.runModal()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}

// MARK: - Shortcut Recorder

/// A tiny window that records the next key combo the user presses and stores it
/// as the trigger shortcut. The event tap hands the press over before macOS sees it, so
/// system shortcuts (⌘Tab, ⌘Space, ⌘`) can be recorded too; a local key monitor covers
/// the case where the tap is not running. Whatever you actually press is what gets saved,
/// so Command/Ctrl/Option remaps are handled automatically.
final class ShortcutRecorderWindowController: NSWindowController, NSWindowDelegate {

    private var keyMonitor: Any?
    private let currentLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private let recordButton = NSButton(title: "Record New Shortcut", target: nil, action: nil)
    private var recording = false

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 180),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "JustTab — Shortcut"
        self.init(window: window)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        buildUI()
        refresh()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        currentLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        currentLabel.alignment = .center
        currentLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(currentLabel)

        hintLabel.stringValue = Self.defaultHint
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(hintLabel)

        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(toggleRecord)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(recordButton)

        NSLayoutConstraint.activate([
            currentLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            currentLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 30),
            hintLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: currentLabel.bottomAnchor, constant: 12),
            recordButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            recordButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 24),
        ])
    }

    private func refresh() {
        currentLabel.stringValue = "Current: " + ShortcutSettings.shared.displayString
    }

    private static let defaultHint = "Hold one or more of ⌃ ⌥ ⇧ ⌘ and press any key. Esc cancels."

    @objc private func toggleRecord() {
        if recording { stopRecording(); return }
        recording = true
        ShortcutSettings.shared.isRecording = true
        ShortcutSettings.shared.recordHandler = { [weak self] modifiers, keyCode in
            self?.capture(modifiers: modifiers, keyCode: keyCode)
        }
        recordButton.title = "Press your shortcut…"
        hintLabel.stringValue = Self.defaultHint
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var cg: CGEventFlags = []
            if mods.contains(.control) { cg.insert(.maskControl) }
            if mods.contains(.option) { cg.insert(.maskAlternate) }
            if mods.contains(.shift) { cg.insert(.maskShift) }
            if mods.contains(.command) { cg.insert(.maskCommand) }
            self?.capture(modifiers: cg, keyCode: Int64(event.keyCode))
            return nil // swallow the keypress while recording
        }
    }

    private func capture(modifiers: CGEventFlags, keyCode: Int64) {
        guard recording else { return }
        switch ShortcutSettings.shared.record(modifiers: modifiers, keyCode: keyCode) {
        case .needsModifier:
            recordButton.title = "Need a modifier — try again"
        case .cancelled:
            stopRecording()
        case .recorded:
            stopRecording()
            refresh()
            let settings = ShortcutSettings.shared
            let key = CarbonHotKey(keyCode: UInt32(truncatingIfNeeded: settings.keyCode),
                                   modifiers: SecureInputFallback.carbonModifiers(settings.modifierFlags))
            if ShortcutSettings.isSystemShortcut(key, in: ShortcutSettings.systemShortcuts()) {
                hintLabel.stringValue = "macOS also uses \(settings.displayString). JustTab takes it over while it runs."
            }
        }
    }

    private func stopRecording() {
        recording = false
        ShortcutSettings.shared.isRecording = false
        ShortcutSettings.shared.recordHandler = nil
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
        recordButton.title = "Record New Shortcut"
    }

    func windowWillClose(_ notification: Notification) {
        stopRecording()
    }
}
