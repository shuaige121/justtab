import Cocoa
let m = WindowModel()
m.mruOrder = [5, 42]
m.pruneMRU(ids: [9, 3, 5, 7, 1, 8, 2])
let ok1 = m.mruOrder == [5, 9, 3, 7, 1, 8, 2]
m.promoteToFront(windowID: 7)
m.pruneMRU(ids: [11, 9, 3, 5, 7, 1, 8, 2])
let ok2 = m.mruOrder == [7, 5, 9, 3, 1, 8, 2, 11]
print(ok1 ? "PASS new windows appended in stacking order, closed dropped" : "FAIL \(m.mruOrder)")
print(ok2 ? "PASS promote + later new window appended at end" : "FAIL \(m.mruOrder)")

// Focus changes reorder only when they come from the frontmost app.
let front: pid_t = 100, background: pid_t = 200
m.mruOrder = [7, 5, 9]
var lookedUp = false
m.focusedWindowChanged(pid: background, frontmostPID: front) { lookedUp = true; return 9 }
let ok3 = m.mruOrder == [7, 5, 9] && !lookedUp
print(ok3 ? "PASS background app's focus change does not reorder" : "FAIL \(m.mruOrder) lookedUp=\(lookedUp)")
m.focusedWindowChanged(pid: front, frontmostPID: front) { 9 }
let ok4 = m.mruOrder == [9, 7, 5]
print(ok4 ? "PASS frontmost app's focus change promotes its window" : "FAIL \(m.mruOrder)")
m.focusedWindowChanged(pid: front, frontmostPID: nil) { 5 }
m.focusedWindowChanged(pid: front, frontmostPID: front) { 0 }
let ok5 = m.mruOrder == [9, 7, 5]
print(ok5 ? "PASS no frontmost app or no window: no reorder" : "FAIL \(m.mruOrder)")
// A window picked in the switcher stays first when a background app's focus changes next.
m.didSwitch(to: WindowInfo(windowID: 5, ownerPID: front, ownerName: "A", windowTitle: "", isMinimized: false))
m.focusedWindowChanged(pid: background, frontmostPID: front) { 7 }
let ok6 = m.mruOrder == [5, 9, 7]
print(ok6 ? "PASS switched-to window keeps first place over background churn" : "FAIL \(m.mruOrder)")
exit(ok1 && ok2 && ok3 && ok4 && ok5 && ok6 ? 0 : 1)
