# Release plan

Less Pull 1.4.4 is a private test release. This repository stays private until a public release is explicitly approved.

## Done

- Separate app and source licenses are in place. See [Licensing](LICENSING.md).
- The project page, screenshots, illustrations, install guide and privacy document are prepared.
- Automated suites pass for build 15: policy, warmth matrix, pause and daylight-saving handling, 576 combined exception cases, fades, website rules, menu dismissal, the extension worker, and display recovery. See the [1.4.4 notes](1.4.4-release.txt).
- Earlier live checks confirmed that Grayscale survives Night Shift turning off, that Color survives Night Shift turning on, and that saved warmth is restored.
- Since version 1.4.2, returning from an exception fades smoothly instead of switching at once. The author confirmed that the fade works as intended.

## Still open before a public release

1. Legal review of the custom license terms.
2. Sign the app and helper with a Developer ID, test with the Hardened Runtime, notarize, staple, and test a clean downloaded installation.
3. Clean installation tests in Chrome and Brave, plus reconnect, sleep and wake, and external display checks.
4. Register a Chrome Web Store publisher, get the production extension identity, align the native allowlist, prepare disclosures and reviewer instructions, then submit.
5. Publish versioned, notarized downloads.
6. Real screenshots of the App Exceptions window and of the popup inside Brave, for the project page.

Ports to Firefox, Safari or other browsers are separate work and will be scoped on their own.

## Not verified

- macOS versions other than 27.
- Extended sleep and display reconnect behavior.
- Optical calibration. No universal claim is made about how any display looks.

## Housekeeping

Do not commit credentials, user preferences, personal browsing context, test state files or private conversation documents.
