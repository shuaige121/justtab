//
//  PermissionManager.swift
//  JustTab — minimal window switcher for macOS
//
//  Watches the permissions JustTab depends on for the app's whole lifetime and asks
//  for whatever is missing, so the user only has to click once in the system dialog:
//
//  - Accessibility (required for the shortcut): checked every 2 s. When missing, the
//    system prompt is shown (it also lists JustTab in System Settings, and its button
//    opens that exact pane). Shown shortly after launch, immediately if the permission
//    is revoked while running, and again every 15 minutes while it stays off.
//  - Screen Recording (optional, live thumbnails): the system prompt is shown once,
//    right after Accessibility is in place. macOS never shows it a second time, so the
//    menu item opens the Screen Recording pane instead.
//  - Launch at Login: if macOS is waiting for approval, offer to open Login Items once.
//
//  Granting takes effect within one check; no relaunch is needed for Accessibility.
//  State changes are logged under subsystem com.leonardchow.justtab.
//
//  Based on alttab-macos by Sergio Farfan (MIT).
//

import Cocoa
import ApplicationServices
import ServiceManagement
import os
import ScreenCaptureKit

let justTabLog = Logger(subsystem: "com.leonardchow.justtab", category: "permissions")
let perfLog = Logger(subsystem: "com.leonardchow.justtab", category: "perf")

final class PermissionManager {

    /// System hooks, injectable so the monitoring logic can be tested without TCC.
    struct Environment {
        var isAccessibilityTrusted: () -> Bool = { AXIsProcessTrusted() }
        var promptAccessibility: () -> Void = {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        var hasScreenRecording: () -> Bool = { CGPreflightScreenCaptureAccess() }
        var requestScreenRecording: () -> Void = {
            CGRequestScreenCaptureAccess()
            // Also query ScreenCaptureKit, the API the thumbnails actually use, so macOS
            // registers JustTab for Screen Recording and lists it in System Settings.
            if #available(macOS 14.0, *) {
                SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { _, _ in }
            }
        }
        var openScreenRecordingSettings: () -> Void = {
            // Give macOS a moment to add JustTab to the list before the pane opens.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        var loginItemRequiresApproval: () -> Bool = {
            if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .requiresApproval }
            return false
        }
        var offerLoginItemApproval: () -> Void = PermissionManager.showLoginItemAlert
        var now: () -> Date = { Date() }
        var defaults: UserDefaults = .standard
    }

    /// Called on the main thread whenever Accessibility flips (and once for the initial state).
    var onAccessibilityChange: ((Bool) -> Void)?

    static let checkInterval: TimeInterval = 2
    /// At login TCC can briefly report "not trusted" before it is ready; wait this long
    /// before the first prompt so a reboot doesn't show a spurious dialog.
    static let launchGrace: TimeInterval = 1.5
    static let reminderInterval: TimeInterval = 15 * 60
    /// v2: the first build's request didn't reliably list JustTab in System Settings, so
    /// anyone who saw only that one is asked once more.
    static let screenRecordingAskedKey = "JustTab.screenRecordingAsked.v2"

    private let env: Environment
    private var timer: Timer?
    private(set) var accessibilityGranted: Bool?
    private var screenRecordingGranted: Bool?
    private var nextAccessibilityPrompt: Date?
    private var loginItemChecked = false

    init(environment: Environment = Environment()) {
        self.env = environment
    }

    var hasScreenRecording: Bool { env.hasScreenRecording() }

    func startMonitoring() {
        guard timer == nil else { return }
        check()
        let t = Timer(timeInterval: Self.checkInterval, repeats: true) { [weak self] _ in self?.check() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// One monitoring pass. Internal (not private) so tests can drive it with a fake clock.
    func check() {
        let ax = env.isAccessibilityTrusted()
        if ax != accessibilityGranted {
            let isLaunch = accessibilityGranted == nil
            accessibilityGranted = ax
            justTabLog.info("accessibility=\(ax ? "granted" : "missing", privacy: .public)")
            if ax {
                nextAccessibilityPrompt = nil
            } else {
                nextAccessibilityPrompt = env.now().addingTimeInterval(isLaunch ? Self.launchGrace : 0)
            }
            onAccessibilityChange?(ax)
        }

        if !ax, let due = nextAccessibilityPrompt, env.now() >= due {
            promptForAccessibility()
        }

        let sr = env.hasScreenRecording()
        if sr != screenRecordingGranted {
            screenRecordingGranted = sr
            justTabLog.info("screenRecording=\(sr ? "granted" : "missing", privacy: .public)")
        }

        // Ask for the optional permissions only once Accessibility is settled, so the user
        // never gets two system dialogs stacked on top of each other.
        if ax {
            requestScreenRecordingIfNeverAsked()
            if !loginItemChecked {
                loginItemChecked = true
                if env.loginItemRequiresApproval() {
                    justTabLog.info("loginItem=requiresApproval, offering to open Login Items")
                    env.offerLoginItemApproval()
                }
            }
        }
    }

    // MARK: - Actions (also used by the menu)

    func promptForAccessibility() {
        justTabLog.info("prompting for accessibility")
        env.promptAccessibility()
        nextAccessibilityPrompt = env.now().addingTimeInterval(Self.reminderInterval)
    }

    /// Menu action: register JustTab for Screen Recording (macOS shows its own prompt the
    /// first time) and open the pane, where JustTab is now listed, so one switch finishes it.
    func requestScreenRecording() {
        guard !env.hasScreenRecording() else { return }
        env.defaults.set(true, forKey: Self.screenRecordingAskedKey)
        justTabLog.info("requesting screen recording from menu, opening settings")
        env.requestScreenRecording()
        env.openScreenRecordingSettings()
    }

    private func requestScreenRecordingIfNeverAsked() {
        guard !env.hasScreenRecording(),
              !env.defaults.bool(forKey: Self.screenRecordingAskedKey) else { return }
        env.defaults.set(true, forKey: Self.screenRecordingAskedKey)
        justTabLog.info("prompting for screen recording (first time)")
        env.requestScreenRecording()
    }

    private static func showLoginItemAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Allow JustTab to start at login"
            alert.informativeText = "Launch at Login is on, but macOS is waiting for your approval in Login Items."
            alert.addButton(withTitle: "Open Login Items")
            alert.addButton(withTitle: "Not Now")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn, #available(macOS 13.0, *) {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}
