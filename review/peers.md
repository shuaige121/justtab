# JustTab vs. open-source peers (2026-11-10)

Scope: JustTab (`AltTab/AltTab/*.swift`, 2,075 lines, MIT) compared with the open-source macOS per-window switchers lwouis/alt-tab-macos, rokartur/BetterCmdTab, ejbills/DockDoor and JustTab's own upstream sergio-farfan/alttab-macos. All peer code was read from shallow clones in the session scratchpad (`…/scratchpad/peers/<owner>_<repo>/`); nothing was built or run. Every figure carries the command or URL that produced it. Claims are tagged **[verified: …]** or **[inference]**. Latency numbers for JustTab come from `review/SYNTHESIS.md` and were not re-measured.

## Executive summary

1. There are four real open-source peers; the biggest are lwouis/alt-tab-macos (16,507 stars, GPL-3.0, 49k lines) and ejbills/DockDoor (6,544 stars, GPL-3.0, 42k lines); rokartur/BetterCmdTab (865 stars, GPL-3.0, 39k lines) is the fast-growing third. JustTab's upstream (sergio-farfan/alttab-macos, 8 stars, MIT, 2.8k lines) has moved on five releases since the fork point and fixed bugs JustTab still has.
2. All three large peers rely on private SkyLight/CGS APIs for the three hard problems (windows on other Spaces, raising a window without the deprecated `activate`, capturing minimized windows). JustTab and its upstream use only public APIs plus `_AXUIElementGetWindow`. That is a real robustness advantage (fewer "broke after macOS update" issues) and a real feature gap (no other-Space windows, no thumbnails of minimized windows).
3. Where JustTab is behind: no download at all (every peer ships a Homebrew cask or a signed DMG); windows on other Spaces and ⌘H-hidden apps are not listed; the panel always opens on the screen with the key window; no fallback when a password field turns on Secure Input; the MRU list can be scrambled by background apps (fixed upstream in 1.3.1); activation uses a public API that macOS 14 downgraded to a "request" (owner's logs: correct window focused 5/5, peers report 1-in-20 failures with similar approaches).
4. Where JustTab is ahead: smallest codebase (2,075 lines vs 2,839 / 38,877 / 41,642 / 49,138), zero dependencies, zero networking code, a configurable shortcut (upstream hard-codes Option+Tab; its only feature request #4 asked for exactly this), progressive thumbnails with a 640 px cap, and a warm open of ~34 ms with no persistent window model to go stale.
5. Positioning: "free forever, no Pro tier" is now a genuine differentiator against lwouis AltTab (Pro tier since v11.0.0, 2026-05-21, 14-day trial) and DockDoor (promotes a separate $20 Pro app inside the free one), but not against BetterCmdTab or the upstream, which are also free. "One setting", "tiny" and "no network" all hold.
6. Recurring complaints in the peers' trackers that JustTab's design already avoids: WindowServer memory growth from background capture (lwouis #4255, 90 comments), "AltTab is sharing your screen" indicator from streams (lwouis #2606, 139 comments; BetterCmdTab #200), breakage of private APIs on new macOS versions, and the other-Space "flash" trick (lwouis #447).
7. Recurring complaints that could hit JustTab: Secure Input making the shortcut dead or stuck (lwouis #157 95 comments, #3117 150 comments), the macOS 15 Screen Recording re-prompt (lwouis #3973; the upstream dropped ScreenCaptureKit over it in 1.1.0), target window raised but not keyboard-focused (BetterCmdTab #180, lwouis #6064), and wrong-window MRU after background window churn (upstream 1.3.1).
8. Worth borrowing (all available under MIT from the upstream, or as ideas): a Homebrew tap plus ad-hoc-signed DMG (S); the frontmost-app guard on focus notifications (S); a focus verify-and-reassert step for every switch, not only the front-of-app case (S); listing ⌘H-hidden and other-Space windows through the existing AX pass (M, must test activation across Spaces); a Carbon `RegisterEventHotKey` fallback for Secure Input (M).
9. Not worth borrowing: SkyLight private APIs (`_SLPSSetFrontProcessWithOptions`, `CGSHWCaptureWindowList`, `CGSCopyWindowsWithOptionsAndTags`, `CGSSetSymbolicHotKeyEnabled`), continuous background capture, `SCStream` live previews, search/tabs/tiling. They cost the peers hundreds of issues and would break the "no private API, one job" story; their implementations are GPL.
10. Licence rule: lwouis/alt-tab-macos, DockDoor and BetterCmdTab are all GPL-3.0 (verified from their LICENSE files). Only the upstream (MIT) may be copied from. Everything recommended below is either MIT-sourced or a technique small enough to implement from the public API documentation without reading GPL code.

---

## 1. Peer set

### 1.1 Compared in depth

| Project | Role | Why included |
|---|---|---|
| lwouis/alt-tab-macos | The reference Windows-style switcher for macOS since 2019 | Largest, most-issues, GPL, private-API heavy |
| rokartur/BetterCmdTab | ⌘Tab replacement with window previews, 2026 | Closest in feature shape to JustTab's Cmd+Tab use; GPL |
| ejbills/DockDoor | Dock previews plus a window switcher | Second-largest; GPL; includes a window switcher mode |
| sergio-farfan/alttab-macos | JustTab's upstream (fork point v1.1.1) | MIT; now at v1.3.3 with fixes JustTab lacks |

Discovery: `gh api -X GET search/repositories -f q='alt-tab macos window switcher' -f sort=stars -f per_page=30` and `-f q='topic:window-switcher macos'`. Everything else returned by those searches with more than 20 stars is listed in 1.2; the rest are <10-star personal projects (many created in 2026) and were not examined.

### 1.2 Smaller open-source projects (metadata only, not read)

| Repo | Stars | Licence | Lang | Last push | Note |
|---|---|---|---|---|---|
| eacryo/oh-my-tab | 33 | MIT | Rust | 2026-11-09 | Cmd+Tab alternative |
| martonpaulo/windowhop | 27 | GPL-3.0 | Swift | 2026-11-02 | "Switch between windows, not just apps" |
| sean01zhang/window-switcher | 24 | Apache-2.0 | Swift | 2026-06-14 | Fuzzy-find overlay, not Alt-Tab style |

Command: `gh api repos/OWNER/REPO --jq '"\(.stargazers_count)\t\(.license.spdx_id)\t\(.language)\t\(.pushed_at)"'`.

### 1.3 Closed-source alternatives (note only)

Witch (Many Tricks), Contexts, HyperSwitch and a Mac App Store app called "AltTab Switcher" exist as paid or closed products in this category. None was installed or inspected here; no technical claims are made about them. One data point from the peers: lwouis #447 cites HyperSwitch as able to focus other-Space windows without the "flash" trick [verified: `gh api repos/lwouis/alt-tab-macos/issues/447`]; DockDoor #1097 reports an unauthorised paid copy of DockDoor on the Mac App Store [verified: search listing above].

---

## 2. Vital statistics

All numbers pulled 2026-11-10.

| | JustTab | sergio-farfan/alttab-macos | rokartur/BetterCmdTab | ejbills/DockDoor | lwouis/alt-tab-macos |
|---|---|---|---|---|---|
| Stars | private repo | 8 | 865 | 6,544 | 16,507 |
| Created | fork 2026 | 2026-03-17 | 2026-05-22 | 2024-06-03 | 2019-08-14 |
| Last push | — | 2026-09-19 | 2026-11-09 | 2026-11-08 | 2026-11-04 |
| Last commit (clone) | — | 165a520 2026-09-19 | a63f6f7 2026-11-09 | 6d3c0db 2026-11-08 | ec4f94a 2026-11-04 |
| Latest release | none | v1.3.3 (2026-09-19) | 26.7 (2026-08-13) | 1.42.4 (2026-11-08) | v11.10.1 (2026-10-23) |
| Licence | MIT | MIT | GPL-3.0 | GPL-3.0 (API says NOASSERTION; LICENSE file is GPL-3.0 text) | GPL-3.0 |
| Language | Swift/AppKit | Swift/AppKit | Swift/AppKit | Swift/SwiftUI+AppKit | Swift/AppKit (+ObjC glue) |
| App lines (.swift/.m/.h) | 2,075 | 2,839 | 38,877 | 41,642 | 49,138 |
| Test lines | 209 | 958 | 4,623 | 1,550 | 19,188 |
| Third-party packages | 0 | 0 | 4 (Better* family, same author) | 6 (Sparkle, Defaults, LaunchAtLogin-Modern, SmoothGradient, ConfettiSwiftUI, mediaremote-adapter) | 3 vendored (Sparkle, ShortcutRecorder, AppCenter) |
| User settings | 2 (shortcut, Launch at Login) | 5 menu items (Launch at Login, Appearance, Background, Glass Strength, Show Window Previews); shortcut hard-coded | 106 `@Published` preferences | ≤264 `Defaults.Key`s (upper bound; includes internal state) | 34 global keys + 12 keys per shortcut, up to 9 shortcuts |
| Min macOS | 13 | 13 | 13.0 | 14.5 | 12.0 |
| Distribution | build from source | ad-hoc DMG + third-party Homebrew tap | Homebrew cask `bettercmdtab` (413 installs/30d), signed DMG, own updater | Homebrew cask `dockdoor` (2,353/30d), notarized DMG, Sparkle | Homebrew cask `alt-tab` (3,442/30d), notarized ZIP, Sparkle |
| Paid tier | none | none | none | separate "DockDoor Pro" app, $20, promoted in-app | "AltTab Pro" since v11.0.0 (2026-05-21), 14-day trial |
| Networking | none | none | update check to GitHub only (README) | Sparkle updates | Sparkle updates + AppCenter crash reports (opt-in, default "ask") |
| Accessibility | required | required | required | required | required |
| Screen Recording | optional (thumbnails) | opt-in (previews off by default) | optional (previews need it) | optional (previews need it) | waivable ("degraded mode") |

Commands behind the table:

- Stars/dates/licence/language: `gh api repos/OWNER/REPO --jq '{stars:.stargazers_count, license:.license.spdx_id, lang:.language, pushed:.pushed_at, created:.created_at}'`
- Latest release: `gh api repos/OWNER/REPO/releases/latest --jq '"\(.tag_name)\t\(.published_at)\t\(.assets|map(.name)|join(","))"'`
- Last commit: `git -C <clone> log -1 --format='%cs %h %s'`
- Lines, excluding vendored/third-party code and tests:
  - JustTab: `find /Users/leonardchow/work/justtab-seed/AltTab/AltTab -name '*.swift' -print0 | xargs -0 wc -l | tail -1` → 2,075; tests `find /Users/leonardchow/work/justtab-seed/tests -name '*.swift' -print0 | xargs -0 wc -l | tail -1` → 209
  - sergio-farfan: `find sergio-farfan_alttab-macos/AltTab/AltTab -type f \( -name '*.swift' -o -name '*.m' -o -name '*.h' \) -print0 | xargs -0 wc -l | tail -1` → 2,839; tests under `Tests/` → 958
  - BetterCmdTab: `find rokartur_BetterCmdTab/BetterCmdTab … | xargs -0 wc -l | tail -1` → 38,877 (excludes `BetterCmdTabTests/`, `web/`, `scripts/`); tests → 4,623
  - DockDoor: `find ejbills_DockDoor/DockDoor … -print0 | xargs -0 wc -l | tail -1` → 41,642 (excludes `DockDoorTests/`, `Sparkle/` which holds only `generate_appcast`, `BuildTools/`); tests → 1,550
  - lwouis: `find lwouis_alt-tab-macos/src -type f \( -name '*.swift' -o -name '*.m' -o -name '*.h' \) -not -path '*/vendors/*' -not -path '*/_test-support/*' -not -name '*Tests.swift' -print0 | xargs -0 wc -l | tail -1` → 49,138. Excluded: `vendor/` (Sparkle, AppCenter, ShortcutRecorder as local SPM packages, per `docs/contributing.md:34`), `src/vendors/` (glue, 559 lines), `src/_test-support/`, and 19,188 lines of `*Tests.swift` that live inside `src/`.
- Settings: lwouis `sed -n '15,120p' src/preferences/Preferences.swift | grep -cE '^\s+"[A-Za-z0-9]+":'` → 34 global keys; per-shortcut keys counted by hand at `Preferences.swift:50-67` (12 per index, `maxShortcutCount = 9` at `:153`). BetterCmdTab `grep -c '@Published var' BetterCmdTab/App/Preferences.swift` → 106. DockDoor `grep -rhoE 'Key<[^>]+>\("[^"]+"' DockDoor | sort -u | wc -l` → 264. sergio `grep -n 'NSMenuItem(title' AltTab/AltTab/PreferencesMenu.swift`. JustTab `grep -n 'NSMenuItem(title' PreferencesMenu.swift` (Change Shortcut…, Launch at Login; the rest are permission prompts, About, Quit).
- Min macOS: `grep -n MACOSX_DEPLOYMENT_TARGET <project>.xcodeproj/project.pbxproj | head -2`; sergio and JustTab from README badge.
- Homebrew: `curl -s https://formulae.brew.sh/api/cask/{alt-tab,dockdoor,bettercmdtab}.json` (fields `version`, `analytics.install.30d`). Sergio's tap: README.md:40-46 (`brew install --cask sergio-farfan/tap/alttab`).
- Notarization: lwouis `scripts/package_and_notarize_release.sh` exists; DockDoor README.md:63 "Notarized by Apple"; BetterCmdTab README.md:24 says "signed .dmg" (notarization not verified); sergio README.md:37-38 says "not yet notarized".
- Pro: lwouis `changelog.md:400-405` ("# 11.0.0 … (2026-05-21) … introducing alt-tab pro!"), `src/pro/ProFeature.swift:1-15` (gated: app-icons-and-titles style, auto-size, search-on-release, extra shortcuts, in-switcher search), https://alt-tab.app/ ("Every Pro feature is free to try for 14 days", no price shown). DockDoor README.md:128-142 ("$20 one-time for 3 Macs"), `DockDoor/Views/Settings/Shared Components/DockDoorProPromo.swift` exists.
- Networking: `grep -rl 'URLSession\|Sparkle\|SPUUpdater\|AppCenter\|BetterUpdater' <app dir> | wc -l` → JustTab 0, sergio 0, BetterCmdTab 5, DockDoor 4, lwouis 16.
- Permissions: lwouis `src/secondary-windows/permission-window/PermissionFlow.swift:4,21` ("Screen Recording is waivable"); BetterCmdTab README.md:26; DockDoor README; sergio README.md:56; JustTab README.

---

## 3. Technical approach, verified from source

File paths are relative to each clone's root; JustTab paths relative to `AltTab/AltTab/`.

### 3.1 Window enumeration

| | JustTab | sergio upstream | BetterCmdTab | DockDoor | lwouis |
|---|---|---|---|---|---|
| Primary list | `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements])` on every activation (`WindowModel.swift:145`) | Same CG call for the cold path; otherwise a cached list refreshed off-main (`WindowModel.swift:13-18, 279, 350`) | `CGWindowListCopyWindowInfo(.optionAll)` plus `.optionOnScreenOnly` for z-order (`Windows/WindowEnumerator.swift:196-197`) + per-app AX | Per-app AX `kAXWindows` into a persistent cache; CG lists as hints (`Utilities/Window Management/WindowDiscoveryShared.swift:405,460`) | Private `CGSCopyWindowsWithOptionsAndTags` over every Space in one call (`src/macos/CGSCallScheduler.swift:100`, `src/switcher/state/Applications.swift:203-210`) |
| Minimized | AX pass, parallel per app, keeps only `kAXMinimized == true` (`WindowModel.swift:161-179, 213-216`) | Same AX pass, `discoverOffScreen` also keeps non-minimized off-screen windows (`WindowModel.swift:424-448`) | AX pass | AX observers `kAXWindowMiniaturized/Deminiaturized` (`WindowManipulationObservers.swift:15-16`) | Preference `showMinimizedWindows` (`Preferences.swift:55`) |
| ⌘H-hidden apps | **not listed** (not on-screen, not minimized) | listed since 1.2.0 (CHANGELOG; `WindowModel.swift:9`) | listed (AX) | `kAXApplicationHidden/Shown` observers (`:17-18`) | `showHiddenWindows` (`Preferences.swift:56`) |
| Other Spaces | **not listed** | listed since 1.2.0 via the same AX pass (CHANGELOG 1.2.0) | private `CGSCopySpacesForWindows` / `CGSCopyManagedDisplaySpaces` resolved through `dlsym` (`System/PrivateAPIs.swift:118,125,167-208`) | private `CGSCopyManagedDisplaySpaces` for current Space IDs (`WindowDiscoveryShared.swift:446`), `CGSCopySpacesForWindows` (`Extensions/CoreGraphics/CGWindowID.swift:19`); setting `showWindowsFromCurrentSpaceOnlyInSwitcher` default false (`consts.swift:125`) | private Spaces model (`src/switcher/state/Spaces.swift:34-45`), `spacesToShow` default all (`Preferences.swift:53`) |
| Fullscreen | Panel can appear over fullscreen (`SwitcherPanel.swift:43` `.fullScreenAuxiliary`); windows in other fullscreen Spaces are off-screen so **not listed** | same as JustTab for the panel; other-Space windows listed | per-app "skip in fullscreen" rules (README) | `fullscreen` title matches in 20 issues | `showFullscreenWindows` (`Preferences.swift:57`) |
| Persistent model | none; fresh list per activation (22-30 ms warm per SYNTHESIS) | cache + debounced refresh + reconcile (`AppDelegate.swift:8-9, 146-149`) | `AppCatalogCache` fed by AX observers (`Catalog/AppCatalogCache.swift:97-101`; `ARCHITECTURE.md` "panel opens from cache") | `SpaceWindowCacheManager` fed by 12 AX notifications (`WindowManipulationObservers.swift:12-24`) | Full tracking subsystem: `src/window-tracking/` (one `AXObserver` per process, `AxObserverRegistry.swift:4-9`), `src/windowserver/` inventory |

JustTab's AX pass is parallel (`DispatchQueue.concurrentPerform`, `WindowModel.swift:166`) with a 0.25 s per-app timeout (`:133`); the upstream made the same change in 1.3.2 [verified: CHANGELOG 1.3.2].

### 3.2 MRU tracking

| | Mechanism | Guard against background apps |
|---|---|---|
| JustTab | `NSWorkspace.didActivateApplication` → focused window off-main (`WindowModel.swift:253-281`) + per-app `AXObserver` on `kAXFocusedWindowChanged` (`:298-313, 330-336`) | **none**: any app's focus change is promoted (`:330-336`) |
| sergio upstream | same two sources | ignores notifications from apps that are not frontmost (`WindowModel.swift:695-698`), fixed in 1.3.1 for "Electron/Chromium window churn" |
| BetterCmdTab | AX observers + "MRU bumps" into the catalog cache (`AppCatalogCache.swift:97-101`; `Windows/WindowMRUTracker.swift`) | not checked |
| DockDoor | `kAXMainWindowChanged`, `kAXFocusedWindowChanged` observers (`WindowManipulationObservers.swift:21-23`) | not checked |
| lwouis | `AttentionDriver`/`AttentionModel` in `src/window-tracking/` turn AX and WindowServer events into an order | elaborate; see `AttentionSettlePolicy.swift` |

### 3.3 Focusing a window

| | Steps | API class |
|---|---|---|
| JustTab | `NSRunningApplication.activate(options: .activateIgnoringOtherApps)` on main (`WindowActivator.swift:43`); if the window is its app's front window, skip the AX raise and check 150 ms later, raise only if the wrong window is focused (`:49-60`); otherwise off-main `kAXRaiseAction` + `kAXMain` after matching by `_AXUIElementGetWindow` (`:86-105`), unminimize first if needed (`:97-99`) | public + `_AXUIElementGetWindow` |
| sergio upstream | plain `activate()` on macOS 14+, deprecated flag below (`WindowActivator.swift:57-63`); ghost check via `CGWindowListCreateDescriptionFromArray` before activating (`:35-48`); per-window AX timeouts | public + `_AXUIElementGetWindow` |
| BetterCmdTab | `NSApp.yieldActivation(to:)` + `activate(from: .current)` on macOS 14+ (`Windows/Activator.swift:749-763`, fixing #180), unminimize, `kAXRaiseAction`, then private `_SLPSSetFrontProcessWithOptions` + `SLPSPostEventRecordTo` synthetic click pair (`System/PrivateAPIs.swift:559-581`), `kAXMain`/`kAXFocused`; re-assert at +80 ms and verify focus at +200 ms (`Activator.swift:541-612`) | public + SkyLight private via `dlsym` |
| DockDoor | `_SLPSSetFrontProcessWithOptions` + `makeKeyWindow` (synthetic click posted with `SLPSPostEventRecordTo`, `WindowUtil.swift:2018-2032`), then `kAXRaiseAction` + `kAXMainWindowAttribute`, 3 retries (`WindowInfo.swift:438-470`) | SkyLight private via `dlsym` (`Utilities/PrivateApis.swift:142-147`) |
| lwouis | 4-step: `_SLPSSetFrontProcessWithOptions(psn, wid)` → `makeKeyWindow` synthetic click → `kAXRaiseAction` with stale-element heal → restore origin Space front process via `SLSSpaceSetFrontPSN` (`src/switcher/state/Window.swift:408-455, 580-598`); plus "repair if superseded" and `verifyNotCovered` (#6064). The comment at `Window.swift:408-409` states the motivation: "macOS 14 downgraded NSRunningApplication.activate to an advisory request" | SkyLight private via `@_silgen_name` |

### 3.4 Thumbnail capture

| | API | When | Minimized windows | Size cap |
|---|---|---|---|---|
| JustTab | `SCScreenshotManager.captureImage` one-shot (`WindowCapture.swift:147`) | on demand per activation, selected first, 8 concurrent, cancelled on dismiss (`:65-125`); last image cached per window (`:32,37-45`) | icon only (`:42,86`) | 640 px longest side (`:29`) |
| sergio upstream | same API (`WindowCapture.swift:70`), opt-in, off by default (`:28-34`) | on demand | icon only | 400 px (`:38`) |
| BetterCmdTab | private `CGSHWCaptureWindowList` only (`System/PrivateAPIs.swift:151-162`); reason given at `Switcher/WindowThumbnailCache.swift:47-50`: SCK "flags the session as screen-shared, which shows the menu bar sharing indicator and on macOS 15 blocks Apple Watch unlock (#200)" | async, off the reveal path, LRU cache (`:35-45`) | yes (private API can) | nominal then full resolution (`:302-308`) |
| DockDoor | private `CGSHWCaptureWindowList` with a 30 s cache (`WindowUtil.swift:519-556`, `consts.swift:68`); optional `SCStream` live previews, default off, low quality, 10 fps (`LiveWindowCapture.swift:155-240`, `consts.swift:75-80`) | on hover/switcher open; cached | yes | configurable |
| lwouis | macOS 26+: `SCScreenshotManager.captureScreenshot` / `captureSampleBuffer` (`src/events/WindowCaptureEvents.swift:234-262`); below 26: `CGSHWCaptureWindowList` (`:319-326`). Reason at `src/switcher/state/WindowThumbnails.swift:170-178`: "macOS 14 crashes inside Apple's own teardown … macOS 15 hits the bugs in #5190 … we only use [SCK] on macOS 26" | continuous background capture by default (`captureWindowsInBackground: true`, `Preferences.swift:46`) plus on-show refresh; full-res preview frames fetched just-in-time (`WindowThumbnails.swift:189-200`) | yes (`WindowCaptureEvents.swift:319`) | thumbnail-scale, full-res on demand |

### 3.5 Hotkey mechanism

| | Mechanism | Thread | Secure Input | Native ⌘Tab |
|---|---|---|---|---|
| JustTab | one `CGEvent` tap, session, head-insert, default (active) tap, `flagsChanged`+`keyDown`, swallows the trigger and all keys while open (`HotkeyManager.swift:117-139, 222-286`); 2 s poll re-enables a disabled tap (`:145-168`) | main run loop (`:136`) | no trigger fallback; only recovers a missed modifier release (`:241-247`) | suppressed by swallowing the keyDown (works for the owner today) |
| sergio upstream | same tap design; Option+Tab hard-coded (`HotkeyManager.swift:172`) | main | none | n/a |
| BetterCmdTab | tap on its own thread, **tail-append** so listen-only taps (KeyCastr) still see ⌘Tab (`Input/HotkeyTap.swift:501-508`); Carbon `RegisterEventHotKey` as the "survivor trigger" under Secure Input (`Input/CarbonHotkeyTrigger.swift:94`; `ARCHITECTURE.md` "The ⌘Tab hot path") | own thread | Carbon fallback | private `CGSSetSymbolicHotKeyEnabled` (`System/PrivateAPIs.swift:78-101`), noted as "the only way … while another app holds Secure Event Input" and "persists after the app quits" |
| DockDoor | active session tap incl. mouse-down (`Utilities/KeybindHelper.swift:572-578`) on `EventTapThread` (`:593`); also watches the native ⌘Tab switcher through AX on the Dock process (`Utilities/DockObserver+CmdTab.swift:1-60`) | own thread | not checked | not disabled; enhances the native one |
| lwouis | Carbon `RegisterEventHotKey` for shortcuts (`src/events/KeyboardEvents.swift:196`) + **listen-only** session tap for modifier flags (`:229-232`) + a cghid Esc tap enabled only while open (`:239-243`) | dedicated keyboard thread (`:255-257`) | comment at `:221-222`: "SecureInput does not block flagsChanged … keyDown is filtered out at the system level"; #157 (95 comments) and #3117 (150 comments) are about this | private `CGSSetSymbolicHotKeyEnabled` (`src/macos/api-wrappers/SkyLight.framework.swift:93-102`; `ControlsTab.swift:743-751`) |

### 3.6 Multi-display

| | Where the panel opens |
|---|---|
| JustTab | `NSScreen.main ?? screens.first` — the screen holding the key window (`SwitcherPanel.swift:94`); no setting |
| sergio upstream | screen under the mouse, fallback main (`SwitcherPanel.swift:278-279`), since 1.2.0 |
| BetterCmdTab | mouse screen / "main display" (origin-zero) / active-menubar display, with explicit reasoning that `NSScreen.main` means the active screen (`Switcher/SwitcherPanel.swift:452-470`) |
| DockDoor | mouse screen or a pinned screen (`KeybindHelper.swift:390-417`) |
| lwouis | preference `showOnScreen`: active / includingMouse / includingMenubar (`src/preferences/MacroPreferences.swift:215-218`), default active (`Preferences.swift:29`) |

### 3.7 Latency techniques

- JustTab: prewarmed cell pool (`SwitcherPanel.swift:29,50`), icon cache (`WindowModel.swift:48-76`), cached last thumbnails (`WindowCapture.swift:37-45`), parallel AX, overlap of `SCShareableContent` fetch with list build (`AppDelegate.swift:107-108`), progressive captures. Measured: warm open 34 ms, first thumbnail ~55 ms, all ~240-280 ms (SYNTHESIS).
- sergio upstream: cached list shown instantly, reconcile off-main (1.2.0), fixes for the three bugs this created (1.3.1 wrong first window, 1.3.2 stale after idle, 1.3.2 wedged app erasing MRU) [verified: CHANGELOG].
- BetterCmdTab: persistent catalog cache, thumbnails off the reveal path, CG snapshot kept as `NSDictionary` to avoid bridging (`WindowEnumerator.swift:190-196`).
- DockDoor: persistent cache plus 30 s image cache.
- lwouis: persistent tracked model, three off-main schedulers (`src/main-thread-ipc.md:1-10`), and a default `windowDisplayDelay` of **100 ms** before the panel is shown (`Preferences.swift:25`) — i.e. the reference app deliberately waits longer than JustTab's whole warm open. Its lag issue #5177 (79 comments, closed "unreproducible") is about a 1-2 s freeze after switching, not about open time.

---

## 4. Issue trackers: what users complain about

Totals: `gh api -X GET search/issues -f q="repo:OWNER/REPO is:issue" --jq .total_count` → lwouis 5,595 (83 open), DockDoor 1,227 (83 open), BetterCmdTab 143 (12 open), sergio 1 (0 open). Keyword counts below are title-only matches (`… -f q="repo:… is:issue in:title <keywords>"`), so they undercount but are not inflated by issue templates.

| Title keyword group | lwouis | DockDoor | BetterCmdTab |
|---|---|---|---|
| lag / slow / latency / freeze / hang | 56 | 9 | 0 |
| cpu / memory / leak / battery | 46 | 4 | 0 |
| "wrong window" / focus | 152 | 20 | 5 |
| permission / "screen recording" / accessibility | 68 | 12 | 0 |
| "secure input" | 2 | 0 | 1 |
| sonoma / sequoia / tahoe | 50 | 3 | 0 |
| "macOS 14/15/26" / beta | 54 | 11 | 5 |
| fullscreen | 44 | 20 | 5 |
| space(s) / desktop | 110 | 41 | 7 |
| crash | 59 | 14 | 2 |

Most-reacted and most-commented issues (`… -f sort=reactions` / `-f sort=comments`):

**lwouis/alt-tab-macos**
- #3117 (98 reactions, 150 comments) Secure Input makes AltTab behave as if Tab is held. #157 (95 comments) shortcuts stop working under Secure Input.
- #1082 (70 reactions) run without Screen Recording in degraded mode; #3477 (57, Sequoia says recording not allowed although it is); #3973 (53) "macOS 15.2 AltTab Is Accessing Your Screen popup madness"; #2606 (139 comments) Sonoma menubar icon "AltTab is sharing your screen".
- #4255 (90 comments) WindowServer memory +1-5 GB with AltTab running, freed on quit.
- #4192 (154 comments) focus not moving to Teams/Grammarly-affected apps; #6064 switcher not fully focusing the window "1 out of 20 quick switches"; #563 (162 comments) window hangs 0.5-1.5 s after choosing.
- #447 (92 comments) the other-Space "flash" trick; #5177 (79 comments) lag after switching; #3882 (110 comments, open) users asking for options removed in v7.
- #1179 (213 reactions, 2021) maintainer looking for someone to take over.

**ejbills/DockDoor**
- #9 (25 comments) previews unavailable for apps on another Space (needed private API); #243 (40) previews randomly stop; #1001 (22) "frequent restart required" on 15.6.1; #21 no preview for VS Code/Calendar/Finder; #238 no preview of minimized/hidden window unless previewed once.
- #1254 (17 reactions) change the modifier key; #688 backup settings; #472 preview stays open on fast mouse.

**rokartur/BetterCmdTab**
- #35 (14 reactions) Homebrew support; #180 selected app comes forward without keyboard focus; #39 "Cmd Tab sometimes activates windows I do not expect"; #46 switcher invisible on other Spaces after closing a fullscreen app; #199 (13 comments) DRM video in Chrome crashes the app and re-triggers the Screen Recording prompt; #145 browser tab previews take 1-2 s.

**sergio-farfan/alttab-macos**: one issue, #4 "Option to change shortcut" (Option+Tab → Cmd+Tab), closed 2026-10-01 without the feature; the shortcut is still hard-coded (`HotkeyManager.swift:172`).

### 4.1 Which of these could hit JustTab

| Complaint class | Could hit JustTab? | Why / why not |
|---|---|---|
| WindowServer memory from capture (lwouis #4255) | No | JustTab captures only while the panel is open, one-shot, 640 px, cancelled on dismiss (`WindowCapture.swift:29, 119-125`) [verified] |
| "Sharing your screen" indicator (lwouis #2606, BetterCmdTab #200) | Low | `SCScreenshotManager` one-shots, no `SCStream`. The purple indicator is tied to streams [inference; not tested on this Mac] |
| macOS 15 monthly Screen Recording re-prompt (lwouis #3973) | Yes | System behaviour for any app holding the permission. The upstream dropped SCK over it (CHANGELOG 1.1.0) and made previews opt-in (1.2.0). JustTab degrades to icons, which limits the damage [verified: `WindowCapture.swift:68-71`] |
| Private API breaks on a macOS update (many lwouis/DockDoor "Sequoia/Tahoe" titles) | No | JustTab's only non-public symbol is `_AXUIElementGetWindow`, which every peer also uses [verified: section 3] |
| Secure Input kills or sticks the shortcut (lwouis #157/#3117) | Yes | JustTab's trigger is a `keyDown` tap; keyDowns are not delivered under Secure Input. Only the missed-release case is handled (`HotkeyManager.swift:241-247`). Frequency: whenever a password field is focused |
| Wrong window focused / app front but no key focus (BetterCmdTab #180, lwouis #6064, #4192) | Possible | JustTab uses `activate(options:)`, deprecated on 14+. Owner's logs: 5/5 correct. The verify step exists only for the front-of-app case (`WindowActivator.swift:49-60`); other windows get a blind raise. Peers see intermittent failures even with private APIs, so 5 samples do not settle it |
| Lag / hang after switching (lwouis #563, #5177) | Unlikely | JustTab's raise runs off-main with a 1 s AX timeout (`WindowActivator.swift:26-30`); measured raise 22-55 ms |
| Windows on other Spaces / hidden apps missing (DockDoor #9, lwouis #447) | Yes, by design today | See 3.1; it is the first thing a user coming from any peer notices |
| Switcher invisible after fullscreen Space changes (BetterCmdTab #46) | Possible | JustTab positions on `NSScreen.main` with `.canJoinAllSpaces`; not tested in this review |
| MRU scrambled by background window churn (upstream 1.3.1) | Yes | `WindowModel.swift:330-336` promotes any app's focus change |
| Permission confusion (lwouis #3477, 68 titles) | Partly addressed | `PermissionManager` polls every 2 s, prompts once, opens the exact pane (`PermissionManager.swift:1-20`). Ad-hoc signing re-prompts Accessibility on every rebuild (upstream CHANGELOG 1.2.1 documents the same) |

---

## 5. Gaps a user of the other apps would notice

Ordered by how early a switching user hits them.

1. **No download.** Every peer has a Homebrew cask or tap and a DMG. JustTab requires Xcode (`README.md` install section). [verified]
2. **Windows on other Spaces and ⌘H-hidden windows are absent.** All four peers list them; the upstream does it with public AX only (`WindowModel.swift:424-448`). [verified]
3. **Fullscreen apps on other Spaces are absent** (same cause). The panel itself does show over a fullscreen app (`SwitcherPanel.swift:43`). [verified for the panel; the list behaviour is an inference from 3.1]
4. **Panel screen.** Always the key window's screen; peers follow the mouse or offer a choice. For the stated audience (Windows users) the current behaviour is defensible: it is close to Windows' "primary/active" behaviour, and JustTab's rule is "no setting", so this is a default to pick, not a feature to add. [inference]
5. **Secure Input.** In a password field the shortcut does nothing (native Cmd+Tab also keeps firing for Cmd+Tab users since JustTab does not disable the symbolic hotkey). BetterCmdTab and lwouis both carry a Carbon hotkey for this. [verified for the mechanism; not reproduced on this Mac]
6. **Activation reliability on macOS 14+.** All three large peers abandoned `NSRunningApplication.activate` as the primary step (lwouis `Window.swift:408-409`, DockDoor `WindowInfo.swift:445-448`, BetterCmdTab `Activator.swift:749-763`). JustTab's 5/5 correct switches are consistent with "works nearly always"; the peers' own failure rates (#6064: ~1 in 20 under fast switching) suggest the failure shows up under rapid toggling, which 5 samples do not cover. JustTab already has the right shape of fix for one case (check after 150 ms, raise if wrong) and lacks it for the other. [verified code; frequency is inference]
7. **MRU corruption from background apps** (above). Symptom: the second slot is sometimes a window the user did not use. [verified code; upstream fixed it]
8. **Minimized windows show icons, not pictures.** Peers using `CGSHWCaptureWindowList` show the last frame. Public APIs cannot capture a minimized window. [verified: lwouis `WindowCaptureEvents.swift:319`]
9. **Stale list on cold start** is not an issue (fresh list every time), but the first switch after launch is 65 ms vs 34 ms warm (SYNTHESIS); peers hide this with persistent caches, at the cost of the staleness bugs the upstream then had to fix.

---

## 6. Positioning check

| Claim | Holds? | Evidence |
|---|---|---|
| "One job, one real setting" | Yes | Shortcut is the only behavioural setting; Launch at Login is housekeeping. lwouis: 34 global + 12×9 shortcut keys, and an open issue (#3882, 110 comments) asking for *more* options back; BetterCmdTab: 106 published preferences plus a JSON config file; DockDoor: ≤264 keys. Upstream has 5 appearance settings but **no shortcut setting** — JustTab's one setting is the one its upstream's only issue asked for |
| "Tiny" | Yes | 2,075 lines, 0 packages, vs 2,839 / 38,877 / 41,642 / 49,138 and 0 / 4 / 6 / 3 packages |
| "Free forever, no Pro tier" | Yes, and newly meaningful | lwouis AltTab added a Pro tier in v11.0.0 (2026-05-21) gating search, styles, auto-size and extra shortcuts behind a 14-day trial; DockDoor advertises a $20 Pro app inside the free app. BetterCmdTab and the upstream remain free, so the claim differentiates against the two biggest names, not against everyone |
| "No network, no telemetry" | Yes | 0 files reference networking/updaters; lwouis ships Sparkle + AppCenter (crash reports opt-in), DockDoor ships Sparkle, BetterCmdTab checks GitHub for updates. Upstream also has none |
| "Windows-style hold/tab/release" | Shared, not unique | All peers do this |
| "Live thumbnails" | Shared; JustTab's are public-API only | Upstream turns previews off by default; BetterCmdTab/DockDoor/lwouis(<26) use private capture |
| Implicit: "robust across macOS updates" | Plausible, unproven | Only one non-public symbol; peers' trackers show dozens of OS-version titles. Not a claim to publish until a release has survived a major macOS update [inference] |

Real differentiators, in order: no private SkyLight APIs; no network at all; configurable shortcut in a 2k-line app; free with no upsell. The honest weaknesses to state in the README: current Space only, no download yet.

---

## 7. Ranked recommendations

Effort: S = under a day, M = a few days including testing, L = a week or more. "Licence" says where the idea or code may come from.

| # | Technique | Why | Who does it | Expected benefit | Effort | Risk | Licence |
|---|---|---|---|---|---|---|---|
| 1 | Ship an ad-hoc-signed universal DMG from a tagged release and a personal Homebrew tap | Largest gap users hit first; everything else is invisible without an install path | Upstream 1.1.2/1.3.3 (`README.md:33-46`, `.github` workflow), all peers | From "needs Xcode" to `brew install --cask <tap>/justtab` | S-M | Gatekeeper "Open Anyway" on every update until notarized; notarization needs a paid Apple Developer account (money decision for the owner, ~USD 99/yr, not verified here) | Upstream is MIT: workflow and README wording can be reused with attribution |
| 2 | Ignore `kAXFocusedWindowChanged` from apps that are not frontmost | Stops Electron/Chromium background window churn from reordering MRU | Upstream 1.3.1 (`WindowModel.swift:695-698`) | Correct second slot after background activity | S | Very low; 3-line guard | MIT (upstream) |
| 3 | Run the existing "check focused window after 150 ms, raise if wrong" for every switch, not only the front-of-app case; add one re-assert at ~80 ms for the raise path | Peers converged on verify-and-reassert because `activate` became advisory on macOS 14; JustTab already has half of it | BetterCmdTab `Activator.swift:565-612` (idea), lwouis `verifyNotCovered` (idea) | Closes the intermittent "app front, wrong window" case without private APIs | S | Low; one extra off-main AX read per switch (the happy path costs one read) | Idea only; implement from JustTab's own `WindowActivator.swift:49-60`. Do not copy GPL code |
| 4 | List ⌘H-hidden and other-Space windows from the AX pass (keep every `kAXWindows` entry that is a standard window and not on-screen, not only minimized) | The most visible feature gap vs every peer; the upstream shows it is doable with public APIs | Upstream 1.2.0 (`WindowModel.swift:424-448`) | Parity on "where is my window" | M | Medium: (a) activation of an other-Space window via `activate` + `kAXRaise` must switch Space — upstream claims it works, not tested here [inference]; (b) the AX pass does more work per app (upstream mitigated with its cache); (c) thumbnails for those windows are not capturable with public APIs (icon fallback). Measure the list time before/after | MIT (upstream) |
| 5 | Carbon `RegisterEventHotKey` as a second trigger when the tap sees no keyDown (Secure Input) | Loudest long-running complaint class in the reference app (#157, #3117) | BetterCmdTab `CarbonHotkeyTrigger.swift`, lwouis `KeyboardEvents.swift:196` | Shortcut keeps working in password fields | M | Medium: Carbon hotkeys cannot swallow the native Cmd+Tab (peers do that with a private symbolic-hotkey call, see "not worth it"); for Option+Tab users the fallback is clean, for Cmd+Tab users the native switcher may also appear. Needs testing with a real Secure Input app | Public Carbon API; implement independently |
| 6 | Pick the panel screen rule deliberately and document it | Users with two displays ask about it in every peer | Upstream (mouse screen), BetterCmdTab (`SwitcherPanel.swift:463-470` explains the `NSScreen.main` trap) | Predictable behaviour | S | Low | n/a |
| 7 | Event tap on its own thread | Peers all do it; protects the shortcut from main-thread stalls and tap time-outs | lwouis `KeyboardEvents.swift:255-257`, BetterCmdTab, DockDoor | Fewer "shortcut stopped working" moments | S-M | Low-medium; already in SYNTHESIS round 2 "only if stalls remain" | Idea only |
| 8 | "Show CG windows first, merge AX later" (already SYNTHESIS round 2) rather than a persistent window model | Upstream's persistent cache produced three follow-up bugs (1.3.1, 1.3.2); lwouis needed a tracking subsystem of ~17 files | Upstream 1.3.2 cold path (`WindowModel.swift:279`) | Warm open ~34 → ~12 ms (SYNTHESIS estimate) | M | Medium: late minimized windows reflow the grid | Idea; MIT if taken from upstream |

### Not worth borrowing

| Technique | Who | Why not |
|---|---|---|
| `_SLPSSetFrontProcessWithOptions` + `SLPSPostEventRecordTo` synthetic clicks | lwouis, DockDoor, BetterCmdTab | Private SkyLight; byte-offset event records (`WindowUtil.swift:2018-2032`) can break silently on any macOS release; forbids Mac App Store; peers still report focus misses (#6064, #180). Implementations are GPL |
| `CGSHWCaptureWindowList` | lwouis (<26), DockDoor, BetterCmdTab | Private; its one real advantage is minimized-window thumbnails. SCK one-shots cover the rest |
| `CGSCopyWindowsWithOptionsAndTags`, `CGSCopySpacesForWindows`, `CGSCopyManagedDisplaySpaces` | lwouis, DockDoor, BetterCmdTab | Private; lwouis #5791/#5954 show the edge cases (empty arrays meaning three different things). The AX route (rec. 4) gets most of the value |
| `CGSSetSymbolicHotKeyEnabled` to disable native Cmd+Tab | lwouis, BetterCmdTab | Private and **persists after the app quits** (BetterCmdTab `PrivateAPIs.swift:97-99`), so a crash leaves the user without Cmd+Tab. JustTab's tap-swallow works for the owner today |
| Continuous background capture | lwouis (`captureWindowsInBackground` default true) | Source of #4255 (WindowServer +1-5 GB) and constant CPU |
| `SCStream` live previews | DockDoor (optional) | Streams trigger the sharing indicator, cost CPU, and crashed on macOS 14 per lwouis (`WindowThumbnails.swift:170-178`) |
| Search, browser tabs, tiling, media widgets, Dock replacement | BetterCmdTab, DockDoor, lwouis Pro | Outside "one job"; this is where the peers' settings counts come from |
| Sparkle / in-app updater | lwouis, DockDoor, BetterCmdTab | Breaks "no network"; Homebrew covers updates for the target audience |

---

## 8. Reproduction commands (summary)

```
# metadata
gh api repos/lwouis/alt-tab-macos --jq '{stars:.stargazers_count,license:.license.spdx_id,pushed:.pushed_at}'
gh api repos/ejbills/DockDoor --jq '{stars:.stargazers_count,license:.license.spdx_id,pushed:.pushed_at}'
gh api repos/rokartur/BetterCmdTab --jq '{stars:.stargazers_count,license:.license.spdx_id,pushed:.pushed_at}'
gh api repos/sergio-farfan/alttab-macos --jq '{stars:.stargazers_count,license:.license.spdx_id,pushed:.pushed_at}'
gh api repos/OWNER/REPO/releases/latest --jq '"\(.tag_name)\t\(.published_at)"'
curl -s https://formulae.brew.sh/api/cask/alt-tab.json | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["version"],d["analytics"]["install"]["30d"])'

# clones (read-only, scratchpad)
P=/private/tmp/claude-501/-Users-leonardchow/d5ecda92-88b0-442c-8060-eaabc167a069/scratchpad/peers
git -C $P/lwouis_alt-tab-macos log -1 --format='%cs %h'

# line counts
find $P/lwouis_alt-tab-macos/src -type f \( -name '*.swift' -o -name '*.m' -o -name '*.h' \) -not -path '*/vendors/*' -not -path '*/_test-support/*' -not -name '*Tests.swift' -print0 | xargs -0 wc -l | tail -1
find $P/ejbills_DockDoor/DockDoor -type f \( -name '*.swift' -o -name '*.m' -o -name '*.h' \) -print0 | xargs -0 wc -l | tail -1
find $P/rokartur_BetterCmdTab/BetterCmdTab -type f \( -name '*.swift' -o -name '*.m' -o -name '*.h' \) -print0 | xargs -0 wc -l | tail -1
find $P/sergio-farfan_alttab-macos/AltTab/AltTab -type f \( -name '*.swift' -o -name '*.m' -o -name '*.h' \) -print0 | xargs -0 wc -l | tail -1
find /Users/leonardchow/work/justtab-seed/AltTab/AltTab -name '*.swift' -print0 | xargs -0 wc -l | tail -1

# settings
sed -n '15,120p' $P/lwouis_alt-tab-macos/src/preferences/Preferences.swift | grep -cE '^\s+"[A-Za-z0-9]+":'
grep -c '@Published var' $P/rokartur_BetterCmdTab/BetterCmdTab/App/Preferences.swift
grep -rhoE 'Key<[^>]+>\("[^"]+"' $P/ejbills_DockDoor/DockDoor | sort -u | wc -l

# issues
gh api -X GET search/issues -f q="repo:lwouis/alt-tab-macos is:issue" --jq .total_count
gh api -X GET search/issues -f q="repo:lwouis/alt-tab-macos is:issue" -f sort=reactions -f per_page=12 --jq '.items[]|"#\(.number)\t\(.reactions.total_count)\t\(.comments)\t\(.title)"'
gh api -X GET search/issues -f q='repo:lwouis/alt-tab-macos is:issue in:title "secure input"' --jq .total_count

# private API scan (count of files per symbol)
grep -rl '_SLPSSetFrontProcessWithOptions' $P/*/ | sort
```

What was not checked: closed-source apps; actual behaviour of any peer on this Mac (nothing was run); whether other-Space activation via public APIs switches Space (upstream's claim); whether `SCScreenshotManager` one-shots ever show the sharing indicator; BetterCmdTab notarization status; the Apple Developer Program fee.
