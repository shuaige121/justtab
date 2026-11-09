//
//  WindowCapture.swift
//  JustTab — minimal window switcher for macOS
//
//  Live window thumbnails via ScreenCaptureKit (macOS 14+). Requires Screen
//  Recording permission; without it capture is skipped and app icons are shown.
//  Minimized windows aren't on-screen, so they keep the icon fallback too.
//
//  Latency: the last thumbnail of every window is cached, so the switcher opens
//  with an image straight away; fresh captures run concurrently and replace the
//  cached ones when they arrive. Each window is downscaled to keep capture cheap.
//
//  Based on alttab-macos by Sergio Farfan (MIT). Thumbnail capture re-added here.
//

import Cocoa
import ScreenCaptureKit

final class WindowCapture {

    /// Returns whether Screen Recording is granted. Capture is skipped without it, so a
    /// denied permission can't make macOS re-prompt in the middle of a switch.
    var isAllowed: () -> Bool = { CGPreflightScreenCaptureAccess() }

    /// How many windows are captured at the same time.
    static let maxConcurrentCaptures = 8

    /// Last thumbnail per window. Main thread only.
    private var cache: [CGWindowID: NSImage] = [:]

    /// Fills in cached thumbnails so the panel can show images immediately.
    func applyCached(to windows: [WindowInfo]) -> [WindowInfo] {
        let live = Set(windows.map { $0.windowID })
        cache = cache.filter { live.contains($0.key) } // drop closed windows
        return windows.map { w in
            var w = w
            if !w.isMinimized, w.thumbnail == nil { w.thumbnail = cache[w.windowID] }
            return w
        }
    }

    /// Captures fresh thumbnails asynchronously, then calls `completion` on the main
    /// thread with the enriched array (same order) and how many images were captured.
    func captureThumbnails(for windows: [WindowInfo], completion: @escaping ([WindowInfo], Int) -> Void) {
        guard #available(macOS 14.0, *), isAllowed() else {
            completion(windows, 0) // older macOS or no Screen Recording: icons only
            return
        }
        Task {
            let (updated, fresh) = await Self.capture(windows)
            await MainActor.run {
                for (id, image) in fresh { self.cache[id] = image }
                completion(updated, fresh.count)
            }
        }
    }

    @available(macOS 14.0, *)
    private static func capture(_ windows: [WindowInfo]) async -> ([WindowInfo], [CGWindowID: NSImage]) {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            justTabLog.error("ScreenCaptureKit unavailable: \(error.localizedDescription, privacy: .public)")
            return (windows, [:])
        }

        var scByID: [CGWindowID: SCWindow] = [:]
        for w in content.windows { scByID[w.windowID] = w }
        let targets: [(Int, SCWindow)] = windows.indices.compactMap { i in
            guard !windows[i].isMinimized, let sc = scByID[windows[i].windowID] else { return nil }
            return (i, sc)
        }

        var fresh: [Int: NSImage] = [:]
        var next = 0
        await withTaskGroup(of: (Int, NSImage?).self) { group in
            func addNext() {
                guard next < targets.count else { return }
                let (index, sc) = targets[next]
                next += 1
                group.addTask { (index, await captureOne(sc)) }
            }
            for _ in 0..<min(maxConcurrentCaptures, targets.count) { addNext() }
            for await (index, image) in group {
                if let image = image { fresh[index] = image }
                addNext()
            }
        }

        var result = windows
        var byID: [CGWindowID: NSImage] = [:]
        for (index, image) in fresh {
            result[index].thumbnail = image
            byID[result[index].windowID] = image
        }
        return (result, byID)
    }

    @available(macOS 14.0, *)
    private static func captureOne(_ scWindow: SCWindow) async -> NSImage? {
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        // Downscale to ~half size: thumbnails don't need full resolution and this
        // keeps both capture latency and memory use low when many windows are open.
        config.width = max(1, Int(scWindow.frame.width * 0.5))
        config.height = max(1, Int(scWindow.frame.height * 0.5))
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
