# Install

Version 1.4.4 (build 40) is a test build. Read [what to expect](#what-to-expect-from-this-build) before you install. The version number stays 1.4.4 on purpose; the build number is what changes.

## The Mac app

1. Download **Less-Pull-1.4.4-40.dmg** from the [build 40 release](https://github.com/Archangeloi89/less-pull/releases/tag/v1.4.4-40).
2. Open it and drag **Less Pull** onto the **Applications** shortcut next to it. (A zip of the same app is on the release page too; the in-app updater uses it.)
3. Open it. A half-filled circle appears in the menu bar, and on the first launch the Settings window opens with a short welcome.
4. Click the circle and choose Grayscale and Extra Warmth. Turn on **Extra Warmth follows Night Shift** if you want warmth only at night. The icon fills on the left while grayscale is showing and warms on the right as you add warmth.

The app is signed with a Developer ID and notarized by Apple, so macOS opens it without a warning. If macOS still objects, the download was altered on the way; get it again from the release page.

To start Less Pull when you sign in, open **Settings…** and check **Launch at login**. The app needs to be in Applications first.

If you are updating from an earlier build: quit Less Pull, replace the app in Applications, and open it again. Your settings and exceptions are kept. If you use the browser extension, reload it on the browser's extensions page, because the copy inside the app has changed.

## Safari, Brave, Chrome, Firefox, Opera or Edge

The extension is optional. It adds [website exceptions](EXCEPTIONS.md#website-exceptions). It ships inside the app, so there is nothing else to download.

1. In Less Pull, open **Settings… → Websites** and choose **Install Browser Extension…**. A window lists the supported browsers installed on your Mac, your default browser first; click **Set up…** next to one. Less Pull sets up its local connection, opens the browser's extensions page and shows the steps to finish. Browsers not on your Mac sit behind **Show uninstalled browsers**, with a globe and a grayed Set up…; the list notices a newly installed browser by itself, and the circular arrow next to the toggle checks again at once. The first time, a notice says what the extension can see; tick "Don’t show this again" if you do not want it next time. The window stays open, so a second browser can follow; close it when you are done.
2. The browser opens the extension's page in the [Chrome Web Store](https://chromewebstore.google.com/detail/lfcjadlpflfdgbgpcbkmdkmnboaakimb). Click **Add to Chrome**, then **Add extension**. Brave, Edge and Opera install from the same page; Edge asks once to allow extensions from other stores, Opera may first offer its helper for the Chrome Web Store.
3. Less Pull sets up the local connection by itself.
4. Open a website, then click the Less Pull icon in the **menu bar**: the menu now offers **Exception for [that site]**. The extension itself shows nothing in the browser.

Firefox is in review at Mozilla’s add-on site. Until that is done the steps differ: on the **about:debugging** page that opens, click **Load Temporary Add-on…** and select `manifest.json` in the **Browser Extension (Firefox)** folder. Firefox removes temporary add-ons when it quits, so load it again next time, or use Firefox Developer Edition with signing turned off.

In Safari the extension comes as a small companion app inside Less Pull. Choosing **Safari** opens it; click **Open Safari Settings** there. Then turn on **Less Pull** under Settings → Extensions and allow it on all websites. The extension shows nothing in Safari itself; website exceptions are set from the Less Pull menu.

Opera and Edge take the same steps as Chrome on their own extensions pages. Several browsers can use the extension at the same time; whichever browser window is in front decides.

Keep the Mac app running, and keep it in the place it was installed. If you move the app, run **Install Browser Extension…** again.

## What to expect from this build

- **Apple silicon only.**
- **macOS 13 or later** is the build target. Only macOS 27 has been tested.
- **Signed with a Developer ID and notarized by Apple** since 9 October 2026 (Team ID CT4CF9Z423).
- **The extension is in the Chrome Web Store** (published 9 October 2026); the Firefox add-on is in review. It asks for access to tab addresses and for a connection to the local app.
- **Brave, Firefox, Safari and Opera are confirmed working** on the author's Mac. Chrome and Edge are implemented but have not been through a clean install test; the Safari companion app is included only in builds made with Xcode.
- **Updates are checked, not installed.** Once a day the app asks GitHub whether a newer build exists and shows a dot on its icon if one is made for your macOS. Installing is still by hand, until the app is signed and notarized.
- Less Pull uses private macOS display interfaces. A macOS update can change how they behave.

The [release plan](RELEASE-PLAN.md) lists what is still open.

## Troubleshooting

**The screen looks different from what the settings say.** Open **Settings… → About → Diagnostics…**. Check whether global and effective Grayscale differ, whether an exception is active, and the display recovery counters. A successful request does not prove what every display shows. Build 15 added recovery after late display resets. The cause of the incident that prompted it has not been confirmed.

**The extension says it cannot connect.** Make sure Less Pull is running, then run **Install Browser Extension…** again from Settings → Websites.

**The arrow pointer stays in color on one display.** That display draws the small arrow in hardware, on top of the picture, so no color filter reaches it. Make the pointer one notch larger under System Settings → Accessibility → Display → Pointer size; it is then drawn into the picture and turns quiet. Settings → General → Displays has a button that opens that pane.

**You only want color for a moment.** Choose **Pause Less Pull** in the menu, or hold the **Peek in color** shortcut from Settings → Shortcuts.

**A website rule does not apply.** Check that the tab is not private, that the browser window is in front, and that the rule's scope matches the address.

**You want to remove Less Pull.** Quit it from the menu first, so it removes the warmth it added. Deleting the app does not delete its preferences.
