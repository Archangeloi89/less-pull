# Where a website address goes: browser → Less Pull's memory → nowhere else. Drawn, same
# style as the other figures. Usage: privacy-figure.py out.png
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
out = sys.argv[1]; W, H = 1280, 560
def font(size, bold=False):
    for path in ['/System/Library/Fonts/HelveticaNeue.ttc', '/System/Library/Fonts/Helvetica.ttc']:
        try: return ImageFont.truetype(path, size, index=1 if bold else 0)
        except Exception: pass
    return ImageFont.load_default()
g = np.linspace(0, 1, H)[:, None]; top, bot = np.array([44, 46, 52]), np.array([24, 25, 29])
im = Image.fromarray((top * (1 - g) + bot * g)[:, None, :].repeat(W, 1).reshape(H, W, 3).astype('uint8'), 'RGB').convert('RGBA')
ORANGE, INK, DIM, LIGHT, RED = (236, 140, 72), (248, 248, 250), (150, 153, 160), (190, 192, 198), (255, 96, 86)
def card(x, y, w, h, fill=(38, 40, 46), outline=(70, 72, 80)):
    global im
    sh = Image.new('RGBA', im.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).rounded_rectangle((x, y + 8, x + w, y + h + 8), 18, fill=(0, 0, 0, 150)); im = Image.alpha_composite(im, sh.filter(ImageFilter.GaussianBlur(14)))
    ImageDraw.Draw(im).rounded_rectangle((x, y, x + w, y + h), 18, fill=fill, outline=outline, width=2)
def center(d, x, y, t, f, fill):
    d.text((x - d.textlength(t, font=f) / 2, y), t, font=f, fill=fill)
d = ImageDraw.Draw(im)
d.text((40, 30), 'Where a website address goes', font=font(30, True), fill=INK)
d.text((40, 72), 'The extension tells the app which site is in front. That is all it does.', font=font(20), fill=DIM)
# three stations
y0, h = 130, 190; xs = [(40, 330), (450, 480), (1010, 230)]
card(xs[0][0], y0, xs[0][1], h); card(xs[1][0], y0, xs[1][1], h, fill=(46, 40, 36), outline=ORANGE); card(xs[2][0], y0, xs[2][1], h)
d = ImageDraw.Draw(im)
# browser tab
x, w = xs[0]; d.rounded_rectangle((x + 24, y0 + 24, x + w - 24, y0 + 60), 8, fill=(232, 234, 238)); d.text((x + 38, y0 + 32), 'news.example/feed', font=font(18), fill=(60, 64, 72))
d.text((x + 24, y0 + 80), 'Your browser', font=font(22, True), fill=INK)
d.text((x + 24, y0 + 112), 'sends the address of the tab in front.\nPrivate tabs: nothing is sent.', font=font(17), fill=LIGHT, spacing=6)
# app memory
x, w = xs[1]; cx = x + w // 2
r = 22; cy = y0 + 46; d.pieslice((cx - r, cy - r, cx + r, cy + r), 90, 270, fill=(245, 245, 247)); d.pieslice((cx - r, cy - r, cx + r, cy + r), 270, 450, fill=ORANGE); d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(245, 245, 247), width=3)
center(d, cx, y0 + 80, 'Less Pull, in memory only', font(22, True), INK)
center(d, cx, y0 + 112, 'Holds the one address in front. Overwritten by the next.', font(17), LIGHT)
center(d, cx, y0 + 138, 'Gone within a minute of the browser going quiet, or at once', font(17), LIGHT)
center(d, cx, y0 + 160, 'when it disconnects. Never written to disk.', font(17), LIGHT)
# display
x, w = xs[2]; d.rounded_rectangle((x + 60, y0 + 24, x + w - 60, y0 + 64), 6, fill=(200, 170, 140)); d.rectangle((x + w // 2 - 14, y0 + 64, x + w // 2 + 14, y0 + 72), fill=(120, 122, 130))
center(d, x + w // 2, y0 + 80, 'Your screen', font(22, True), INK)
center(d, x + w // 2, y0 + 112, 'takes the look you set', font(17), LIGHT); center(d, x + w // 2, y0 + 136, 'for that site.', font(17), LIGHT)
# arrows
def arrow(x1, x2, y):
    d.line((x1, y, x2 - 14, y), fill=ORANGE, width=4); d.polygon([(x2, y), (x2 - 18, y - 10), (x2 - 18, y + 10)], fill=ORANGE)
arrow(xs[0][0] + xs[0][1] + 14, xs[1][0] - 14, y0 + h // 2); arrow(xs[1][0] + xs[1][1] + 14, xs[2][0] - 14, y0 + h // 2)
# what never happens
yb = 372; d.text((40, yb), 'And where it never goes', font=font(22, True), fill=INK)
items = [('Disk', 'not in preferences,\nnot in logs'), ('Internet', 'no server, no sync,\nno analytics'), ('Page content', 'no reading, no\nchanging, no typing'), ('Account', 'none to create,\nnothing to identify you')]
cw = (W - 80 - 3 * 24) // 4
for k, (t, sub) in enumerate(items):
    x = 40 + k * (cw + 24); y = yb + 42
    card(x, y, cw, 110, fill=(34, 36, 42), outline=(60, 62, 70)); d = ImageDraw.Draw(im)
    cx, cy = x + 40, y + 36; d.ellipse((cx - 18, cy - 18, cx + 18, cy + 18), outline=RED, width=4); d.line((cx - 12, cy - 12, cx + 12, cy + 12), fill=RED, width=4)
    d.text((x + 72, y + 20), t, font=font(21, True), fill=INK); d.text((x + 72, y + 50), sub, font=font(15), fill=DIM, spacing=4)
im.convert('RGB').save(out, optimize=True); print(out, im.size)
