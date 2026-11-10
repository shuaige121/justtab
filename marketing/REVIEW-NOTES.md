# Review notes — launch copy and release-script fix

## What changed

- Replaced the README with English-first copy and a complete Chinese section, including installation, usage, permission requirements, FAQ, credit and MIT license. Kept both badges.
- Added a self-contained English landing page with system fonts, light/dark styling and an abstract CSS grid. Its outbound links lead only to the repository and README anchors; no external assets or scripts.
- Rewrote all platform drafts, added the five-post X thread and Product Hunt gallery directions, and printed script-computed counts for all ten length-limited items.
- Replaced the fact inventory and positioning with the supplied brief. Retired F14 and the old F13 bundle, corrected disk size to about 520 KB, and restricted speed figures to the technical first comment with measurement conditions.
- Superseded the old hero proposal and updated the keyword guide so older copy cannot silently reintroduce unsupported claims.
- Added a real-media capture plan. No screenshot or recording is supplied; the upstream image is not used.
- Optional claims are isolated on removable tagged lines. The planned Download button is disabled, and source installation remains the complete current path. <!-- P3 -->
- In `--no-notarize` mode, the release script uses `JUSTTAB_SIGN_IDENTITY` if nonempty, otherwise the first valid Apple Development identity returned by `security find-identity -v -p codesigning`. It fails clearly when neither is available. The full-release `SIGN_IDENTITY` behavior is preserved.
- The release script's help describes the new variable. `docs/RELEASE.md` and `CHANGELOG.md` remain untouched as requested; the former's environment list does not yet document the new test-mode variable.

## Open questions for the owner

- When will the repository be made public so the prepared posts can be published?
- Do Cmd-H-hidden apps' windows appear and bring the app back when selected on your Mac? <!-- P1 -->
- Do windows on other desktops (Spaces) appear and switch to the correct desktop when selected? <!-- P2 -->
- When is the Developer ID-signed, Apple-notarized GitHub Releases DMG verified and available? <!-- P3 -->
- Does the switcher open on the display with the mouse pointer in your two-display test? <!-- P4 -->
- Has the post-switch focus check and single retry been confirmed on a real Mac? <!-- P5 -->
- Who will capture and approve the clean real-app recording and gallery images described in `capture-plan.md`?
- Which V2EX node should receive the Chinese post?
- Can you visually check the landing page at 375 px in light and dark mode before publishing?

## Remove optional lines before publishing

Until confirmed, remove the relevant tagged lines. The following single-line command removes **all** P-tagged lines from Markdown/HTML and the plain-text drafts inside Markdown fences. It edits the three public-copy files in place; review the diff afterward. It matches tags at the end of a line, including combined tags. Confirmed and unconfirmed lines are both removed by this conservative command.

```bash
python3 -c 'import pathlib,re,sys; tag=re.compile(r"(?:<!--\s*P[1-5](?:\s+P[1-5])*\s*-->|\[P[1-5](?:\s+P[1-5])*\])\s*$"); [(p.write_text("".join(line for line in p.read_text().splitlines(True) if not tag.search(line)))) for p in map(pathlib.Path,sys.argv[1:])]' README.md site/index.html marketing/launch-posts.md
```

Re-run `python3 marketing/check-copy.py`, `xmllint --html --noout site/index.html` and `git diff --check` after removal. No length-limited post depends on an optional line. Whole optional HTML elements are kept on one line, and optional README headings are tagged too.

## Publishing and evidence limits

Do not publish while the repository is private. Preconditions, counts, fact tags and gallery directions are editorial material, not post text. After owner confirmation, remove only the tags for retained verified claims before copying a post. Keep the full F9 credit with every README-style text and the complete X thread.

The supplied F19 attribution is retained without invented links. Exact Apple Developer Forums references would require a later source check when network access is authorized. The current work does not install, build, sign, notarize or release the app. Runtime behavior remains subject to the owner's real-Mac checks. No app source, tests, release instructions, license or changelog is changed.

## Local verification limits

The identity-selection checks use synthetic `security find-identity` output under macOS `/bin/bash` 3.2. They cover overrides, first development identity, missing identities, command failure and preserved full-release selection; they do not access the real keychain or run a build.

The installed Playwright browser could not start in this sandbox: macOS Mach port registration returned `Permission denied (1100)` before any page loaded. No screenshot or browser layout result is claimed. The CSS uses a single-column layout below 720 px, flexible grid tracks and wrapping controls, but the 375 px light/dark visual check still needs a browser outside this restriction. No package was installed and no network lookup was used.
