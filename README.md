<div align="center">

# JustTab

**A minimal, free window switcher for macOS — hold, Tab through live window previews, release to switch.**

*极简、免费的 macOS 窗口切换器 —— 按住快捷键，在实时窗口预览中切换。*

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-13%2B-blue)

</div>

---

## English

**JustTab does one thing: switch between *windows* (not just apps), Windows-style, with a live thumbnail grid.**

Press and hold your shortcut (default **⌥ Option + Tab**) to bring up a grid of every open window as a live preview. Keep holding and tap **Tab** (or the arrow keys) to move the selection; **release** to jump to that window. Press **Esc** to cancel.

### Why it exists

It's built for people who just want the classic Alt-Tab window switcher — nothing more. No paywall, no upsell, no telemetry, no account, no settings maze. The **only** thing you can configure is the shortcut key; everything else is a sensible default that just works.

### Features

- 🪟 **Per-window switching** with **live thumbnails** (not just app icons)
- ⌨️ **One configurable setting** — record any trigger shortcut you like: any key plus one or more of ⌃ ⌥ ⇧ ⌘, including ones macOS uses such as ⌘Tab (menu bar → *Change Shortcut…*)
- 🧱 **Grid layout** — every window stays on screen, nothing scrolls off
- 🆓 **Free forever, MIT-licensed, open source** — no Pro tier, ever
- 🔒 **No network, no telemetry** — it never phones home
- 🪶 **Tiny** — pure Swift + AppKit, zero third-party dependencies

### Requirements & permissions

- macOS 13 (Ventura) or later
- **Accessibility** — *required* (to capture the global shortcut and focus windows)
- **Screen Recording** — *optional* (only for live thumbnails; without it you get app icons)

Grant them in **System Settings → Privacy & Security**.

### Install / build from source

```bash
git clone https://github.com/shuaige121/justtab.git
cd justtab
./build.sh run          # build and launch
./build.sh install      # build and install to ~/Applications
tests/run.sh            # run the unit tests (hotkey, permissions, grid, MRU)
```

Requires full Xcode (not just the Command Line Tools).

### Usage

| Key | Action |
|-----|--------|
| Hold **⌥** + **Tab** | Open the switcher / select next window |
| **Tab** (while holding) | Next · **Shift+Tab** or **←/→** previous |
| Release **⌥** | Switch to the selected window |
| **Esc** | Cancel |
| Click a thumbnail | Switch to that window |
| Hold **⌥** + **⇧ Shift** + **Tab** | Open with the last window selected |

To use a different trigger, open the menu bar icon → **Change Shortcut…** and press the keys you want. Any key works with at least one modifier (the switch happens when you release it), including shortcuts macOS uses, such as ⌘Tab or ⌘`; JustTab takes those over while it runs.

### Credits

JustTab is a stripped-down fork of [**alttab-macos** by Sergio Farfan](https://github.com/sergio-farfan/alttab-macos) (MIT), itself inspired by the excellent [AltTab](https://github.com/lwouis/alt-tab-macos). Huge thanks to both.

---

## 中文

**JustTab 只做一件事:像 Windows 一样在「窗口」之间切换(而不只是 App),并显示实时窗口预览网格。**

按住你的快捷键(默认 **⌥ Option + Tab**),屏幕中央弹出所有打开窗口的实时预览网格;按住不放、点 **Tab**(或方向键)移动选择,**松开**即切换到该窗口,**Esc** 取消;也可以直接点击缩略图切换。加按 **⇧ Shift** 打开时从最后一个窗口开始。

### 为什么做它

给只想要经典 Alt-Tab 窗口切换、别的都不要的人。**没有付费墙、没有推销、没有遥测、没有账号、没有设置迷宫。** 唯一能配置的就是快捷键,其余全是开箱即用的好默认。

### 特性

- 🪟 **逐窗口切换** + **实时缩略图**(不是只有 App 图标)
- ⌨️ **唯一一个设置** —— 自定义触发快捷键:任意按键加一个或多个 ⌃ ⌥ ⇧ ⌘,包括 ⌘Tab 这类系统快捷键(菜单栏 → *Change Shortcut…*,按什么键存什么)
- 🧱 **网格布局** —— 所有窗口都在屏幕内,不会跑出去
- 🆓 **永久免费、MIT 协议、开源** —— 永远不会有 Pro 版
- 🔒 **不联网、无遥测** —— 绝不回传任何数据
- 🪶 **极小** —— 纯 Swift + AppKit,零第三方依赖

### 系统要求与权限

- macOS 13 (Ventura) 及以上
- **辅助功能(Accessibility)** —— *必需*(捕获全局快捷键、聚焦窗口)
- **屏幕录制(Screen Recording)** —— *可选*(仅用于实时缩略图;不给则显示 App 图标)

在 **系统设置 → 隐私与安全性** 中授权。

### 从源码构建

```bash
git clone https://github.com/shuaige121/justtab.git
cd justtab
./build.sh run          # 编译并运行
./build.sh install      # 编译并安装到 ~/Applications
tests/run.sh            # 运行单元测试(快捷键、权限、网格、最近使用排序)
```

需要完整版 Xcode(不只是命令行工具)。

### 致谢

JustTab 是 [Sergio Farfan 的 **alttab-macos**](https://github.com/sergio-farfan/alttab-macos)(MIT)的精简 fork,后者受优秀的 [AltTab](https://github.com/lwouis/alt-tab-macos) 启发。向两者致谢。

---

<div align="center">
<sub>JustTab · MIT License · Just Tab. Nothing else.</sub>
</div>
