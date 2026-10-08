# Firefox Add-ons (addons.mozilla.org) listing

Firefox installs the extension from addons.mozilla.org (AMO). Mozilla signs it on upload; no Apple or Google account is involved. The add-on id `lesspull@jiriarion.com` is fixed in the manifest, so the Mac app already allows it: nothing in the app changes for Firefox.

## Package

```sh
zsh tools/store/firefox-amo.sh "/path/to/an/output/folder"
```

## The steps (author's account)

1. **Account.** https://addons.mozilla.org/developers/ with a Mozilla account (free), 2-step verification on.
2. **Submit a new add-on** → "On this site" (listed) → upload the zip. AMO validates the package (expect no errors; `nativeMessaging` is allowed) and asks whether source code is needed: the package *is* the source, so answer no.
3. **Fill the listing** with the texts below and the screenshots from `docs/store/` (AMO accepts the 1280 × 800 files). Category: Other, or Privacy & Security. License: choose "Custom license" and paste the first lines of `LICENSE-APP.txt` with the link. Privacy policy: paste the "Website exceptions, in your browser" part of `docs/PRIVACY.md` and the link.
4. **Submit for review.** Listed add-ons with `nativeMessaging` get a human review; usually days. Firefox users can install as soon as it is approved: the app needs no update.

## Note for the reviewer (paste into "Notes to Reviewer")

The extension sends the address of the active tab to the Less Pull app on the same Mac through native messaging (host `local.less_pull.browser`). That is its only function. Nothing is sent to the developer or to any server; the app keeps the address in memory only and never stores it. The manifest therefore declares `data_collection_permissions: {"required": ["none"]}`. The native host and the app are open to inspection at https://github.com/Archangeloi89/less-pull (Source/BrowserHost.m, Source/BrowserBridge.m, docs/PRIVACY.md).

## Listing texts

**Name:** Less Pull — Website Exceptions

**Summary (250 characters max):**
Connects Firefox to the Less Pull Mac app, so websites can have their own display settings: full color for a photo site, a little warmth for a reading site, your quiet defaults everywhere else. No buttons; set exceptions from the Less Pull menu.

**Description:** the same text as the Chrome Web Store description in `STORE-CHROME.md`, with "Firefox" in place of "your browser" in the first line of the second paragraph.

**Homepage:** https://github.com/Archangeloi89/less-pull · **Support:** https://github.com/Archangeloi89/less-pull/issues

## Permissions, as AMO shows them to users

"Access browser tabs" (the `tabs` permission) and "Exchange messages with programs other than Firefox" (`nativeMessaging`). The listing's description explains both in one line each; reviewers look for that.

## After approval

The install help and the Websites tab point at the AMO page; the agent pack's Firefox step becomes "open the AMO page". The temporary-add-on dance with the remote port goes away for Firefox users.
