#!/bin/zsh
# Installs or updates Less Pull from a release zip. Usage: install.sh <Less Pull zip> [SHA256SUMS.txt]
set -eu
ZIP="$1"; SUMS="${2:-}"
if [[ -n "$SUMS" ]]; then
 expected=$(grep -F "$(basename "$ZIP")" "$SUMS" | awk '{print $1}' | head -1); actual=$(shasum -a 256 "$ZIP" | awk '{print $1}')
 [[ -n "$expected" && "$expected" == "$actual" ]] || { echo "Checksum mismatch for $ZIP" >&2; exit 1; }; echo "checksum ok"
fi
T=$(mktemp -d "${TMPDIR:-/tmp}/lesspull.XXXXXX"); trap 'rm -rf "$T"' EXIT
ditto -x -k "$ZIP" "$T"; APP="$T/Less Pull.app"; [[ -d "$APP" ]] || { echo "No Less Pull.app in the zip" >&2; exit 1; }
codesign --verify --strict "$APP" && echo "signature ok ($(codesign -dv "$APP" 2>&1 | grep -o 'Signature=.*'))"
osascript -e 'quit app "Less Pull"' 2>/dev/null || true; sleep 2; pkill -f "Less Pull.app/Contents/MacOS/LessPullBrowserHost" 2>/dev/null || true
rm -rf "/Applications/Less Pull.app"; ditto --norsrc "$APP" "/Applications/Less Pull.app"; xattr -cr "/Applications/Less Pull.app" 2>/dev/null || true
codesign --verify --strict "/Applications/Less Pull.app"
"/Applications/Less Pull.app/Contents/MacOS/LessPullBrowserHost" --install
if [[ -d "/Applications/Less Pull.app/Contents/Resources/Less Pull for Safari.app" ]]; then
 rm -rf "/Applications/Less Pull for Safari.app"; ditto --norsrc "/Applications/Less Pull.app/Contents/Resources/Less Pull for Safari.app" "/Applications/Less Pull for Safari.app"; xattr -cr "/Applications/Less Pull for Safari.app" 2>/dev/null || true
 /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Less Pull for Safari.app"; open "/Applications/Less Pull for Safari.app"; echo "Safari companion installed; enable it in Safari → Settings → Extensions"
fi
open "/Applications/Less Pull.app"; echo "Less Pull installed and launched"
