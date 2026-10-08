# Privacy

This describes Less Pull 1.5.0.

## In short

- No account, analytics, telemetry or cloud sync.
- The app and the extension run no network service of their own.
- About once a week the app asks GitHub whether a newer version exists. That is one HTTPS request to GitHub's releases API with no identifiers; it can be turned off in Settings → About.
- The extension never reads or changes the content of web pages.
- Your rules are stored on your Mac.

The optional author and support buttons open websites in your browser, and those sites have their own policies. Downloads are hosted by GitHub under GitHub's policies.

## The browser extension

The extension asks for two permissions:

| Permission | Why |
| :-- | :-- |
| `tabs` | To know which website is in the active tab |
| `nativeMessaging` | To talk to the Less Pull app on the same Mac |

The domain and URL of the active public tab are sent through a small helper and a local Unix socket to the Mac app. Private tabs are excluded. The app keeps the active site in memory only. It is cleared when the browser disconnects or the information expires.

## The update check

Once a week at most, and when you choose **Check for Updates…**, the app requests `https://api.github.com/repos/Archangeloi89/less-pull/releases/latest` over HTTPS. The request carries no account, identifier or settings; GitHub sees the same thing any browser visiting that address would send, including your IP address, under [GitHub's privacy statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement). The reply (version, release notes, download page) is stored on your Mac so the menu can show it. Nothing is downloaded or installed by itself; installing a new version is done by you. Untick **Check for updates automatically** in Settings → About to stop the weekly check; the manual button still works.

## What is stored

- **Website exceptions.** Domains and exact URLs you save are stored in macOS user defaults under `local.nightshiftfilters.app`. Exact URLs keep their query string and drop the part after `#`. Avoid saving addresses that contain tokens or other secrets.
- **App exceptions.** The app's identifier and your settings for it.
- **Your global settings.**
- **Update check.** The date of the last check and, if one was found, the newer version's number, release notes and download page.

Removing an exception removes its stored entry. Deleting the app does not delete its preferences.

## Logs and diagnostics

Diagnostics show your appearance choices and display recovery counters. The normal appearance log contains no app identifiers and no website addresses. A developer test output exists, and it is written only when the app is started with an explicit command-line flag.

## Questions

Contact the author through [jiriarion.com](https://jiriarion.com).
