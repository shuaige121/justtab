
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

// ===== Secure Input fallback: driven through fakes, never real Carbon or real Secure Input =====
final class FakeRegistrar: HotKeyRegistrar {
    var onPress: ((UInt32) -> Void)?
    var active: [UInt32: CarbonHotKey] = [:]
    var calls: [String] = []
    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        calls.append("register \(id)"); active[id] = CarbonHotKey(keyCode: keyCode, modifiers: modifiers); return noErr
    }
    func unregister(id: UInt32) { calls.append("unregister \(id)"); active[id] = nil }
    /// What Carbon would deliver: only presses of a registered hotkey.
    func press(_ id: UInt32) { if active[id] != nil { onPress?(id) }; spin() }
}
var secureOn = false
func secureManager(_ reg: FakeRegistrar, poll: TimeInterval = 60) -> (HotkeyManager, Rec) {
    let m = HotkeyManager(isSecureInputEnabled: { secureOn }, hotKeyRegistrar: reg, secureInputPollInterval: poll)
    let r = Rec(); m.delegate = r; return (m, r)
}
let opt: CGEventFlags = .maskAlternate
let optTab = CarbonHotKey(keyCode: UInt32(kVK_Tab), modifiers: UInt32(optionKey))
let optShiftTab = CarbonHotKey(keyCode: UInt32(kVK_Tab), modifiers: UInt32(optionKey | shiftKey))
ShortcutSettings.shared.set(modifierFlags: opt, keyCode: Int64(kVK_Tab))

do { // S1 registers ⌥Tab and ⌥⇧Tab once Secure Input is on, not before
    secureOn = false
    let reg = FakeRegistrar(); let (m, _) = secureManager(reg)
    send(m, .flagsChanged, flagsEvent(opt))
    let emptyWhileOff = reg.active.isEmpty
    send(m, .flagsChanged, flagsEvent([]))
    secureOn = true
    send(m, .flagsChanged, flagsEvent(opt))
    check("secure input on, ⌥Tab trigger: registers ⌥Tab + ⌥⇧Tab", emptyWhileOff && reg.active == [1: optTab, 2: optShiftTab], "\(reg.calls)")
}
do { // S2 never for ⌘Tab; switching the trigger to ⌘Tab drops a registration
    secureOn = true
    ShortcutSettings.shared.set(modifierFlags: cmd, keyCode: Int64(kVK_Tab))
    let reg = FakeRegistrar(); let (m, _) = secureManager(reg)
    send(m, .flagsChanged, flagsEvent(cmd)); send(m, .flagsChanged, flagsEvent([cmd, .maskShift]))
    check("secure input on, ⌘Tab trigger: never registers", reg.calls.isEmpty, "\(reg.calls)")
    ShortcutSettings.shared.set(modifierFlags: opt, keyCode: Int64(kVK_Tab))
    send(m, .flagsChanged, flagsEvent(opt))
    ShortcutSettings.shared.set(modifierFlags: cmd, keyCode: Int64(kVK_Tab))
    send(m, .flagsChanged, flagsEvent(cmd))
    check("trigger changed to ⌘Tab while registered: unregisters", reg.active.isEmpty && reg.calls.count == 4, "\(reg.calls)")
    ShortcutSettings.shared.set(modifierFlags: opt, keyCode: Int64(kVK_Tab))
}
do { // S3 Secure Input ends with no key pressed: the timer unregisters, then stops polling
    secureOn = true
    let reg = FakeRegistrar(); let (m, _) = secureManager(reg, poll: 0.05)
    withExtendedLifetime(m) {
        send(m, .flagsChanged, flagsEvent(opt))
        let wasRegistered = reg.active.count == 2
        secureOn = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        check("secure input off: timer unregisters without any key event", wasRegistered && reg.active.isEmpty, "\(reg.calls)")
        secureOn = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        check("idle: no polling (on again, nothing registers until a modifier press)", reg.active.isEmpty, "\(reg.calls)")
    }
}
do { // S4 Secure Input ends: the next modifier press unregisters
    secureOn = true
    let reg = FakeRegistrar(); let (m, _) = secureManager(reg)
    send(m, .flagsChanged, flagsEvent(opt)); send(m, .flagsChanged, flagsEvent([]))
    secureOn = false
    send(m, .flagsChanged, flagsEvent(opt))
    check("secure input off: next modifier press unregisters", reg.active.isEmpty && reg.calls.count == 4, "\(reg.calls)")
}
do { // S5 Carbon presses drive the same state machine; the release (flagsChanged) confirms
    secureOn = true
    let reg = FakeRegistrar(); let (m, r) = secureManager(reg)
    send(m, .flagsChanged, flagsEvent(opt))
    reg.press(SecureInputFallback.forwardID)
    let afterFirst = r.log
    reg.press(SecureInputFallback.forwardID); reg.press(SecureInputFallback.reverseID)
    send(m, .flagsChanged, flagsEvent([]))
    check("Carbon: press activates, press cycles, ⇧ press goes back, release confirms",
          afterFirst == ["activate"] && r.log == ["activate", "next", "prev", "confirm"], "\(r.log)")
    send(m, .flagsChanged, flagsEvent(opt)); reg.press(SecureInputFallback.reverseID)
    check("Carbon: ⌥⇧Tab from idle opens in reverse", r.log.last == "activate-rev", "\(r.log)")
}
do { // S6 the same press seen by both the tap and Carbon acts once
    secureOn = true
    let reg = FakeRegistrar(); let (m, r) = secureManager(reg)
    send(m, .flagsChanged, flagsEvent(opt))
    send(m, .keyDown, key(kVK_Tab, opt))      // the tap saw this press
    reg.press(SecureInputFallback.forwardID)  // and Carbon reports it too
    check("Carbon press right after the tap's keyDown for it is ignored", r.log == ["activate"], "\(r.log)")
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    reg.press(SecureInputFallback.forwardID)
    check("a later Carbon-only press still cycles", r.log == ["activate", "next"], "\(r.log)")
}
do { // S7 a tap press just before Secure Input came on does not swallow the first Carbon press
    secureOn = false
    let reg = FakeRegistrar(); let (m, r) = secureManager(reg)
    send(m, .flagsChanged, flagsEvent(opt)); send(m, .keyDown, key(kVK_Tab, opt)); send(m, .flagsChanged, flagsEvent([]))
    secureOn = true
    send(m, .flagsChanged, flagsEvent(opt)); reg.press(SecureInputFallback.forwardID)
    check("switch into a password field, switch again at once: Carbon press activates", r.log == ["activate", "confirm", "activate"], "\(r.log)")
}
do { // S8 Secure Input off: tap behaviour unchanged, nothing ever registered
    secureOn = false
    let reg = FakeRegistrar(); let (m, r) = secureManager(reg)
    send(m, .flagsChanged, flagsEvent(opt))
    let swallowed = !send(m, .keyDown, key(kVK_Tab, opt))
    send(m, .keyDown, key(kVK_Tab, [opt, .maskShift])); send(m, .keyDown, key(kVK_Escape, opt))
    send(m, .flagsChanged, flagsEvent([]))
    check("secure input off: ⌥Tab tap flow unchanged, nothing registered",
          swallowed && r.log == ["activate", "prev", "cancel"] && reg.calls.isEmpty, "\(r.log) \(reg.calls)")
}
do { // S9 recording a new shortcut: the timer drops the fallback so the recorder sees the keys
    secureOn = true
    let reg = FakeRegistrar(); let (m, _) = secureManager(reg, poll: 0.05)
    withExtendedLifetime(m) {
        send(m, .flagsChanged, flagsEvent(opt))
        ShortcutSettings.shared.isRecording = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        check("recording a shortcut: fallback unregistered", reg.calls.count == 4 && reg.active.isEmpty, "\(reg.calls)")
        ShortcutSettings.shared.isRecording = false
    }
}
print(failures == 0 ? "ALL HOTKEY TESTS PASSED" : "\(failures) HOTKEY TEST(S) FAILED")
exit(failures == 0 ? 0 : 1)
