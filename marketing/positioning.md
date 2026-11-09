# JustTab positioning (internal)

Source of truth for claims: `facts-check.md`. Fact IDs (F1-F16) are cited in brackets. O1 is the owner's brief (the Windows Alt-Tab behavior description and the core angle).

## 1. Target audience

**Primary: people who recently moved from Windows to a Mac.** They have years of Alt-Tab habit: hold Alt, tap Tab, see every window, release to switch [O1]. On macOS, Cmd-Tab switches between apps, not windows [F15], so the habit stops working.

Secondary audiences (each justified only by the facts we hold):

- **People who keep a PC keyboard on a Mac.** The Alt key acts as Option, so the default shortcut is physically Alt+Tab [F4]. This is the clearest match for the angle.
- **Users who keep several windows of one app open** (browser, editor, terminal). Cmd-Tab shows one entry per app and Cmd-` cycles only the current app's windows [F15]; JustTab lists individual windows from all apps in one grid [F2].
- **Users who prefer small, auditable, open-source utilities.** MIT, no networking code, zero third-party dependencies, source on GitHub [F9, F10, F11, F16]. Because install is build-from-source [F13], this group is also the realistic early audience.

Not a target today: anyone who needs a download button, a notarized build, or Homebrew [F13].

## 2. The core problem, in their words

- "I press Alt-Tab out of habit and the wrong thing happens."
- "Cmd-Tab only shows apps. I have four browser windows and cannot pick one."
- "I want to see the windows, then let go to switch."

## 3. One-sentence positioning

JustTab brings Windows-style Alt-Tab window switching to the Mac: hold the shortcut, see a grid of live window thumbnails, release to switch, with the default shortcut on the same keys (Alt+Tab on a PC keyboard) [O1, F2, F3, F4].

## 4. Three key messages

1. **It switches windows, not just apps.** A grid of live window thumbnails, most recently used first; a quick press and release toggles between your two most recent windows [F2, F6]. (Thumbnails need macOS 14+ and Screen Recording permission; otherwise app icons are shown [F12].)
2. **The keys you already know.** Hold, tap Tab, release. Default is Option+Tab, which is the Alt key on a PC keyboard. It can be changed to any modifier + key combination, including Cmd+Tab [F3, F4].
3. **Small, free and private by construction.** Free, MIT, open source; no networking code, so no telemetry, account or update checks; about 316 KB; Swift + AppKit with no third-party dependencies [F9, F10, F11].

## 5. Objections and honest answers

| Objection | Answer |
|---|---|
| "Where is the download?" | There is none today. Install means building from source with full Xcode: clone the repository, run `./build.sh install`. No prebuilt, notarized, App Store or Homebrew version exists [F13]. |
| "Can I see windows on my other desktops?" | No. Only windows on the current Space are listed, plus minimized windows [F14]. |
| "macOS already has Cmd-Tab and Cmd-`." | Cmd-Tab switches apps and Cmd-` cycles windows of the current app only [F15]. JustTab shows windows from all apps in one grid [F2]. |
| "I don't want to give permissions." | Accessibility permission is required. Screen Recording is needed only for live thumbnails, which also need macOS 14+; without it, app icons are shown [F12]. |
| "What does it need?" | macOS 13 or later [F12]. |
| "Is it a new project?" | It is a stripped-down fork of alttab-macos by Sergio Farfan (MIT), itself inspired by AltTab by lwouis. State this wherever the README text appears [F9]. |
| "Does it phone home?" | It contains no networking code [F10]. |
| "Can I configure it?" | The shortcut is the only real setting, plus a Launch at Login toggle [F5]. We present this as a plain fact, not a selling point about "simplicity" beyond that. |
| "Can I look at the code?" | The repository is github.com/shuaige121/justtab. It is currently private; the owner decides when to make it public [F16]. No post should go out before that. |

## 6. Tone

- Professional, restrained, factual. Short sentences. State what it does and what it does not do.
- Lead with the limitation-aware install note; do not bury it.
- No superlatives, hype words, exclamation marks, slang or memes. No comparisons with other products.
- Credit upstream plainly and every time the README text is reused [F9].
- Chinese copy is written natively in the same register (plain, 克制), not translated word for word.
- Keep key names as written: Option, Cmd, Tab, Alt.
- Do not show the upstream `Screenshots/AltTab1.jpg` as JustTab. No visual exists yet (see gaps).
