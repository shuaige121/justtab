# JustTab review (Fable): latency cuts and lighter code

Scope: read-only review of `src/*.swift` (2,034 lines) against `brief.md`. No source edited, nothing built or run except two throwaway timing harnesses under `fable-scratch/` (`enumerate_harness.swift`, `panel_harness.swift`), compiled with `swiftc -O` and run on this Mac (macOS 27.0.1, Apple Silicon, 14 cores, 13 regular apps / 21 layer-0 windows at the time; the owner's measurements were with 23 windows). Harness numbers are labelled "measured (harness)"; they measure the same API calls the app makes, not the app itself.

Harness results used below (medians unless stated):

| Call | Cold | Warm |
|---|---|---|
| `CGPreflightScreenCaptureAccess()` | – | **8.4 ms per call** (20 calls: min 7.6, max 14.6) |
| `AXIsProcessTrusted()` | – | 0.000 ms |
| `CGWindowListCopyWindowInfo` + bridge + parse | 10.0 ms | 0.35 ms (raw CF only 0.21) |
| `NSWorkspace.runningApplications` filter | 9.3 ms | 0.01 ms |
| `kAXWindows` + per-window `_AXUIElementGetWindow`/`kAXMinimized`, per app | **12–48 ms each, 392 ms for 13 apps sequential** | 6.4 ms sequential, 1.5 ms `concurrentPerform` |
| `kAXWindows` alone, 12-window app | – | 0.2 ms; `_AXUIElementGetWindow` 0.03 ms each |
| `kAXFocusedWindow` per app | – | 0.0–0.1 ms |
| `NSRunningApplication.icon`, 13 apps | 6.3 ms total | 0.0 |
| Grid build, 23 Auto Layout cells + new row stacks + `setFrame(display:true)` | 20.5 ms | 4.4 ms pooled (3.5 ms with pooled row stacks) |
| Same, frame-based cells (no Auto Layout) | 7.4 ms | 0.3 ms |
| `clearRows()` alone (23 cells) | – | 1.8 ms |
| First `orderFrontRegardless` + `orderOut` of the panel | 1.5 ms | – |

Two things the harness could not measure without side effects, so they stay estimates: ScreenCaptureKit calls (`SCShareableContent`, `captureImage`; the harness process would trigger a TCC prompt) and `kAXRaise`/`kAXMain` (would reorder the user's windows).

---

## Latency (ranked)

Ranked by expected gain per effort. (a) cold open, (b) warm open, (c) time to fresh thumbnails, (d) raise after release.

1. **Stop calling `CGPreflightScreenCaptureAccess()` on the activation path; read the state PermissionManager already polls.** `AppDelegate.swift:44` wires `windowCapture.isAllowed` to `permissionManager.hasScreenRecording`, which is `env.hasScreenRecording()` (`PermissionManager.swift:90`), i.e. a live TCC round-trip, evaluated inside `captureThumbnails` (`WindowCapture.swift:45`) before `show()` runs. PermissionManager already holds `screenRecordingGranted` (`PermissionManager.swift:82,120`); expose it and return that. Gain: ~8 ms off (a) and (b), on the main thread, before the panel is ordered front; also removes two more calls per 2 s tick (`PermissionManager.swift:119` and `:158`, ~17 ms of main-thread stall every 2 s). Effort S. Risk: state is up to 2 s stale right after the user grants permission; acceptable. Evidence: measured (harness), 8.4 ms per call.

2. **Prewarm the per-app Accessibility pass at launch (off main) and ~2 s after each app launch.** `WindowModel.swift:116-149` runs `scanApp` for every regular app on the first switch; the first `kAXWindows` query to a process is the expensive part. `init()` (`WindowModel.swift:93-102`) already touches each app via `AXObserverAddNotification` but never asks for windows. Add a `DispatchQueue.global(qos: .utility).async { concurrentPerform(scanApp...) }` after `installAXObserversForRunningApps()`, and in the `didLaunchApplicationNotification` observer (`WindowModel.swift:327-333`) schedule one `scanApp` for the new PID after a delay. Gain: (a) cold list 142 ms → close to the warm 24 ms, i.e. −100 to −118 ms on cold open. Effort S (reuses `scanApp`, which is already static and thread-safe per app). Risk: low; the same AX initialization cost moves from first switch to launch; apps launched after JustTab are cold until the delayed scan runs. Evidence: measured (harness) for the per-app cold cost (12–48 ms/app, 392 ms sequential for 13 apps, warm 1.5 ms parallel); attribution of the owner's 142−24 ms delta to this is estimate.

3. **Deliver thumbnails one by one as each capture finishes instead of after the whole task group.** `WindowCapture.swift:77-89` collects all results, then `:51-54` calls `completion` once; `AppDelegate.swift:122-128` replaces `currentWindows` and `SwitcherPanel.swift:153-159` repaints every cell. With 8 concurrent captures and 22 windows, cells 1–8 (including the preselected index 1) could update after the first round instead of after the third. Add `onImage: (index, NSImage) -> Void` dispatched via `MainActor.run` inside the `for await` loop, guarded by `activationID`. Gain for (c): first fresh images at roughly 1/3 of the current 301/469 ms (estimate ~100–150 ms warm), the last one unchanged. Effort M (small code, but touches three files and allows deleting the `updatedWindows` plumbing, see Lighter code 6). Risk: 22 main-thread hops instead of one; each is a single `imageView.image =`. Evidence: estimate (based on 22 windows / 8 concurrent = 3 rounds).

4. **Start the `SCShareableContent` fetch before `enumerateWindows()`, not after.** `AppDelegate.swift:108` blocks main for 24–142 ms enumerating, then `:122` → `WindowCapture.swift:62` starts the content fetch. Create the `Task` for `SCShareableContent.excludingDesktopWindows` at the top of `hotkeyDidActivate` and hand it to `captureThumbnails`. Gain for (c): min(list time, fetch time), i.e. up to ~24 ms warm and up to ~100 ms cold before item 2 lands. Effort S. Risk: none; the fetch does not depend on the window list. Evidence: estimate (fetch cost not measurable here without a TCC prompt; commonly tens of ms).

5. **Prewarm ScreenCaptureKit at launch when Screen Recording is already granted.** `PermissionManager.swift:46-48` only touches SCK when permission is missing (to register the app); when it is granted nothing warms the capture service until the first switch. Once, off main, after the first `check()` reports granted: one `SCShareableContent` fetch and one tiny `SCScreenshotManager.captureImage`. Gain for (a)+(c): most of the 469−301 = 168 ms cold thumbnail delta. Effort S. Risk: must be gated on the cached granted flag (never call SCK ungranted at launch, it prompts). Evidence: estimate (cold delta from the brief; cause attribution is mine).

6. **Skip the AX raise when the selected window is already its app's frontmost (or only) window.** `WindowActivator.swift:41-50` always activates then runs `raiseWindow`. The harness shows our side of the raise is cheap (`kAXWindows` 0.2 ms, `_AXUIElementGetWindow` 0.03 ms), so the 17–93 ms is the target app answering `kAXRaise`/`kAXMain` while it is itself activating. `enumerateWindows` sees the CG list front-to-back (`WindowModel.swift:125-132`), so the first window per PID is that app's front window; record `isFrontOfApp` in `WindowInfo` and when it is set and not minimized, `app.activate` alone brings it up. Gain for (d): 17–93 ms → ~0 for the most common switch (another app's front window). Effort S. Risk: medium-low; an app whose key window is not its CG-front layer-0 window would come up with the wrong window key; keep the AX path when the flag is false. Also try sending the AX raise *before* `activate` (the app answers while idle) and measure. Evidence: measured (harness) for the cheap half; the rest estimate.

7. **Keep the `AXUIElement` per window from the enumeration pass; one AX fetch for unminimize+raise.** `WindowModel.swift:183-186` already maps every AX window to its CGWindowID; `WindowActivator.swift:62` and `:82` each re-fetch `kAXWindows` (two round-trips for a minimized window) and loop again. Store `[CGWindowID: AXUIElement]` alongside the result (AXUIElement is an immutable CF token, fine to hand to `axQueue`), raise it directly, fall back to the current path if the action fails. Gain for (d): ~0.5 ms warm (measured), tens of ms if the app has gone cold since enumeration (estimate); the real win is deleting the title/first-window fallbacks (Lighter code 7). Effort S. Risk: low. Evidence: measured (harness) / estimate.

8. **Replace the Auto Layout grid with frame-based cells (or at minimum pool the row stacks).** `SwitcherPanel.swift:104-127` creates new `NSStackView` rows every open and `ThumbnailView.swift:101-133` keeps 16 constraints per cell; `setFrame(display:true)` at `:138` then solves them. Gain: (b) −4 ms, (a) −13 ms, plus `clearRows()` (`SwitcherPanel.swift:166-172`, 1.8 ms) drops to ~0 on dismiss, which is on the confirm path. Effort M (override `layout()` in `ThumbnailView`, lay rows out by arithmetic; removes the four stored constraints and ~30 constraint lines). Risk: low, visual parity verifiable by screenshot. Evidence: measured (harness): 4.4 → 0.3 ms pooled, 20.5 → 7.4 ms cold; pooled rows alone 4.4 → 3.5 ms.

9. **Prewarm the cell pool at launch.** `SwitcherPanel.swift:113-118` creates cells lazily on first show. Create ~24 cells in `init` (no need to order the panel front: first `orderFrontRegardless`+`orderOut` cost only 1.5 ms). Gain for (a): −16 ms with the current Auto Layout cells (−7 ms if item 8 is done). Effort S. Risk: none. Evidence: measured (harness).

10. **Defer `clearRows()` off the confirm path.** `AppDelegate.swift:164-165` calls `dismissSwitcher()` → `orderOut` + `clearRows()` (`SwitcherPanel.swift:161-164`) synchronously before `WindowActivator.activate`. Keep `orderOut` first (panel disappears), start activation, then `DispatchQueue.main.async { clearRows() }`. Gain for (d): ~2 ms earlier `app.activate`. Effort S. Risk: none. Evidence: measured (harness), 1.8 ms.

11. **Cancel the in-flight capture task on dismiss.** `WindowCapture.swift:49` discards the `Task` handle; `:78-88` keeps queueing captures after the switcher closed, so a cancel-and-reopen within ~300 ms queues the new activation's captures behind up to 14 stale ones. Keep the handle, cancel in `dismiss`, check `Task.isCancelled` in `addNext()`; still write finished images to the cache. Gain for (c): up to ~200 ms in the rapid-reopen case only. Effort S. Risk: none. Evidence: estimate.

12. **Cap thumbnail pixels to what a cell can show.** `WindowCapture.swift:106-107` requests half the window size in pixels (a 2560×1440 window → 1280×720, 3.7 MB); the image area is ≤284×190 pt = 568×380 px on a 2x display. Cap the longer side at ~640 px. Gain: memory 81 MB → ~18 MB for 22 such windows (arithmetic); capture latency −5–15% and cheaper `NSImageView` scaling (estimate; SCK per-request overhead dominates). Effort S. Risk: none visible at current cell sizes. Evidence: arithmetic / estimate.

13. **Move `promoteAppWindows`' AX call off main and skip it for JustTab's own activation.** `WindowModel.swift:248-258` runs a synchronous `kAXFocusedWindow` on main (1 s systemwide timeout, `:96`) every time any app activates, including the app JustTab just raised, which is exactly when that app is busy and the user may re-trigger. Warm cost measured 0.0–0.1 ms, so the gain is in the tail: avoids up to 1 s main-thread stalls under a busy target. `AppDelegate.swift:166` already promotes the chosen window, so the notification is redundant for our own switches. Effort S. Risk: none. Evidence: measured (harness) for the common case; the stall is estimate.

14. **Run the Accessibility pass off the critical path (show CG windows first, merge AX results after).** `WindowModel.swift:135-158`: the harness shows the warm pass is ~1.5 ms of CPU, so the owner's warm 24 ms list is mostly waiting for the slowest app's main thread (estimate). Gain for (b): warm open 35 → ~12 ms. Effort M. Risk: medium: minimized windows and (without Screen Recording) titles arrive after the panel is shown and must be appended without shifting the selected cell; strict MRU placement of a late minimized window would reflow the grid. Do items 1, 2, 8, 9 first and re-measure; only do this if warm open still matters. Evidence: measured (harness) for CPU cost; the wait attribution is estimate. Instrument `enumerateWindows` with `os_signpost` per phase first (S) to confirm.

15. **Try 16 and unbounded capture concurrency.** `WindowCapture.swift:26` is 8 with no stated measurement. Gain for (c): 0–100 ms, unknown; the capture service may serialize anyway. Effort S (one constant, measure three values). Risk: none. Evidence: estimate.

---

## Lighter code

Estimated total: ~210–240 lines (about 10–12%) without touching any kept feature.

1. **Delete the exponential back-off for tap creation.** `HotkeyManager.swift:51-55, 60-63, 67-85`. Two other mechanisms already cover it: PermissionManager restarts the tap when Accessibility flips (`AppDelegate.swift:64-74`) and the 2 s timer retries while `eventTap == nil` (`HotkeyManager.swift:146-152`). −30 lines. Effort S. Risk: none.

2. **One `notify` helper for the ten `DispatchQueue.main.async { [weak self] in self?.delegate?... }` blocks.** `HotkeyManager.swift:160-162, 178-180, 207-209, 229-231, 240-242, 248-254, 260-262, 266-268, 273-275, 280-282`. −25 lines. Effort S. Risk: none.

3. **Replace the NotificationCenter click channel with a closure.** `SwitcherPanel.swift:195-199, 205-207` posts `switcherClickedWindow` with `userInfo["index"]`; `AppDelegate.swift:50-59` subscribes and casts. A `var onSelect: ((Int) -> Void)?` on the panel does the same with no string key. −10 lines. Effort S. Risk: none.

4. **Dead or redundant bits.** `ThumbnailView.init(windowInfo:width:height:)` is never called (`ThumbnailView.swift:39-42`, −4). `WindowInfo.withTitle` exists only because `windowTitle` is `let` (`WindowModel.swift:33-36`, −4 with `var`). `parseWindowInfo(_:isMinimized:)` is only ever called with `false` (`WindowModel.swift:126, 345`, −1). `configure` sets `isSelected = false` and the caller immediately sets it again (`ThumbnailView.swift:141`, `SwitcherPanel.swift:120`, −1, and one fewer `updateAppearance` per cell per open). Total −10. Effort S. Risk: none.

5. **Drop `seedMRUFromStackingOrder`.** `WindowModel.swift:216-227` duplicates the layer/size filter of `parseWindowInfo` (`:345-353`). If `pruneMRU` (`:229-235`) appends new IDs by iterating `windows` (CG front-to-back) instead of a `Set`, the first enumeration seeds the MRU in stacking order and the explicit seed is unnecessary; this also fixes Bugs 2. −12 lines. Effort S. Risk: none (observers that fire before the first switch promote into an empty list, same as today after prune).

6. **Stop carrying thumbnails inside `WindowInfo`.** With Latency 3, images go from `WindowCapture` to the panel by index; then `applyCached` (`WindowCapture.swift:31-40`), the `updatedWindows` rebuild (`:91-97`), `currentWindows = updatedWindows` (`AppDelegate.swift:126-127`), the `cachedCount` log (`:132`), and `updateImages` with its full-`show()` fallback that can never trigger (`SwitcherPanel.swift:153-159`) all go; the panel asks the cache at `configure`. −20 lines net and one less mutable copy of the window list. Effort M (bundled with Latency 3). Risk: low.

7. **Delete the raise fallbacks and merge unminimize+raise.** With Latency 7, `WindowActivator.swift:97-114` (title match, then "raise the first window", which can raise the wrong window) and the duplicate fetch in `:58-74` become one function. −30 lines. Effort S. Risk: low; apps where `_AXUIElementGetWindow` fails lose only the title-match path, which `activate` mostly covers.

8. **Hover highlight.** `ThumbnailView.swift:179-200` adds a tracking area per cell per layout pass for a 5% white tint; hover is not in the keep list (click-to-switch is). −22 lines and 23 fewer tracking areas per open. Effort S. Risk: UX change; the owner's call.

9. **Fold the duplicate 2 s polls.** `HotkeyManager.swift:140-166` and `PermissionManager.swift:92-98` both tick every 2 s and both call `AXIsProcessTrusted()`. Keep PermissionManager as the only Accessibility poller and reduce HotkeyManager's timer to the "tap disabled → re-enable" check (`:154-164`), or drive even that from PermissionManager. −8 lines. Effort S. Risk: none (`AXIsProcessTrusted` measured at 0.000 ms, so this is duplication, not latency).

10. **Trim stale headers.** Every file opens with 10–17 lines of header; several are wrong for this app: "Windows-style", "Option-Tab", "3-state machine" for a two-case enum (`HotkeyManager.swift:7` vs `:39-42`), Author/Version/Date blocks (`AppDelegate.swift:1-14`, `HotkeyManager.swift:1-18`, `WindowModel.swift:1-17`, `ThumbnailView.swift:1-14`, `WindowActivator.swift:1-14`, `main.swift:1-13`). Keep the MIT attribution line; cut the rest. −80 lines. Effort S. Risk: none.

11. **One logging API.** `NSLog` at `AppDelegate.swift:36,85` and `HotkeyManager.swift:71,76,80,148,155` next to `Logger` everywhere else. 0 lines net, one fewer convention. Effort S. Risk: none.

12. **`ShortcutSettings` as two stored properties.** `HotkeyManager.swift:334-350` re-reads UserDefaults on every event. Cache on load, write through on set. ~−5 lines. Effort S. Risk: none. (Not a latency item: see Not worth it 3.)

---

## Bugs / risks

1. **`CGPreflightScreenCaptureAccess()` runs on the main thread twice every 2 s and once per switch.** `PermissionManager.swift:119, 158` (via `check()`, `:101`) and `AppDelegate.swift:44` → `WindowCapture.swift:45`. ~17 ms of main-thread stall per tick plus 8 ms per activation. Fix: Latency 1. Effort S. Evidence: measured (harness), 8.4 ms per call.

2. **New windows enter the MRU in `Set` iteration order.** `WindowModel.swift:232` iterates `validIDs: Set<CGWindowID>`, so windows never seen before are ordered arbitrarily among themselves on each process run. Fix: iterate `windows` (CG stacking order). Effort S. Risk: none. Evidence: Swift `Set` iteration order is unspecified and per-process seeded (Apple docs).

3. **`AXObserverAddNotification` result is ignored; the observer is stored even when registration failed.** `WindowModel.swift:293-297`. For apps launched after JustTab (`:327-333`) the AX server may not be ready at `didLaunch`, so intra-app focus tracking is silently missing for that app until restart. Fix: check the result; on failure do not store it (the next enumeration or a delayed retry can reinstall). Effort S. Evidence: estimate (readiness timing); the unchecked return is fact.

4. **Synchronous AX on the main thread on every app activation, with a force cast.** `WindowModel.swift:249-252`: `kAXFocusedWindow` with the 1 s systemwide timeout (`:96`), and `focusedRef as! AXUIElement` crashes if an app returns a non-element value. Fix: `as?`, and Latency 13. Effort S. Evidence: timeout semantics per Apple docs (`AXUIElementSetMessagingTimeout`); crash path is fact.

5. **`enumerateWindows` can block main for seconds under one hung app.** `WindowModel.swift:144-149` waits for all `scanApp` calls; `:179` caps each *message* at 0.25 s, but `scanApp` sends 1 + up to 2 messages per window (`:181, 188, 194, 197`), so a hung app with 10 windows can cost ~5 s on main. While main is blocked the tap callback cannot run, so the tap is disabled by timeout and the switcher is force-cancelled (`HotkeyManager.swift:172-183`). Fix: per-app deadline (skip the per-window loop if `kAXWindows` alone took >100 ms), or Latency 14. Effort S. Evidence: Apple docs for per-message timeout; multiplication is arithmetic; the tap-disable threshold is estimate.

6. **Event tap on the main run loop.** `HotkeyManager.swift:131`. Any main-thread stall longer than the system's tap timeout drops the switch (recovered by `:154-164` and `:172-183`, but the user sees a missed Cmd+Tab). Moving the tap to its own thread (M) fixes the drop but requires `state` to live on that thread; the delegate calls still land on main. Do the cheaper items (1, 13, 5 above) first; they remove the known stalls. Evidence: estimate.

7. **Trigger with no windows leaves the state machine active.** `AppDelegate.swift:110` returns before `switcherActive = true`, but `HotkeyManager.swift:228` already set `.active`, so every key is swallowed (`:285-289`) until the modifier is released. Fix: call `hotkeyManager.reset()` in that guard. Effort S. Evidence: code path.

8. **"Last resort: raise the first window" can raise the wrong window.** `WindowActivator.swift:110-114`. If neither the ID nor the title matched, the app is already activated by `:41`; raising an arbitrary window changes the user's result. Delete (Lighter code 7). Effort S.

9. **Panel always opens on `NSScreen.main`.** `SwitcherPanel.swift:88`. JustTab never has a key window, so this is effectively the primary display on multi-monitor setups rather than the display the user is working on. Fix: screen containing `NSEvent.mouseLocation`, or the screen of the frontmost window. Effort S. Evidence: Apple docs define `main` as the screen with the key window; the fallback when there is none is estimate.

10. **Thumbnail memory is bounded only by window count × half resolution.** `WindowCapture.swift:29, 106-107`: ~3.7 MB per 2560×1440 window, ~81 MB for the owner's 22, >500 MB for 60 windows on a 5K display (arithmetic). Fix: Latency 12. Effort S.

11. **In-flight captures are never cancelled.** `WindowCapture.swift:49`. Stale captures from a dismissed switcher compete with the next one's. Fix: Latency 11. Effort S.

12. **`HotkeyManager` has no `deinit` that calls `stop()`.** `HotkeyManager.swift:115` hands the tap an unretained pointer; `WindowModel` does the equivalent and does clean up in `deinit` (`WindowModel.swift:104-106`). Safe only while `AppDelegate` keeps the one instance for the process lifetime. Add `deinit { stop() }`. Effort S. Risk: none.

13. **Strict-concurrency debt in `capture`.** `WindowCapture.swift:75-88` mutates `var next` and `fresh` from a nested function inside `withTaskGroup`. Not a runtime race today (one task touches them), but Swift 6 strict concurrency will reject it; Latency 3 restructures this anyway. Evidence: Swift 6 isolation rules.

---

## Not worth it

1. **Swapping `SCScreenshotManager` for `CGWindowListCreateImage`.** Deprecated since macOS 14 (Apple docs) and would re-introduce a synchronous per-window capture; the realistic wins for (c) are ordering and prefetching (Latency 3–5), not the capture API. Evidence: Apple docs / estimate.

2. **A persistent live window model (tracking every window via AX notifications + CG events) to make the list instant.** `WindowModel.swift:116-166` is 24 ms warm and becomes ~24 ms cold with Latency 2; a live model is L effort and fragile across apps that do not post AX notifications. Evidence: estimate.

3. **Caching `ShortcutSettings` for latency.** `HotkeyManager.swift:202, 220-222` read UserDefaults three times per key event; CFPreferences reads are in-process cached and take microseconds. Fine as a tidy-up (Lighter code 12), no measurable latency. Evidence: estimate.

4. **Rewriting the AX pass with Swift concurrency / `async let`.** `WindowModel.swift:144-149`: `concurrentPerform` already gives 1.5 ms vs 6.4 ms sequential (measured (harness)); a task-based version adds hops and buys nothing.

5. **SkyLight SPIs (`_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo`) to speed the raise.** The measured cheap half of `WindowActivator.swift:78-95` shows the cost is the target app's response; private window-server calls might shave 10–20 ms (estimate) at the price of breakage on OS updates, and the brief's SPI allowance covers `_AXUIElementGetWindow` only.

6. **A persistent `SCStream` per window instead of screenshots.** Streams are for continuous capture and carry far higher setup cost than one `captureImage` (Apple docs); 22 streams would be slower and heavier. Evidence: Apple docs / estimate.

7. **`setFrame(display: false)` at `SwitcherPanel.swift:138`.** AppKit draws once at `orderFrontRegardless` either way; no measurable difference expected. Evidence: estimate.

8. **Removing the async hop from the tap callback to the delegate.** `HotkeyManager.swift:229-231`: the callback already runs on main, so the hop costs one run-loop turn (<1 ms) and keeps the callback short, which protects the tap from `tapDisabledByTimeout`. Keep it. Evidence: estimate.

9. **Shortening the 2 s permission poll or replacing it with notifications.** `PermissionManager.swift:70, 92-98`: `AXIsProcessTrusted` is 0.000 ms (measured (harness)); the only expensive thing in the tick is `CGPreflightScreenCaptureAccess`, which Latency 1 removes. The poll itself is fine.

10. **Moving icon prewarm off main.** `WindowModel.swift:275-282`: 6.3 ms total for 13 apps, once at launch (measured (harness)). Leave it.

11. **Optimising `pruneMRU`'s O(n²) `contains`.** `WindowModel.swift:230-234`: n ≈ 23, microseconds. Fix the ordering (Bugs 2), not the complexity.
