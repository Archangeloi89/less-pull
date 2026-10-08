# Privacy

This describes Less Pull 1.4.4.

## In short

- No account, analytics, telemetry or cloud sync.
- The app and the extension run no network service of their own.
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

## What is stored

- **Website exceptions.** Domains and exact URLs you save are stored in macOS user defaults under `local.nightshiftfilters.app`. Exact URLs keep their query string and drop the part after `#`. Avoid saving addresses that contain tokens or other secrets.
- **App exceptions.** The app's identifier and your settings for it.
- **Your global settings.**

Removing an exception removes its stored entry. Deleting the app does not delete its preferences.

## Logs and diagnostics

Diagnostics show your appearance choices and display recovery counters. The normal appearance log contains no app identifiers and no website addresses. A developer test output exists, and it is written only when the app is started with an explicit command-line flag.

## Questions

Contact the author through [jiriarion.com](https://jiriarion.com).
