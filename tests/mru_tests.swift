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
exit(ok1 && ok2 ? 0 : 1)
