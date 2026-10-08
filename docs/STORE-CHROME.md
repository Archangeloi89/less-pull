# Chrome Web Store listing

**Status:** draft item created on 9 October 2026, id `lfcjadlpflfdgbgpcbkmdkmnboaakimb`, name "Less Pull Extension" (from the manifest), package 0.4.2. The Mac app allows this id in the native host from the build 33 refresh of 9 October. Not yet submitted for review.

The extension for Chrome, Brave, Opera and Edge is published once, in the Chrome Web Store; all four install from there. This page has everything to paste, and the three steps that need the author's Google account.

## Package

```sh
zsh tools/store/chrome-web-store.sh "/path/to/an/output/folder"
```

The zip holds the Chromium manifest without the local `key` (the store assigns the public ID), the background script, the icons and the licenses. Nothing else.

## The steps (author's account)

1. **Developer account.** https://chrome.google.com/webstore/devconsole with a Google account that has 2-step verification on. One-time registration fee of USD 5. Use a publisher name that is yours ("Jiri Arion Rose").
2. **New item.** Upload the zip. The dashboard shows the item's **ID** at once, before anything is public. Send that ID to the developer: the Mac app must allow it in the native-messaging host (one line, a new app build), or the store extension cannot reach the app.
3. **Fill the listing** with the texts below, upload the screenshots from `docs/store/`, answer the privacy practices as below, set visibility to Public, and submit for review. Reviews take from a day to a couple of weeks for a `nativeMessaging` extension. Publish only after the app build that allows the store ID is released, so a store install works on day one.

## Listing texts

**Name:** Less Pull Extension (from the manifest; the store shows it read-only)

**Summary (132 characters max):**
Connects your browser to the Less Pull Mac app, so websites can have their own display settings. Set them from the Less Pull menu.

**Description:**
Less Pull is a free Mac menu-bar app that takes the color out of your screen, so it pulls at you less, and adds warmth when you like. Every app and every website can have its own settings.

This extension has no buttons and no settings of its own. It tells the Less Pull app which website is in front, so the app can apply the exception you set for that site: full color for a photo site, a little warmth for a reading site, and your quiet defaults everywhere else. You set website exceptions from the Less Pull menu on your Mac, not in the browser.

What it reads: the address of the active tab in the window in front. Private windows are never reported. What it does not do: read or change anything on a page, see what you type, use the network. The address goes to the Less Pull app on the same Mac and is kept in memory only, never stored.

Requires the Less Pull app for macOS, free at https://github.com/Archangeloi89/less-pull.

**Category:** Accessibility. **Language:** English.

**Homepage:** https://github.com/Archangeloi89/less-pull
**Support:** https://github.com/Archangeloi89/less-pull/issues
**Privacy policy:** https://github.com/Archangeloi89/less-pull/blob/main/docs/PRIVACY.md

## Privacy practices (the form)

- **Single purpose:** Tells the Less Pull macOS app which website is in front, so the app can apply that website's display settings.
- **tabs:** Needed to read the address of the active tab, which is the only thing the extension reports. No page content is read.
- **nativeMessaging:** Needed to pass that address to the Less Pull app on the same Mac. There is no other recipient and no network use.
- **Remote code:** No. All code is in the package.
- **Data usage:** Collects nothing. The address of the active tab is handled on the user's Mac and is not stored, sold, or transferred. Tick "Web history" under "Personally identifiable information"? No: the data never leaves the device and is not stored; declare that no data is collected, and explain the tab address under the permission justifications, which is where reviewers look.
- **Certify** that the data use complies with the Developer Program Policies.

## Screenshots

`docs/store/` holds 1280 × 800 screenshots made from the project page figures: the exception submenu set from the menu, and where a website address goes. Five are allowed; two are enough. The 128 px icon is `Browser Extension/icon128.png`.

## After approval

The app's install help and the Websites tab point at the store page instead of the unpacked install; the agent pack's Chromium step becomes "open the store page". Chrome and Edge, untested until now, get their first real test through the store install.
