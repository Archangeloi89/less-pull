# About the pictures

| File | What it is |
| :-- | :-- |
| `interfaces.png` | Two real screenshots of Less Pull 1.4.4 build 16, the menu-bar dropdown with its icon and the Settings window on General, cropped and placed side by side on a drawn backdrop (`src/menu-figures.py`) |
| `exceptions.png` | Two real screenshots of the menu with the Exception for Finder and Exception for mubi.com submenus open, on a drawn backdrop |
| `settings-tabs.png` | Four window captures of build 16 (Shortcuts, Apps, Websites, About) with example rules, placed on a drawn backdrop by `src/settings-figure.py` |
| `before-after.png` | The same drawn web page as it is and as Less Pull shows it, with captions, for the project page (`src/social-preview.py --plain`) |
| `peek.png` | Three frames of the same drawn page: quiet, in color while the Peek shortcut is held, quiet again (`src/social-preview.py --peek`) |
| `screenshots.png` | What you see (the display, quiet) next to what you share (the screenshot, in color), drawn (`src/social-preview.py --shots`) |
| `sessions.png` | A session in the menu bar: the icon through its states and the two panels, drawn (`src/sessions-figure.py`) |
| `privacy.png` | Where a website address goes and where it never goes, drawn (`src/privacy-figure.py`) |
| `social-preview.png` | The card GitHub shows in link previews: a drawn screen, color on the left and Less Pull's grayscale with a light amber on the right, computed with the app's own matrix (`src/social-preview.py`) |
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
python3 menu-figures.py raw ../interfaces.png interfaces   # menu + General tab (needs Pillow and NumPy)
python3 menu-figures.py raw ../exceptions.png exceptions   # the two exception submenus
python3 settings-figure.py raw ../settings-tabs.png shortcuts.jpg apps.jpg websites.jpg about.jpg
python3 social-preview.py ../social-preview.png          # the link-preview card
python3 social-preview.py ../before-after.png --plain    # the same screen with captions
python3 social-preview.py ../peek.png --peek             # Peek in color, three frames
python3 privacy-figure.py ../privacy.png                 # where a website address goes
python3 sessions-figure.py ../sessions.png               # a session in the menu bar
python3 social-preview.py ../screenshots.png --shots     # display vs screenshot
```

Text in the SVG files is converted to outlines, because GitHub shows README images without web fonts. The typefaces are Schibsted Grotesk and IBM Plex Mono, both under the SIL Open Font License.
