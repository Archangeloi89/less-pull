# About the pictures

| File | What it is |
| :-- | :-- |
| `interfaces.png` | Two real screenshots of Less Pull 1.4.4 build 16, the menu-bar dropdown with its icon and the Settings window, cropped and placed side by side on a drawn backdrop |
| `src/raw/*.png` | The two original captures, untouched |
| `website-popup-light.png`, `website-popup-dark.png` | The shipped extension popup (`Browser Extension/popup.html`) rendered in Chromium with example data. The browser window around it is drawn. It is not a screenshot taken inside Brave or Chrome |
| `hero-*.svg` | Animated illustration of one display changing with the app in front. It respects Reduce Motion |
| `warmth-*.svg` | Illustration of Extra Warmth from Off to Red, in color and grayscale |
| `examples-*.svg` | Three example rules: what is in front, what you set, and what the screen shows |
| `levels-*.svg` | Three example levels, from your defaults to one website to one page, showing what each one sets and what it keeps |
| `nightshift-*.svg` | Timeline of warmth following Night Shift |

Each illustration comes in a light and a dark version. GitHub picks one to match the reader's theme.

## Accuracy

The colors in the illustrations are calculated with a JavaScript port of `Source/WarmthCurve.h`, the same curve and matrix the app uses. They are still drawings. They are not photographs or measurements of a display, and a real screen will look somewhat different.

The app names, websites, schedule and percentages shown are examples. Less Pull has no presets.

## Rebuilding

The sources are in [`src`](src). They need Node.js, and Playwright with Chromium for the popup render.

```sh
cd docs/assets/src
npm install
node build.mjs        # writes the SVG files
node popshot.mjs      # renders the popup images
python3 stage.py raw ..   # places the two screenshots on one backdrop (needs Pillow and NumPy)
```

Text in the SVG files is converted to outlines, because GitHub shows README images without web fonts. The typefaces are Schibsted Grotesk and IBM Plex Mono, both under the SIL Open Font License.
