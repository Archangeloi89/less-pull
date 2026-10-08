# Install

Version 1.4.4 (build 16) is a test build. Read [what to expect](#what-to-expect-from-this-build) before you install. The version number stays 1.4.4 on purpose; the build number is what changes.

## The Mac app

1. Download **Less.Pull.1.4.4.zip** from the [build 16 release](https://github.com/Archangeloi89/less-pull/releases/tag/v1.4.4-16).
2. Unzip it and move **Less Pull.app** to **Applications**.
3. Open it. A half-filled circle appears in the menu bar, and on the first launch the Settings window opens with a short welcome.
4. Click the circle and choose Grayscale and Extra Warmth. Turn on **Extra Warmth follows Night Shift** if you want warmth only at night. The icon fills on the left while grayscale is showing and warms on the right as you add warmth.

If macOS says the app cannot be opened, that is Gatekeeper reacting to a build that is not notarized. Only allow a copy you trust, using the normal macOS security settings.

To start Less Pull when you sign in, open **Settings…** and check **Launch at login**. The app needs to be in Applications first.

If you are updating from an earlier build: quit Less Pull, replace the app in Applications, and open it again. Your settings and exceptions are kept. If you use the browser extension, reload it on the browser's extensions page, because the copy inside the app has changed.

## Brave, Chrome or Firefox

The extension is optional. It adds [website exceptions](EXCEPTIONS.md#website-exceptions). It ships inside the app, so there is nothing else to download.

1. In Less Pull, open **Settings… → Websites**, choose **Install Browser Extension…**, and pick your browser. Less Pull sets up its local connection, opens the browser's extensions page, and shows the extension folder in Finder.
2. On the Extensions page, turn on **Developer mode**.
3. Click **Load unpacked** and select the **Browser Extension** folder shown in Finder. You can also press <kbd>⌘</kbd><kbd>⇧</kbd><kbd>G</kbd> in the file picker and enter `/Applications/Less Pull.app/Contents/Resources/Browser Extension`.
4. Pin Less Pull to the browser toolbar.
5. Open a website and click the Less Pull icon. The popup already shows the site you are on.

In Firefox the steps differ: on the **about:debugging** page that opens, click **Load Temporary Add-on…** and select `manifest.json` in the **Browser Extension (Firefox)** folder. Firefox removes temporary add-ons when it quits, so load it again next time, or use Firefox Developer Edition with signing turned off.

Keep the Mac app running, and keep it in the place it was installed. If you move the app, run **Install Browser Extension…** again.

## What to expect from this build

- **Apple silicon only.**
- **macOS 13 or later** is the build target. Only macOS 27 has been tested.
- **Ad-hoc signed, not notarized.** Developer ID signing and notarization are planned.
- **The extension is loaded by hand.** It is not in the Chrome Web Store yet. It asks for access to tab addresses and for a connection to the local app.
- **Brave is confirmed working.** Chrome and Firefox are implemented but have not been through a clean install test. Safari, Edge and Opera are not supported.
- **Updates are checked, not installed.** Once a day the app asks GitHub whether a newer build exists and shows a dot on its icon if one is made for your macOS. Installing is still by hand, until the app is signed and notarized.
- Less Pull uses private macOS display interfaces. A macOS update can change how they behave.

The [release plan](RELEASE-PLAN.md) lists what is still open.

## Troubleshooting

**The screen looks different from what the settings say.** Open **Settings… → About → Diagnostics…**. Check whether global and effective Grayscale differ, whether an exception is active, and the display recovery counters. A successful request does not prove what every display shows. Build 15 added recovery after late display resets. The cause of the incident that prompted it has not been confirmed.

**The extension says it cannot connect.** Make sure Less Pull is running, then run **Install Browser Extension…** again from Settings → Websites.

**You only want color for a moment.** Choose **Pause Less Pull** in the menu, or hold the **Peek in color** shortcut from Settings → General.

**A website rule does not apply.** Check that the tab is not private, that the browser window is in front, and that the rule's scope matches the address.

**You want to remove Less Pull.** Quit it from the menu first, so it removes the warmth it added. Deleting the app does not delete its preferences.
