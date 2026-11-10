# Real-media capture plan (internal)

No media is claimed to exist in this delivery. Capture the actual JustTab app. Never use `Screenshots/AltTab1.jpg` or draw app UI and present it as a capture. The site's abstract blocks remain an illustration.

## Prepare a neutral session

Use a clean local demo user with no personal accounts, or a clean desktop containing only demo windows. A separate demo user is preferred because thumbnails can expose other open content. Do not sign into email, messaging, cloud storage or a browser profile. Hide notifications and remove personal desktop files, recent-document lists and bookmarks from the capture area. Use a plain wallpaper.

Use macOS 14 or later for live-thumbnail footage. Install from source with full Xcode using the README steps, grant Accessibility and Screen Recording permission, and confirm the app runs. Set the shortcut to Option+Tab from Change Shortcut… in the menu bar. These are capture prerequisites, not a claim that owner testing has already happened.

Open three real TextEdit documents titled “Sample A”, “Sample B” and “Sample C”, containing only those words and neutral lines such as “First paragraph” and “Second paragraph”. Open a Finder window containing only a new empty demo folder. No actual work documents, addresses, filenames or account details may appear. TextEdit and Finder are capture tools, not names to add to marketing copy.

## Short README and site recording

Aim for one concise, readable sequence. Record at normal speed; do not use edited timing to imply measured latency. Do not publish timing numbers over the footage. Keep the real pointer and selection visible. Captions may identify keys, but must not imitate an app control.

1. Click Sample C, press Cmd+M to minimize it, then click Sample B and finally Sample A. This establishes a known recent-window order and one minimized window.
2. Start recording. Hold Option, press and release Tab, and keep holding Option. Pause so the grid and selected previous window can be read. Confirm Sample C is present and dimmed (F6, F7).
3. Still holding Option, tap Tab once, then Shift+Tab once, then Right Arrow once and Left Arrow once. Check that the real selection moves. Do not claim a fixed cell position across runs (F3).
4. Release Option. Show the selected window in front (F3).
5. Quickly press Option+Tab and release both keys. Repeat once to show the two most recent windows toggling (F6).
6. Hold Option, tap Tab, then press Esc and release Option. Show cancellation (F3).
7. Hold Option and tap Tab again; click a different visible thumbnail, then release Option. Show that window in front (F3).
8. Stop recording. Review every frame, including the menu bar and background. Export only reviewed footage.

For README, attach the reviewed real recording through the owner's chosen repository media workflow. For the site, keep media local and preserve the no-external-request requirement. Do not add media links until the real files and their destinations exist. The present page stays under the requested size limit and does not embed a recording.

Suggested factual captions: “Hold Option+Tab”, “Tab or arrow keys to choose”, “Release to switch”, “Esc to cancel” (F3, F4). Include “Live thumbnails require macOS 14+ and Screen Recording permission” (F12) alongside thumbnail footage.

## Product Hunt gallery

Check the platform's current requirements at upload time; no fixed image dimensions are assumed here.

| Shot | Capture sequence | Public caption fact |
| --- | --- | --- |
| Grid | With Sample A and B open, hold Option and tap Tab; capture the real grid | Windows from all apps in one grid; include the thumbnail permission requirement (F2, F12) |
| Choose and switch | Capture one frame while holding Option, then one after release | Release to switch to the selected window (F3) |
| Minimized entry | Minimize Sample C with Cmd+M, open the grid, capture its dimmed entry | Minimized windows are included and dimmed (F7) |
| Menu and shortcut | Open the real menu bar menu; capture Change Shortcut… and Launch at Login | Shortcut setting plus Launch at Login (F5) |
| Icon fallback | Stop capture, withhold Screen Recording permission for JustTab in the demo user, reopen the app if needed, check the actual grid, then capture | Without thumbnail requirements, app icons are shown (F12) |

For a separate shortcut demonstration, select Change Shortcut…, press Cmd+Tab, and check switching while JustTab runs. Open Change Shortcut… again and press Esc to show cancellation. Finally record Option+Tab again. Do not leave the demo with an unexpected shortcut (F5).

## Optional owner validation, separate from the core demo

- Hide the demo text app with Cmd-H, invoke JustTab, select one of its listed windows, release and check that the app returns. Retain the associated copy only after confirmation (P1). <!-- P1 -->
- Put a neutral window on a second desktop (Space), return to the first desktop, invoke JustTab, select that window and release; check both listing and desktop transition (P2). <!-- P2 -->
- On two displays, put the mouse pointer on each in turn and invoke JustTab; check the switcher opens on that display (P4). <!-- P4 -->
- Confirm the post-switch focus check and single retry with a controlled real-Mac test. A successful recording alone does not establish that a retry happened (P5). <!-- P5 -->
- Before enabling any download link, verify the Developer ID signature and Apple notarization, the actual GitHub Releases DMG, and installation on a real Mac (P3). <!-- P3 -->

## Before publishing

- Owner has made the repository public (F16).
- All footage is JustTab, recorded on a real Mac, with no personal or credential content in any frame.
- Every shown behavior was observed; captions state only the supplied facts and retain permission qualifications.
- Optional feature lines are either confirmed or removed using the command in `REVIEW-NOTES.md`.
- No real app UI is replaced, retouched or generated. Simple cropping and key captions must not change the meaning of the capture.
- No fabricated stars, reviews, user counts, speed demonstrations or release claims are added.
- Upstream attribution travels with README-style descriptions (F9).
- Review the final upload, not just the local source, for legibility, cropping and unintended content.
