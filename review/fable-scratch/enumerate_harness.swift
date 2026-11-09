// Throwaway harness: times the pieces of WindowModel.enumerateWindows() in isolation.
// Read-only: no prompts (AXIsProcessTrusted without options; CGPreflight only), no events.
import Cocoa
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

func ms(_ block: () -> Void) -> Double {
    let t0 = DispatchTime.now().uptimeNanoseconds
    block()
    return Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
}

func parse(_ info: [String: Any]) -> (CGWindowID, pid_t, String)? {
    guard let id = info[kCGWindowNumber as String] as? CGWindowID,
          let pid = info[kCGWindowOwnerPID as String] as? pid_t,
          let owner = info[kCGWindowOwnerName as String] as? String,
          let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
          let b = info[kCGWindowBounds as String] as? [String: CGFloat],
          let w = b["Width"], let h = b["Height"], w > 0, h > 0 else { return nil }
    return (id, pid, owner)
}

_ = NSApplication.shared
print("AXIsProcessTrusted:", AXIsProcessTrusted(), " CGPreflightScreenCaptureAccess:", CGPreflightScreenCaptureAccess())

// 1. CGWindowListCopyWindowInfo + bridge + parse
var rawCount = 0, parsedCount = 0
var times: [Double] = []
for _ in 0..<11 {
    times.append(ms {
        if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            rawCount = list.count
            parsedCount = list.compactMap(parse).count
        }
    })
}
print(String(format: "CGWindowList: raw=%d layer0=%d  cold %.2f ms, warm median %.2f ms", rawCount, parsedCount, times[0], times.dropFirst().sorted()[5]))

// Bridging share: raw CFArray only
let rawOnly = (0..<5).map { _ in ms { _ = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) } }
print(String(format: "CGWindowList raw CF only: median %.2f ms", rawOnly.sorted()[2]))

// 2. NSWorkspace.runningApplications filter
let raTimes = (0..<6).map { _ in ms {
    _ = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map { ($0.processIdentifier, $0.localizedName ?? "") }
} }
let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != getpid() }
print(String(format: "runningApplications (%d regular): cold %.2f ms, warm median %.2f ms", apps.count, raTimes[0], raTimes.dropFirst().sorted()[2]))

// 3. Permission checks (polled every 2 s in the app)
let axT = (0..<5).map { _ in ms { _ = AXIsProcessTrusted() } }
let srT = (0..<5).map { _ in ms { _ = CGPreflightScreenCaptureAccess() } }
print(String(format: "AXIsProcessTrusted median %.3f ms, CGPreflightScreenCaptureAccess median %.3f ms", axT.sorted()[2], srT.sorted()[2]))

// 4. Icons (prewarm cost)
let iconT = ms { for a in apps { _ = a.icon } }
let iconT2 = ms { for a in apps { _ = a.icon } }
print(String(format: "NSRunningApplication.icon x%d: first %.1f ms, second %.1f ms", apps.count, iconT, iconT2))

// 5. AX pass (only meaningful if trusted)
guard AXIsProcessTrusted() else { print("AX not trusted for this host process; skipping AX timings"); exit(0) }
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)

func scan(_ pid: pid_t) -> (Int, Double) {
    var n = 0
    let t = ms {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &ref) == .success, let ws = ref as? [AXUIElement] {
            for w in ws {
                var id: CGWindowID = 0
                _ = _AXUIElementGetWindow(w, &id)
                var m: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &m)
                n += 1
            }
        }
    }
    return (n, t)
}

// cold sequential, per app
print("AX cold per app (sequential):")
var coldTotal = 0.0
for a in apps {
    let (n, t) = scan(a.processIdentifier)
    coldTotal += t
    print(String(format: "  %-28@ windows=%2d  %.1f ms", (a.localizedName ?? "?") as NSString, n, t))
}
print(String(format: "AX cold sequential total: %.1f ms", coldTotal))

// warm sequential
let warmSeq = (0..<5).map { _ in ms { for a in apps { _ = scan(a.processIdentifier) } } }
print(String(format: "AX warm sequential: median %.1f ms", warmSeq.sorted()[2]))

// warm parallel
let pids = apps.map { $0.processIdentifier }
let warmPar = (0..<5).map { _ in ms {
    var out = [Double](repeating: 0, count: pids.count)
    out.withUnsafeMutableBufferPointer { buf in
        DispatchQueue.concurrentPerform(iterations: pids.count) { i in buf[i] = scan(pids[i]).1 }
    }
} }
print(String(format: "AX warm concurrentPerform: median %.1f ms", warmPar.sorted()[2]))

// kAXFocusedWindow (what promoteAppWindows does on main)
let focusT = apps.prefix(5).map { a -> Double in ms {
    let app = AXUIElementCreateApplication(a.processIdentifier)
    var ref: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &ref)
} }
print("kAXFocusedWindow per app (first 5):", focusT.map { String(format: "%.1f", $0) }.joined(separator: " "), "ms")

// kAXWindows alone for the app with most windows (what raiseWindow pays)
if let big = apps.max(by: { scan($0.processIdentifier).0 < scan($1.processIdentifier).0 }) {
    let app = AXUIElementCreateApplication(big.processIdentifier)
    let t = (0..<5).map { _ in ms { var ref: CFTypeRef?; _ = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &ref) } }
    var ref: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &ref)
    let ws = (ref as? [AXUIElement]) ?? []
    let getWin = ms { for w in ws { var id: CGWindowID = 0; _ = _AXUIElementGetWindow(w, &id) } }
    print(String(format: "kAXWindows for %@ (%d windows): median %.1f ms; _AXUIElementGetWindow x%d: %.2f ms", (big.localizedName ?? "?") as NSString, ws.count, t.sorted()[2], ws.count, getWin))
}
