# Launch post drafts

Internal publishing instructions: copy only the fenced post text. Counts, headings, preconditions and gallery directions are editorial notes. Nothing has been posted. Every section requires the repository to be public first (F16). Installation in these drafts is the notarized download from GitHub Releases (v1.2.0, 2026-11-11), with building from source as the alternative.

Counts are Unicode code points, including spaces and punctuation, excluding fence markers and the final newline. X posts also fit when their one URL is counted as 23 characters. Recheck platform rules at posting time. Run `python3 marketing/check-copy.py` to verify the printed counts.

## GitHub repository

Preconditions: the owner has made the repository public. Publish the README with its F9 credit before setting the description and topics.

<!-- count: GitHub description; max: 350 -->
```text
Windows-style Alt-Tab for the Mac: JustTab switches individual windows, not just apps, in one thumbnail grid. Option+Tab by default, with a configurable shortcut. Free forever, open source (MIT), no networking code. Requires macOS 13+; live thumbnails need macOS 14+ and Screen Recording permission. Signed, notarized download in Releases.
```
(339/350)

**Topics**

```text
macos, window-switcher, swift, appkit, menu-bar-app, open-source, mit-license, keyboard-shortcuts
```

## Show HN

Preconditions: the repository is public. Check the source install on a real Mac before posting. Keep the measurement conditions with the speed figures.
Preconditions for optional lines: confirm P1, P2, P4 and P5 on a real Mac, or delete the tagged lines. <!-- P1 P2 P4 P5 -->

<!-- count: Show HN title; max: 80 -->
```text
Show HN: JustTab – Windows-style Alt-Tab for the Mac, free and open source
```
(74/80)

**First comment**

```text
JustTab switches between individual windows, not just apps. It puts windows from all apps in one grid, ordered most recently used first. On macOS, Cmd-Tab switches apps; Cmd-` cycles windows of the current app only.

Hold Option+Tab, tap Tab or the arrow keys to move, then release to switch. Shift+Tab goes back, Esc cancels, and clicking a thumbnail switches to it. The previous window is selected on opening, so a quick press and release toggles between your two most recent windows. Minimized windows are included and shown dimmed.

The shortcut is the one real setting, with a separate Launch at Login toggle. Record any key plus one or more of Control, Option, Shift and Cmd via Change Shortcut… in the menu bar. Esc cancels recording. Cmd+Tab replaces the built-in app switcher while JustTab runs. There is no Dock icon.

Pure Swift + AppKit, zero third-party dependencies, about 2,600 lines of Swift and about 520 KB on disk. Memory use is about 25 MB. On the developer's Mac with 22 windows open in November 2026, the median of real Cmd+Tab use was about 34 ms from key press to the switcher appearing and about 55 ms from key press to the first live thumbnail. These are measurements under those conditions.

The source uses exactly one private macOS function: _AXUIElementGetWindow, to match an accessibility window to its window ID.

- Apps hidden with Cmd-H are listed; choosing a window brings the app back. [P1]
- Windows on other desktops (Spaces) are listed; choosing one switches to that desktop. [P2]
- The switcher opens on the display that has the mouse pointer. [P4]
- After each switch, JustTab checks that the chosen window came to the front and retries once if needed. [P5]

Requires macOS 13+ and Accessibility permission. Live thumbnails need macOS 14+ and Screen Recording permission; otherwise, app icons are shown.

Download (free; signed with Developer ID and notarized by Apple): https://github.com/shuaige121/justtab/releases/latest
Unzip and move JustTab to Applications. Building from source with Xcode is also possible.

Free forever and open source (MIT). No paywall, no Pro tier, no upsell; nothing in the app will ever be sold. The app contains no networking code: no telemetry, no account, no update checks.

Repository: https://github.com/shuaige121/justtab
JustTab is a stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis.
```

## r/macapps

Preconditions: the repository is public. Check the source install before posting. Attach only reviewed footage of JustTab if footage is used.
Preconditions for optional lines: confirm P1 and P2 on a real Mac, or delete the tagged lines. <!-- P1 P2 -->

**Title**

```text
JustTab: Windows-style Alt-Tab for the Mac, free forever and open source
```

**Post**

```text
JustTab brings windows from all apps into one thumbnail grid. It does one job: switching windows. The shortcut is the one real setting, with a separate Launch at Login toggle.

The default is Option+Tab. On a PC keyboard connected to a Mac, Alt acts as Option, so it is physically Alt+Tab. You can record any key plus one or more of Control, Option, Shift and Cmd through Change Shortcut… in the menu bar. Esc cancels recording. Choosing Cmd+Tab replaces the built-in app switcher while JustTab runs.

- Hold the shortcut, tap Tab or the arrow keys, release to switch. Shift+Tab goes back, Esc cancels, and clicking a thumbnail switches to it.
- Most recently used windows come first. The previous window is selected on opening, so a quick press and release toggles between your two most recent windows.
- Minimized windows are included, shown dimmed. Grid cells shrink so every listed window fits on screen.
- Lives in the menu bar, with no Dock icon.
- Apps hidden with Cmd-H are listed; choosing a window brings the app back. [P1]
- Windows on other desktops (Spaces) are listed; choosing one switches to that desktop. [P2]

Free forever, MIT-licensed and open source. No paywall, no Pro tier, no upsell; nothing in the app will ever be sold. No networking code: no telemetry, no account, no update checks.

Requires macOS 13+ and Accessibility permission. Live thumbnails need macOS 14+ and Screen Recording permission; otherwise, app icons are shown.

Download (free; signed with Developer ID and notarized by Apple): https://github.com/shuaige121/justtab/releases/latest
Unzip and move JustTab to Applications. Building from source with Xcode is also possible.

Repository: https://github.com/shuaige121/justtab
JustTab is a stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis.
```

## Product Hunt

Preconditions: the repository is public. The owner has reviewed a real source installation and the gallery assets below. Use the repository as the product link. Check the platform's current upload requirements at upload time.

**Name**

```text
JustTab
```

<!-- count: Product Hunt tagline; max: 60 -->
```text
Windows-style Alt-Tab for Mac: switch windows, not apps
```
(55/60)

<!-- count: Product Hunt description; max: 260 -->
```text
A free, open-source macOS window switcher. Hold Option+Tab, choose a window, release to switch. Requires macOS 13+ and Accessibility permission. Live thumbnails need macOS 14+ and Screen Recording permission. Signed and notarized download.
```
(239/260)

**First comment**

```text
JustTab puts windows from all apps into one grid. Windows are ordered most recently used first; the previous window is selected when it opens. A quick press and release toggles between your two most recent windows. Minimized windows are included and shown dimmed.

Hold the shortcut, tap Tab or the arrow keys to move, Shift+Tab to go back, and release to switch. Esc cancels. Clicking a thumbnail switches to it.

Default shortcut: Option+Tab. Record any key plus one or more of Control, Option, Shift and Cmd from Change Shortcut… in the menu bar; Esc cancels recording. Cmd+Tab replaces the built-in app switcher while JustTab runs. The only other setting is Launch at Login. No Dock icon.

Free forever, MIT-licensed and open source. No paywall, no Pro tier, no upsell. Nothing in the app will ever be sold. The app contains no networking code: no telemetry, no account, no update checks.

Requires macOS 13+ and Accessibility permission. Live thumbnails need macOS 14+ and Screen Recording permission; without them, app icons are shown.

Download (free; signed with Developer ID and notarized by Apple): https://github.com/shuaige121/justtab/releases/latest
Unzip and move JustTab to Applications. Building from source with Xcode is also possible.

Repository: https://github.com/shuaige121/justtab
JustTab is a stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis.
```

**Gallery shot list (capture directions, not public copy)**

1. Real JustTab grid over neutral demo windows. Include more than one window from the same app (F2); show the macOS 14+ and Screen Recording requirement in the caption (F12).
2. Two frames from the real recording: selection in the grid, then the chosen window in front after release (F3).
3. A real grid with a minimized window shown dimmed (F7).
4. The real menu bar menu showing Change Shortcut… and Launch at Login (F5).
5. The real app with Screen Recording permission withheld, showing app icons (F12).

Use the sequence and privacy checks in `capture-plan.md`. Do not invent app UI or use upstream imagery.

## X thread

Preconditions: the repository is public. Publish all five posts in order so the install, permission and credit context stays with the introduction. No assets are required.

<!-- count: X post 1; max: 280 -->
```text
JustTab is Windows-style Alt-Tab for the Mac: it switches individual windows, not just apps, in one grid. Free forever and open source (MIT). No paywall, no Pro tier, no upsell. The app contains no networking code: no telemetry, no account, no update checks.
```
(258/280)

<!-- count: X post 2; max: 280 -->
```text
Hold Option+Tab, tap Tab or the arrow keys, release to switch. Shift+Tab goes back; Esc cancels. On a PC keyboard connected to a Mac, Alt acts as Option, so the physical shortcut is Alt+Tab. A quick press and release toggles between your two most recent windows.
```
(262/280)

<!-- count: X post 3; max: 280 -->
```text
Record any key plus Control, Option, Shift or Cmd (one or more) via Change Shortcut… in the menu bar; Esc cancels recording. Cmd+Tab replaces the built-in app switcher while JustTab runs. The only other setting is Launch at Login. No Dock icon.
```
(244/280)

<!-- count: X post 4; max: 280 -->
```text
Requires macOS 13+ and Accessibility permission. Live thumbnails need macOS 14+ and Screen Recording permission; otherwise, app icons are shown. Free download, signed with Developer ID and notarized by Apple: https://github.com/shuaige121/justtab/releases/latest
```
(262/280)

<!-- count: X post 5; max: 280 -->
```text
JustTab is a stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis. Minimized windows are included and shown dimmed. Grid cells shrink so every listed window fits on screen. https://github.com/shuaige121/justtab
```
(252/280)

## V2EX（中文）

发布前提：仓库已公开，已在真实 Mac 上检查源码安装流程。节点由主人选择。仅复制下方正文，不发布这些编辑说明。
可选内容前提：先在真实 Mac 上确认 P1、P2，否则删除带标签的行。 <!-- P1 P2 -->

**标题**

```text
JustTab：像 Windows 的 Alt+Tab 一样在 Mac 上按窗口切换，永久免费、开源
```

**正文**

```text
macOS 的 Cmd-Tab 切换 App，Cmd-` 只切换当前 App 的窗口。如果同一个 App 开了多个窗口，JustTab 可以把它们和其他 App 的窗口放在一个网格里选择。

JustTab 默认用 Option+Tab。PC 键盘接到 Mac 时，Alt 键等同于 Option，实际按的就是 Alt+Tab。按住快捷键，点按 Tab 或方向键移动选择，Shift+Tab 返回，松手切换；Esc 取消，也可以直接点击缩略图。

窗口按最近使用顺序排列，打开时默认选中上一个窗口。快速按下再松开，就能在最近两个窗口之间来回切换。已最小化的窗口也会列出，显示为暗色；网格会缩小单元格，让所有已列出的窗口都能显示在屏幕内。

在菜单栏打开 Change Shortcut…，可以录制任意按键加一个或多个 Control、Option、Shift、Cmd，Esc 取消录制。设为 Cmd+Tab 后，JustTab 运行时会取代系统自带的 App 切换器。主要设置只有快捷键，另有 Launch at Login 开关；没有 Dock 图标。

用 Cmd-H 隐藏的 App，其窗口也会列出，选中后重新显示该 App。 [P1]
其他桌面（Spaces）的窗口也会列出，选中后切换到对应桌面。 [P2]

永久免费，MIT 协议，开源。没有付费墙、Pro 版或升级推销，应用内不会出售任何内容。不含联网代码，无遥测、无账号、不检查更新。

纯 Swift + AppKit，零第三方依赖，约 2,600 行 Swift，应用占用磁盘空间约 520 KB。

需要 macOS 13 或更高版本，以及辅助功能权限。实时缩略图需要 macOS 14 或更高版本及屏幕录制权限，否则显示 App 图标。

免费下载（已用 Developer ID 签名并经 Apple 公证）：https://github.com/shuaige121/justtab/releases/latest
解压后把 JustTab 移到「应用程序」。也可以用 Xcode 从源码构建。

仓库：https://github.com/shuaige121/justtab
JustTab 是 Sergio Farfan 的 alttab-macos（MIT）的精简 fork，后者受 lwouis 的 AltTab 启发。
```

## Xiaohongshu（中文）

发布前提：仓库已公开，已检查源码安装流程。若配图，只用经过检查的 JustTab 实拍画面；上传时核对平台的当前要求。仅复制下方标题和正文。

<!-- count: Xiaohongshu title; max: 20 -->
```text
Mac 上像 Windows 一样切窗口
```
(20/20)

**正文**

```text
同一个 App 开了几个窗口，想直接选到其中一个，可以用 JustTab。它把各个 App 的窗口放在同一个网格里。

默认按 Option+Tab：按住，点 Tab 或方向键移动选择，松手切换。Shift+Tab 返回，Esc 取消，也可以点击缩略图。PC 键盘接 Mac 时，Alt 键就是 Option，实际按的仍是 Alt+Tab。

窗口按最近使用顺序排列，打开时选中上一个窗口。快速按下再松开，就在最近两个窗口之间来回切换。已最小化的窗口也会列出，显示为暗色。

JustTab 常驻菜单栏，没有 Dock 图标。主要设置只有快捷键，另有「登录时启动」开关。永久免费、MIT 协议、开源，没有付费墙、Pro 版或升级推销，应用内不会出售任何内容。不含联网代码，无遥测、无账号、不检查更新。

需要 macOS 13 或更高版本及辅助功能权限。实时缩略图需要 macOS 14 或更高版本及屏幕录制权限，否则显示 App 图标。

免费下载（已用 Developer ID 签名并经 Apple 公证）：https://github.com/shuaige121/justtab/releases/latest
解压后把 JustTab 移到「应用程序」。也可以用 Xcode 从源码构建。

仓库：https://github.com/shuaige121/justtab
JustTab 是 Sergio Farfan 的 alttab-macos（MIT）的精简 fork，后者受 lwouis 的 AltTab 启发。

#Mac窗口切换 #macOS #开源
```
