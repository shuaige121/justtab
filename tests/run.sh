#!/bin/bash
# Compiles the app's real sources with each test file and runs it. No Xcode project needed.
set -euo pipefail
cd "$(dirname "$0")"
SRC=../AltTab/AltTab
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

run() { # name, then sources (the first one becomes main.swift)
    local name=$1; shift
    mkdir -p "$OUT/$name"
    cat "$@" > "$OUT/$name/main.swift"
    swiftc -O "$OUT/$name/main.swift" "${EXTRA[@]}" -o "$OUT/$name/bin"
    "$OUT/$name/bin"
}

# Hotkey tests are appended to HotkeyManager.swift so they can call its fileprivate handler.
EXTRA=("$SRC/PermissionManager.swift"); run hotkey "$SRC/HotkeyManager.swift" hotkey_tests.swift
EXTRA=("$SRC/PermissionManager.swift"); run permission permission_tests.swift
EXTRA=("$SRC/SwitcherPanel.swift" "$SRC/ThumbnailView.swift" "$SRC/WindowModel.swift"); run grid grid_tests.swift
# MRU tests need two private members exposed.
sed -e 's/private func pruneMRU/func pruneMRU/' -e 's/private var mruOrder/var mruOrder/' \
    "$SRC/WindowModel.swift" > "$OUT/wm.swift"
EXTRA=("$OUT/wm.swift"); run mru mru_tests.swift
echo "ALL SUITES PASSED"
