# JustTab review brief: further latency cuts and lighter code

JustTab is a minimal macOS window switcher (Swift + AppKit, zero third-party dependencies, macOS 13+, no network code).
Hold the trigger (this user: Cmd+Tab), tap Tab to move through a grid of window thumbnails, release to switch.
Source: `src/*.swift` (about 2,000 lines including comments). Read all of it.

## Measured on the owner's Mac (os_log timings from the installed Release build, 23 windows)
| Path | Cold (first switch after launch) | Warm |
|---|---|---|
| Window list (`WindowModel.enumerateWindows`) | 142 ms | 24 ms |
| Key press → panel ordered front | 199 ms | 35 ms |
| Fresh thumbnails (22 windows, ScreenCaptureKit, 8 concurrent, half resolution) | 469 ms | 301 ms |
| Raise after release (`WindowActivator`, background queue) | 17–93 ms | |

- Warm open uses pooled cells and shows cached thumbnails from the previous open immediately; fresh images are swapped in place.
- Before pooling, warm open took 72–98 ms (list 29–53 ms).
- A standalone harness measured the per-app Accessibility pass: parallel (`concurrentPerform`) warm median 3–5 ms vs about 8 ms sequential, with an identical window set.
- The event tap callback runs on the main run loop and dispatches delegate calls to main asynchronously.

## Constraints (do not propose breaking these)
- Keep: window grid with live thumbnails (optional permission), MRU order, minimized windows, click-to-switch, grid that fits the screen, configurable shortcut, permission monitor that prompts for missing permissions, Launch at Login.
- No third-party dependencies, no network code, single real setting (the shortcut).
- The private SPI `_AXUIElementGetWindow` is already used; it is acceptable (not App Store bound).
- Changes must be testable without injecting keystrokes into the user's session (logic tests with fakes are fine).

## Questions
1. Latency: what else would cut (a) cold open, (b) warm open, (c) time until fresh thumbnails, (d) raise after release? Rank by expected gain per effort. Give the expected effect in ms where you can, and say whether it is measured, documented, or your estimate.
2. Lightness: what code can be deleted or simplified without losing the features above (dead code, duplicate logic, over-abstraction, unnecessary state)? Estimate lines removed.
3. Risks: anything in the current code that is wrong, racy, or likely to regress latency (e.g. main-thread blocking, retain cycles, unbounded caches, AX calls on main).
4. What not to do: tempting optimizations that are not worth it here.

## Output format
Markdown. Sections: "Latency (ranked)", "Lighter code", "Bugs / risks", "Not worth it". Every item: one-line claim, `file:line` reference, expected gain, effort (S/M/L), risk, and evidence type (measured / Apple docs / estimate). Be concrete; no generic advice.
