#!/bin/zsh
set -eu
cd "$(dirname "$0")"
BUILD_ROOT=$(mktemp -d /tmp/lesspull.XXXXXX)
trap 'rm -rf "$BUILD_ROOT"' EXIT
APP="$BUILD_ROOT/Less Pull.app"
mkdir -p "$APP/Contents/MacOS"
clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 -arch arm64 main.m Engine.m SwitchingPolicy.m WarmthEngine.m PausePolicy.m ExclusionPolicy.m BrowserBridge.m MenuDismissal.m -framework UniformTypeIdentifiers -framework Cocoa -framework Carbon -framework ServiceManagement -o "$APP/Contents/MacOS/LessPull"
clang -fobjc-arc -O2 -Wall -mmacosx-version-min=13.0 -arch arm64 BrowserHost.m -framework Foundation -o "$APP/Contents/MacOS/LessPullBrowserHost"
codesign --force --sign - "$APP/Contents/MacOS/LessPullBrowserHost"
mkdir -p "$APP/Contents/Resources"
cp ../LICENSE-APP.txt ../LICENSE-SOURCE.txt AppIcon.icns MenuBar/menubar-*.png "$APP/Contents/Resources/"
ditto --norsrc "../Browser Extension" "$APP/Contents/Resources/Browser Extension"
rm -f "$APP/Contents/Resources/Browser Extension/manifest.firefox.json"
# Firefox loads the same code with its own manifest (event page, add-on id).
ditto --norsrc "../Browser Extension" "$APP/Contents/Resources/Browser Extension (Firefox)"
mv "$APP/Contents/Resources/Browser Extension (Firefox)/manifest.firefox.json" "$APP/Contents/Resources/Browser Extension (Firefox)/manifest.json"
cp Info.plist "$APP/Contents/Info.plist"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
rm -rf "../Less Pull.app"
ditto --norsrc "$APP" "../Less Pull.app"
ditto -c -k --keepParent --norsrc "$APP" "../Less Pull.zip"
