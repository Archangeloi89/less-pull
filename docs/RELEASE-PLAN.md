# Release plan

Less Pull 1.4.4 build 16 is a private test release. This repository stays private until a public release is explicitly approved. The version number stays 1.4.4 for good; releases are tagged `v1.4.4-<build>`.

## Done

- Separate app and source licenses are in place. See [Licensing](LICENSING.md).
- The project page, screenshots, illustrations, install guide and privacy document are prepared.
- Build 16 adds the app improvements of 8 October 2026: icons, plain language, a welcome in Settings, a shorter menu, sectioned Settings, the warmth ramp slider, a state-showing menu-bar icon, better App Exceptions, website rules in the app, popup polish, Pause Less Pull, Peek in color, a daily update check, Firefox support, and the executable rename. See the [build 16 notes](1.4.4-16-release.txt).
- Automated suites pass for build 16 and passed for build 15: policy, warmth matrix, pause and daylight-saving handling, 576 combined exception cases, fades, website rules, menu dismissal, the extension worker, and display recovery. See the [1.4.4 notes](1.4.4-release.txt).
- Earlier live checks confirmed that Grayscale survives Night Shift turning off, that Color survives Night Shift turning on, and that saved warmth is restored.
- Since version 1.4.2, returning from an exception fades smoothly instead of switching at once. The author confirmed that the fade works as intended.

## Still open before a public release

1. Legal review of the custom license terms.
2. Sign the app and helper with a Developer ID, test with the Hardened Runtime, notarize, staple, and test a clean downloaded installation.
3. Clean installation tests in Chrome and Brave, plus reconnect, sleep and wake, and external display checks.
4. Register a Chrome Web Store publisher, get the production extension identity, align the native allowlist, prepare disclosures and reviewer instructions, then submit.
5. Publish versioned, notarized downloads.
6. Real screenshots of the Settings tabs and of the popup inside Brave, for the project page.
7. Make the repository or a releases feed public, so the in-app update check can see releases; attach `lesspull-update.json` to each release.
8. Developer ID signing and notarization also unlock update phase 2 (download, verify and install from the menu; Sparkle 2 is the recommended route and would be the first third-party dependency, so it needs an explicit decision).
9. Decide on the bundle identifier rename (`local.nightshiftfilters.app`), which needs a one-time preferences migration.
10. Safari: a Safari web extension wrapped in an app extension built with Xcode, after signing is in place.

Firefox is implemented but untested live. Safari, Edge and Opera remain separate work.

## Not verified

- macOS versions other than 27.
- Extended sleep and display reconnect behavior.
- Optical calibration. No universal claim is made about how any display looks.

## Housekeeping

Do not commit credentials, user preferences, personal browsing context, test state files or private conversation documents.
