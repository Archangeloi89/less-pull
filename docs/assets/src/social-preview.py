# Social preview: one screen, left in color, right as Less Pull shows it (grayscale with
# some warmth), computed with the same matrix as Source/WarmthCurve.h. Drawn, not a photo.
import math, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
out = sys.argv[1]; W, H = 1280, 640
def gains(s):
    s = max(0, min(3, s))
    if s <= 1: return [1, 1 - .45 * s, 1 - .88 * s]
    if s <= 2: return [1, .55 * (.20 / .55) ** (s - 1), .12 * (.005 / .12) ** (s - 1)]
    r = 3 - s; return [1, .20 * r ** (-math.log(.20 / .55)), .005 * r ** (-math.log(.005 / .12))]
def matrix(s, gray=True):
    g = gains(s); luma = [.30, .59, .11]; mix = 1 if gray else s / 3
    return np.array([[((1 - mix) * (1 if r == c else 0) + mix * luma[c]) * g[r] for c in range(3)] for r in range(3)])
# a vivid "screen": wallpaper gradient plus app-like cards
sw, sh = 1120, 460
y, x = np.mgrid[0:sh, 0:sw]
wall = np.stack([120 + 110 * np.sin(x / 260 + 1.2), 80 + 120 * np.cos(y / 180 + .4), 150 + 100 * np.sin((x + y) / 320)], -1).clip(0, 255).astype('uint8')
screen = Image.fromarray(wall, 'RGB').convert('RGBA')
d = ImageDraw.Draw(screen)
cards = [((60, 60, 520, 400), (255, 94, 77)), ((560, 60, 1060, 220), (66, 181, 255)), ((560, 250, 790, 400), (255, 203, 60)), ((820, 250, 1060, 400), (84, 220, 120))]
for (x0, y0, x1, y1), col in cards:
    d.rounded_rectangle((x0, y0, x1, y1), 22, fill=col)
    d.rounded_rectangle((x0 + 24, y0 + 24, x1 - 24, y0 + 44), 8, fill=(255, 255, 255, 230))
    for i in range(3): d.rounded_rectangle((x0 + 24, y0 + 64 + i * 26, x1 - 24 - i * 60, y0 + 78 + i * 26), 6, fill=(255, 255, 255, 150))
arr = np.asarray(screen.convert('RGB')).astype(float)
right = arr[:, sw // 2:] @ matrix(0.5, True).T  # grayscale with a light amber, an everyday setting
arr[:, sw // 2:] = right.clip(0, 255)
screen = Image.fromarray(arr.astype('uint8'), 'RGB')
# backdrop, headline, screen with rounded corners and a shadow
g = np.linspace(0, 1, H)[:, None]; top, bot = np.array([44, 46, 52]), np.array([24, 25, 29])
im = Image.fromarray((top * (1 - g) + bot * g)[:, None, :].repeat(W, 1).reshape(H, W, 3).astype('uint8'), 'RGB').convert('RGBA')
def font(size, bold=False):
    for path in ['/System/Library/Fonts/HelveticaNeue.ttc', '/System/Library/Fonts/Helvetica.ttc']:
        try: return ImageFont.truetype(path, size, index=1 if bold else 0)
        except Exception: pass
    return ImageFont.load_default()
d = ImageDraw.Draw(im)
d.text((80, 46), 'A quieter screen.', font=font(112, True), fill=(248, 248, 250))
d.text((86, 172), 'Less Pull for macOS', font=font(40), fill=(170, 172, 178))
scale = 0.78; sw2, sh2 = int(sw * scale), int(sh * scale); sx, sy = 80, 236
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
im.convert('RGB').save(out, optimize=True); print(out, im.size)
