# About the pictures

| File | What it is |
| :-- | :-- |
| `interfaces.png` | Two real screenshots of Less Pull 1.4.4 build 16, the menu-bar dropdown with its icon and the Settings window, cropped and placed side by side on a drawn backdrop |
| `settings-tabs.png` | Four window captures of build 16 (Shortcuts, Apps, Websites, About) with example rules, placed on a drawn backdrop by `src/settings-figure.py` |
| `src/raw/*` | The original captures, untouched |
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
python3 stage.py raw ..   # places the menu and the General tab on one backdrop (needs Pillow and NumPy)
python3 settings-figure.py raw ../settings-tabs.png shortcuts.jpg apps.jpg websites.jpg about.jpg
```

Text in the SVG files is converted to outlines, because GitHub shows README images without web fonts. The typefaces are Schibsted Grotesk and IBM Plex Mono, both under the SIL Open Font License.
