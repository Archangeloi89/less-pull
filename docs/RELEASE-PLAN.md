# Release plan

Less Pull 1.4.4 build 41 is the current release (11 October 2026). The version number stays 1.4.4 for good; releases are tagged `v1.4.4-<build>`, and the [release history](1.4.4-19-release.txt) describes every build since 19. The repository has been public since 8 October 2026.

## Done

- **Signed and notarized.** Since 9 October 2026 every release is signed with a Developer ID and notarized by Apple: the app, the browser helper and the Safari companion app. It opens like any other app, and Safari needs no Allow Unsigned Extensions.
- **Downloads for people and for the updater.** Each release carries a disk image, a zip for the in-app updater, `lesspull-update.json` (so the app only offers builds made for the reader's macOS), the agent pack and `SHA256SUMS.txt`.
- **Install update in the menu.** The app downloads the zip, checks it against the release's checksums, requires the Developer ID signature and Apple's notarization, and only then replaces itself. Settings and exceptions stay.
- **Browser extension.** Published in the Chrome Web Store (Chrome, Brave, Edge, Opera). Safari through the signed companion app. Firefox is submitted to addons.mozilla.org and loads as a temporary add-on until it is approved.
- **Automated suites** pass for every build: Night Shift policy, the warmth matrix, pause and daylight-saving handling, 576 combined exception cases, fades, website rules, menu dismissal, the extension worker, sessions and display recovery. See [testing](../Source/TESTING.txt).
- **13 languages.** English and German reviewed line by line; the others are marked experimental until a native speaker has read them.
- **Licenses.** Separate app and source licenses. See [Licensing](LICENSING.md).
- **Real screenshots** of the menu, the panels and every Settings tab, from the current build.

## Still open

1. Mozilla's approval of the Firefox extension; then the install help points at the add-on page.
2. Legal review of the custom license terms.
3. Clean installation tests on a fresh Mac, in Edge, and after long sleep or a display reconnect.
4. Native-speaker review of the experimental languages.

## Not verified

- macOS versions other than 27. Less Pull relies on private display interfaces, so each macOS version needs its own check.
- Optical calibration. No universal claim is made about how any display looks.

## Housekeeping

Do not commit credentials, user preferences, personal browsing context, test state files or private conversation documents. See [Publishing safely](PUBLISHING.md) for how signing and store hosting protect the release path.
