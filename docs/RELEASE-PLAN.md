# Release plan

Less Pull 1.4.4 build 28 is a test release shared with friends (build 16 was the first public one); the repository went public on 8 October 2026 at the author's request. The version number stays 1.4.4 for good; releases are tagged `v1.4.4-<build>`.

## Done

- Separate app and source licenses are in place. See [Licensing](LICENSING.md).
- The project page, screenshots, illustrations, install guide and privacy document are prepared.
- Build 16 adds the app improvements of 8 October 2026: icons, plain language, a welcome in Settings, a shorter menu, sectioned Settings, the warmth ramp slider, a state-showing menu-bar icon, better App Exceptions, website rules in the app, popup polish, Pause Less Pull, Peek in color, a daily update check, Firefox support, and the executable rename. See the [build 16 notes](1.4.4-16-release.txt).
- Automated suites pass for build 16 and passed for build 15: policy, warmth matrix, pause and daylight-saving handling, 576 combined exception cases, fades, website rules, menu dismissal, the extension worker, and display recovery. See the [1.4.4 notes](1.4.4-release.txt).
- Earlier live checks confirmed that Grayscale survives Night Shift turning off, that Color survives Night Shift turning on, and that saved warmth is restored.
- Since version 1.4.2, returning from an exception fades smoothly instead of switching at once. The author confirmed that the fade works as intended.

See [Publishing safely](PUBLISHING.md) for how signing and store hosting protect the release path. Until then, the release carries an [agent pack](../tools/agent-pack/README.md) so an AI agent can install the app and connect the browsers for a user.

## Still open before a public release

1. Legal review of the custom license terms.
2. Sign the app and helper with a Developer ID, test with the Hardened Runtime, notarize, staple, and test a clean downloaded installation.
3. Clean installation tests in Chrome and Brave, plus reconnect, sleep and wake, and external display checks.
4. Register a Chrome Web Store publisher, get the production extension identity, align the native allowlist, prepare disclosures and reviewer instructions, then submit.
5. Publish versioned, notarized downloads.
6. Real screenshots of the Settings tabs and of the popup inside Brave, for the project page.
7. Attach `lesspull-update.json` to each release (the repository is public, so the in-app update check sees releases).
8. Developer ID signing and notarization also unlock update phase 2 (download, verify and install from the menu; Sparkle 2 is the recommended route and would be the first third-party dependency, so it needs an explicit decision).
10. Safari: sign and notarize the companion app (built by build.sh with Xcode) so the extension loads without Allow Unsigned Extensions; consider App Store distribution of the companion.

Firefox, Safari, Opera and Edge are implemented but need clean-install tests; Safari also needs Developer ID signing of the companion app before it can be used without Allow Unsigned Extensions.

## Not verified

- macOS versions other than 27.
- Extended sleep and display reconnect behavior.
- Optical calibration. No universal claim is made about how any display looks.

## Housekeeping

Do not commit credentials, user preferences, personal browsing context, test state files or private conversation documents.
