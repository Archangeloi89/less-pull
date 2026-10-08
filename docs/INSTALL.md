# Install

Version 1.4.4 (build 15) is a test build. Read [what to expect](#what-to-expect-from-this-build) before you install.

## The Mac app

1. Download **Less.Pull.1.4.4.zip** from the [1.4.4 release](https://github.com/Archangeloi89/less-pull/releases/tag/v1.4.4).
2. Unzip it and move **Less Pull.app** to **Applications**.
3. Open it. A half-filled circle appears in the menu bar.
4. Click the circle and choose Grayscale and Extra Warmth. Turn on **Extra Warmth follows Night Shift** if you want warmth only at night.

If macOS says the app cannot be opened, that is Gatekeeper reacting to a build that is not notarized. Only allow a copy you trust, using the normal macOS security settings.

To start Less Pull when you sign in, open **Settings…** and check **Launch at login**. The app needs to be in Applications first.

## Brave or Chrome

The extension is optional. It adds [website exceptions](EXCEPTIONS.md#website-exceptions). It ships inside the app, so there is nothing else to download.

1. In Less Pull, choose **Install Browser Extension…** from the menu or the settings window, and pick your browser. Less Pull sets up its local connection, opens the browser's Extensions page, and shows the extension folder in Finder.
2. On the Extensions page, turn on **Developer mode**.
3. Click **Load unpacked** and select the **Browser Extension** folder shown in Finder. You can also press <kbd>⌘</kbd><kbd>⇧</kbd><kbd>G</kbd> in the file picker and enter `/Applications/Less Pull.app/Contents/Resources/Browser Extension`.
4. Pin Less Pull to the browser toolbar.
5. Open a website, click the Less Pull icon, and choose **Customize current website**.

Keep the Mac app running, and keep it in the place it was installed. If you move the app, run **Install Browser Extension…** again.

## What to expect from this build

- **Apple silicon only.**
- **macOS 13 or later** is the build target. Only macOS 27 has been tested.
- **Ad-hoc signed, not notarized.** Developer ID signing and notarization are planned.
- **The extension is loaded by hand.** It is not in the Chrome Web Store yet. It asks for access to tab addresses and for a connection to the local app.
- **Brave is confirmed working.** Chrome is implemented but has not been through a clean install test. Safari, Firefox, Edge and Opera are not supported.
- Less Pull uses private macOS display interfaces. A macOS update can change how they behave.

The [release plan](RELEASE-PLAN.md) lists what is still open.

## Troubleshooting

**The screen looks different from what the settings say.** Open **Help → Diagnostics**. Check whether global and effective Grayscale differ, whether an exception is active, and the display recovery counters. A successful request does not prove what every display shows. Build 15 adds recovery after late display resets. The cause of the incident that prompted it has not been confirmed.

**The extension says it cannot connect.** Make sure Less Pull is running, then run **Install Browser Extension…** again.

**A website rule does not apply.** Check that the tab is not private, that the browser window is in front, and that the rule's scope matches the address.

**You want to remove Less Pull.** Quit it from the menu first, so it removes the warmth it added. Deleting the app does not delete its preferences.
