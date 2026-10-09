#!/bin/zsh
# Builds Less Pull. Ad hoc by default; with a Developer ID the build is signed with the
# hardened runtime and, if a notarytool keychain profile is given, notarized and stapled:
#   LESS_PULL_SIGN_IDENTITY="Developer ID Application: Jiri Arion Rose (TEAMID)" \
#   LESS_PULL_NOTARY_PROFILE=lesspull zsh Source/build.sh
# The certificate and the notarization password live in the keychain, never in the repository.
set -eu
SIGN="${LESS_PULL_SIGN_IDENTITY:--}"
sign() { if [[ "$SIGN" == "-" ]]; then codesign --force --sign - "$@"; else codesign --force --sign "$SIGN" --options runtime --timestamp "$@"; fi; }
cd "$(dirname "$0")"
BUILD_ROOT=$(mktemp -d /tmp/lesspull.XXXXXX)
trap 'rm -rf "$BUILD_ROOT"' EXIT
APP="$BUILD_ROOT/Less Pull.app"
mkdir -p "$APP/Contents/MacOS"
clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 -arch arm64 main.m Engine.m SwitchingPolicy.m WarmthEngine.m PausePolicy.m ExclusionPolicy.m BrowserBridge.m MenuDismissal.m Session.m Localize.m -framework CoreVideo -framework QuartzCore -framework UniformTypeIdentifiers -framework Cocoa -framework Carbon -framework ServiceManagement -o "$APP/Contents/MacOS/LessPull"
clang -fobjc-arc -O2 -Wall -mmacosx-version-min=13.0 -arch arm64 BrowserHost.m -framework Foundation -o "$APP/Contents/MacOS/LessPullBrowserHost"
sign "$APP/Contents/MacOS/LessPullBrowserHost"
mkdir -p "$APP/Contents/Resources"
cp ../LICENSE-APP.txt ../LICENSE-SOURCE.txt AppIcon.icns MenuBar/menubar-*.png Sounds/session-*.wav "$APP/Contents/Resources/"
for l in Localizations/*.lproj; do [ -d "$l" ] && cp -R "$l" "$APP/Contents/Resources/"; done
ditto --norsrc "../Browser Extension" "$APP/Contents/Resources/Browser Extension"
rm -f "$APP/Contents/Resources/Browser Extension/manifest.firefox.json"
# Firefox loads the same code with its own manifest (event page, add-on id).
ditto --norsrc "../Browser Extension" "$APP/Contents/Resources/Browser Extension (Firefox)"
mv "$APP/Contents/Resources/Browser Extension (Firefox)/manifest.firefox.json" "$APP/Contents/Resources/Browser Extension (Firefox)/manifest.json"
rm -f "$APP/Contents/Resources/Browser Extension (Firefox)/manifest.safari.json" "$APP/Contents/Resources/Browser Extension/manifest.safari.json"
# Safari: the same extension inside a companion app. The Xcode project is generated
# here by Apple's converter (so the file list always matches), our handler replaces the
# template, and the app is built ad hoc when Xcode is installed.
if [[ -d /Applications/Xcode.app && "${LESS_PULL_SKIP_SAFARI:-0}" != 1 ]]; then
 SAFARI_SRC="$BUILD_ROOT/safari-extension"; SAFARI_PROJECT="$BUILD_ROOT/safari-project"; SAFARI_BUILD="$BUILD_ROOT/safari-build"
 ditto --norsrc "../Browser Extension" "$SAFARI_SRC"; rm -f "$SAFARI_SRC/manifest.firefox.json"; mv "$SAFARI_SRC/manifest.safari.json" "$SAFARI_SRC/manifest.json"
 export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
 xcrun safari-web-extension-converter "$SAFARI_SRC" --project-location "$SAFARI_PROJECT" --app-name "Less Pull for Safari" --bundle-identifier com.jiriarion.lesspull.safari --macos-only --no-open --no-prompt --copy-resources --force > /dev/null
 cp Safari/SafariWebExtensionHandler.swift "$SAFARI_PROJECT/Less Pull for Safari/Less Pull for Safari Extension/SafariWebExtensionHandler.swift"
 # The converter derives the app's identifier from its name; the extension must sit under the app's.
 sed -i '' 's/com\.jiriarion\.lesspull\.Less-Pull-for-Safari/com.jiriarion.lesspull.safari/g' "$SAFARI_PROJECT/Less Pull for Safari/Less Pull for Safari.xcodeproj/project.pbxproj"
 xcodebuild -project "$SAFARI_PROJECT/Less Pull for Safari/Less Pull for Safari.xcodeproj" -scheme "Less Pull for Safari" -configuration Release -derivedDataPath "$SAFARI_BUILD" CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS="$PWD/Safari/LessPullSafari.entitlements" -quiet build
 ditto --norsrc "$SAFARI_BUILD/Build/Products/Release/Less Pull for Safari.app" "$APP/Contents/Resources/Less Pull for Safari.app"
 unset DEVELOPER_DIR
else
 echo "Xcode not found or skipped: building without the Safari companion app." >&2
fi
cp Info.plist "$APP/Contents/Info.plist"
xattr -cr "$APP"
if [[ -d "$APP/Contents/Resources/Less Pull for Safari.app" ]]; then
 # Ad-hoc signing through xcodebuild drops entitlements; sign the extension here so it is sandboxed.
 sign --entitlements Safari/LessPullSafari.entitlements "$APP/Contents/Resources/Less Pull for Safari.app/Contents/PlugIns/Less Pull for Safari Extension.appex"
 sign "$APP/Contents/Resources/Less Pull for Safari.app"
fi
sign "$APP"
codesign --verify --strict "$APP"
if [[ -n "${LESS_PULL_NOTARY_PROFILE:-}" ]]; then
 # Notarize the whole app (it contains the host and the Safari companion) and staple the ticket.
 NOTARIZE_ZIP="$BUILD_ROOT/notarize.zip"; ditto -c -k --keepParent --norsrc "$APP" "$NOTARIZE_ZIP"
 xcrun notarytool submit "$NOTARIZE_ZIP" --keychain-profile "$LESS_PULL_NOTARY_PROFILE" --wait
 xcrun stapler staple "$APP"; [[ -d "$APP/Contents/Resources/Less Pull for Safari.app" ]] && xcrun stapler staple "$APP/Contents/Resources/Less Pull for Safari.app" || true
 spctl --assess --type execute --verbose=2 "$APP"
fi
rm -rf "../Less Pull.app"
ditto --norsrc "$APP" "../Less Pull.app"
xattr -cr "../Less Pull.app"  # Finder attributes on the copy would count as detritus for Gatekeeper
ditto -c -k --keepParent --norsrc "$APP" "../Less Pull.zip"
