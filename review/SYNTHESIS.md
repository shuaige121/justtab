# JustTab latency and lightness review: synthesis (2026-11-10)

Inputs: `brief.md` (same for both), `fable.md` (Fable, 51 items, with harness measurements), `codex.md` (Codex, 33 items).
Verification by the main session: Fable's key number re-measured independently; Codex's code claims spot-checked in source.

## Verified facts
- `CGPreflightScreenCaptureAccess()` costs **7.6 ms per call** on this Mac (main session re-measurement, 2×30 calls; Fable measured 8.4 ms). JustTab calls it once per switch before the panel is shown (`AppDelegate` → `WindowCapture.isAllowed`) and twice per 2 s permission tick (`PermissionManager.check()`).
- Warm open accounting now adds up: 35 ms = list 24 ms + ~7.6 ms permission check + ~3.5 ms panel build (Fable harness: pooled build 3.5–4.4 ms).
- Confirmed in source: `AXObserverAddNotification` result ignored (observer stored even on failure); unused `ThumbnailView(windowInfo:width:height:)`, unused `selfBundleID`, unused `import ServiceManagement` in AppDelegate, `WindowInfo.bounds` never read; capture results written to the cache before any activation check; tap retry closure only checks `eventTap == nil`.

## Consensus (both reviewers)
1. Prewarm at launch so the first switch is not cold (cold list 142 ms vs warm 24 ms).
2. Deliver thumbnails progressively (selected cell first) instead of after all captures.
3. Resolve the target AX window once; merge unminimize + raise; delete the "raise the first window" fallback (can raise the wrong window).
4. Cap capture resolution to the cell size (2560×1440 window → 1280×720 today; a cell needs about 568×380 px).
5. Generation check before cache writes and/or cancel in-flight captures on dismiss.
6. Do not store failed AXObservers; retry when Accessibility is granted.
7. Append new MRU entries in stacking order, not `Set` order.
8. Replace the NotificationCenter click channel with a closure; delete dead code.
9. Not worth it: persistent live window model, per-window `SCStream`, `CGWindowListCreateImage`, SkyLight SPIs, rewriting the AX pass with async/await, removing the tap → main async hop.

## Plan
### Round 1 (small, low risk)
| Change | Expected effect | Evidence |
|---|---|---|
| Use the cached Screen Recording state instead of calling the system check | Warm open 35 → ~27 ms; removes ~15 ms main-thread stall every 2 s | measured (7.6 ms/call) |
| Prewarm AX pass (off main), cell pool, and ScreenCaptureKit when granted | First switch after launch 199 → ~40–50 ms | estimate (Fable harness: cold AX 12–48 ms/app, cold cells ~16 ms) |
| Progressive thumbnails, selected first | First fresh thumbnail ~100–150 ms instead of ~300 ms | estimate |
| Cap thumbnail resolution | Thumbnail memory ~81 MB → ~18 MB for 22 large windows; capture slightly faster | arithmetic / estimate |
| Skip AX raise when the target is already its app's front window | Raise 17–93 ms → ~0 for the common case | estimate; measure after |
| Bug fixes: failed AXObservers, no-window trigger leaves keys swallowed, force cast in `promoteAppWindows`, stale captures, MRU order, wrong-window fallback | Correctness | source-confirmed |
| End-to-end timing from the key event (Codex): current timer starts when the delegate runs | Honest numbers | source-confirmed |

### Round 2 (medium, measure Round 1 first)
- Frame-based cell layout instead of Auto Layout: warm −4 ms, cold −13 ms (Fable harness).
- Show CG windows first and merge the AX pass after: warm open ~35 → ~12 ms (estimate, medium risk: late minimized windows may reflow the grid).
- Event tap on its own thread (only if stalls remain).

### Lighter code (about 210–240 lines, 10–12%)
Stale file headers −80 (keep MIT attribution), tap back-off −30, raise fallbacks −30, delegate-dispatch helper −25, `seedMRUFromStackingOrder` −12, click closure −10, dead code −10, duplicate 2 s polls −8, NSLog → Logger.
Owner decision: hover highlight (−22 lines, small UX change).

## Round 1 results (2026-11-10, this Mac, 22 windows, real Cmd+Tab use)
Before = build 27ddf58, 12 switches; after = Round 1 build, 11 switches. Times are medians. "After" is measured from the key event (event tap → handler adds ~0.1 ms), "before" from the handler.

| Metric | Before | After |
|---|---|---|
| First switch after launch, panel shown | 199 ms (earlier session) | 64.6 ms (list 33.4 ms) |
| Warm open, panel shown | 39.5 ms | 34.0 ms |
| Warm open, work besides the window list | 11.3 ms | 8.4 ms |
| First fresh thumbnail on screen | ~250–300 ms (all at once) | ~55 ms (49.5–62.1) |
| All fresh thumbnails | 248–262 ms | 241–281 ms (unchanged) |
| Raise, app's front window (5 switches) | 25–39 ms | skipped; check 150 ms later found the right window focused 5/5 |
| Raise, other windows | 26–61 ms | 22–55 ms |
| Memory (phys_footprint) | 22 MB | 25 MB (no measurable gain; the 81 MB estimate never matched reality) |

Cancellation works: three quick switches stopped after 8, 10 and 14 of 22 captures.
The window list (22–30 ms warm) is now most of the warm open time; that is Round 2's "show CG windows first" item.
