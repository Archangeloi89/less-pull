# Chrome Web Store promo tiles (small 440×280, large 1400×560): the mark, the name, one line. No alpha.
import sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np
out = sys.argv[1]
def font(size, bold=False):
    for path in ['/System/Library/Fonts/HelveticaNeue.ttc', '/System/Library/Fonts/Helvetica.ttc']:
        try: return ImageFont.truetype(path, size, index=1 if bold else 0)
        except Exception: pass
    return ImageFont.load_default()
def tile(W, H, name):
    g = np.linspace(0, 1, H)[:, None]; top, bot = np.array([44, 46, 52]), np.array([24, 25, 29])
    im = Image.fromarray((top * (1 - g) + bot * g)[:, None, :].repeat(W, 1).reshape(H, W, 3).astype('uint8'), 'RGB'); d = ImageDraw.Draw(im)
    r = int(H * 0.22); cx, cy = int(W * 0.24), H // 2
    d.ellipse((cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6), fill=(36, 37, 42))
    d.pieslice((cx - r, cy - r, cx + r, cy + r), 90, 270, fill=(245, 245, 247)); d.pieslice((cx - r, cy - r, cx + r, cy + r), 270, 450, fill=(236, 140, 72)); d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(245, 245, 247), width=max(3, H // 90))
    x = cx + r + int(H * 0.12); big = font(int(H * 0.2), True); small = font(int(H * 0.085))
    d.text((x, cy - int(H * 0.22)), 'Less Pull', font=big, fill=(248, 248, 250)); d.text((x, cy + int(H * 0.04)), 'A quieter screen.', font=small, fill=(190, 192, 198))
    d.text((x, cy + int(H * 0.17)), 'Grayscale and warmth for your Mac. Free.', font=font(int(H * 0.062)), fill=(140, 143, 150))
    im.save(f'{out}/{name}', optimize=True); print(name, im.size)
tile(440, 280, 'promo-small-440x280.png'); tile(1400, 560, 'promo-large-1400x560.png')
