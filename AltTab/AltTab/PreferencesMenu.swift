//
//  PreferencesMenu.swift
//  JustTab — minimal window switcher for macOS
//
//  Status bar dropdown: "Change Shortcut…" (the only real setting), a
//  "Launch at Login" toggle (SMAppService, macOS 13+), About, and Quit.
//
//  Based on alttab-macos by Sergio Farfan (MIT).
//

import Cocoa
import Carbon.HIToolbox
import ServiceManagement

final class PreferencesMenu {

    let menu: NSMenu
    private var recorderWC: ShortcutRecorderWindowController?

    init() {
        menu = NSMenu()

        let changeShortcutItem = NSMenuItem(title: "Change Shortcut…",
                                            action: #selector(changeShortcut(_:)),
                                            keyEquivalent: "")
        changeShortcutItem.target = self
        menu.addItem(changeShortcutItem)

        menu.addItem(NSMenuItem.separator())

        let launchItem = NSMenuItem(title: "Launch at Login",
                                    action: #selector(toggleLaunchAtLogin(_:)),
                                    keyEquivalent: "")
        launchItem.target = self
        launchItem.state = Self.isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)

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

    private static var isLaunchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
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
/// as the trigger shortcut. Uses a local key monitor while the window is key, so
/// it captures exactly what the keyboard emits — any Command/Ctrl/Option remap is
/// handled automatically (whatever you actually press is what gets saved).
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

        hintLabel.stringValue = "Hold your modifier and press a key (e.g. Tab)."
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

    @objc private func toggleRecord() {
        if recording { stopRecording(); return }
        recording = true
        ShortcutSettings.shared.isRecording = true
        recordButton.title = "Press your shortcut…"
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.capture(event)
            return nil // swallow the keypress while recording
        }
    }

    private func capture(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var cg: CGEventFlags = []
        if mods.contains(.control) { cg.insert(.maskControl) }
        if mods.contains(.option) { cg.insert(.maskAlternate) }
        if mods.contains(.shift) { cg.insert(.maskShift) }
        if mods.contains(.command) { cg.insert(.maskCommand) }

        guard !cg.isEmpty else {
            recordButton.title = "Need a modifier — try again"
            return
        }
        ShortcutSettings.shared.set(modifierFlags: cg, keyCode: Int64(event.keyCode))
        stopRecording()
        refresh()
    }

    private func stopRecording() {
        recording = false
        ShortcutSettings.shared.isRecording = false
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
