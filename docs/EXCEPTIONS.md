# App and website exceptions

Less Pull has one set of global settings: Grayscale, Extra Warmth and Night Shift. An exception gives one app, one website or one page different settings. Whatever is in front decides what the screen shows.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/cascade-dark.svg">
    <img src="assets/cascade-light.svg" width="100%" alt="How a website tab resolves its settings. Grayscale, Extra Warmth and Night Shift each inherit separately through four levels: Global, App, Domain and Exact URL. In this example the domain example.com turns Grayscale off, the exact URL example.com/reading sets Warmth to 70 percent, and Night Shift stays on from the global setting. The tab shows in color, at 70 percent warmth, with Night Shift on.">
  </picture>
</p>

<sub>Example values, not presets.</sub>

## How a rule is chosen

There are four levels, from broad to narrow:

1. **Global.** Your defaults, set in the menu or the settings window.
2. **App.** A rule for one app. A browser counts as an app here.
3. **Domain.** A rule for a website. It also covers the site's subdomains. If rules exist for both a domain and one of its subdomains, the more specific one wins.
4. **Exact URL.** A rule for one page.

Each of the three settings is resolved on its own. For each one, Less Pull uses the narrowest level that sets a value and skips the levels that inherit. So a rule can change only warmth and leave Grayscale and Night Shift to follow whatever is above it.

Apps other than Brave and Chrome use only the first two levels.

## App exceptions

There are two ways in:

- Click the Less Pull icon in the menu bar and choose **Customize [current app]…**. The menu names the app you were just using, and the rule for that app opens.
- Choose **App Exceptions…** in the menu or in the settings window, then **Add app…**.

For each app you can set:

| Control | Choices |
| :-- | :-- |
| Grayscale | Use global setting, On, Off |
| Night Shift | Use global setting, On, Off |
| Use global warmth | Checked to inherit. Uncheck it to give the app its own Extra Warmth, from Off to Red |

**Remove** deletes the rule, and the app goes back to your global settings.

Things to know:

- The rule applies while the app is frontmost and has a visible window that is not minimized.
- It changes all your displays, not only that app's window.
- Your global settings are kept. They return when you switch to an app without a rule.
- If you have turned Night Shift off for a set time, that pause wins over an app rule that says Night Shift: On.
- With Grayscale off, an app's own warmth still mutes colors as it rises. Color with warmth is not calibrated color.

## Website exceptions

Website rules need the browser extension for Brave or Chrome. See [Install](INSTALL.md#brave-or-chrome). The Mac app has to be running.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/website-popup-dark.png">
    <img src="assets/website-popup-light.png" width="620" alt="The Less Pull Website Exceptions popup open from a browser toolbar on example.com/reading. Apply to is set to This exact URL. Grayscale and Night Shift are set to Use inherited setting. Extra Warmth is 70 percent. Buttons read Save exception and Remove.">
  </picture>
</p>

<sub>The popup is the shipped extension code, rendered with example data. The browser window around it is a drawing, and menus and sliders look a little different in Brave and Chrome on a Mac.</sub>

1. Open the website and click the Less Pull icon in the browser toolbar. The popup shows the site you are on.
2. Under **Apply to**, choose **Whole domain** or **This exact URL**.
3. Set Grayscale and Night Shift to **On**, **Off** or **Use inherited setting**. Uncheck **Use inherited warmth** to give the site its own Extra Warmth.
4. Click **Save exception**.

To change or delete a rule later, pick it from the **Website Exceptions** list in the popup. **Remove** deletes it.

Things to know:

- The rule applies while that tab is the active tab of the browser window in front. It changes all your displays. Nothing is added to the web page.
- A domain rule covers subdomains. `example.com` also covers `www.example.com`.
- An exact URL rule matches the whole address, including its path and query string. The part after `#` is ignored.
- An exact URL inherits from its domain, a domain inherits from the browser's app rule, and that inherits from your global settings.
- Private tabs are excluded. The extension does not report them, so they use the browser's app rule or your global settings.
- Avoid saving exact URLs that contain tokens or other secrets. Saved rules are stored on your Mac. See [Privacy](PRIVACY.md).

Browser support in 1.4.4: Brave is confirmed working. Chrome is implemented, but a clean installation has not been fully tested. Safari, Firefox, Edge and Opera are not supported.

## Examples

These are ideas, not built-in presets.

| You want | Rule |
| :-- | :-- |
| A photo editor in color while everything else is gray | App rule: Grayscale Off |
| A video site in color, only when its tab is in front | Domain rule: Grayscale Off |
| A long-read page warmer than the rest of the site | Exact URL rule: uncheck Use inherited warmth, set Extra Warmth |
| A design tool that should never get Night Shift | App rule: Night Shift Off |

## Switching

When you move between apps or tabs, the screen fades to the new look over half a second. If **Reduce motion** is on in macOS, it changes at once.
