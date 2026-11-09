# Launch post drafts (nothing has been posted)

Preconditions before any of these go out (owner decisions, not copy):

- The repository is private today [F16]. Every draft links to it, so it must be public first.
- Every draft states the install path honestly: build from source with full Xcode, no prebuilt download [F13].
- No screenshot or GIF exists for JustTab. Do not attach the upstream `AltTab1.jpg`.
- Each post that reproduces README text must keep the credit to alttab-macos / AltTab [F9]. It is included in every draft below.

---

## 1. GitHub repository description (<=350 characters)

```
Windows-style Alt-Tab for Mac: switch windows, not just apps. Hold Option+Tab (Alt+Tab on a PC keyboard), see live window thumbnails, release to switch. Free forever, open source (MIT), no networking code. Build from source, macOS 13+. Stripped-down fork of alttab-macos.
```

Suggested topics:
`macos`, `window-switcher`, `alt-tab`, `windows-style`, `switch-windows`, `swift`, `appkit`, `menu-bar-app`, `productivity`, `open-source`

See `keyword-strategy.md` for why no topic uses another product's name.

---

## 2. Show HN

**Title**

```
Show HN: JustTab, Windows-style Alt-Tab for Mac (switch windows, not apps)
```

**First comment**

```
JustTab is a free, open-source, Windows-style Alt-Tab for the Mac: it switches windows, not just apps. Free forever, with no paywall, no Pro tier and no upsell. It does one job and has one real setting, the shortcut. It is a stripped-down fork of alttab-macos by Sergio Farfan (MIT), which was itself inspired by AltTab by lwouis.

The motivation: if you come to the Mac from Windows, you are used to holding Alt, tapping Tab, seeing every window, and releasing to switch. On macOS, Cmd-Tab switches between apps, and Cmd-` cycles windows of the current app only. JustTab switches between individual windows and shows them as a grid of live thumbnails.

Behavior:
- Default shortcut is Option+Tab. On a PC keyboard connected to a Mac, the Alt key acts as Option, so it is physically Alt+Tab. You can change it to any modifier + key combination, including Cmd+Tab, which then replaces the built-in switcher.
- Hold the shortcut, tap Tab or the arrow keys to move, Shift+Tab to go back, release to switch. Esc cancels.
- Windows are ordered most recently used first, and it opens with the previous window selected, so a quick press and release toggles between your two latest windows.
- Minimized windows are included.

Other facts: MIT-licensed, about 316 KB, pure Swift + AppKit with no third-party dependencies, and no networking code (no telemetry, account or update checks).

Limitations: it only lists windows on the current Space, plus minimized ones. It needs macOS 13+ and Accessibility permission. Live thumbnails need macOS 14+ and Screen Recording permission; otherwise it shows app icons.

Install: there is no prebuilt download, notarized build, App Store or Homebrew listing. You build it from source with full Xcode:

  git clone https://github.com/shuaige121/justtab.git
  cd justtab
  ./build.sh install

Feedback is welcome.
```

---

## 3. Reddit r/macapps

**Title**

```
JustTab: Windows-style Alt-Tab for Mac, switches windows not apps (free forever, open source, build from source)
```

**Body**

```
If you moved from Windows, you probably still reach for Alt-Tab: hold Alt, tap Tab, see every window, release to switch. On macOS, Cmd-Tab switches apps, not windows.

JustTab is free forever and open source, with no paywall, no Pro tier and no upsell. It does one job: it switches individual windows and shows a grid of live thumbnails. The default shortcut is Option+Tab, which is the Alt key on a PC keyboard used with a Mac. You can change it to any modifier + key combination, including Cmd+Tab (which then replaces the built-in switcher).

- Hold the shortcut, tap Tab or the arrow keys, release to switch. Shift+Tab goes back, Esc cancels, clicking a thumbnail switches to it.
- Most recently used first. A quick press and release toggles between your two latest windows.
- Minimized windows are included.
- The grid shrinks cells so every window fits on screen.
- Lives in the menu bar, no Dock icon. The shortcut is the only real setting, plus Launch at Login.
- Free forever, MIT, open source. No paywall, no Pro tier, no upsell. No networking code: no telemetry, no account, no update checks. About 316 KB, Swift + AppKit, no third-party dependencies.

Limitations: only windows on the current Space are listed (plus minimized ones). Needs macOS 13+ and Accessibility permission. Live thumbnails need macOS 14+ and Screen Recording permission; otherwise you get app icons.

How to install today: build from source with full Xcode. There is no prebuilt download, no notarized build, and no App Store or Homebrew listing.

  git clone https://github.com/shuaige121/justtab.git
  cd justtab
  ./build.sh install

Repo: https://github.com/shuaige121/justtab
JustTab is a stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis.
```

---

## 4. Product Hunt

Note: Product Hunt listings usually expect a way to try the product. With build-from-source only [F13], consider holding this one until a prebuilt option exists; that is the owner's call.

**Tagline (<=60 characters; 55 used)**

```
Windows-style Alt-Tab for Mac: switch windows, not apps
```

**Description**

```
JustTab is a free, open-source, Windows-style Alt-Tab for the Mac. It switches between individual windows, not just apps. Hold the shortcut, see a grid of live window thumbnails, tap Tab to move, release to switch. The default shortcut is Option+Tab, which is the Alt key on a PC keyboard used with a Mac, so it is physically Alt+Tab. It can be changed to any modifier + key combination, including Cmd+Tab.

Windows are ordered most recently used first, minimized windows are included, and a quick press and release toggles between your two latest windows. Free forever with no paywall, no Pro tier and no upsell; MIT-licensed, open source, no networking code, about 316 KB. One job, one real setting (the shortcut).

Limitation: only windows on the current Space are listed. Requires macOS 13+ and Accessibility permission; live thumbnails need macOS 14+ and Screen Recording permission.

Install today: build from source with full Xcode (no prebuilt download). A stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis.
```

---

## 5. V2EX (Chinese)

**Title**

```
JustTab：Mac 像 Windows 一样 Alt+Tab 切换窗口（永久免费、开源，需从源码构建）
```

**Body**

```
JustTab 是一个永久免费、开源的 Mac 窗口切换器：像 Windows 一样用 Alt+Tab 切换窗口，而不只是切换 App。没有付费版，也不会有；只做这一件事，只有一个真正的设置，就是快捷键。

从 Windows 转到 Mac 之后，Alt-Tab 的习惯很难改：按住 Alt，点 Tab，看到所有窗口，松手切换。macOS 的 Cmd-Tab 切换的是 App 而不是窗口，Cmd-` 也只能在当前 App 的窗口之间切换。

JustTab 做的就是这件事：在单个窗口之间切换，并以实时缩略图网格显示。默认快捷键是 Option+Tab。PC 键盘接到 Mac 上时，Alt 键等同于 Option，所以实际按的就是 Alt+Tab。快捷键可以改成任意「修饰键 + 按键」的组合，包括 Cmd+Tab（此时会取代系统自带的切换器）。

操作：
- 按住快捷键，Tab 或方向键移动选择，Shift+Tab 返回，松手即切换；Esc 取消；也可以直接点击缩略图。
- 窗口按最近使用顺序排列，打开时默认选中上一个窗口，所以快速按下再松开就是在最近两个窗口之间来回切换。
- 包含已最小化的窗口。
- 窗口多时网格会缩小单元格，保证都显示在屏幕内。
- 常驻菜单栏，没有 Dock 图标。唯一真正的设置是快捷键，另有「登录时启动」开关。

其他信息：MIT 协议，开源；永久免费，不收费，也不会在应用内销售任何功能；不含任何联网代码，没有遥测、账号和更新检查；纯 Swift + AppKit，零第三方依赖，约 316 KB。

限制：只列出当前 Space（桌面）上的窗口，加上已最小化的窗口，其他 Space 的窗口不显示。需要 macOS 13 及以上和辅助功能权限；实时缩略图需要 macOS 14 及以上和屏幕录制权限，否则显示 App 图标。

安装方式（目前只有这一种）：需要完整版 Xcode，从源码构建。没有预编译下载包，没有公证版本，也没有 App Store 或 Homebrew 上架。

git clone https://github.com/shuaige121/justtab.git
cd justtab
./build.sh install

仓库：https://github.com/shuaige121/justtab

JustTab 是 Sergio Farfan 的 alttab-macos（MIT）的精简 fork，后者受 lwouis 的 AltTab 启发。欢迎反馈。
```

---

## 6. Xiaohongshu note (Chinese)

**Title (18 characters, limit 20)**

```
Mac 上用 Alt+Tab 切窗口
```

**Body**

```
Mac 像 Windows 一样用 Alt+Tab 切换窗口：JustTab，永久免费、开源。

从 Windows 换到 Mac，最先不习惯的可能就是切窗口。

Windows 里：按住 Alt，点 Tab，所有窗口都列出来，松手就切过去。
Mac 里：Cmd-Tab 切换的是 App，不是窗口；Cmd-` 只能在当前 App 的窗口之间切换。

JustTab 把 Windows 的这套操作带到了 Mac 上：
· 在单个窗口之间切换，以实时缩略图网格显示
· 默认快捷键是 Option+Tab。PC 键盘接 Mac 时，Alt 键就是 Option，按的还是 Alt+Tab
· 按最近使用顺序排列，快速按下再松开，就在最近两个窗口之间来回切换
· 包含已最小化的窗口
· 快捷键可以改，包括改成 Cmd+Tab
· 永久免费，没有付费版，不推销，也不会在应用内收费；MIT 协议，开源，不含联网代码，约 316 KB
· 只做一件事，只有一个真正的设置：快捷键

需要注意：
· 只显示当前桌面（Space）上的窗口，其他桌面的窗口不显示
· 需要 macOS 13 及以上，需要辅助功能权限；实时缩略图需要 macOS 14 及以上和屏幕录制权限，否则显示 App 图标
· 目前没有下载安装包，只能用完整版 Xcode 从源码构建：
  git clone https://github.com/shuaige121/justtab.git
  cd justtab
  ./build.sh install

JustTab 是 Sergio Farfan 的 alttab-macos（MIT）的精简 fork，后者受 lwouis 的 AltTab 启发。

#Mac切换窗口 #Mac窗口切换 #Windows转Mac #macOS #效率工具 #开源
```

Notes: this note would be stronger with a screen recording; none exists, so none is referenced. Hashtags are topic labels, not claims. V2EX: post in the Mac / macOS node (owner picks the node); suggested tags: Mac, macOS, 窗口切换, 效率工具, 开源. See `keyword-strategy.md`.
