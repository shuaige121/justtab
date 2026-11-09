//
//  WindowCapture.swift
//  JustTab — minimal window switcher for macOS
//
//  Live window thumbnails via ScreenCaptureKit (macOS 14+). Requires Screen
//  Recording permission; without it capture is skipped and app icons are shown.
//  Minimized windows aren't on-screen, so they keep the icon fallback too.
//
//  Latency: the last thumbnail of every window is cached, so the switcher opens
//  with an image straight away. Fresh captures run concurrently, the selected
//  window first, and each one is shown as soon as it arrives. Captures are sized
//  to what a cell can display and are cancelled when the switcher closes.
//
//  Based on alttab-macos by Sergio Farfan (MIT). Thumbnail capture re-added here.
//

import Cocoa
import ScreenCaptureKit

final class WindowCapture {

    /// Returns whether Screen Recording is granted. Capture is skipped without it, so a
    /// denied permission can't make macOS re-prompt in the middle of a switch.
    var isAllowed: () -> Bool = { false }

    /// How many windows are captured at the same time.
    static let maxConcurrentCaptures = 8
    /// Longest side of a captured thumbnail, in pixels. A cell shows at most ~568×380 px.
    static let maxThumbnailPixels: CGFloat = 640

    /// Last thumbnail per window and the activation that captured it. Main thread only.
    private var cache: [CGWindowID: (generation: Int, image: NSImage)] = [:]
    private var contentTask: Task<SCShareableContent?, Never>?
    private var captureTask: Task<Void, Never>?

    /// Fills in cached thumbnails so the panel can show images immediately.
    func applyCached(to windows: [WindowInfo]) -> [WindowInfo] {
        let live = Set(windows.map { $0.windowID })
        cache = cache.filter { live.contains($0.key) } // drop closed windows
        return windows.map { w in
            var w = w
            if !w.isMinimized, w.thumbnail == nil { w.thumbnail = cache[w.windowID]?.image }
            return w
        }
    }

    /// Starts fetching the capturable window list. Called before the window list is built,
    /// so the two overlap; `captureThumbnails` picks the result up.
    func prefetchContent() {
        guard #available(macOS 14.0, *), isAllowed() else { return }
        contentTask = Task {
            do {
                return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            } catch {
                justTabLog.error("ScreenCaptureKit unavailable: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }

    /// Captures fresh thumbnails, `windows[first]` first. `onImage(index, image)` runs on the
    /// main thread for each one as it arrives; `onDone(count)` runs once at the end.
    /// `generation` (the activation number) keeps a late, older capture from replacing a
    /// newer cached one.
    func captureThumbnails(for windows: [WindowInfo], first: Int, generation: Int,
                           onImage: @escaping (Int, NSImage) -> Void,
                           onDone: @escaping (Int) -> Void) {
        guard #available(macOS 14.0, *), isAllowed() else {
            onDone(0) // older macOS or no Screen Recording: icons only
            return
        }
        if contentTask == nil { prefetchContent() }
        let content = contentTask
        contentTask = nil
        captureTask?.cancel()
        captureTask = Task {
            guard let shareable = await content?.value else {
                await MainActor.run { onDone(0) }
                return
            }
            var scByID: [CGWindowID: SCWindow] = [:]
            for w in shareable.windows { scByID[w.windowID] = w }
            let order = windows.indices.contains(first)
                ? [first] + windows.indices.filter { $0 != first } : Array(windows.indices)
            let targets: [(Int, SCWindow)] = order.compactMap { i in
                guard !windows[i].isMinimized, let sc = scByID[windows[i].windowID] else { return nil }
                return (i, sc)
            }

            var captured = 0
            var next = 0
            await withTaskGroup(of: (Int, NSImage?).self) { group in
                func addNext() {
                    guard next < targets.count, !Task.isCancelled else { return }
                    let (index, sc) = targets[next]
                    next += 1
                    group.addTask { (index, await Self.captureOne(sc)) }
                }
                for _ in 0..<min(Self.maxConcurrentCaptures, targets.count) { addNext() }
                for await (index, image) in group {
                    if let image = image {
                        captured += 1
                        let id = windows[index].windowID
                        DispatchQueue.main.async {
                            if (self.cache[id]?.generation ?? .min) <= generation {
                                self.cache[id] = (generation, image)
                            }
                            onImage(index, image)
                        }
                    }
                    addNext()
                }
            }
            let total = captured
            DispatchQueue.main.async { onDone(total) }
        }
    }

    /// Stops queueing captures for a switcher that has closed. Ones already running finish
    /// and still refresh the cache.
    func cancel() {
        captureTask?.cancel()
        captureTask = nil
        contentTask = nil
    }

    /// Opens the connection to the capture service ahead of the first switch. Lists windows
    /// only; nothing is captured.
    func prewarm() {
        guard #available(macOS 14.0, *), isAllowed() else { return }
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { _, _ in }
    }

    @available(macOS 14.0, *)
    private static func captureOne(_ scWindow: SCWindow) async -> NSImage? {
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        // Points → pixels at 1:1, capped so the longest side fits what a cell can show.
        let size = scWindow.frame.size
        let scale = min(1, maxThumbnailPixels / max(1, max(size.width, size.height)))
        config.width = max(1, Int(size.width * scale))
        config.height = max(1, Int(size.height * scale))
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true

        do {
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            return nil // this window failed; keep its icon or cached image
        }
    }
}
