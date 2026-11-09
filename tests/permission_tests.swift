import Cocoa
var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: String = "") { print((ok ? "PASS " : "FAIL ") + name + (detail.isEmpty ? "" : "  [\(detail)]")); if !ok { failures += 1 } }

final class Fake {
    var t: TimeInterval = 0; var ax = false; var sr = false; var loginNeedsApproval = false
    var srChecks = 0; var axPrompts: [TimeInterval] = []; var srRequests = 0; var srSettingsOpened = 0; var loginOffers = 0; var changes: [Bool] = []
    let defaults: UserDefaults
    init() { defaults = UserDefaults(suiteName: "justtab.pmtest")!; defaults.removePersistentDomain(forName: "justtab.pmtest") }
    func make() -> PermissionManager {
        var e = PermissionManager.Environment()
        e.isAccessibilityTrusted = { self.ax }; e.promptAccessibility = { self.axPrompts.append(self.t) }
        e.hasScreenRecording = { self.srChecks += 1; return self.sr }; e.requestScreenRecording = { self.srRequests += 1 }
        e.openScreenRecordingSettings = { self.srSettingsOpened += 1 }
        e.loginItemRequiresApproval = { self.loginNeedsApproval }; e.offerLoginItemApproval = { self.loginOffers += 1 }
        e.now = { Date(timeIntervalSince1970: self.t) }; e.defaults = defaults
        let m = PermissionManager(environment: e); m.onAccessibilityChange = { self.changes.append($0) }; return m
    }
    func run(_ m: PermissionManager, until end: TimeInterval) { while t + 2 <= end { t += 2; m.check() } }
}

do { // missing at launch: grace, one prompt, reminder every 15 min, no Screen Recording dialog stacked on top
    let f = Fake(); let m = f.make()
    m.check()
    check("launch: reports missing, no instant prompt (TCC grace)", f.changes == [false] && f.axPrompts.isEmpty, "\(f.changes) \(f.axPrompts)")
    f.run(m, until: 10)
    check("prompts exactly once ~2 s after launch", f.axPrompts == [2], "\(f.axPrompts)")
    f.run(m, until: 2 + 15 * 60 - 2)
    check("no nagging inside 15 min", f.axPrompts.count == 1, "\(f.axPrompts.count)")
    f.run(m, until: 2 + 15 * 60 + 2)
    check("reminder after 15 min", f.axPrompts.count == 2, "\(f.axPrompts)")
    check("no Screen Recording / Login Items dialog while Accessibility missing", f.srRequests == 0 && f.loginOffers == 0)
}
do { // granted: hotkey callback, then Screen Recording asked once, Login Items offered once
    let f = Fake(); f.loginNeedsApproval = true; let m = f.make()
    m.check(); f.run(m, until: 6)
    f.ax = true; f.run(m, until: 8)
    check("grant detected within one check", f.changes == [false, true], "\(f.changes)")
    check("Screen Recording prompt chained after grant", f.srRequests == 1)
    check("Login Items approval offered", f.loginOffers == 1)
    let prompts = f.axPrompts.count
    f.run(m, until: 3600)
    check("after grant: no more prompts of any kind for an hour", f.axPrompts.count == prompts && f.srRequests == 1 && f.loginOffers == 1, "ax=\(f.axPrompts.count) sr=\(f.srRequests) login=\(f.loginOffers)")
    // revoked while running
    f.ax = false; f.t += 2; m.check()
    check("revoke: reported and prompted immediately", f.changes.last == false && f.axPrompts.last == f.t, "\(f.changes) \(f.axPrompts)")
    f.ax = true; f.t += 2; m.check()
    check("re-grant reported (hotkey gets recreated)", f.changes.suffix(2) == [false, true])
}
do { // TCC false negative at login: true by the first timer tick -> never prompts
    let f = Fake(); let m = f.make()
    m.check(); f.ax = true; f.run(m, until: 20)
    check("login false-negative: no spurious prompt", f.axPrompts.isEmpty && f.changes == [false, true], "\(f.axPrompts) \(f.changes)")
}
do { // Screen Recording already asked once -> menu opens the pane instead of a prompt macOS won't show
    let f = Fake(); f.ax = true; let m = f.make()
    m.check()
    check("first time: system Screen Recording prompt", f.srRequests == 1 && f.srSettingsOpened == 0)
    m.requestScreenRecording()
    check("menu after that: registers again and opens the pane", f.srRequests == 2 && f.srSettingsOpened == 1)
    f.sr = true; m.requestScreenRecording()
    check("menu when granted: does nothing", f.srSettingsOpened == 1 && f.srRequests == 2)
    let m2 = f.make(); f.sr = false; m2.check()
    check("relaunch: never auto-prompts Screen Recording again", f.srRequests == 2)
}
do { // menu action re-prompts accessibility right away and resets the reminder clock
    let f = Fake(); let m = f.make()
    m.check(); f.run(m, until: 4)
    f.t = 100; m.promptForAccessibility()
    f.run(m, until: 100 + 15 * 60 - 2)
    check("manual prompt resets reminder clock", f.axPrompts == [2, 100], "\(f.axPrompts)")
}
do { // the switcher reads the cached state: no system check per activation, one per tick
    let f = Fake(); f.ax = true; f.sr = true; let m = f.make()
    var srChanges: [Bool] = []; m.onScreenRecordingChange = { srChanges.append($0) }
    m.check()
    let afterCheck = f.srChecks
    for _ in 0..<50 { _ = m.hasScreenRecording }
    check("hasScreenRecording uses cached state (no system call)", f.srChecks == afterCheck && m.hasScreenRecording, "checks=\(f.srChecks)")
    let before = f.srChecks; f.run(m, until: 20)
    check("one system Screen Recording check per tick", f.srChecks - before == 10, "\(f.srChecks - before) for 10 ticks")
    f.sr = false; f.t += 2; m.check()
    check("revoked: cached state follows within one tick", !m.hasScreenRecording && srChanges == [true, false], "\(srChanges)")
}
do { // already granted on first run: never shows the Screen Recording prompt
    let f = Fake(); f.ax = true; f.sr = true; let m = f.make()
    m.check(); f.run(m, until: 10)
    check("Screen Recording already granted: no prompt", f.srRequests == 0, "requests=\(f.srRequests)")
}
UserDefaults.standard.removePersistentDomain(forName: "justtab.pmtest")
print(failures == 0 ? "ALL PERMISSION TESTS PASSED" : "\(failures) PERMISSION TEST(S) FAILED"); exit(failures == 0 ? 0 : 1)
