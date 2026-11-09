
// ===== test harness (appended to a copy of HotkeyManager.swift) =====
final class Rec: HotkeyDelegate {
    var log: [String] = []
    func hotkeyDidActivate(reverse: Bool, pressedAt: DispatchTime) { log.append(reverse ? "activate-rev" : "activate") }
    func hotkeyDidCycleNext() { log.append("next") }
    func hotkeyDidCyclePrevious() { log.append("prev") }
    func hotkeyDidConfirm() { log.append("confirm") }
    func hotkeyDidCancel() { log.append("cancel") }
}
func key(_ code: Int, _ flags: CGEventFlags) -> CGEvent {
    let e = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
    e.flags = flags; return e
}
func flagsEvent(_ flags: CGEventFlags) -> CGEvent {
    let e = CGEvent(source: nil)!; e.type = .flagsChanged; e.flags = flags; return e
}
func spin() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    print((ok ? "PASS " : "FAIL ") + name + (detail.isEmpty ? "" : "  [\(detail)]")); if !ok { failures += 1 }
}
@discardableResult
func send(_ m: HotkeyManager, _ type: CGEventType, _ e: CGEvent) -> Bool { // true = passed through
    let r = m.handleEvent(OpaquePointer(bitPattern: 1)!, type: type, event: e); spin(); return r != nil
}
ShortcutSettings.shared.set(modifierFlags: .maskCommand, keyCode: Int64(kVK_Tab))
let cmd: CGEventFlags = .maskCommand

do { // 1 Cmd+Tab activates, swallowed
    let m = HotkeyManager(); let r = Rec(); m.delegate = r
    let passed = send(m, .keyDown, key(kVK_Tab, cmd))
    check("Cmd+Tab activates and is swallowed", !passed && r.log == ["activate"], "\(r.log)")
}
do { // 2 Cmd+Shift+Tab starts in reverse
    let m = HotkeyManager(); let r = Rec(); m.delegate = r
    send(m, .keyDown, key(kVK_Tab, [cmd, .maskShift]))
    check("Cmd+Shift+Tab activates in reverse", r.log == ["activate-rev"], "\(r.log)")
}
do { // 3 Cmd+Q while open must not reach the frontmost app
    let m = HotkeyManager(); let r = Rec(); m.delegate = r
    send(m, .keyDown, key(kVK_Tab, cmd))
    let passed = send(m, .keyDown, key(kVK_ANSI_Q, cmd))
    check("Cmd+Q while switcher open is swallowed", !passed, "passedThrough=\(passed)")
    let passedW = send(m, .keyDown, key(kVK_ANSI_W, cmd))
    check("Cmd+W while switcher open is swallowed", !passedW, "passedThrough=\(passedW)")
}
do { // 4 missed modifier release: next plain key confirms and passes through
    let m = HotkeyManager(); let r = Rec(); m.delegate = r
    send(m, .keyDown, key(kVK_Tab, cmd))
    let passed = send(m, .keyDown, key(kVK_ANSI_A, []))
    check("plain key after missed release confirms + passes through", passed && r.log == ["activate", "confirm"], "\(r.log) passed=\(passed)")
    let passed2 = send(m, .keyDown, key(kVK_ANSI_B, []))
    check("typing works normally afterwards", passed2 && r.log.count == 2, "\(r.log)")
}
do { // 5 normal hold-tab-tab-release flow still works
    let m = HotkeyManager(); let r = Rec(); m.delegate = r
    send(m, .keyDown, key(kVK_Tab, cmd)); send(m, .keyDown, key(kVK_Tab, cmd))
    send(m, .keyDown, key(kVK_Tab, [cmd, .maskShift])); send(m, .keyDown, key(kVK_RightArrow, cmd))
    let passedFlags = send(m, .flagsChanged, flagsEvent([]))
    check("hold/Tab/Shift-Tab/Right/release flow", r.log == ["activate", "next", "prev", "next", "confirm"] && passedFlags, "\(r.log)")
    send(m, .keyDown, key(kVK_Escape, []))
    check("Esc after close goes to app (not swallowed)", r.log.count == 5)
}
do { // 6 reset() after a click: next Cmd+Tab opens the switcher again
    let m = HotkeyManager(); let r = Rec(); m.delegate = r
    send(m, .keyDown, key(kVK_Tab, cmd))
    m.reset()
    send(m, .keyDown, key(kVK_Tab, cmd))
    check("after click-confirm, Cmd+Tab reopens (not cycles hidden panel)", r.log == ["activate", "activate"], "\(r.log)")
}
do { // 7 trigger with no windows: AppDelegate calls reset(); keys must reach apps again
    let m = HotkeyManager(); let r = Rec(); m.delegate = r
    send(m, .keyDown, key(kVK_Tab, cmd))
    m.reset()
    let passedQ = send(m, .keyDown, key(kVK_ANSI_Q, cmd))
    check("after no-window reset, Cmd+Q reaches the app", passedQ && r.log == ["activate"], "\(r.log) passed=\(passedQ)")
}
print(failures == 0 ? "ALL HOTKEY TESTS PASSED" : "\(failures) HOTKEY TEST(S) FAILED")
exit(failures == 0 ? 0 : 1)
