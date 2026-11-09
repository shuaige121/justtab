//
//  SwitcherPanel.swift
//  JustTab — minimal window switcher for macOS
//
//  The overlay UI: a centered grid of window thumbnails. Built as a
//  .nonactivatingPanel so it floats above everything without stealing focus.
//  Cells wrap into multiple rows so every window is visible without running off
//  the screen edge. NSVisualEffectView (.hudWindow) gives the frosted backdrop.
//
//  Based on alttab-macos by Sergio Farfan (MIT). Grid layout added here.
//

import Cocoa

final class SwitcherPanel: NSPanel {

    private let itemWidth: CGFloat = 300
    private let itemHeight: CGFloat = 240
    private let itemSpacing: CGFloat = 14
    private let panelPadding: CGFloat = 24

    private var gridStack: NSStackView!      // vertical stack of row stacks
    private var thumbnailViews: [ThumbnailView] = []
    /// Cells kept between openings and reused, so showing the switcher doesn't recreate
    /// every image view and label.
    private var pool: [ThumbnailView] = []
    private var selectedIndex: Int = 0
    /// Cells created at launch, so the first switch doesn't pay for building them.
    private static let prewarmedCells = 24

    /// Called with the cell index when the user clicks a window.
    var onClick: ((Int) -> Void)?

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = false

        setupUI()
        pool = (0..<Self.prewarmedCells).map { _ in ThumbnailView(width: itemWidth, height: itemHeight) }
    }

    convenience init() {
        self.init(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
    }

    // MARK: - UI Setup

    private func setupUI() {
        let backdrop = NSVisualEffectView()
        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 16
        backdrop.layer?.masksToBounds = true
        contentView = backdrop

        gridStack = NSStackView()
        gridStack.orientation = .vertical
        gridStack.spacing = itemSpacing
        gridStack.alignment = .centerX
        gridStack.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(gridStack)

        NSLayoutConstraint.activate([
            gridStack.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: panelPadding),
            gridStack.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -panelPadding),
            gridStack.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: panelPadding),
            gridStack.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -panelPadding),
        ])
    }

    // MARK: - Public API

    func show(windows: [WindowInfo], selectedIndex: Int) {
        self.selectedIndex = selectedIndex

        // Detach old rows; their cells go back to the pool.
        clearRows()

        guard !windows.isEmpty else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let area = screen.visibleFrame // excludes menu bar and Dock

        // Fit the whole grid inside 90% of the visible screen, shrinking cells when needed.
        let grid = Self.fitGrid(count: windows.count,
                                maxWidth: area.width * 0.9 - panelPadding * 2,
                                maxHeight: area.height * 0.9 - panelPadding * 2,
                                itemWidth: itemWidth, itemHeight: itemHeight,
                                spacing: itemSpacing)
        let columns = grid.columns
        let rows = grid.rows
        let cellWidth = (itemWidth * grid.scale).rounded(.down)
        let cellHeight = (itemHeight * grid.scale).rounded(.down)

        // Build the grid row by row.
        var index = 0
        for _ in 0..<rows {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.spacing = itemSpacing
            rowStack.alignment = .centerY
            for _ in 0..<columns {
                guard index < windows.count else { break }
                let captured = index
                let view: ThumbnailView
                if captured < pool.count {
                    view = pool[captured]
                } else {
                    view = ThumbnailView(width: cellWidth, height: cellHeight)
                    pool.append(view)
                }
                view.configure(with: windows[captured], width: cellWidth, height: cellHeight)
                view.isSelected = (captured == selectedIndex)
                view.onClicked = { [weak self] in self?.handleClick(index: captured) }
                rowStack.addArrangedSubview(view)
                thumbnailViews.append(view)
                index += 1
            }
            gridStack.addArrangedSubview(rowStack)
        }

        // Panel size = grid content + padding (width based on the fullest row).
        let cols = min(columns, windows.count)
        let contentWidth = CGFloat(cols) * cellWidth + CGFloat(max(0, cols - 1)) * itemSpacing
        let contentHeight = CGFloat(rows) * cellHeight + CGFloat(max(0, rows - 1)) * itemSpacing
        let panelWidth = contentWidth + panelPadding * 2
        let panelHeight = contentHeight + panelPadding * 2

        let panelX = area.midX - panelWidth / 2
        let panelY = area.midY - panelHeight / 2
        setFrame(NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight), display: true)

        orderFrontRegardless()
    }

    func updateSelection(index: Int) {
        guard index >= 0, index < thumbnailViews.count,
              selectedIndex >= 0, selectedIndex < thumbnailViews.count else { return }
        thumbnailViews[selectedIndex].isSelected = false
        selectedIndex = index
        thumbnailViews[selectedIndex].isSelected = true
    }

    /// Swaps in a fresh picture for one cell without touching the rest of the grid.
    func updateImage(at index: Int, image: NSImage) {
        guard thumbnailViews.indices.contains(index) else { return }
        thumbnailViews[index].setThumbnail(image)
    }

    func dismiss() {
        orderOut(nil)
        clearRows()
    }

    private func clearRows() {
        for row in gridStack.arrangedSubviews {
            (row as? NSStackView)?.arrangedSubviews.forEach { $0.removeFromSuperview() }
            row.removeFromSuperview()
        }
        thumbnailViews.removeAll()
    }

    /// Chooses the column count that lets `count` cells fit in `maxWidth` x `maxHeight` at the
    /// largest scale (capped at 1 = full size). Ties go to more columns, so a handful of windows
    /// still shows as a single row like before; only the cells shrink, spacing stays fixed.
    static func fitGrid(count: Int, maxWidth: CGFloat, maxHeight: CGFloat,
                        itemWidth: CGFloat, itemHeight: CGFloat,
                        spacing: CGFloat) -> (columns: Int, rows: Int, scale: CGFloat) {
        guard count > 0 else { return (1, 0, 1) }
        var best: (columns: Int, rows: Int, scale: CGFloat) = (1, count, -1)
        for columns in stride(from: count, through: 1, by: -1) {
            let rows = (count + columns - 1) / columns
            let widthScale = (maxWidth - CGFloat(columns - 1) * spacing) / (CGFloat(columns) * itemWidth)
            let heightScale = (maxHeight - CGFloat(rows - 1) * spacing) / (CGFloat(rows) * itemHeight)
            let scale = min(1, widthScale, heightScale)
            if scale > best.scale + 0.0001 { best = (columns, rows, scale) }
        }
        best.scale = max(best.scale, 0.05)
        return best
    }

    // MARK: - Private

    private func handleClick(index: Int) {
        updateSelection(index: index)
        onClick?(index)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
