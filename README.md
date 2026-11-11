# JustTab

Windows-style Alt-Tab for the Mac: switch between individual windows, not just apps, in one thumbnail grid.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

[中文](#中文)

## What it does

JustTab brings windows from all apps into one grid. Windows are ordered most recently used first. Minimized windows are included and shown dimmed. The grid shrinks its cells so every listed window fits on screen.

The default shortcut is **Option+Tab**. On a PC keyboard connected to a Mac, Alt acts as Option, so the physical shortcut is **Alt+Tab**. On macOS, Cmd-Tab switches apps; Cmd-` cycles windows of the current app only.

JustTab does one job: switching windows. The shortcut is its one real setting, with a separate Launch at Login toggle. It lives in the menu bar and has no Dock icon.

Free forever, MIT-licensed and open source. No paywall, no Pro tier, no upsell. Nothing in the app will ever be sold.

Pure Swift + AppKit, with zero third-party dependencies. About 2,600 lines of Swift and about 520 KB on disk.

## Install

Download `JustTab-2.0.0.zip` from [GitHub Releases](https://github.com/shuaige121/justtab/releases/latest), unzip it and move JustTab to Applications. The app is signed with Developer ID and notarized by Apple. Requires macOS 13 or later.

Or with [Homebrew](https://brew.sh):

```bash
brew install --cask shuaige121/tap/justtab
```

Or build from source with full Xcode:

```bash
git clone https://github.com/shuaige121/justtab.git
cd justtab
./build.sh install
```

This installs JustTab to `~/Applications`.

## Usage

| Action | Result |
| --- | --- |
| Hold Option and press Tab | Open the switcher with the previous window selected |
| Keep holding the shortcut; tap Tab or the arrow keys | Move the selection |
| Shift+Tab while holding | Move back |
| Release the shortcut | Switch to the selected window |
| Esc | Cancel switching |
| Click a thumbnail | Switch to that window |
| Quickly press and release the shortcut | Toggle between your two most recent windows |
| Menu bar → Change Shortcut… | Record any key plus one or more of Control, Option, Shift, Cmd; Esc cancels recording |
| Record Cmd+Tab | Replace the built-in app switcher while JustTab runs |
| Menu bar → Launch at Login | Set whether JustTab starts at login |

## Permissions and privacy

- Requires **macOS 13 or later** and **Accessibility** permission.
- Live thumbnails require **macOS 14 or later** and **Screen Recording** permission. Without them, app icons are shown.
- The app contains **no networking code**: no telemetry, no account, no update checks.

## FAQ

### Why not on the Mac App Store?

App Store apps must be sandboxed. A sandboxed app cannot use the Accessibility API to list or focus other apps' windows, as Apple Developer Technical Support explained on the Apple Developer Forums ([2024](https://developer.apple.com/forums/thread/756130), [2025](https://developer.apple.com/forums/thread/780626)). Window switchers of this kind are distributed directly. JustTab is not on the Mac App Store. Download it from [GitHub Releases](https://github.com/shuaige121/justtab/releases/latest): it is signed with Developer ID and notarized by Apple.

### Can it replace Cmd-Tab?

Yes. Open **Change Shortcut…** from the menu bar and record **Cmd+Tab**. It replaces the built-in app switcher while JustTab runs. Any key plus one or more of Control, Option, Shift and Cmd can be recorded. Esc cancels recording.

### Does it phone home?

No. The app contains no networking code: no telemetry, no account, no update checks.

### Which windows are listed?

Windows from all apps, including minimized windows, shown dimmed.


Windows of apps hidden with Cmd-H are listed; choosing one brings the app back. <!-- P1 -->
Windows on other desktops (Spaces) are listed; choosing one switches to that desktop. <!-- P2 -->

### Does it use private macOS functions?

The source uses exactly one private macOS function, `_AXUIElementGetWindow`, to match an accessibility window to its window ID.

## Credits

JustTab is a stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis.

## License

[MIT](LICENSE). Free forever.

---

## 中文

### JustTab

像 Windows 的 Alt+Tab 一样，在 Mac 上按窗口切换，而不只是切换 App。

### 功能

JustTab 将各个 App 的窗口放在同一个网格中，按最近使用顺序排列。已最小化的窗口也会列出，显示为暗色。窗口较多时，网格会缩小单元格，让每个已列出的窗口都能显示在屏幕内。

默认快捷键是 **Option+Tab**。PC 键盘接到 Mac 上时，Alt 键等同于 Option，实际按的就是 **Alt+Tab**。macOS 的 Cmd-Tab 切换 App；Cmd-` 只在当前 App 的窗口之间切换。

JustTab 专注于切换窗口。主要设置只有快捷键，另有「登录时启动」开关。它常驻菜单栏，没有 Dock 图标。

永久免费，开源，采用 MIT 协议。没有付费墙、Pro 版或升级推销，应用内的任何内容都不会出售。

纯 Swift + AppKit，零第三方依赖。约 2,600 行 Swift，应用占用磁盘空间约 520 KB。

### 安装

从 [GitHub Releases](https://github.com/shuaige121/justtab/releases/latest) 下载 `JustTab-2.0.0.zip`，解压后把 JustTab 移到「应用程序」。App 已用 Developer ID 签名并经 Apple 公证。系统要求为 macOS 13 或更高版本。

或用 [Homebrew](https://brew.sh) 安装：

```bash
brew install --cask shuaige121/tap/justtab
```

也可以用完整版 Xcode 从源码构建：

```bash
git clone https://github.com/shuaige121/justtab.git
cd justtab
./build.sh install
```

安装位置为 `~/Applications`。

### 使用

| 操作 | 结果 |
| --- | --- |
| 按住 Option，再按 Tab | 打开切换器，默认选中上一个窗口 |
| 保持按住快捷键，点按 Tab 或方向键 | 移动选择 |
| 保持按住，点按 Shift+Tab | 向前返回 |
| 松开快捷键 | 切换到所选窗口 |
| Esc | 取消切换 |
| 点击缩略图 | 切换到该窗口 |
| 快速按下再松开快捷键 | 在最近两个窗口之间来回切换 |
| 菜单栏 → Change Shortcut… | 录制任意按键加一个或多个 Control、Option、Shift、Cmd；Esc 取消录制 |
| 录制 Cmd+Tab | JustTab 运行时取代系统自带的 App 切换器 |
| 菜单栏 → Launch at Login | 设置是否登录时启动 |

### 权限与隐私

- 需要 **macOS 13 或更高版本**及**辅助功能（Accessibility）**权限。
- 实时缩略图需要 **macOS 14 或更高版本**及**屏幕录制（Screen Recording）**权限；不满足这些条件时显示 App 图标。
- 应用**不含联网代码**：无遥测、无账号、不检查更新。

### 常见问题

#### 为什么不在 Mac App Store 上架？

App Store 要求应用启用 sandbox。启用后，应用无法通过 Accessibility API 列出或聚焦其他 App 的窗口。Apple Developer Technical Support 在 Apple Developer Forums 的答复中说明了这一限制（[2024](https://developer.apple.com/forums/thread/756130)、[2025](https://developer.apple.com/forums/thread/780626)），因此这类窗口切换器通过直接分发提供。JustTab 不在 Mac App Store 上架，请从 [GitHub Releases](https://github.com/shuaige121/justtab/releases/latest) 下载：已用 Developer ID 签名并经 Apple 公证。

#### 可以替换 Cmd-Tab 吗？

可以。在菜单栏打开 **Change Shortcut…**，录制 **Cmd+Tab**。JustTab 运行期间会取代系统自带的 App 切换器。也可以录制任意按键加一个或多个 Control、Option、Shift、Cmd。按 Esc 取消录制。

#### 会联网回传数据吗？

不会。应用不含联网代码，无遥测、无账号，也不检查更新。

#### 会列出哪些窗口？

所有 App 的窗口，包括已最小化的窗口（显示为暗色）。


用 Cmd-H 隐藏的 App，其窗口也会列出；选中窗口后会重新显示该 App。 <!-- P1 -->
其他桌面（Spaces）的窗口也会列出；选中后会切换到对应桌面。 <!-- P2 -->

#### 是否使用私有 macOS 函数？

源码只使用一个私有 macOS 函数：`_AXUIElementGetWindow`，用于将辅助功能窗口与其 window ID 对应起来。

### 致谢

JustTab 是 Sergio Farfan 的 alttab-macos（MIT）的精简 fork，后者受 lwouis 的 AltTab 启发。

### 许可

[MIT](LICENSE)，永久免费。
