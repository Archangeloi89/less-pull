# Social preview: one screen, left in color, right as Less Pull shows it (grayscale with
# some warmth), computed with the same matrix as Source/WarmthCurve.h. Drawn, not a photo.
# --plain draws the same screen with captions for the project page; --peek draws three
# frames of it (quiet, in color while the Peek shortcut is held, quiet again).
import math, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
out = sys.argv[1]; plain = '--plain' in sys.argv; peek = '--peek' in sys.argv; shots = '--shots' in sys.argv
W, H = (1280, 480) if shots else (1280, 370) if peek else (1280, 520) if plain else (1280, 640)
def font(size, bold=False):
    for path in ['/System/Library/Fonts/HelveticaNeue.ttc', '/System/Library/Fonts/Helvetica.ttc']:
        try: return ImageFont.truetype(path, size, index=1 if bold else 0)
        except Exception: pass
    return ImageFont.load_default()
def gains(s):
    s = max(0, min(3, s))
    if s <= 1: return [1, 1 - .45 * s, 1 - .88 * s]
    if s <= 2: return [1, .55 * (.20 / .55) ** (s - 1), .12 * (.005 / .12) ** (s - 1)]
    r = 3 - s; return [1, .20 * r ** (-math.log(.20 / .55)), .005 * r ** (-math.log(.005 / .12))]
def matrix(s, gray=True):
    g = gains(s); luma = [.30, .59, .11]; mix = 1 if gray else s / 3
    return np.array([[((1 - mix) * (1 if r == c else 0) + mix * luma[c]) * g[r] for c in range(3)] for r in range(3)])
# a vivid "screen": wallpaper gradient plus app-like cards
sw, sh = 1120, 380
y, x = np.mgrid[0:sh, 0:sw]
wall = np.stack([120 + 110 * np.sin(x / 260 + 1.2), 80 + 120 * np.cos(y / 180 + .4), 150 + 100 * np.sin((x + y) / 320)], -1).clip(0, 255).astype('uint8')
screen = Image.fromarray(wall, 'RGB').convert('RGBA')
d = ImageDraw.Draw(screen)
# A busy screen, the same on both halves: a feed with pictures, headlines, badges and
# buttons on a loud wallpaper. Only Less Pull's effect differs across the seam.
import random
rnd = random.Random(7)
def photo(x0, y0, x1, y1, a, b):
    w, h = x1 - x0, y1 - y0; yy, xx = np.mgrid[0:h, 0:w]
    t = (xx / max(w, 1) * .6 + yy / max(h, 1) * .4)[..., None]
    img = (np.array(a) * (1 - t) + np.array(b) * t).astype('uint8'); tile = Image.fromarray(img, 'RGB')
    m = Image.new('L', (w, h), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), 10, fill=255); screen.paste(tile, (x0, y0), m)
    dd = ImageDraw.Draw(screen); dd.ellipse((x0 + w * .62, y0 + h * .18, x0 + w * .82, y0 + h * .18 + w * .2), fill=(255, 240, 150))
def lines(x0, y0, w, n, bold=False):
    for k in range(n):
        d.rounded_rectangle((x0, y0 + k * 16, x0 + w * (1 - .18 * (k % 3)), y0 + 9 + k * 16), 4, fill=(40, 42, 48) if bold else (120, 124, 134))
def badge(x, y, n):
    d.ellipse((x - 14, y - 14, x + 14, y + 14), fill=(255, 59, 48)); d.text((x - 7 if n > 9 else x - 4, y - 9), str(n), font=font(15, True), fill=(255, 255, 255))
def button(x0, y0, x1, y1, col, t):
    d.rounded_rectangle((x0, y0, x1, y1), 10, fill=col); d.text((x0 + 12, y0 + 5), t, font=font(15, True), fill=(255, 255, 255))
d.rounded_rectangle((20, 18, 1100, 366), 18, fill=(248, 248, 250))                      # browser window
d.rectangle((20, 36, 1100, 70), fill=(232, 234, 238)); d.rounded_rectangle((20, 18, 1100, 70), 18, fill=(232, 234, 238))
for k, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]): d.ellipse((36 + k * 22, 36, 52 + k * 22, 52), fill=c)
d.rounded_rectangle((120, 32, 760, 58), 8, fill=(255, 255, 255)); d.text((132, 36), 'news.example/feed', font=font(16), fill=(90, 94, 104))
for k in range(5): d.rounded_rectangle((790 + k * 60, 33, 838 + k * 60, 57), 6, fill=[(66, 133, 244), (234, 67, 53), (251, 188, 5), (52, 168, 83), (155, 81, 224)][k])
badge(1086, 45, 12); badge(846, 57, 3); badge(1030, 57, 99)
d.rectangle((20, 70, 190, 366), fill=(240, 241, 245))                                     # sidebar
for k in range(7):
    d.rounded_rectangle((40, 92 + k * 38, 64, 116 + k * 38), 6, fill=[(66, 133, 244), (234, 67, 53), (251, 188, 5), (52, 168, 83), (155, 81, 224), (255, 120, 40), (0, 180, 200)][k])
    d.rounded_rectangle((76, 98 + k * 38, 160 - (k % 3) * 18, 110 + k * 38), 4, fill=(110, 114, 124))
badge(170, 104, 7); badge(170, 218, 2)
cols = [((255, 90, 60), (255, 200, 40)), ((40, 130, 255), (120, 240, 255)), ((60, 200, 90), (230, 255, 120)), ((200, 60, 255), (255, 120, 200)), ((255, 150, 40), (255, 60, 120)), ((20, 200, 220), (90, 60, 255))]
for k in range(6):                                                                         # feed cards
    cx0 = 210 + (k % 3) * 296; cy0 = 84 + (k // 3) * 142; a, b = cols[k]
    d.rounded_rectangle((cx0, cy0, cx0 + 276, cy0 + 128), 12, fill=(255, 255, 255)); d.rounded_rectangle((cx0, cy0, cx0 + 276, cy0 + 128), 12, outline=(222, 224, 230))
    photo(cx0 + 10, cy0 + 10, cx0 + 110, cy0 + 118, a, b)
    lines(cx0 + 122, cy0 + 14, 140, 1, bold=True); lines(cx0 + 122, cy0 + 36, 140, 3)
    button(cx0 + 122, cy0 + 92, cx0 + 196, cy0 + 116, [(255, 59, 48), (0, 122, 255), (255, 149, 0), (52, 199, 89), (175, 82, 222), (255, 45, 85)][k], ['LIVE', 'NEW', 'SALE', 'JOIN', 'PLAY', 'HOT'][k])
    hx, hy = cx0 + 208, cy0 + 100; d.ellipse((hx, hy, hx + 9, hy + 9), fill=(255, 59, 48)); d.ellipse((hx + 7, hy, hx + 16, hy + 9), fill=(255, 59, 48)); d.polygon([(hx, hy + 5), (hx + 16, hy + 5), (hx + 8, hy + 15)], fill=(255, 59, 48))
    d.text((cx0 + 230, cy0 + 96), '%d' % rnd.randint(120, 980), font=font(15, True), fill=(255, 59, 48))
arr = np.asarray(screen.convert('RGB')).astype(float)
quiet = Image.fromarray((arr @ matrix(0.35, True).T).clip(0, 255).astype('uint8'), 'RGB')  # the whole screen as Less Pull shows it
color = screen.convert('RGB')
right = arr[:, sw // 2:] @ matrix(0.35, True).T  # grayscale with a light amber, an everyday setting
arr[:, sw // 2:] = right.clip(0, 255)
screen = Image.fromarray(arr.astype('uint8'), 'RGB')
# backdrop, headline, screen with rounded corners and a shadow
g = np.linspace(0, 1, H)[:, None]; top, bot = np.array([44, 46, 52]), np.array([24, 25, 29])
im = Image.fromarray((top * (1 - g) + bot * g)[:, None, :].repeat(W, 1).reshape(H, W, 3).astype('uint8'), 'RGB').convert('RGBA')
d = ImageDraw.Draw(im)
def place(src, x, y, w, h, radius=14):
    global im
    m = Image.new('L', (w, h), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
    sh_ = Image.new('RGBA', im.size, (0, 0, 0, 0)); ImageDraw.Draw(sh_).rounded_rectangle((x, y + 10, x + w, y + h + 10), radius, fill=(0, 0, 0, 160)); im = Image.alpha_composite(im, sh_.filter(ImageFilter.GaussianBlur(16)))
    im.paste(src.resize((w, h), Image.LANCZOS), (x, y), m)
if shots:
    # left: the display, as Less Pull shows it; right: the screenshot taken of it, in full color
    fw, fh = 540, int(540 * sh / sw); y0 = 118; xl, xr = 60, W - 60 - fw
    d.text((60, 34), 'What you see', font=font(28, True), fill=INK if False else (248, 248, 250)); d.text((60, 72), 'the display, quiet', font=font(20), fill=(150, 153, 160))
    d.text((xr, 34), 'What you share', font=font(28, True), fill=(248, 248, 250)); d.text((xr, 72), 'the screenshot of that same screen', font=font(20), fill=(150, 153, 160))
    # a monitor: bezel and stand
    d.rounded_rectangle((xl - 14, y0 - 14, xl + fw + 14, y0 + fh + 14), 22, fill=(30, 31, 36), outline=(70, 72, 80), width=2); place(quiet, xl, y0, fw, fh, radius=10)
    d = ImageDraw.Draw(im); d.rounded_rectangle((xl + fw // 2 - 50, y0 + fh + 14, xl + fw // 2 + 50, y0 + fh + 40), 6, fill=(60, 62, 70)); d.rounded_rectangle((xl + fw // 2 - 110, y0 + fh + 38, xl + fw // 2 + 110, y0 + fh + 48), 5, fill=(60, 62, 70))
    # a screenshot file: white border, slight tilt-free, with the camera mark
    d.rounded_rectangle((xr - 10, y0 - 10, xr + fw + 10, y0 + fh + 10), 12, fill=(245, 245, 247)); place(color, xr, y0, fw, fh, radius=6)
    d = ImageDraw.Draw(im); cx, cy = xr + fw - 26, y0 + fh - 26; d.ellipse((cx - 26, cy - 26, cx + 26, cy + 26), fill=(236, 140, 72)); d.rounded_rectangle((cx - 13, cy - 7, cx + 13, cy + 10), 4, fill=(30, 20, 12)); d.ellipse((cx - 6, cy - 4, cx + 6, cy + 8), fill=(236, 140, 72)); d.rectangle((cx - 5, cy - 11, cx + 2, cy - 7), fill=(30, 20, 12))
    cap = font(20); d.text((xl, y0 + fh + 62), 'Less Pull changes the display itself, after the picture is made.', font=cap, fill=(190, 192, 198)); d.text((xl, y0 + fh + 90), 'Screenshots, recordings and screen sharing keep their normal colors.', font=cap, fill=(190, 192, 198))
    im.convert('RGB').save(out, optimize=True); print(out, im.size); sys.exit()
if peek:
    fw, fh = 392, int(392 * sh / sw); gap = 32; x0 = (W - 3 * fw - 2 * gap) // 2; y0 = 128
    frames = [(quiet, 'Your screen, as usual'), (color, 'Color while you hold the Peek shortcut'), (quiet, 'Let go, and it is quiet again')]
    for k, (src, cap) in enumerate(frames):
        x = x0 + k * (fw + gap); place(src, x, y0, fw, fh); d = ImageDraw.Draw(im)
        f = font(22); words = cap.split(' '); line, lines_ = '', []
        for wd in words:
            if d.textlength((line + ' ' + wd).strip(), font=f) > fw - 8: lines_.append(line); line = wd
            else: line = (line + ' ' + wd).strip()
        lines_.append(line)
        for j, ln in enumerate(lines_): d.text((x + (fw - d.textlength(ln, font=f)) / 2, y0 + fh + 20 + j * 30), ln, font=f, fill=(190, 192, 198) if k == 1 else (150, 153, 160))
    # the key, held, above the middle frame: an example shortcut
    kx, ky = x0 + fw + gap + fw // 2, 60; keys = [('⌥', 44), ('A', 44)]; tw = sum(k[1] for k in keys) + 12; cx0 = kx - tw // 2
    for t, kw in keys:
        d.rounded_rectangle((cx0, ky - 22, cx0 + kw, ky + 22), 9, fill=(236, 140, 72), outline=(255, 200, 160), width=2)
        if t == '⌥':  # the Option glyph, drawn: a slash with a flat top-left and top-right stroke
            ox, oy = cx0 + kw // 2, ky; d.line([(ox - 11, oy - 8), (ox - 4, oy - 8), (ox + 4, oy + 8), (ox + 11, oy + 8)], fill=(30, 20, 12), width=3); d.line([(ox + 4, oy - 8), (ox + 11, oy - 8)], fill=(30, 20, 12), width=3)
        else:
            f = font(24, True); bb = d.textbbox((0, 0), t, font=f); d.text((cx0 + (kw - (bb[2] - bb[0])) / 2 - bb[0], ky - (bb[3] - bb[1]) / 2 - bb[1]), t, font=f, fill=(30, 20, 12))
        cx0 += kw + 12
    d.text((kx + tw // 2 + 18, ky - 13), 'held', font=font(22), fill=(190, 192, 198))
    d.text((x0, ky - 13), 'Peek in color', font=font(26, True), fill=(248, 248, 250))
    d.text((W - x0 - d.textlength('an example shortcut; you choose your own', font=font(20)), ky - 11), 'an example shortcut; you choose your own', font=font(20), fill=(130, 133, 140))
    im.convert('RGB').save(out, optimize=True); print(out, im.size); sys.exit()
if not plain:
    d.text((80, 34), 'A quieter screen.', font=font(96, True), fill=(248, 248, 250))
    d.text((1010, 48), 'Less Pull', font=font(34, True), fill=(170, 172, 178)); d.text((1010, 88), 'for macOS · free', font=font(28), fill=(140, 143, 150))
# The sentences live in the repository description (Open Graph text); the card shows what text cannot.
scale = 1.0; sw2, sh2 = int(sw * scale), int(sh * scale); sx, sy = 80, (56 if plain else 190)
mask = Image.new('L', (sw2, sh2), 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw2 - 1, sh2 - 1), 24, fill=255)
shadow = Image.new('RGBA', im.size, (0, 0, 0, 0)); ImageDraw.Draw(shadow).rounded_rectangle((sx, sy + 18, sx + sw2, sy + sh2 + 18), 24, fill=(0, 0, 0, 170)); shadow = shadow.filter(ImageFilter.GaussianBlur(28)); im = Image.alpha_composite(im, shadow)
im.paste(screen.resize((sw2, sh2), Image.LANCZOS), (sx, sy), mask)
# the seam and the half-circle mark on it
d = ImageDraw.Draw(im); cx = sx + sw2 // 2
d.rectangle((cx - 2, sy, cx + 2, sy + sh2), fill=(250, 250, 250, 235))
r = 54; cy = sy + sh2 // 2
d.ellipse((cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6), fill=(36, 37, 42, 255))
d.pieslice((cx - r, cy - r, cx + r, cy + r), 90, 270, fill=(245, 245, 247, 255))
d.pieslice((cx - r, cy - r, cx + r, cy + r), 270, 450, fill=(236, 140, 72, 255))
d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(245, 245, 247, 255), width=5)
if plain:
    d.text((sx + 24, sy + sh2 + 22), 'The screen as it is', font=font(26), fill=(170, 172, 178)); d.text((cx + 24, sy + sh2 + 22), 'With Less Pull: grayscale and a little warmth', font=font(26), fill=(170, 172, 178))
im.convert('RGB').save(out, optimize=True); print(out, im.size)
