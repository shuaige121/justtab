# Releasing JustTab outside the App Store

`scripts/release.sh` builds JustTab, signs it with a Developer ID certificate, puts it in a DMG,
sends the DMG to Apple for notarization, and staples the result. It publishes nothing. The DMG
ends up in `~/work/justtab-build/dist/JustTab-<version>.dmg`.

## Quick path: the Apple account signed in to Xcode (used for 2.0.0)

`scripts/release-xcode.sh` needs no certificate in the keychain and no notarytool profile. It
archives the app, has Xcode sign it with a cloud-managed Developer ID certificate, uploads it to Apple
for notarization through the account in Xcode > Settings > Accounts, waits for the ticket, checks
Gatekeeper (`source=Notarized Developer ID`) and writes `~/work/justtab-build/dist/JustTab-<version>.zip`
with its SHA-256. It publishes nothing. Then attach the ZIP to a GitHub Release (`gh release create`).

It produces a ZIP, not a DMG: the cloud-managed certificate has no local private key, so the DMG
itself could not be signed. For a signed and notarized DMG use `scripts/release.sh` after the
one-time setup below.

## One-time setup

### 1. Create a Developer ID Application certificate

The keychain currently holds Apple Distribution and Apple Development identities only. Those cannot
be used for downloads outside the App Store.

In Xcode: Settings > Accounts > select the team > Manage Certificates > `+` > Developer ID Application.
(Apple's page documents the same certificate being created in the developer account and says Xcode
can also be used; the Xcode menu path above is not spelled out there, so check it on screen.)

Who may create it: Apple's page lists the required role as **Account Holder**; admins can use
cloud-managed Developer ID certificates only with the "cloud-managed Developer ID certificate access"
role. Source: https://developer.apple.com/help/account/certificates/create-developer-id-certificates/
(checked 2026-11-10).

Check it worked: `security find-identity -v -p codesigning` should list `Developer ID Application: ...`.

### 2. Store notarization credentials (once)

Generate an app-specific password at https://account.apple.com (Sign-In and Security >
App-Specific Passwords), then run in Terminal:

    xcrun notarytool store-credentials justtab-notary --apple-id <Apple ID email> --team-id <Team ID>

`notarytool` asks for the password itself (its help says it shows a secure prompt when `--password` is
omitted). Type it there; the release script never sees it. Your Team ID is `VKSJ2FY567`
(the TeamIdentifier on the current build).

## Release

    scripts/release.sh

Optional environment: `SIGN_IDENTITY`, `NOTARY_PROFILE` (default `justtab-notary`), `BUILD_DIR`, `DIST_DIR`.
On success it prints the DMG path and its SHA-256. If Apple rejects the build, the script prints
the notarization log.

To test the pipeline without Apple: `scripts/release.sh --no-notarize`. That build is signed with a
development identity, is not notarized, and Gatekeeper blocks it on other Macs. It does not contact Apple.

## Accessibility and Screen Recording prompts

The installed development build has this designated requirement (checked with `codesign -d -r-`):

    identifier "com.leonardchow.justtab" and anchor apple generic and certificate leaf[subject.CN] = "Apple Development: Leonard Chow (335489CA3Q)" ...

It is tied to the development certificate. A Developer ID build is signed by a different certificate,
so its requirement differs. Expected behaviour (not tested here): macOS treats it as a different
identity and asks once more for Accessibility and Screen Recording; you may need to remove the old
JustTab entry in System Settings > Privacy & Security and add the new one.

## Hardened runtime

The script signs with `--options runtime`. A search of the sources found no Apple Events/AppleScript,
JIT, `dlopen`/`dlsym` or DYLD use, so no runtime exception entitlement is added; the entitlements
file only turns the sandbox off. Accessibility, the event tap and ScreenCaptureKit are permissioned
through System Settings, not entitlements.
