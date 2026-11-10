//
//  HotkeyManager.swift
//  AltTab — Windows-style Window Switcher for macOS
//
//  Global hotkey detection via a CGEvent tap installed at the session level.
//  Implements a 3-state machine (idle → active → idle) that tracks Option
//  key hold state and Tab/Arrow/Escape keypresses. The CGEvent callback is
//  a C function pointer bridged to Swift via Unmanaged<HotkeyManager>.
//  Only keyDown events are swallowed; flagsChanged is always passed through
//  to avoid breaking system modifier state. Includes retry logic with
//  exponential backoff for event tap creation, handling the case where the
//  Accessibility subsystem isn't ready at login time. While Secure Event Input
//  hides keyDown events from the tap, the trigger is also registered as a Carbon
//  hotkey (SecureInputFallback).
//
//  Author:  Sergio Farfan <sergio.farfan@gmail.com>
//  Version: 1.1.0
//  Date:    2026-03-17
//  License: MIT
//

import Cocoa
import Carbon.HIToolbox

// MARK: - Delegate Protocol

protocol HotkeyDelegate: AnyObject {
    /// `pressedAt` is when the event tap received the key, for end-to-end timing.
    func hotkeyDidActivate(reverse: Bool, pressedAt: DispatchTime)
    func hotkeyDidCycleNext()
    func hotkeyDidCyclePrevious()
    func hotkeyDidConfirm()
    func hotkeyDidCancel()
}

// MARK: - HotkeyManager

final class HotkeyManager {

    weak var delegate: HotkeyDelegate?

    private enum State {
        case idle
        case active
    }

    private var state: State = .idle
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var reEnableTimer: Timer?
    private let secureInput: SecureInputFallback

    /// The defaults are the real system; tests pass fakes.
    init(isSecureInputEnabled: @escaping () -> Bool = { IsSecureEventInputEnabled() },
         hotKeyRegistrar: HotKeyRegistrar = CarbonHotKeyRegistrar(),
         secureInputPollInterval: TimeInterval = 1.0) {
        secureInput = SecureInputFallback(isSecureInputEnabled: isSecureInputEnabled,
                                          registrar: hotKeyRegistrar,
                                          pollInterval: secureInputPollInterval)
        secureInput.onPress = { [weak self] reverse in self?.handleFallbackPress(reverse: reverse) }
    }

    // MARK: - Lifecycle

    /// Maximum number of retries for event tap creation at startup.
    private static let maxTapRetries = 10
    /// Delay between retries, in seconds (doubles each attempt, capped at 4s).
    private static let baseTapRetryInterval: TimeInterval = 0.5
    private var tapRetryCount = 0
    /// False after stop(), so a retry queued before it doesn't install a tap again.
    private var running = false

    /// Safe to call repeatedly: does nothing while a tap is already installed.
    func start() {
        running = true
        guard eventTap == nil else { return }
        tapRetryCount = 0
        if !installEventTap() {
            scheduleRetry()
        }
        if reEnableTimer == nil { startReEnablePolling() }
    }

    /// Retry event tap creation with exponential back-off.
    /// At login the accessibility subsystem may not be ready yet.
    private func scheduleRetry() {
        guard tapRetryCount < Self.maxTapRetries else {
            NSLog("AltTab: Gave up creating event tap after \(Self.maxTapRetries) retries.")
            return
        }
        let delay = min(Self.baseTapRetryInterval * pow(2.0, Double(tapRetryCount)), 4.0)
        tapRetryCount += 1
        NSLog("AltTab: Will retry event tap in %.1fs (attempt %d/%d)", delay, tapRetryCount, Self.maxTapRetries)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.running, self.eventTap == nil else { return }
            if self.installEventTap() {
                NSLog("AltTab: Event tap created on retry %d", self.tapRetryCount)
            } else {
                self.scheduleRetry()
            }
        }
    }

    /// Return to idle without notifying the delegate (e.g. the selection was confirmed by a
    /// mouse click while the modifier is still held).
    func reset() {
        state = .idle
    }

    func stop() {
        running = false
        reEnableTimer?.invalidate()
        reEnableTimer = nil
        state = .idle
        secureInput.unregisterAll()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
            eventTap = nil
            runLoopSource = nil
        }
    }

    // MARK: - Event Tap

    @discardableResult
    private func installEventTap() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                (1 << CGEventType.keyDown.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyEventCallback,
            userInfo: userInfo
        ) else {
            justTabLog.error("event tap creation failed (Accessibility not granted?)")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        justTabLog.info("event tap installed")
        return true
    }

    /// The system can disable our tap if the callback takes too long. Poll to re-enable.
    /// If the tap was disabled while the switcher was active, we missed the Option release —
    /// force-cancel to prevent the panel from sticking.
    private func startReEnablePolling() {
        reEnableTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // If the tap was never created (e.g. permissions weren't ready at launch),
            // keep trying — accessibility may have been granted in the meantime.
            guard let tap = self.eventTap else {
                if AXIsProcessTrusted() {
                    NSLog("AltTab: Accessibility now trusted, retrying event tap creation.")
                    self.installEventTap()
                }
                return
            }

            if !CGEvent.tapIsEnabled(tap: tap) {
                NSLog("AltTab: Event tap was disabled by system, re-enabling.")
                CGEvent.tapEnable(tap: tap, enable: true)
                // If we were active, we missed the Option release — force cancel
                if self.state == .active {
                    self.state = .idle
                    notify { $0.hotkeyDidCancel() }
                }
            }
        }
    }

    // MARK: - Event Handling

    /// Delegate calls are made on the next main run-loop turn, outside the tap callback.
    private func notify(_ call: @escaping (HotkeyDelegate) -> Void) {
        DispatchQueue.main.async { [weak self] in
            if let delegate = self?.delegate { call(delegate) }
        }
    }

    fileprivate func handleEvent(_ proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // If tap is disabled, re-enable and force-cancel any active switcher
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            if state == .active {
                state = .idle
                notify { $0.hotkeyDidCancel() }
            }
            return Unmanaged.passUnretained(event)
        }

        // While recording a new shortcut, stay out of the way entirely.
        if ShortcutSettings.shared.isRecording {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .flagsChanged:
            return handleFlagsChanged(event)
        case .keyDown:
            return handleKeyDown(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let modifierHeld = flags.contains(ShortcutSettings.shared.modifierFlags)

        // Trigger modifier released while active → confirm selection.
        if state == .active && !modifierHeld {
            state = .idle
            notify { $0.hotkeyDidConfirm() }
        }

        // flagsChanged still arrives under Secure Input and the modifier goes down before the
        // trigger key, so this is where the Carbon fallback is switched on or off. Deferred so no
        // Carbon call runs inside the tap callback.
        DispatchQueue.main.async { [weak self] in self?.secureInput.refresh() }

        // NEVER swallow flagsChanged — always pass through
        return Unmanaged.passUnretained(event)
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let settings = ShortcutSettings.shared
        if keyCode == settings.keyCode && event.flags.contains(settings.modifierFlags) {
            secureInput.tapHandledTrigger()
        }
        return handleKey(keyCode, flags: event.flags) ? nil : Unmanaged.passUnretained(event)
    }

    /// A trigger press from the Carbon fallback (Secure Input on), fed to the same handler as a
    /// tap keyDown with the modifiers the hotkey was registered with.
    private func handleFallbackPress(reverse: Bool) {
        var flags = ShortcutSettings.shared.modifierFlags
        if reverse { flags.insert(.maskShift) }
        handleKey(ShortcutSettings.shared.keyCode, flags: flags)
    }

    /// The switcher's key handling, shared by the event tap and the Carbon fallback.
    /// Returns true when the tap must swallow the key. Under Secure Input only the trigger and
    /// Shift+trigger arrive (as Carbon hotkeys): Escape, Return and the arrow keys never reach
    /// us, and other keys go to the secure app instead of being swallowed.
    @discardableResult
    private func handleKey(_ keyCode: Int64, flags: CGEventFlags) -> Bool {
        let modifierHeld = flags.contains(ShortcutSettings.shared.modifierFlags)
        let shiftDown = flags.contains(.maskShift)
        let triggerKey = ShortcutSettings.shared.keyCode

        switch state {
        case .idle:
            // configured modifier + trigger key → activate switcher
            if modifierHeld && keyCode == triggerKey {
                state = .active
                let pressedAt = DispatchTime.now()
                notify { $0.hotkeyDidActivate(reverse: shiftDown, pressedAt: pressedAt) }
                return true // swallow the trigger key
            }

        case .active:
            // Modifier no longer held: we missed its release (e.g. secure input swallowed the
            // flagsChanged). Confirm as if released and let this key through normally.
            if !modifierHeld {
                state = .idle
                notify { $0.hotkeyDidConfirm() }
                return false
            }
            // The trigger key cycles selection (Shift = previous).
            if keyCode == triggerKey {
                if shiftDown {
                    notify { $0.hotkeyDidCyclePrevious() }
                } else {
                    notify { $0.hotkeyDidCycleNext() }
                }
                return true // swallow
            }
            switch Int(keyCode) {
            case kVK_LeftArrow:
                notify { $0.hotkeyDidCyclePrevious() }
                return true

            case kVK_RightArrow:
                notify { $0.hotkeyDidCycleNext() }
                return true

            case kVK_Escape:
                state = .idle
                notify { $0.hotkeyDidCancel() }
                return true

            case kVK_Return:
                state = .idle
                notify { $0.hotkeyDidConfirm() }
                return true

            default:
                // Swallow every other key while the switcher is open. With a Command trigger,
                // passing e.g. Cmd-Q / Cmd-W through would act on the frontmost app, not on
                // the window the user is looking at in the switcher.
                return true
            }
        }

        // Pass through all other keys
        return false
    }
}

// MARK: - Secure Input Fallback

/// While an app has Secure Event Input on (a focused password field, Terminal's Secure Keyboard
/// Entry, 1Password), the system delivers no keyDown events to event taps, so the trigger does
/// nothing; flagsChanged still arrives. Carbon hotkeys are still delivered, so while Secure Input
/// is on the trigger and Shift+trigger are also registered with `RegisterEventHotKey`, and each
/// press goes through HotkeyManager's normal key handler. The modifier release still reaches the
/// tap as flagsChanged and confirms as usual.
///
/// When it checks: on every flagsChanged (the modifier goes down before the trigger key, so the
/// hotkey is in place in time), and on a timer that exists only while registered, so the hotkey
/// goes away soon after Secure Input ends even if no modifier is pressed. Nothing polls while
/// idle; a check is one `IsSecureEventInputEnabled()` call (about 3 µs).
///
/// Never for ⌘Tab or ⌘⇧Tab: a Carbon hotkey cannot suppress the native app switcher, so both
/// would appear. Under Secure Input those users get the native switcher, as before.
final class SecureInputFallback {
    static let forwardID: UInt32 = 1
    static let reverseID: UInt32 = 2
    /// A Carbon press this soon after the tap handled the trigger is the same press, seen twice.
    /// Generous because the Carbon event can queue behind a slow activation on the main thread.
    static let duplicateWindowNs: UInt64 = 500_000_000

    /// Called for each accepted press; true for the Shift (reverse) variant.
    var onPress: ((Bool) -> Void)?

    private let isSecureInputEnabled: () -> Bool
    private let registrar: HotKeyRegistrar
    private let pollInterval: TimeInterval
    private var registered: [UInt32: CarbonHotKey] = [:]
    private var pollTimer: Timer?
    private var lastTapTriggerNs: UInt64?
    private var loggedNativeSwitcher = false
    private var reportedFailures: Set<CarbonHotKey> = []

    init(isSecureInputEnabled: @escaping () -> Bool, registrar: HotKeyRegistrar, pollInterval: TimeInterval) {
        self.isSecureInputEnabled = isSecureInputEnabled
        self.registrar = registrar
        self.pollInterval = pollInterval
        registrar.onPress = { [weak self] id in self?.carbonPressed(id: id) }
    }

    deinit {
        pollTimer?.invalidate()
        for id in registered.keys { registrar.unregister(id: id) }
    }

    /// Registers or unregisters to match the Secure Input state and the trigger setting.
    func refresh() {
        let settings = ShortcutSettings.shared
        if settings.isRecording {
            apply([:], reason: "recording a shortcut")
        } else if !isSecureInputEnabled() {
            apply([:], reason: "secure input off")
        } else if Self.isNativeSwitcher(settings.modifierFlags, keyCode: settings.keyCode) {
            if !loggedNativeSwitcher {
                loggedNativeSwitcher = true
                justTabLog.info("secure input on: no Carbon fallback for \(settings.displayString, privacy: .public), it cannot suppress the native app switcher")
            }
            apply([:], reason: "trigger uses the native app switcher")
        } else {
            apply(Self.hotKeys(for: settings.modifierFlags, keyCode: settings.keyCode),
                  reason: settings.displayString)
        }
    }

    func unregisterAll() {
        apply([:], reason: "hotkey stopped")
    }

    /// The tap handled a trigger keyDown, so keyDowns are reaching it right now.
    func tapHandledTrigger() {
        lastTapTriggerNs = DispatchTime.now().uptimeNanoseconds
    }

    private func carbonPressed(id: UInt32) {
        guard registered[id] != nil, !ShortcutSettings.shared.isRecording else { return }
        if let tapAt = lastTapTriggerNs, DispatchTime.now().uptimeNanoseconds &- tapAt < Self.duplicateWindowNs {
            justTabLog.info("secure input fallback: hotkey press ignored, the event tap already handled it")
            return
        }
        let reverse = id == Self.reverseID
        justTabLog.info("secure input fallback: hotkey pressed (reverse=\(reverse, privacy: .public))")
        onPress?(reverse)
    }

    private func apply(_ wanted: [UInt32: CarbonHotKey], reason: String) {
        let before = registered
        for (id, key) in before where wanted[id] != key {
            registrar.unregister(id: id)
            registered[id] = nil
        }
        for (id, key) in wanted where registered[id] == nil {
            let status = registrar.register(id: id, keyCode: key.keyCode, modifiers: key.modifiers)
            if status == noErr {
                registered[id] = key
            } else if reportedFailures.insert(key).inserted {
                justTabLog.error("secure input on: Carbon hotkey \(id, privacy: .public) for \(reason, privacy: .public) not registered, OSStatus \(status, privacy: .public) (another app may own this shortcut)")
            }
        }
        guard registered != before else { return }
        if registered.isEmpty {
            pollTimer?.invalidate()
            pollTimer = nil
            justTabLog.info("Carbon fallback unregistered (\(reason, privacy: .public))")
            return
        }
        if before.isEmpty {
            lastTapTriggerNs = nil // a tap press from before registration is not a duplicate
            let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in self?.refresh() }
            RunLoop.main.add(timer, forMode: .common)
            pollTimer = timer
        }
        justTabLog.info("secure input on: Carbon fallback registered for \(reason, privacy: .public) (\(self.registered.count, privacy: .public) hotkeys)")
    }

    /// ⌘Tab and ⌘⇧Tab belong to the native app switcher.
    static func isNativeSwitcher(_ modifiers: CGEventFlags, keyCode: Int64) -> Bool {
        keyCode == Int64(kVK_Tab) && modifiers.contains(.maskCommand)
    }

    /// The trigger, plus Shift+trigger (reverse) unless the trigger already includes Shift.
    static func hotKeys(for modifiers: CGEventFlags, keyCode: Int64) -> [UInt32: CarbonHotKey] {
        let code = UInt32(truncatingIfNeeded: keyCode)
        var keys = [forwardID: CarbonHotKey(keyCode: code, modifiers: carbonModifiers(modifiers))]
        if !modifiers.contains(.maskShift) {
            keys[reverseID] = CarbonHotKey(keyCode: code, modifiers: carbonModifiers(modifiers.union(.maskShift)))
        }
        return keys
    }

    static func carbonModifiers(_ flags: CGEventFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.maskCommand) { m |= UInt32(cmdKey) }
        if flags.contains(.maskAlternate) { m |= UInt32(optionKey) }
        if flags.contains(.maskShift) { m |= UInt32(shiftKey) }
        if flags.contains(.maskControl) { m |= UInt32(controlKey) }
        return m
    }
}

struct CarbonHotKey: Hashable {
    let keyCode: UInt32
    let modifiers: UInt32 // Carbon mask: cmdKey, optionKey, shiftKey, controlKey
}

/// Where the fallback registers its hotkeys: Carbon in the app, a recorder in tests.
protocol HotKeyRegistrar: AnyObject {
    /// Called with the id of a registered hotkey each time it is pressed.
    var onPress: ((UInt32) -> Void)? { get set }
    /// Returns noErr on success.
    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) -> OSStatus
    func unregister(id: UInt32)
}

/// `RegisterEventHotKey` with one `kEventHotKeyPressed` handler on the event dispatcher target.
/// The handler is installed on first use, so creating one has no side effects.
final class CarbonHotKeyRegistrar: HotKeyRegistrar {
    var onPress: ((UInt32) -> Void)?

    private static let signature: OSType = 0x4A54_6162 // 'JTab'
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?

    deinit {
        refs.values.forEach { UnregisterEventHotKey($0) }
        if let handler = handler { RemoveEventHandler(handler) }
    }

    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetEventDispatcherTarget(), carbonHotKeyCallback, 1, &spec,
                                             Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard status == noErr else { return status }
        }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: Self.signature, id: id),
                                         GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref = ref else { return status == noErr ? OSStatus(eventInternalErr) : status }
        refs[id] = ref
        return noErr
    }

    func unregister(id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
    }

    fileprivate func handle(_ event: EventRef?) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                       nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        guard status == noErr, hotKeyID.signature == Self.signature else { return OSStatus(eventNotHandledErr) }
        onPress?(hotKeyID.id)
        return noErr
    }
}

// MARK: - C Callback Bridge

private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.handleEvent(proxy, type: type, event: event)
}

private func carbonHotKeyCallback(
    next: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    return Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue().handle(event)
}

// MARK: - ShortcutSettings

/// The single user-configurable setting: the trigger shortcut (required modifier
/// flags + a key code), persisted in UserDefaults. Default is Option+Tab.
/// HotkeyManager reads this live on every event, so a change takes effect at once
/// without restarting the tap.
final class ShortcutSettings {
    static let shared = ShortcutSettings()

    /// While true, HotkeyManager passes every event through untouched so the
    /// recorder can capture keys without the switcher reacting. Not persisted.
    var isRecording = false

    private let defaults = UserDefaults.standard
    private let modsKey = "JustTab.triggerModifierFlags"
    private let keyKey = "JustTab.triggerKeyCode"

    /// Only these modifier bits are ever stored/compared (keeps values clean and small).
    static let relevantMask: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]

    /// Required modifier(s) that must be held. Default: Option.
    var modifierFlags: CGEventFlags {
        get {
            guard defaults.object(forKey: modsKey) != nil else { return .maskAlternate }
            return CGEventFlags(rawValue: UInt64(defaults.integer(forKey: modsKey)))
                .intersection(Self.relevantMask)
        }
        set { defaults.set(Int(newValue.intersection(Self.relevantMask).rawValue), forKey: modsKey) }
    }

    /// Key that activates and cycles the switcher. Default: Tab.
    var keyCode: Int64 {
        get {
            guard defaults.object(forKey: keyKey) != nil else { return Int64(kVK_Tab) }
            return Int64(defaults.integer(forKey: keyKey))
        }
        set { defaults.set(Int(newValue), forKey: keyKey) }
    }

    func set(modifierFlags: CGEventFlags, keyCode: Int64) {
        self.modifierFlags = modifierFlags
        self.keyCode = keyCode
    }

    /// Human-readable like "⌥Tab" for the menu / recorder UI.
    var displayString: String {
        var s = ""
        let m = modifierFlags
        if m.contains(.maskControl) { s += "⌃" }
        if m.contains(.maskAlternate) { s += "⌥" }
        if m.contains(.maskShift) { s += "⇧" }
        if m.contains(.maskCommand) { s += "⌘" }
        return s + Self.keyName(keyCode)
    }

    static func keyName(_ code: Int64) -> String {
        switch Int(code) {
        case kVK_Tab: return "Tab"
        case kVK_Space: return "Space"
        case kVK_ANSI_Grave: return "`"
        case kVK_Escape: return "Esc"
        default: return "key#\(code)"
        }
    }
}
