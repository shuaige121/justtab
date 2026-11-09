// Throwaway harness: cost of building the SwitcherPanel grid (Auto Layout cells + row stacks)
// cold vs pooled, plus CGPreflightScreenCaptureAccess per call. The panel is only ever
// ordered front at alphaValue 0 and immediately ordered out (invisible), nothing else is shown.
import Cocoa

func ms(_ block: () -> Void) -> Double {
    let t0 = DispatchTime.now().uptimeNanoseconds
    block()
    return Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
}

// CGPreflightScreenCaptureAccess cost, 20 calls
let pre = (0..<20).map { _ in ms { _ = CGPreflightScreenCaptureAccess() } }
print(String(format: "CGPreflightScreenCaptureAccess x20: min %.2f median %.2f max %.2f ms", pre.min()!, pre.sorted()[10], pre.max()!))

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

// Minimal replica of ThumbnailView (same subviews and constraint count)
final class Cell: NSView {
    let imageView = NSImageView(), title = NSTextField(labelWithString: ""), sub = NSTextField(labelWithString: ""), border = NSView()
    var wC: NSLayoutConstraint!, hC: NSLayoutConstraint!, iwC: NSLayoutConstraint!, ihC: NSLayoutConstraint!
    var isSelected = false { didSet { border.layer?.borderColor = (isSelected ? NSColor.controlAccentColor : .clear).cgColor; layer?.backgroundColor = (isSelected ? NSColor.white.withAlphaComponent(0.1) : .clear).cgColor } }
    init(width: CGFloat, height: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        wantsLayer = true
        border.wantsLayer = true; border.layer?.borderWidth = 3; border.layer?.cornerRadius = 8
        imageView.imageScaling = .scaleProportionallyUpOrDown; imageView.wantsLayer = true; imageView.layer?.cornerRadius = 6; imageView.layer?.masksToBounds = true
        title.font = .systemFont(ofSize: 11, weight: .medium); title.alignment = .center; title.lineBreakMode = .byTruncatingTail; title.maximumNumberOfLines = 1
        sub.font = .systemFont(ofSize: 10); sub.alignment = .center; sub.lineBreakMode = .byTruncatingTail; sub.maximumNumberOfLines = 1
        for v in [border, imageView, title, sub] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        wC = widthAnchor.constraint(equalToConstant: width); hC = heightAnchor.constraint(equalToConstant: height)
        iwC = imageView.widthAnchor.constraint(equalToConstant: width - 16); ihC = imageView.heightAnchor.constraint(equalToConstant: max(10, height - 50))
        NSLayoutConstraint.activate([
            border.topAnchor.constraint(equalTo: topAnchor), border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.leadingAnchor.constraint(equalTo: leadingAnchor), border.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 8), imageView.centerXAnchor.constraint(equalTo: centerXAnchor), iwC, ihC,
            title.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4), title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
            sub.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4), sub.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            wC, hC])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(_ i: Int, width: CGFloat, height: CGFloat, image: NSImage) {
        if wC.constant != width { wC.constant = width }; if hC.constant != height { hC.constant = height }
        iwC.constant = width - 16; ihC.constant = max(10, height - 50)
        isSelected = false
        title.stringValue = "Window title number \(i) — some longer text to truncate"
        sub.stringValue = "Application \(i)"
        imageView.image = image
    }
}

let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true; panel.alphaValue = 0
let backdrop = NSVisualEffectView(); backdrop.material = .hudWindow; backdrop.blendingMode = .behindWindow; backdrop.state = .active
backdrop.wantsLayer = true; backdrop.layer?.cornerRadius = 16; backdrop.layer?.masksToBounds = true
panel.contentView = backdrop
let grid = NSStackView(); grid.orientation = .vertical; grid.spacing = 14; grid.alignment = .centerX; grid.translatesAutoresizingMaskIntoConstraints = false
backdrop.addSubview(grid)
NSLayoutConstraint.activate([grid.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 24), grid.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -24),
                             grid.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 24), grid.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -24)])

var pool: [Cell] = []
let icon = NSImage(named: NSImage.applicationIconName)!
let count = 23, columns = 6, rows = 4
let cellW: CGFloat = 268, cellH: CGFloat = 214

func clearRows() {
    for row in grid.arrangedSubviews { (row as? NSStackView)?.arrangedSubviews.forEach { $0.removeFromSuperview() }; row.removeFromSuperview() }
}
func build(order: Bool) {
    clearRows()
    var index = 0
    for _ in 0..<rows {
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 14; row.alignment = .centerY
        for _ in 0..<columns {
            guard index < count else { break }
            let c: Cell
            if index < pool.count { c = pool[index] } else { c = Cell(width: cellW, height: cellH); pool.append(c) }
            c.configure(index, width: cellW, height: cellH, image: icon)
            c.isSelected = index == 1
            row.addArrangedSubview(c); index += 1
        }
        grid.addArrangedSubview(row)
    }
    let w = CGFloat(columns) * cellW + CGFloat(columns - 1) * 14 + 48, h = CGFloat(rows) * cellH + CGFloat(rows - 1) * 14 + 48
    panel.setFrame(NSRect(x: 100, y: 100, width: w, height: h), display: true)
    if order { panel.orderFrontRegardless(); panel.orderOut(nil) }
}

// Cold: pool empty, panel never shown. Then warm (pooled) x5, then with order-front/out.
let cold = ms { build(order: false) }
let coldOrder = ms { panel.orderFrontRegardless(); panel.orderOut(nil) }
let warm = (0..<5).map { _ in ms { build(order: false) } }
let warmOrder = (0..<5).map { _ in ms { build(order: true) } }
let clearOnly = ms { clearRows() }
print(String(format: "grid build (23 cells, Auto Layout): cold %.1f ms (+first orderFront/out %.1f ms), pooled median %.1f ms, pooled+orderFront/out median %.1f ms, clearRows alone %.2f ms",
             cold, coldOrder, warm.sorted()[2], warmOrder.sorted()[2], clearOnly))

// Pre-created rows variant: keep row stacks, only re-add cells (no row churn)
var rowPool: [NSStackView] = []
func buildKeepRows() {
    for row in rowPool { row.arrangedSubviews.forEach { $0.removeFromSuperview() } }
    var index = 0
    for r in 0..<rows {
        if r >= rowPool.count { let row = NSStackView(); row.orientation = .horizontal; row.spacing = 14; row.alignment = .centerY; rowPool.append(row); grid.addArrangedSubview(row) }
        for _ in 0..<columns { guard index < count else { break }; let c = pool[index]; c.configure(index, width: cellW, height: cellH, image: icon); c.isSelected = index == 1; rowPool[r].addArrangedSubview(c); index += 1 }
    }
    let w = CGFloat(columns) * cellW + CGFloat(columns - 1) * 14 + 48, h = CGFloat(rows) * cellH + CGFloat(rows - 1) * 14 + 48
    panel.setFrame(NSRect(x: 100, y: 100, width: w, height: h), display: true)
}
clearRows()
_ = ms { buildKeepRows() }
let keepRows = (0..<5).map { _ in ms { buildKeepRows() } }
print(String(format: "grid build keeping row stacks: median %.1f ms", keepRows.sorted()[2]))

// Frame-based variant: no Auto Layout, set frames directly on pooled plain cells
final class FrameCell: NSView {
    let imageView = NSImageView(), title = NSTextField(labelWithString: ""), sub = NSTextField(labelWithString: "")
    override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true; [imageView, title, sub].forEach(addSubview) ; title.alignment = .center; sub.alignment = .center; title.lineBreakMode = .byTruncatingTail; sub.lineBreakMode = .byTruncatingTail }
    required init?(coder: NSCoder) { fatalError() }
    func layoutCell(_ i: Int, image: NSImage) {
        let b = bounds
        imageView.frame = NSRect(x: 8, y: 50, width: b.width - 16, height: b.height - 58)
        title.frame = NSRect(x: 4, y: 24, width: b.width - 8, height: 18)
        sub.frame = NSRect(x: 4, y: 6, width: b.width - 8, height: 16)
        title.stringValue = "Window title number \(i) — some longer text to truncate"; sub.stringValue = "Application \(i)"; imageView.image = image
    }
}
let flat = NSView(); flat.wantsLayer = true
let panel2 = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel2.alphaValue = 0; panel2.contentView = flat
var fpool: [FrameCell] = []
func buildFrames() {
    for i in 0..<count {
        let c: FrameCell
        if i < fpool.count { c = fpool[i] } else { c = FrameCell(frame: .zero); fpool.append(c); flat.addSubview(c) }
        let col = i % columns, row = i / columns
        c.frame = NSRect(x: 24 + CGFloat(col) * (cellW + 14), y: 24 + CGFloat(rows - 1 - row) * (cellH + 14), width: cellW, height: cellH)
        c.layoutCell(i, image: icon)
    }
    let w = CGFloat(columns) * cellW + CGFloat(columns - 1) * 14 + 48, h = CGFloat(rows) * cellH + CGFloat(rows - 1) * 14 + 48
    panel2.setFrame(NSRect(x: 100, y: 100, width: w, height: h), display: true)
}
let fcold = ms { buildFrames() }
let fwarm = (0..<5).map { _ in ms { buildFrames() } }
print(String(format: "frame-based grid (no Auto Layout): cold %.1f ms, pooled median %.1f ms", fcold, fwarm.sorted()[2]))
