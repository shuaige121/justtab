# Proposed README hero (not applied)

Proposed replacement for the top of `README.md` (title through feature bullets). The existing Credits section must stay in place; a Credits block is included below so the attribution travels with the text. Everything not shown here (requirements, install, usage table) can stay as it is, with one correction noted at the end.

---

## English

<div align="center">

# JustTab

**Alt-Tab window switching for macOS.**

*Just Tab. Nothing else.*

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-13%2B-blue)

</div>

JustTab switches between individual windows, not just apps. Hold the shortcut (default **Option+Tab**) to see a grid of live window thumbnails, tap **Tab** to move, and release to switch.

### Coming from Windows?

On Windows you hold Alt, tap Tab, see every window, and release to switch. On macOS, Cmd-Tab switches between apps, not windows. JustTab brings the Windows behavior back, and the default shortcut sits on the same keys: on a PC keyboard connected to a Mac, the Alt key acts as Option, so it is physically Alt+Tab. If you prefer, change the shortcut to any modifier + key combination, including Cmd+Tab, which then replaces the built-in switcher.

### Features

- 🪟 **Switches windows, not just apps**, with a grid of live thumbnails
- ⏱️ **Most recently used first.** A quick press and release toggles between your two most recent windows
- ➖ **Minimized windows are included** (shown with their app icon, dimmed)
- 🧱 **Grid shrinks to fit**, so every window stays on screen
- ⌨️ **One real setting:** the shortcut (plus a Launch at Login toggle). Lives in the menu bar, no Dock icon
- 🆓 **Free, MIT-licensed, open source**
- 🔒 **No networking code:** no telemetry, no account, no update checks
- 🪶 **Small:** pure Swift + AppKit, zero third-party dependencies, about 316 KB

Limitation: only windows on the current Space (desktop) are listed, plus minimized windows.

Install today means building from source with full Xcode. There is no prebuilt download.

```bash
git clone https://github.com/shuaige121/justtab.git
cd justtab
./build.sh install
```

### Credits

JustTab is a stripped-down fork of [**alttab-macos** by Sergio Farfan](https://github.com/sergio-farfan/alttab-macos) (MIT), itself inspired by [AltTab](https://github.com/lwouis/alt-tab-macos) by lwouis.

---

## 简体中文

<div align="center">

# JustTab

**macOS 上的 Alt-Tab 窗口切换。**

*Just Tab. Nothing else.*

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-13%2B-blue)

</div>

JustTab 在单个窗口之间切换，而不只是在 App 之间切换。按住快捷键（默认 **Option+Tab**），屏幕上会出现实时窗口缩略图网格；按 **Tab** 移动选择，松开即切换。

### 从 Windows 转来？

在 Windows 上，按住 Alt、点按 Tab，就能看到所有窗口，松手即切换。macOS 的 Cmd-Tab 切换的是 App，不是窗口。JustTab 把 Windows 的这套操作带回 Mac，默认快捷键就在同样的按键上：PC 键盘接到 Mac 上时，Alt 键等同于 Option，所以实际按的就是 Alt+Tab。如果想换，可以改成任意「修饰键 + 按键」的组合，包括 Cmd+Tab，此时它会取代系统自带的切换器。

### 特性

- 🪟 **按窗口切换，不只是按 App**，以实时缩略图网格呈现
- ⏱️ **按最近使用顺序排列。** 快速按下再松开，即可在最近的两个窗口之间来回切换
- ➖ **包含已最小化的窗口**（显示 App 图标，颜色变暗）
- 🧱 **网格自动缩小**，保证所有窗口都显示在屏幕内
- ⌨️ **只有一个真正的设置：**快捷键（另有「登录时启动」开关）。常驻菜单栏，没有 Dock 图标
- 🆓 **免费、MIT 协议、开源**
- 🔒 **不含任何联网代码：**无遥测、无账号、不检查更新
- 🪶 **体积小：**纯 Swift + AppKit，零第三方依赖，约 316 KB

限制：只列出当前 Space（桌面）上的窗口，以及已最小化的窗口。

目前只能从源码构建安装，需要完整版 Xcode，没有预编译下载包。

```bash
git clone https://github.com/shuaige121/justtab.git
cd justtab
./build.sh install
```

### 致谢

JustTab 是 [Sergio Farfan 的 **alttab-macos**](https://github.com/sergio-farfan/alttab-macos)（MIT）的精简 fork，后者受 lwouis 的 [AltTab](https://github.com/lwouis/alt-tab-macos) 启发。

---

## Notes for applying

- The current README says "Free forever ... no Pro tier, ever", "no paywall, no upsell" and "no settings maze". These go beyond the fact list (F9 says free, MIT, open source). They are replaced here by the plain statements above. If the owner wants to keep a "free forever" promise, it is the owner's commitment to make, not ours.
- Keep the existing "Requirements & permissions" section; it matches F12. Add one clarification: live thumbnails need macOS 14+ as well as Screen Recording permission.
- The existing bilingual tagline line （极简、免费的 macOS 窗口切换器 ...） is dropped in favor of the section split above； restore it if preferred.
- No screenshot or GIF is included because none exists for JustTab.
