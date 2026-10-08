# Less Pull — installation pack for AI agents

For an AI agent (Claude Code, Codex, or similar) that sets Less Pull up on someone's Mac, before the app is Apple-signed and before the browser extension is in the stores. Everything here runs locally; nothing is sent anywhere. Read `docs/PRIVACY.md` before installing the browser extension and tell the user what it can see.

Requirements: Apple silicon Mac, macOS 13 or later (tested on macOS 27), the release zip and `SHA256SUMS.txt` from the same GitHub release, Node 22+ for the browser scripts.

## 1. Install the app

```sh
zsh install.sh "/path/to/Less-Pull-1.4.4-31.zip" "/path/to/SHA256SUMS.txt"
```

The script verifies the checksum, extracts a clean copy (synced folders add metadata that breaks signature checks), checks the signature, quits a running copy, replaces `/Applications/Less Pull.app` (keeping the user's settings), registers the browser bridge for Chrome, Brave, Firefox, Opera and Edge, installs the Safari companion app, and launches Less Pull. Gatekeeper may ask the user to allow an app that is not notarized; that is expected until the signed build exists.

## 2. Connect a browser (optional, for website exceptions)

The extension has no buttons. It only tells Less Pull which website is in front; website exceptions are set from the Less Pull menu. Private tabs are never reported.

- **Chromium browsers (Brave, Chrome, Opera, Edge)**: relaunch the browser with a debugging port, then drop the extension folder onto its extensions page:
  ```sh
  open -a "Brave Browser" --args --remote-debugging-port=9333   # or Opera, "Google Chrome", "Microsoft Edge"
  node chromium-load.mjs 9333 "/Applications/Less Pull.app/Contents/Resources/Browser Extension"
  ```
  Developer mode must be on in the browser's extensions page (the script says so if it is not). Chrome 137+ ignores `--load-extension`, which is why the drop is used. Unpacked extensions stay installed across restarts.
- **Firefox**: relaunch with its remote port, then install the unpacked extension through WebDriver BiDi:
  ```sh
  open -a Firefox --args --remote-debugging-port 9222
  node firefox-load.mjs "/Applications/Less Pull.app/Contents/Resources/Browser Extension (Firefox)"
  ```
  Firefox keeps a temporary add-on only until it quits; repeat after a restart (or use Firefox Developer Edition with `xpinstall.signatures.required` off). Once the extension is signed on addons.mozilla.org this step goes away.
- **Safari**: `install.sh` already placed `/Applications/Less Pull for Safari.app` and opened it once. The user then turns the extension on in Safari → Settings → Extensions. Until the companion app is Apple-signed, Safari needs *Allow Unsigned Extensions* from the Develop menu (Settings → Advanced → Show features for web developers first); that choice lasts until Safari quits.

Check: `pgrep -fl LessPullBrowserHost` lists one helper per connected Chromium/Firefox browser. Less Pull → Settings → Websites shows "Extension connected in …".

## 3. What to tell the user

- Less Pull lives in the menu bar; the first launch opens Settings with a short welcome.
- Launch at login is a checkbox in Settings → General; the app must stay in Applications.
- The update check (daily, one request to GitHub, nothing about the user) can be turned off in Settings → About. Installing updates is by hand until signed releases exist.
- Remove: quit Less Pull from its menu, delete the app; preferences remain in `~/Library/Preferences/com.jiriarion.lesspull.plist`.

## Files

- `install.sh` — install or update the app, register the bridge, install the Safari companion.
- `chromium-load.mjs` — load the unpacked extension into a Chromium browser through its debugging port (Playwright over CDP; `npm i playwright` or set `NODE_PATH` to a copy).
- `firefox-load.mjs` — install the unpacked extension into Firefox through WebDriver BiDi (no dependencies).
