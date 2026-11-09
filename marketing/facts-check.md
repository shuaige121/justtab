# Facts check

Fact IDs F1-F17 are from the allowed list. O1 = the owner's brief: on Windows, Alt-Tab means hold Alt, tap Tab, see every window, release to switch; on macOS Cmd-Tab switches apps, not windows; JustTab restores the Windows-style behavior with the default shortcut on the same keys.

Files: P = positioning.md, R = readme-hero.md, L = launch-posts.md. The same claim appears in several places; it is listed once.

F17 (added 2026-11-09, owner's decision): JustTab is free forever: no paywall, no Pro tier, no upsell.

## Claims made and their sources

| # | Claim text (as used in copy) | Fact ID(s) | Where |
|---|---|---|---|
| 1 | Product is called JustTab; tagline "Just Tab. Nothing else." | F1 | R, P |
| 2 | Switches between individual windows, not just apps | F2 | P, R, L |
| 3 | Shows a grid of live window thumbnails | F2 | P, R, L |
| 4 | Hold the shortcut, tap Tab (or arrow keys) to move, release to switch | F3 | P, R, L |
| 5 | Shift+Tab goes back; Esc cancels; clicking a thumbnail switches | F3 | L |
| 6 | Holding Shift when opening starts on the last window | F3 | (not used in new copy; README usage table unchanged) |
| 7 | Default shortcut is Option+Tab | F4 | P, R, L |
| 8 | On a PC keyboard used with a Mac, Alt acts as Option, so physically Alt+Tab | F4 | P, R, L |
| 9 | Shortcut can be changed to any modifier + key combination, including Cmd+Tab, which then replaces the built-in switcher | F4 | P, R, L |
| 10 | Shortcut is the only real setting; plus Launch at Login toggle | F5 | P, R, L |
| 11 | Lives in the menu bar; no Dock icon | F5 | R, L |
| 12 | Windows ordered most recently used first | F6 | P, R, L |
| 13 | Opens with previous window selected; quick press and release toggles between two most recent windows | F6 | P, R, L |
| 14 | Minimized windows are included (app icon, dimmed) | F7 | R, L |
| 15 | Grid shrinks cells so every window fits on screen | F8 | R, L |
| 16 | Free, MIT-licensed, open source | F9 | P, R, L |
| 17 | Stripped-down fork of alttab-macos by Sergio Farfan (MIT), inspired by AltTab by lwouis (credit repeated in every file/post) | F9 | P, R, L |
| 18 | No networking code: no telemetry, no account, no update checks | F10 | P, R, L |
| 19 | Pure Swift + AppKit, zero third-party dependencies | F11 | P, R, L |
| 20 | About 316 KB | F11 | P, R, L |
| 21 | Requires macOS 13 or later | F12 | P, R, L |
| 22 | Accessibility permission is required | F12 | P, L |
| 23 | Live thumbnails need macOS 14+ and Screen Recording permission; otherwise app icons | F12 | P, L, R (notes) |
| 24 | Install by building from source with full Xcode: `git clone https://github.com/shuaige121/justtab.git`, `./build.sh install` | F13 | P, R, L |
| 25 | No prebuilt download, notarized build, App Store or Homebrew listing | F13 | P, R, L |
| 26 | Only windows on the current Space are listed, plus minimized windows; other Spaces not shown | F14 | P, R, L |
| 27 | Cmd-Tab switches apps, not windows | F15, O1 | P, R, L |
| 28 | Cmd-` cycles windows of the current app only | F15 | P, L |
| 29 | On Windows: hold Alt, tap Tab, see every window, release to switch | O1 | P, R, L |
| 30 | JustTab gives the Windows-style behavior back; default shortcut on the same keys | O1, F4 | P, R, L |
| 31 | Repository is github.com/shuaige121/justtab | F16 | P, R, L |
| 32 | Repository is currently private; owner decides when it goes public (internal note only, not in public copy) | F16 | P, L (preconditions) |
| 33 | Windows listed from all apps in one grid (contrast with Cmd-`) | F2, F15 | P |
| 34 | Taglines "Alt-Tab window switching for macOS" / "Alt-Tab style window switching for macOS" are descriptive of the behavior | O1, F2, F3 | R, L |
| 35 | Xiaohongshu title length 12 characters (<=20); Product Hunt tagline 40 characters (<=60); GitHub description well under 350 | (format limits in brief) | L |
| 36 | "Windows-style Alt-Tab for Mac" / "像 Windows 一样 Alt+Tab 切换窗口" (descriptive phrase, generic keyboard term, no product name) | O1, F2, F3, F4 | R, L |
| 37 | "Switch windows, not just apps" / "切换窗口，而不只是切换 App" | F2, F15 | R, L |
| 38 | "Free forever; no paywall, no Pro tier, no upsell" now in first lines of README, GitHub description, HN comment, Reddit, Product Hunt, V2EX, Xiaohongshu | F17 | R, L |
| 39 | "Nothing in the app will ever be sold" / "不会在应用内收费、销售任何功能" | F17 | R, L |
| 40 | "One job, one real setting (the shortcut)" / "只做一件事，只有一个真正的设置" ("one job" = switching windows; positive focus statement, no other product named) | F2, F5, F17 (owner stance 5a) | R, L |
| 41 | "A free, open-source window switcher for macOS that works like Alt-Tab on Windows" | F9, F17, O1 | R |
| 42 | GitHub description (271 characters, limit 350): Option+Tab, Alt+Tab on a PC keyboard, live thumbnails, build from source, macOS 13+, fork of alttab-macos | F2, F3, F4, F9, F10, F12, F13, F17 | L |
| 43 | GitHub topics `windows-style`, `switch-windows` (labels, not claims) | F2, O1 | L |
| 44 | Show HN title "Windows-style Alt-Tab for Mac (switch windows, not apps)" (74 characters, limit 80) | O1, F2 | L |
| 45 | Product Hunt tagline "Windows-style Alt-Tab for Mac: switch windows, not apps" (55 characters, limit 60) | O1, F2 | L |
| 46 | Xiaohongshu title "Mac 上用 Alt+Tab 切窗口" (18 characters, limit 20); Alt+Tab is the physical key combination on a PC keyboard, Option+Tab otherwise | F4 | L |
| 47 | V2EX title and tags (Mac, macOS, 窗口切换, 效率工具, 开源) | O1, F2, F9 | L |
| 48 | Hashtags #Mac切换窗口 #Mac窗口切换 (labels) | F2 | L |

Judgment notes:
- "Alt-Tab style" is shorthand for claim 29 plus claims 2-4.
- Hashtags and GitHub topics are labels, not factual claims.
- In the Windows description, "see every window" is quoted from the owner's brief (O1) for Windows. For JustTab we say "every window" never; we say the grid fits all listed windows (F8) and state F14.

## Claims I wanted to make but could not support (excluded from the copy)

- ~~"Free forever" / "no Pro tier" / "no paywall, no upsell"~~ now supported by F17 (owner's commitment, 2026-11-09) and used in the copy.
- "No settings maze" / "just works" / "sensible defaults" (current README). Subjective; replaced by F5.
- "Fast", "lightweight on CPU/memory", "instant", any speed or resource number other than 316 KB.
- "Works on Apple Silicon / Intel / specific Mac models", "tested on macOS 13 / 14 / 15 / 26". Only the minimum versions in F12 are known.
- "Works with multiple monitors" (source may handle it, but not in the fact list).
- "Includes all apps' windows including full-screen windows / hidden apps / windows of apps without a normal window." Not in the fact list.
- "Supports Mission Control / Stage Manager / Spaces switching."
- "Keyboard layout / non-US layout support", "localized UI".
- "Uses X API (ScreenCaptureKit, Accessibility API) under the hood." Read in source; not in the fact list.
- "Open the app at login works reliably", "sandboxed", "signed", "hardened runtime".
- Anything about user counts, stars, downloads, testimonials, ratings, awards, release dates, version numbers, prices, roadmap (none given).
- "Replaces / better than / lighter than" any other switcher (no competitor claims allowed).
- "Pressing the Alt key on Windows keyboards 'is' Option on all Mac setups". F4 says Alt acts as Option on a PC keyboard used with a Mac; we do not claim anything about remapping settings.

## Gaps (items missing, lines left out)

1. **No JustTab screenshot or GIF.** The only image, `Screenshots/AltTab1.jpg`, belongs to upstream and must not be shown as JustTab. All posts are text-only; Show HN, Reddit, Product Hunt and especially Xiaohongshu would benefit from a recording of the real app.
2. **Repository is private (F16).** All drafts link to it; they cannot be posted until the owner makes it public.
3. **No prebuilt download (F13).** Install is build-from-source with full Xcode, which limits the realistic audience (Windows switchers who are not developers) and makes Product Hunt a weak fit for now.
4. **Product Hunt needs a website/link and gallery image.** Not available; not invented.
5. **No release/version information**, so no "v1.0" or "latest release" lines.
6. **No author/maker byline or contact** was provided; posts speak neutrally ("Feedback is welcome") without a name or email.
7. ~~Free-forever promise~~ decided: keep it (F17).
8. **Language of the README tagline** in Chinese was reworded; confirm the owner is happy dropping the bilingual tagline line.
