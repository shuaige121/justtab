import Cocoa
// Windows the on-screen pass did not list: which ones the switcher shows, and how they are marked.
var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    print((ok ? "PASS " : "FAIL ") + name + (detail.isEmpty ? "" : "  [\(detail)]")); if !ok { failures += 1 }
}
typealias Attrs = WindowModel.AXWindowAttributes
let standard = kAXStandardWindowSubrole as String
let size = CGSize(width: 800, height: 600)
func entry(_ a: Attrs, appHidden: Bool = false, id: CGWindowID = 42) -> WindowInfo? {
    WindowModel.offScreenWindow(id: id, pid: 123, name: "App", appHidden: appHidden, attributes: a)
}
func kind(_ w: WindowInfo?) -> String {
    guard let w = w else { return "skip" }
    let flags = [(w.isMinimized, "minimized"), (w.isHidden, "hidden"),
                 (w.isOnOtherSpace, "otherSpace"), (w.isFrontOfApp, "front")]
    return flags.filter { $0.0 }.map { $0.1 }.joined(separator: "+")
}

let cases: [(String, Attrs, Bool, String)] = [
    ("minimized window", Attrs(minimized: true, subrole: standard, size: size), false, "minimized"),
    ("minimized window of a hidden app", Attrs(minimized: true, subrole: standard, size: size), true, "minimized+hidden"),
    ("minimized non-standard window still listed", Attrs(minimized: true, subrole: "AXDialog"), false, "minimized"),
    ("standard window of a hidden app", Attrs(subrole: standard, size: size), true, "hidden"),
    ("standard window, app not hidden: other Space", Attrs(subrole: standard, size: size), false, "otherSpace"),
    ("dialog skipped", Attrs(subrole: "AXDialog", size: size), false, "skip"),
    ("floating palette skipped", Attrs(subrole: "AXFloatingWindow", size: size), true, "skip"),
    ("no subrole skipped", Attrs(size: size), false, "skip"),
    ("zero-size window skipped", Attrs(subrole: standard, size: .zero), false, "skip"),
    ("zero-width window skipped", Attrs(subrole: standard, size: CGSize(width: 0, height: 300)), false, "skip"),
    ("zero-height window of a hidden app skipped", Attrs(subrole: standard, size: CGSize(width: 300, height: 0)), true, "skip"),
    ("window without a size skipped", Attrs(subrole: standard), false, "skip"),
]
for (name, attrs, appHidden, want) in cases {
    let got = kind(entry(attrs, appHidden: appHidden))
    check(name, got == want, "got \(got), want \(want)")
}
check("window ID 0 skipped", entry(Attrs(minimized: true), id: 0) == nil)
let titled = entry(Attrs(subrole: standard, size: size, title: "Report"), appHidden: true)
check("entry keeps id, owner and title",
      titled?.windowID == 42 && titled?.ownerPID == 123 && titled?.ownerName == "App" && titled?.windowTitle == "Report")

// Decoding the single AXUIElementCopyMultipleAttributeValues read (minimized, subrole, size, title).
var sz = CGSize(width: 640, height: 480)
let sizeValue = AXValueCreate(.cgSize, &sz)!
var err = AXError.attributeUnsupported
let missing = AXValueCreate(.axError, &err)! // what AX returns for an attribute the window lacks
let full = Attrs([kCFBooleanFalse!, standard as CFString, sizeValue, "Doc" as CFString])
check("decodes all four attributes",
      !full.minimized && full.subrole == standard && full.size == sz && full.title == "Doc", "\(full)")
let none = Attrs([missing, missing, missing, missing])
check("missing attributes keep their defaults",
      !none.minimized && none.subrole == nil && none.size == nil && none.title.isEmpty, "\(none)")
let minimizedOnly = Attrs([kCFBooleanTrue!, missing, missing, missing])
check("minimized window lacking the other attributes is listed", kind(entry(minimizedOnly)) == "minimized")
check("unexpected value count decodes to defaults", !Attrs([kCFBooleanTrue!]).minimized)

print(failures == 0 ? "ALL WINDOW LIST TESTS PASSED" : "\(failures) WINDOW LIST FAILURES"); exit(failures == 0 ? 0 : 1)
