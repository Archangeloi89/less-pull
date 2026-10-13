# About the pictures

| File | What it is |
| :-- | :-- |
| `interfaces.png` | Two real screenshots of Less Pull 1.4.4 build 41.2, the menu under its icon and the Settings window on General, placed side by side on a drawn backdrop |
| `exceptions.png` | Real screenshots of build 41.2: the menu, and the exception panel that Exception for Finder… opens under the icon, on a drawn backdrop |
| `settings-tabs.png` | Five window captures of build 41.2 (Shortcuts, Sessions, Apps, Websites, About) with example rules, on a drawn backdrop |
| `before-after.webp` | The same drawn web page as it is and as Less Pull shows it, the seam gliding left and right in a loop, for the project page (`src/social-preview.py --parts`, then `src/before-after-sweep.py`) |
| `before-after.png` | The still version with captions (`src/social-preview.py --plain`), kept for places that cannot play an animation |
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
| `nightshift-*.svg` | Timeline of one night: Night Shift on Automatic, Extra Warmth with Warmer at night |
| `tour-*.svg` | The tour on your own screen: the guide by the menu-bar circle and the tour bar with its seven stops |
| `support-button.svg` | The README's Support my work button in the website's colors, one version for both themes (`src/support-button.mjs`) |

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
# Since build 41.2 the three screenshot figures come from window captures of a test copy started with --screenshot
# (English, example settings and rules; see Source/TESTING.txt) and are put together by compose-screens.swift:
swiftc -O compose-screens.swift -o /tmp/compose-screens && /tmp/compose-screens <captures folder> ..   # menu, panel, general, shortcuts, sessions, apps, websites, about (.png)
python3 menu-figures.py raw ../interfaces.png interfaces   # the earlier way: menu + General tab (needs Pillow and NumPy)
python3 menu-figures.py raw ../exceptions.png exceptions   # the two exception submenus
python3 settings-figure.py raw ../settings-tabs.png shortcuts.jpg apps.jpg websites.jpg about.jpg
python3 social-preview.py ../social-preview.png          # the link-preview card
python3 social-preview.py ../before-after.png --plain    # the same screen with captions
python3 social-preview.py /tmp/screen --parts && python3 before-after-sweep.py /tmp/screen ../before-after.webp   # the moving seam
python3 social-preview.py ../peek.png --peek             # Peek in color, three frames
python3 privacy-figure.py ../privacy.png                 # where a website address goes
python3 sessions-figure.py ../sessions.png               # a session in the menu bar
python3 social-preview.py ../screenshots.png --shots     # display vs screenshot
```

Text in the SVG files is converted to outlines, because GitHub shows README images without web fonts. The typefaces are Schibsted Grotesk and IBM Plex Mono, both under the SIL Open Font License.
