# Install the test build

## Mac app

Download the app ZIP from the 1.4.4 release, unzip, and move Less Pull.app to /Applications. It is currently ad-hoc signed, not Apple-notarized. Downloaded copies may be blocked by Gatekeeper; only allow a copy you trust using macOS's normal security controls. Developer ID signing and notarization are still planned.

The build is for Apple silicon. macOS 13 is the deployment target; macOS 27 is tested. Earlier versions are not yet verified. Launch the app and open Settings from its menu-bar icon. Grayscale stays selected across Night Shift changes. Extra Warmth follows Night Shift controls warmth only.

## Chrome or Brave

1. Open Settings → Install Browser Extension… in Less Pull to register the local browser bridge.
2. Open your browser's Extensions page and enable Developer mode.
3. Choose Load unpacked, then use the file picker's Command–Shift–G shortcut and enter `/Applications/Less Pull.app/Contents/Resources/Browser Extension`.
4. Select that folder and pin Less Pull to the toolbar if desired.
5. Keep the Mac app running. Use Customize current website in the extension to create a domain or exact-URL exception.

The extension requires tab-address access and native messaging to the local app. It has not yet been submitted to the Chrome Web Store. Safari, Firefox, Opera, and Edge are not currently implemented by the bridge.

## Troubleshooting

If appearance changes unexpectedly, open Help → Diagnostics and note whether global and effective grayscale differ, whether an exception is active, and the pipeline recovery counters. A successful matrix request is not proof of the appearance on every display. Build 15 includes recovery after late display resets; the cause of the original reported incident is unconfirmed.
