#!/bin/bash
# Build, Developer ID-sign and notarize JustTab through the Apple account signed in to Xcode,
# then package the notarized app as a ZIP. No certificate or notarytool profile is needed:
# Xcode signs with a cloud-managed Developer ID certificate (Account Holder or Admin role).
#
# Usage: scripts/release-xcode.sh            (uploads the app to Apple for notarization)
# Environment: TEAM_ID (default VKSJ2FY567), BUILD_DIR, DIST_DIR, WAIT_MINUTES (default 30)
set -euo pipefail

die()  { echo "error: $*" >&2; exit 1; }
step() { echo "==> $*"; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_ID="${TEAM_ID:-VKSJ2FY567}"
BUILD_DIR="${BUILD_DIR:-$HOME/work/justtab-build/xc-release}"
DIST_DIR="${DIST_DIR:-$HOME/work/justtab-build/dist}"
WAIT_MINUTES="${WAIT_MINUTES:-30}"
ARCHIVE="$BUILD_DIR/JustTab.xcarchive"

[ "$(uname)" = "Darwin" ] || die "this script runs on macOS only"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

export_options() { # $1 = export | upload
  cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>teamID</key><string>$TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
<key>destination</key><string>$1</string>
</dict></plist>
PLIST
}

step "Archiving (Release, hardened runtime)"
rm -rf "$ARCHIVE"
xcodebuild -project "$ROOT/AltTab/AltTab.xcodeproj" -scheme AltTab -configuration Release \
  -derivedDataPath "$BUILD_DIR/dd" -archivePath "$ARCHIVE" archive \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic ENABLE_HARDENED_RUNTIME=YES \
  -allowProvisioningUpdates > "$BUILD_DIR/archive.log" 2>&1 || die "archive failed, see $BUILD_DIR/archive.log"
VERSION="$(defaults read "$ARCHIVE/Products/Applications/JustTab.app/Contents/Info.plist" CFBundleShortVersionString)"
echo "Version: $VERSION"

step "Uploading to Apple for notarization (Developer ID, Xcode account)"
export_options upload > "$BUILD_DIR/export-upload.plist"
rm -rf "$BUILD_DIR/export-upload"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$BUILD_DIR/export-upload" \
  -exportOptionsPlist "$BUILD_DIR/export-upload.plist" -allowProvisioningUpdates \
  > "$BUILD_DIR/export-upload.log" 2>&1 || die "upload failed, see $BUILD_DIR/export-upload.log"

step "Waiting for notarization (up to $WAIT_MINUTES minutes)"
APP="$BUILD_DIR/notarized/JustTab.app"
i=0
until xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$BUILD_DIR/notarized" \
        > "$BUILD_DIR/notarized.log" 2>&1; do
  i=$((i + 1))
  [ "$i" -lt $((WAIT_MINUTES * 2)) ] || die "not notarized after $WAIT_MINUTES minutes, see $BUILD_DIR/notarized.log"
  rm -rf "$BUILD_DIR/notarized"
  sleep 30
done

step "Verifying"
xcrun stapler validate "$APP" >/dev/null || die "no stapled notarization ticket"
# Capture output first: grep -q closing the pipe early would trip pipefail (SIGPIPE, exit 141).
GK="$(spctl --assess --type execute --verbose=2 "$APP" 2>&1 || true)"
case "$GK" in *"source=Notarized Developer ID"*) ;; *) die "Gatekeeper did not accept the app: $GK" ;; esac
SIG="$(codesign -dv "$APP" 2>&1 || true)"
case "$SIG" in *"(runtime)"*) ;; *) die "hardened runtime missing" ;; esac

step "Packaging"
ZIP="$DIST_DIR/JustTab-$VERSION.zip"
rm -f "$ZIP"
(cd "$(dirname "$APP")" && ditto -c -k --keepParent JustTab.app "$ZIP")
echo "ZIP:    $ZIP"
echo "SHA256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
