//
//  WindowCapture.swift
//  JustTab — minimal window switcher for macOS
//
//  Live window thumbnails via ScreenCaptureKit (macOS 14+). Requires Screen
//  Recording permission; if it's missing, capture throws and we fall back to
//  app icons (thumbnail stays nil). Minimized windows aren't on-screen, so they
//  keep the icon fallback too. Each window is downscaled to keep capture cheap.
//
//  Based on alttab-macos by Sergio Farfan (MIT). Thumbnail capture re-added here.
//

import Cocoa
import ScreenCaptureKit

final class WindowCapture {

    /// Returns whether Screen Recording is granted. Capture is skipped without it, so a
    /// denied permission can't make macOS re-prompt in the middle of a switch.
    var isAllowed: () -> Bool = { CGPreflightScreenCaptureAccess() }

    /// Captures thumbnails for on-screen windows asynchronously, then calls
    /// `completion` on the main thread with the enriched WindowInfo array.
    func captureThumbnails(for windows: [WindowInfo], completion: @escaping ([WindowInfo]) -> Void) {
        guard #available(macOS 14.0, *), isAllowed() else {
            completion(windows) // older macOS or no Screen Recording: icons only
            return
        }
        Task {
            let updated = await Self.capture(windows)
            await MainActor.run { completion(updated) }
        }
    }

    @available(macOS 14.0, *)
    private static func capture(_ windows: [WindowInfo]) async -> [WindowInfo] {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            NSLog("JustTab: ScreenCaptureKit unavailable (Screen Recording not granted?): \(error.localizedDescription)")
            return windows
        }

        // Index SCWindows by CGWindowID for matching against our enumerated windows.
        var scByID: [CGWindowID: SCWindow] = [:]
        for w in content.windows { scByID[w.windowID] = w }

        var result = windows
        for i in result.indices {
            guard !result[i].isMinimized, let scWindow = scByID[result[i].windowID] else { continue }
            if let image = await captureOne(scWindow) {
                result[i].thumbnail = image
            }
        }
        return result
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
            return nil // this window failed; keep its icon fallback
        }
    }
}
