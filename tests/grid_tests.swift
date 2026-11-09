import Cocoa
// Screens: this Mac's current display (2048x1122 visible) and a 1512x949 laptop panel.
let screens: [(String, CGFloat, CGFloat)] = [("PA329CRV 2048x1122", 2048, 1122), ("laptop 1512x949", 1512, 949)]
let pad: CGFloat = 24, sp: CGFloat = 14, iw: CGFloat = 300, ih: CGFloat = 240
var fails = 0
for (name, w, h) in screens {
    let maxW = w * 0.9 - pad * 2, maxH = h * 0.9 - pad * 2
    var oldOverflowFrom: Int? = nil
    for n in 1...120 {
        let g = SwitcherPanel.fitGrid(count: n, maxWidth: maxW, maxHeight: maxH, itemWidth: iw, itemHeight: ih, spacing: sp)
        let cw = (iw * g.scale).rounded(.down), ch = (ih * g.scale).rounded(.down)
        let cols = min(g.columns, n)
        let panelW = CGFloat(cols) * cw + CGFloat(cols - 1) * sp + pad * 2
        let panelH = CGFloat(g.rows) * ch + CGFloat(g.rows - 1) * sp + pad * 2
        let fits = panelW <= w && panelH <= h && g.columns * g.rows >= n && g.scale <= 1
        if !fits { fails += 1; print("FAIL \(name) n=\(n) \(g) panel=\(panelW)x\(panelH)") }
        // Old formula, for comparison
        let oldCols = max(1, min(n, Int((maxW + sp) / (iw + sp))))
        let oldRows = (n + oldCols - 1) / oldCols
        let oldH = CGFloat(oldRows) * ih + CGFloat(oldRows - 1) * sp + pad * 2
        if oldH > h && oldOverflowFrom == nil { oldOverflowFrom = n }
        if n <= Int((maxW + sp) / (iw + sp)) && !(g.rows == 1 && g.scale == 1) { fails += 1; print("FAIL small n=\(n) should stay one full-size row: \(g)") }
        if [5, 17, 22, 40, 85].contains(n) { print("\(name) n=\(n): \(g.columns)x\(g.rows) scale=\(String(format: "%.2f", g.scale)) panel=\(Int(panelW))x\(Int(panelH))  old panel height=\(Int(oldH))") }
    }
    print("\(name): old layout runs off screen from n=\(oldOverflowFrom ?? -1) windows")
}
print(fails == 0 ? "ALL GRID TESTS PASSED (n=1...120, 2 screens)" : "\(fails) GRID FAILURES"); exit(fails == 0 ? 0 : 1)
