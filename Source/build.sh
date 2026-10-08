#!/bin/zsh
set -eu
cd "$(dirname "$0")"
BUILD_ROOT=$(mktemp -d /tmp/nightshiftfilters.XXXXXX)
trap 'rm -rf "$BUILD_ROOT"' EXIT
APP="$BUILD_ROOT/Less Pull.app"
mkdir -p "$APP/Contents/MacOS"
clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 -arch arm64 main.m Engine.m SwitchingPolicy.m WarmthEngine.m PausePolicy.m ExclusionPolicy.m BrowserBridge.m MenuDismissal.m -framework UniformTypeIdentifiers -framework Cocoa -framework ServiceManagement -o "$APP/Contents/MacOS/NightShiftFilters"
clang -fobjc-arc -O2 -Wall -mmacosx-version-min=13.0 -arch arm64 BrowserHost.m -framework Foundation -o "$APP/Contents/MacOS/LessPullBrowserHost"
codesign --force --sign - "$APP/Contents/MacOS/LessPullBrowserHost"
mkdir -p "$APP/Contents/Resources"
cp ../LICENSE-APP.txt ../LICENSE-SOURCE.txt "$APP/Contents/Resources/"
ditto --norsrc "../Browser Extension" "$APP/Contents/Resources/Browser Extension"
cp Info.plist "$APP/Contents/Info.plist"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
ditto --norsrc "$APP" "../Less Pull.app"
ditto -c -k --keepParent --norsrc "$APP" "../Less Pull.zip"
