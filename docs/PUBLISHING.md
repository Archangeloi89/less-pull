# Publishing safely

How Less Pull and its browser extension reach other people without anyone being able to slip something into them. Written 8 October 2026; nothing here has been done yet unless the release plan says so.

## The principle

The code is small and readable, and the extension asks for the least it can (`tabs` and `nativeMessaging`, no page access, no network). What has to be protected is the *release path*: whoever can sign and upload a build can reach every user. So every channel below is one where a store or Apple signs the package and reviews updates, and every account on that path has two-factor authentication.

## The Mac app

- **Apple Developer Program** (paid, yearly). It issues the *Developer ID* certificate. With it the app, the native host and the Safari companion are signed and **notarized**; Gatekeeper opens them without warnings on any Mac.
- Without it, only an "Apple Development" certificate from a free Apple ID exists: fine for the author's own Macs (and it removes Safari's *Allow Unsigned Extensions* step locally), not for distribution.
- Signing happens on the author's Mac from the keychain. Certificates and keys never go into the repository or a build service.
- Once releases are signed, update phase 2 can verify a download's signature before installing it (see the release plan).

## The browser extension

| Browser | Where it is hosted | Who signs it | Account protection |
| :-- | :-- | :-- | :-- |
| Chrome, Brave, Opera, Edge | Chrome Web Store (one-time registration fee) | Google; every update is reviewed | Google account with 2FA (mandatory for developers) |
| Firefox | addons.mozilla.org, listed or self-hosted | Mozilla | Mozilla account with 2FA (mandatory for developers) |
| Safari | App Store, or a Developer-ID-signed and notarized companion app | Apple | Apple Developer account with 2FA |

Store identity: the Chrome Web Store assigns its own extension ID when the package is first uploaded (the local `key` in `manifest.json` is for unpacked installs and must not be in the store upload). The app's native-host allowlist then lists both the local origin and the store origin, so unpacked and store copies both work.

## GitHub

- Two-factor authentication with a hardware key or authenticator app on the account.
- Branch protection on `main`: no force pushes, changes through pull requests.
- No secrets in the repository: no certificates, tokens or store credentials. The app never embeds a token for the update check.
- Releases carry `lesspull-update.json` so the app only offers builds made for the reader's macOS.

## What users can check

- The privacy page states what the extension can see and cannot do; the manifest is the proof.
- Browsers show the permissions before installation, and show them again if an update asks for more.
- The app's update check sends nothing about the user; installing stays a deliberate step until signed releases exist.
