# Facts check and public-claim map

Authority: the owner's supplied fact list for this round, F1–F20 and P1–P5. There is no F14 in the current list. The old F13 installation bundle and retired F14 window-scope claim must not be reused. This is a copy audit against that brief, not independent app validation or web research.

Locations below cover `README.md` (R, English and Chinese), `site/index.html` (S) and `launch-posts.md` (L). L sections: G = GitHub description/topics; H = Show HN; M = r/macapps; P = Product Hunt; X1–X5 = individual X posts; V = V2EX; C = Xiaohongshu. Section names identify every reuse, including metadata, captions and translations. Editorial capture directions are not claims of completed work.

## Verified claim inventory

| ID | Allowed claim, including qualifications | Public-copy locations |
| --- | --- | --- |
| F1 | Product name is JustTab | R title, Chinese title, prose and credits; S title, metadata, wordmark, prose and footer; all L sections |
| F2 | Switch individual windows, not just apps; one grid of live window thumbnails with windows from all apps | R pitch and What it does / 功能; S title, metadata, hero, Features; L G, H, M, P name/tagline/description/comment/gallery, X1, V, C |
| F3 | Hold shortcut, Tab or arrow keys move, Shift+Tab goes back, release switches, Esc cancels, clicking a thumbnail switches | R Usage / 使用; S hero and three steps; L H, M, P description/comment/gallery, X2, V, C |
| F4 | Option+Tab default; PC keyboard Alt acts as Option on a Mac, physically Alt+Tab | R What it does and Usage / 功能 and 使用; S hero, decorative key labels, first step; L G, H, M, P description/comment, X2, V, C |
| F5 | Record any key plus one or more of Control, Option, Shift and Cmd through menu bar Change Shortcut…; Esc cancels recording | R Usage and Cmd-Tab FAQ in both languages; S Features and Cmd-Tab FAQ; L G configurable-shortcut phrase, H, M, P comment/gallery, X3, V |
| F5 | Cmd+Tab replaces the built-in app switcher while JustTab runs | R Usage and Cmd-Tab FAQ in both languages; S Cmd-Tab FAQ; L H, M, P comment, X3, V |
| F5 | One real setting, the shortcut, plus Launch at Login; menu-bar app with no Dock icon | R What it does and Usage / 功能 and 使用; S Features; L G menu-bar topic, H, M, P comment/gallery, X3, V, C |
| F6 | Most recently used first; opens with previous window selected; quick press and release toggles the two most recent windows | R What it does and Usage / 功能 and 使用; S first step and Features; L H, M, P comment, X2 toggle sentence, V, C |
| F7 | Minimized windows included and dimmed | R What it does / 功能; S Features; L H, M, P comment/gallery, X5, V, C |
| F8 | Grid cells shrink so every listed window fits on screen | R What it does / 功能; S Features; L M, X5, V |
| F9 | Free, MIT-licensed, open source | R badge, What it does and License / 功能 and 许可; S top strip, Privacy, footer; L G description/topics, H title/comment, M title/post, P tagline/description/comment, X1, V, C |
| F9 | Full credit: stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis | R Credits / 致谢; S footer; L H, M, P comment, X5, V, C. G's brief metadata is paired with the repository README; P metadata is paired with its credited first comment. |
| F10 | App contains no networking code; no telemetry, account or update checks | R Permissions and privacy and phone-home FAQ in both languages; S Privacy and phone-home FAQ; L G no-networking phrase, H, M, P comment, X1, V, C |
| F11 | Pure Swift + AppKit, zero third-party dependencies, about 2,600 Swift lines, about 520 KB on disk | R What it does / 功能; S Features; L G language/framework topics, H, V |
| F12 | macOS 13+; Accessibility required; live thumbnails need macOS 14+ and Screen Recording permission, otherwise app icons | R platform badge, Install, Permissions / 安装, 权限; S metadata strip, hero note, Privacy; L G minimum versions and thumbnail permission, H, M, P description/comment/gallery, X4, V, C |
| F13 | Only install today is source build with full Xcode: clone repository, cd justtab, ./build.sh install; installs to ~/Applications | R Install / 安装; S metadata, hero install link and App Store FAQ; L G, H, M, P description/comment, X4 linked instructions, V, C |
| F15 | macOS Cmd-Tab switches apps; Cmd-` cycles windows of the current app only | R What it does / 功能; S Cmd-Tab FAQ; L H, V |
| F16 | Repository URL is github.com/shuaige121/justtab | R clone commands; S GitHub CTA and README anchor links; L clone commands and repository links in H, M, P, X4, X5, V, C |
| F16 | Repository is private; owner must make it public before posting | Editorial preconditions in every L section only; excluded from all fenced public copy, R and S |
| F17 | Free forever; no paywall, Pro tier or upsell; nothing in app will ever be sold | R What it does and License / 功能 and 许可; S top strip, Privacy, footer; L G free-forever phrase, H, M, P tagline/comment, X1 (except final sale clause), V, C |
| F18 | About 34 ms key press to switcher; about 55 ms key press to first live thumbnail, measured on developer's Mac with 22 windows open, November 2026, median of real Cmd+Tab use; about 25 MB memory | L H first comment only. Measurement conditions appear in the same sentence as both latency numbers; memory is separately qualified as approximate. |
| F19 | Not on Mac App Store: sandbox required, preventing Accessibility API access to list/focus other apps' windows; this kind of switcher is distributed directly. Apple Developer Technical Support, Apple Developer Forums, 2024 and 2025 | R App Store FAQ in both languages; S App Store FAQ |
| F20 | Exactly one private macOS function, _AXUIElementGetWindow, matches an accessibility window to its window ID | R private-function FAQ in both languages; S private-function FAQ; L H first comment only |

## Pending claim inventory

Each public line or complete HTML element below carries its P tag. In fenced plain-text posts the tag is `[P1]` style; outside fences and in HTML it is an HTML comment. Combined tags mean the whole line depends on both facts. Deleting every tagged line leaves complete factual copy, intact Markdown fences and valid HTML.

| ID | Optional claim | Public-copy locations |
| --- | --- | --- |
| P1 | Cmd-H-hidden apps' windows are listed; choosing one brings the app back | R bilingual optional FAQ; S Features and combined optional FAQ element; L H, M, V optional lines | <!-- P1 -->
| P2 | Windows on other desktops (Spaces) are listed; choosing one switches desktops | R bilingual optional FAQ; S Features and combined optional FAQ element; L H, M, V optional lines | <!-- P2 -->
| P3 | Planned Developer ID-signed DMG, notarized by Apple, from GitHub Releases; not available yet | R bilingual Install and App Store FAQ; S disabled Download button, hero note and App Store FAQ note. No launch post links a download. | <!-- P3 -->
| P4 | Opens on display with mouse pointer | S Features; L H optional line | <!-- P4 -->
| P5 | After switching, checks chosen window came to front and retries once if needed | S Features; L H optional line | <!-- P5 -->

F19's planned distribution sentence depends on P3 and is split out of every otherwise verified FAQ answer. The core install path stays F13. <!-- P3 -->

## Completeness and interpretation

- English and Chinese README sections contain the same factual set, including the full usage table, private-function FAQ, license and credit. English badges summarize F9/F12 and apply to the whole document.
- R pitch: F1/F2. R What it does: F2/F4–F9/F11/F15/F17. R Install: F12/F13. R Usage: F3/F5/F6. R Permissions: F10/F12. R verified FAQ: F5/F10/F19/F20. R Credits/License: F9/F17. The optional FAQ and install lines are separately mapped above.
- S metadata/hero: F1–F4/F9/F12/F13/F17; steps: F3/F4/F6; verified Features: F2/F5–F8/F11; Privacy: F9/F10/F12/F17; verified FAQ: F5/F10/F15/F19/F20; footer: F9/F17. The illustration uses neutral blocks only and makes no screenshot or app-content claim.
- G description/topics: F1/F2/F4/F5/F9–F13/F17. H title: F1/F2/F9; comment: F1–F7/F9–F13/F15–F18/F20, plus tagged optional facts. M title: F1/F2/F9/F17; post: F1–F10/F12/F13/F16/F17, plus tagged optional facts.
- P name: F1; tagline: F2/F17; description: F2–F4/F9/F12/F13; comment: F1–F7/F9/F10/F12/F13/F16/F17. Gallery directions map to F2/F3/F5/F7/F12 and require actual capture.
- X1: F1/F2/F9/F10/F17. X2: F3/F4/F6. X3: F5. X4: F12/F13/F16. X5: F7–F9/F16. Publish the whole thread, retaining requirements and credit.
- V title: F1/F2/F9/F17; body: F1–F13/F15–F17, plus tagged optional facts. C title: F2; body: F1–F7/F9/F10/F12/F13/F16/F17. Topic labels describe those facts, not popularity or outcomes.
- “Cmd” in copy is the brief's requested display name for the Command modifier. “One job” is switching windows (F2); “one real setting” always keeps the separate Launch at Login qualification (F5).
- No performance number or hardware compatibility claim is inferred from the source. No claim has been promoted from pending to verified in this round.
- All constrained lengths are computed by `check-copy.py`, not claims about the app. The file checks the printed counts and limits, including the X URL-length convention as an extra check.

## Wanted but unsupported

- Exact Apple Developer Forums URLs for F19. The brief supplies the attribution and years but no URLs; no network was used and no links were invented.
- CPU usage, launch time, battery effect, “instant” switching, cross-machine speed guarantees, or memory figures beyond the supplied approximate F18 value.
- Hardware architecture/model compatibility, tested macOS versions, full-screen-window behavior, localization and keyboard-layout guarantees.
- Package-manager availability, automatic updating, release versions/dates, release schedules, maker name or contact.
- User counts, stars, testimonials, ratings, awards, popularity claims and comparisons with other products.
- Real screenshots, recordings and gallery assets. These are not fabricated; `capture-plan.md` specifies the work still needed.
