# Privacy

This describes Less Pull 1.5.0.

## In short

- No account, analytics, telemetry or cloud sync.
- The app and the extension run no network service of their own.
- Once a day the app asks GitHub whether a newer build exists. That is one HTTPS request to GitHub's releases API with no identifiers (a second one reads which macOS versions a newer build is made for); it can be turned off in Settings → About.
- The extension never reads or changes the content of web pages.
- Your rules are stored on your Mac.

The optional author and support buttons open websites in your browser, and those sites have their own policies. Downloads are hosted by GitHub under GitHub's policies.

## The browser extension

The extension asks for two permissions:

| Permission | Why |
| :-- | :-- |
| `tabs` | To know which website is in the active tab |
| `nativeMessaging` | To talk to the Less Pull app on the same Mac |

The domain and URL of the active public tab are sent through a small helper and a local Unix socket (or, for Safari, a local Mach port) to the Mac app. Private tabs are excluded. The app keeps the active site in memory only: one entry per connected browser, overwritten by the next report, removed a minute after the last report or as soon as the browser disconnects. It is never written to disk, not to preferences, logs or diagnostics, and the extension and the helper keep no copy either. A browser's native-messaging channel and the socket carry it between processes on the same Mac and store nothing. The socket accepts only the app's own browser helper (the process on the other end must be the helper executable inside the app bundle); other programs on the Mac get no answer. Nothing the app offers over that socket returns the address of the site in front, so no other app can ask for it.

## The update check

Once a day at most, and when you choose **Check for Updates…**, the app requests `https://api.github.com/repos/Archangeloi89/less-pull/releases/latest` over HTTPS. If that names a newer build, it also fetches the small `lesspull-update.json` file attached to that release, which says which macOS versions the build is made for; builds made for another macOS version are not offered. The request carries no account, identifier or settings; GitHub sees the same thing any browser visiting that address would send, including your IP address, under [GitHub's privacy statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement). The reply (version, release notes, download page) is stored on your Mac so the menu can show it. Nothing is downloaded or installed by itself; installing a new version is done by you. Untick **Check for updates automatically** in Settings → About to stop the daily check; the manual button still works.

## What the extension can and cannot do

Safari and the other browsers warn that the extension "can see your browsing history". That is what the `tabs` permission means: the extension can read the address and title of your tabs. It uses that for one thing, telling the Less Pull app which public website is in front. It cannot read or change what is on a page (it has no content scripts and no host permissions), it cannot see what you type, your passwords, cookies or form data, it has no network code, and it has no user interface. `nativeMessaging` only lets it talk to the Less Pull app on the same Mac.

The honest risk is the release path, not the running code: a tampered update could send the addresses of sites you visit somewhere. The protections are that the extension code is small and readable, that store-distributed versions are reviewed and signed by the store, and that signed, notarized app releases are the plan before a public launch. A request for new permissions is always shown before it takes effect.

## What is stored

- **Sessions.** The running session (its start, end and call-back time) and your session preferences. Nothing about what you did during it.
- **Website exceptions.** Domains and exact URLs you save are stored in macOS user defaults under `com.jiriarion.lesspull` (builds before 16 used `local.nightshiftfilters.app`; the first launch of build 16 copies those settings over once and leaves the old entry in place). Exact URLs keep their query string and drop the part after `#`. Avoid saving addresses that contain tokens or other secrets.
- **App exceptions.** The app's identifier and your settings for it.
- **Your global settings.**
- **Update check.** The date of the last check and, if one was found, the newer version's number, release notes and download page.

Removing an exception removes its stored entry. Deleting the app does not delete its preferences.

## What is never stored

The addresses of the websites you visit. They stream from the browser to the app, live in the app's memory while that tab is in front, and are overwritten or dropped as described above. The only addresses on disk are the ones you save as exceptions yourself. Like any process, the app's memory is managed by macOS, which encrypts swapped memory by default.

## Logs and diagnostics

Diagnostics show your appearance choices and display recovery counters. The normal appearance log contains no app identifiers and no website addresses. A developer test output exists, and it is written only when the app is started with an explicit command-line flag.

## Questions

Contact the author through [jiriarion.com](https://jiriarion.com).
