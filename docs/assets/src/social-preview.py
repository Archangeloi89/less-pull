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
sw, sh = 1120, 380
y, x = np.mgrid[0:sh, 0:sw]
wall = np.stack([120 + 110 * np.sin(x / 260 + 1.2), 80 + 120 * np.cos(y / 180 + .4), 150 + 100 * np.sin((x + y) / 320)], -1).clip(0, 255).astype('uint8')
screen = Image.fromarray(wall, 'RGB').convert('RGBA')
d = ImageDraw.Draw(screen)
# the same window on each half, so the only difference is what Less Pull does to it
def window(x0, y0, x1, y1):
    d.rounded_rectangle((x0, y0, x1, y1), 22, fill=(255, 255, 255, 235))
    d.rounded_rectangle((x0, y0, x1, y0 + 44), 22, fill=(236, 238, 242, 255)); d.rectangle((x0, y0 + 22, x1, y0 + 44), fill=(236, 238, 242, 255))
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]): d.ellipse((x0 + 18 + i * 22, y0 + 14, x0 + 34 + i * 22, y0 + 30), fill=c)
    tiles = [(255, 94, 77), (66, 181, 255), (255, 203, 60), (84, 220, 120), (170, 100, 255), (255, 140, 60)]
    tw = (x1 - x0 - 24 * 4) // 3
    for i, c in enumerate(tiles):
        tx = x0 + 24 + (i % 3) * (tw + 24); ty = y0 + 68 + (i // 3) * 118
        d.rounded_rectangle((tx, ty, tx + tw, ty + 94), 14, fill=c)
        d.rounded_rectangle((tx + 16, ty + 58, tx + tw - 16, ty + 70), 5, fill=(255, 255, 255, 190))
for (x0, y0, x1, y1) in [(50, 40, 530, 340), (590, 40, 1070, 340)]: window(x0, y0, x1, y1)
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
d.text((80, 34), 'A quieter screen.', font=font(96, True), fill=(248, 248, 250))
d.text((1010, 48), 'Less Pull', font=font(34, True), fill=(170, 172, 178)); d.text((1010, 88), 'for macOS · free', font=font(28), fill=(140, 143, 150))
# The sentences live in the repository description (Open Graph text); the card shows what text cannot.
scale = 1.0; sw2, sh2 = int(sw * scale), int(sh * scale); sx, sy = 80, 190
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
