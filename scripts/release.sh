#!/bin/bash
# Build, sign, package (and optionally notarize) JustTab as a DMG.
# Never publishes anything. Run with --help for usage.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/release.sh [--no-notarize] [--help]

Builds JustTab (Release), signs it, wraps it in a DMG, and notarizes it.

  (no flag)       Full release: Developer ID signature, notarization by Apple
                  (uploads the DMG to Apple), stapling, Gatekeeper check.
  --no-notarize   Pipeline test only. Signs with JUSTTAB_SIGN_IDENTITY,
                  SIGN_IDENTITY, a Developer ID Application identity or the
                  first "Apple Development" identity, skips notarization, stapling
                  and spctl, never contacts Apple. The DMG is a local test
                  build that Gatekeeper will block on other Macs.

Environment:
  SIGN_IDENTITY   Signing identity (name or SHA-1). Default: the first
                  "Developer ID Application" identity in the keychain.
  JUSTTAB_SIGN_IDENTITY
                  Signing identity for --no-notarize (overrides SIGN_IDENTITY).
  NOTARY_PROFILE  notarytool keychain profile. Default: justtab-notary
  BUILD_DIR       Derived data folder. Default: $HOME/work/justtab-build/release
  DIST_DIR        DMG output folder.  Default: $HOME/work/justtab-build/dist

One-time setup is described in docs/RELEASE.md.
USAGE
}

die() { echo "error: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

NOTARIZE=1
for arg in "$@"; do
  case "$arg" in
    --no-notarize) NOTARIZE=0 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $arg" ;;
  esac
done

[ "$(uname)" = "Darwin" ] || die "this script runs on macOS only"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT/AltTab"
ENTITLEMENTS="$PROJECT_DIR/AltTab/AltTab.entitlements"
BUILD_DIR="${BUILD_DIR:-$HOME/work/justtab-build/release}"
DIST_DIR="${DIST_DIR:-$HOME/work/justtab-build/dist}"
NOTARY_PROFILE="${NOTARY_PROFILE:-justtab-notary}"

[ -f "$ENTITLEMENTS" ] || die "entitlements file not found: $ENTITLEMENTS"

# --- Signing identity (resolved to a SHA-1 so duplicate names cannot confuse codesign)
IDENTITIES="$(security find-identity -v -p codesigning || true)"
find_hash() { printf '%s\n' "$IDENTITIES" | grep "\"$1" | head -n 1 | awk '{print $2}' || true; }

if [ "$NOTARIZE" = 0 ]; then
  IDENTITY="${JUSTTAB_SIGN_IDENTITY:-${SIGN_IDENTITY:-}}"
  [ -n "$IDENTITY" ] || IDENTITY="$(find_hash 'Developer ID Application')"
  [ -n "$IDENTITY" ] || IDENTITY="$(find_hash 'Apple Development:')"
  [ -n "$IDENTITY" ] || die "no valid 'Apple Development:' identity in the keychain.
Create an Apple Development certificate, or set JUSTTAB_SIGN_IDENTITY for --no-notarize."
elif [ -n "${SIGN_IDENTITY:-}" ]; then
  IDENTITY="$SIGN_IDENTITY"
elif [ "$NOTARIZE" = 1 ]; then
  IDENTITY="$(find_hash 'Developer ID Application')"
  [ -n "$IDENTITY" ] || die "no 'Developer ID Application' identity in the keychain.
Create one first (see docs/RELEASE.md, step 1), or set SIGN_IDENTITY.
Use --no-notarize to test the pipeline with a development identity."
fi
echo "Signing identity: $IDENTITY"

if [ "$NOTARIZE" = 1 ]; then
  TIMESTAMP="--timestamp"
else
  TIMESTAMP="--timestamp=none"
  echo "WARNING: --no-notarize: local test build, no Apple contact."
fi

# --- Build (unsigned by Xcode; signed below with the hardened runtime)
step "Building Release into $BUILD_DIR"
(cd "$PROJECT_DIR" && xcodebuild -scheme AltTab -configuration Release \
  -derivedDataPath "$BUILD_DIR" CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" -quiet build) \
  || die "xcodebuild failed"
APP="$BUILD_DIR/Build/Products/Release/JustTab.app"
[ -d "$APP" ] || die "built app not found: $APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[ -n "$VERSION" ] || die "could not read the version from Info.plist"
echo "Version: $VERSION"

# --- Sign the app
step "Signing JustTab.app"
codesign --force --options runtime $TIMESTAMP --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" "$APP" || die "codesign failed for the app"
codesign --verify --strict --deep --verbose=2 "$APP" || die "app signature verification failed"

# --- DMG
step "Creating DMG"
mkdir -p "$DIST_DIR"
DMG="$DIST_DIR/JustTab-$VERSION.dmg"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/justtab-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/JustTab.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "JustTab $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null \
  || die "hdiutil create failed"
codesign --force $TIMESTAMP --sign "$IDENTITY" "$DMG" || die "codesign failed for the DMG"
codesign --verify --strict --verbose=2 "$DMG" || die "DMG signature verification failed"

if [ "$NOTARIZE" = 0 ]; then
  echo
  echo "WARNING: local test build. Not notarized; Gatekeeper will block it on other Macs."
  echo "DMG:    $DMG"
  echo "SHA256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
  exit 0
fi

# --- Notarize (uploads the DMG to Apple)
step "Submitting to Apple notary service (profile: $NOTARY_PROFILE)"
RESULT="$(mktemp "${TMPDIR:-/tmp}/justtab-notary.XXXXXX")"
trap 'rm -rf "$STAGE" "$RESULT"' EXIT
if ! xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 | tee "$RESULT"; then
  die "notarytool submit failed; check the profile with: xcrun notarytool history --keychain-profile $NOTARY_PROFILE"
fi
if ! grep -q "status: Accepted" "$RESULT"; then
  SUB_ID="$(grep -m1 '^ *id:' "$RESULT" | awk '{print $2}' || true)"
  if [ -n "$SUB_ID" ]; then
    echo "--- notarytool log for $SUB_ID ---" >&2
    xcrun notarytool log "$SUB_ID" --keychain-profile "$NOTARY_PROFILE" >&2 || true
  fi
  die "notarization was not accepted"
fi

step "Stapling"
xcrun stapler staple "$DMG" || die "stapler staple failed"
xcrun stapler validate "$DMG" || die "stapler validate failed"

step "Gatekeeper assessment"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" || die "spctl rejected the DMG"
MNT="$(mktemp -d "${TMPDIR:-/tmp}/justtab-mnt.XXXXXX")"
trap 'hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || true; rm -rf "$STAGE" "$RESULT" "$MNT"' EXIT
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MNT" -quiet || die "could not mount the DMG"
spctl --assess --type execute --verbose=2 "$MNT/JustTab.app" || die "spctl rejected the app"

echo
echo "Release ready (not published)."
echo "DMG:    $DMG"
echo "SHA256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
