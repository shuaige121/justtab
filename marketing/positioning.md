# JustTab positioning (internal)

The supplied F1–F20 and P1–P5 brief is the only authority for public claims. F14 is retired; it has no replacement verified claim. See `facts-check.md` for the claim inventory and public-copy locations. Do not publish this planning document as a post.

## Audience and message

Primary audience: people who came to the Mac from Windows and miss choosing individual windows with Alt-Tab. Secondary audience: people who keep several windows of one app open. These are audience choices from the brief, not claims about current users.

Public pitch: **Switch between individual windows on macOS in one thumbnail grid.** (F1, F2)

The explanation is concrete: macOS Cmd-Tab switches apps; Cmd-` cycles only the current app's windows (F15). JustTab gathers windows from all apps into one grid (F2). Option+Tab is the default; on a PC keyboard connected to a Mac, Alt acts as Option (F4).

## Message order

1. Individual windows in one grid, most recently used first; quick press and release toggles between the two most recent windows (F2, F6).
2. Hold, choose, release; Tab, arrow keys, Shift+Tab, Esc and clicking are the available actions described in this round (F3).
3. Free forever, MIT-licensed and open source. No paywall, Pro tier or upsell; nothing in the app will ever be sold (F9, F17).
4. One job, switching windows; one real setting, the shortcut, plus Launch at Login. Menu bar, no Dock icon (F2, F5). State this positively.
5. Build from source with full Xcode today, macOS 13+, Accessibility required; live thumbnails require macOS 14+ and Screen Recording permission, otherwise app icons (F12, F13).

## Supporting detail

- Minimized windows are included and dimmed; the grid shrinks cells so every listed window fits (F7, F8).
- Any key plus one or more of Control, Option, Shift and Cmd can be recorded through Change Shortcut…; Esc cancels recording. Cmd+Tab replaces the built-in app switcher while JustTab runs (F5).
- No networking code, telemetry, account or update checks (F10).
- Pure Swift + AppKit, zero third-party dependencies, about 2,600 lines of Swift and about 520 KB on disk (F11).
- Technical audience only: on the developer's Mac with 22 windows open in November 2026, median real Cmd+Tab use measured about 34 ms to show the switcher and about 55 ms to show the first live thumbnail, both from key press. Memory use is about 25 MB (F18). Do not shorten this into an unqualified speed promise.
- App Store sandboxing prevents use of the Accessibility API to list or focus other apps' windows; direct distribution is the approach for this kind of switcher (F19). Cite the supplied Apple Developer Technical Support / Apple Developer Forums attribution, 2024 and 2025, without inventing forum URLs.
- Technical FAQ and HN comment: exactly one private function, `_AXUIElementGetWindow`, matches an accessibility window to its window ID (F20).

## Pending claims and publishing gate

- Apps hidden with Cmd-H are listed and return when a window is chosen; confirm on a real Mac before retaining the optional copy (P1). <!-- P1 -->
- Windows on other desktops (Spaces) are listed and choosing one switches desktops; confirm on a real Mac (P2). <!-- P2 -->
- A Developer ID-signed, Apple-notarized DMG from GitHub Releases is planned, not available today; the site button remains disabled (P3). <!-- P3 -->
- The switcher opens on the display with the mouse pointer; confirm with two displays (P4). <!-- P4 -->
- The focus check after switching retries once if needed; confirm on a real Mac (P5). <!-- P5 -->

The repository is private. The owner must make it public before any launch post is published (F16). This is an editorial precondition, never part of public copy. Source installation is the complete install path in every draft (F13). Optional lines must be removable without breaking that path.

## Attribution and register

Every README-style text keeps this credit (F9): JustTab is a stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis.

English first. Chinese is written natively in a plain, restrained register. Use short sentences, no hype or unsupported comparisons. Do not put other product names into headlines, topics or body copy beyond the required attribution and the names required by the allowed facts. Keep key names consistent. Use “listed windows” when describing the grid fitting on screen.

The canonical copy is now `README.md`, `site/index.html` and `launch-posts.md`. `readme-hero.md` points to that copy; `keyword-strategy.md` records phrase choices only.
