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
    private var selectedIndex: Int = 0

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

        // Clear old rows + cells
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        thumbnailViews.removeAll()

        guard !windows.isEmpty else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first!

        // How many columns fit across 90% of the screen at full cell size.
        let usableWidth = screen.frame.width * 0.9 - panelPadding * 2
        let columns = max(1, min(windows.count,
                                 Int((usableWidth + itemSpacing) / (itemWidth + itemSpacing))))
        let rows = Int(ceil(Double(windows.count) / Double(columns)))

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
                let view = ThumbnailView(windowInfo: windows[captured], width: itemWidth, height: itemHeight)
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
        let contentWidth = CGFloat(cols) * itemWidth + CGFloat(max(0, cols - 1)) * itemSpacing
        let contentHeight = CGFloat(rows) * itemHeight + CGFloat(max(0, rows - 1)) * itemSpacing
        let panelWidth = contentWidth + panelPadding * 2
        let panelHeight = contentHeight + panelPadding * 2

        let panelX = screen.frame.midX - panelWidth / 2
        let panelY = screen.frame.midY - panelHeight / 2
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

    func dismiss() {
        orderOut(nil)
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        thumbnailViews.removeAll()
    }

    // MARK: - Private

    private func handleClick(index: Int) {
        updateSelection(index: index)
        NotificationCenter.default.post(name: .switcherClickedWindow, object: nil,
                                        userInfo: ["index": index])
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

extension Notification.Name {
    static let switcherClickedWindow = Notification.Name("com.justtab.switcherClickedWindow")
}
