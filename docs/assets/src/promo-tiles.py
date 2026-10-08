# Chrome Web Store promo tiles (small 440×280, large 1400×560): the mark, the name, two lines, the whole group centered. No alpha.
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
    wide = W / H >= 2; k = 1.0 if wide else 0.8
    r = int(H * (0.22 if wide else 0.19)); gap = int(H * 0.1)
    big = font(int(H * 0.2 * k), True); small = font(int(H * 0.085 * k)); tiny = font(int(H * 0.062 * k))
    lines = [('Less Pull', big, (248, 248, 250)), ('A quieter screen.', small, (190, 192, 198)), ('Grayscale and warmth for your Mac. Free.' if wide else 'Grayscale and warmth. Free.', tiny, (140, 143, 150))]
    heights = [d.textbbox((0, 0), t, font=f)[3] for t, f, _ in lines]; spacing = int(H * 0.035)
    text_w = max(d.textlength(t, font=f) for t, f, _ in lines); text_h = sum(heights) + spacing * 2
    group_w = 2 * r + gap + text_w; x0 = (W - group_w) / 2; cy = H / 2
    cx = x0 + r
    d.ellipse((cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6), fill=(36, 37, 42))
    d.pieslice((cx - r, cy - r, cx + r, cy + r), 90, 270, fill=(245, 245, 247)); d.pieslice((cx - r, cy - r, cx + r, cy + r), 270, 450, fill=(236, 140, 72)); d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(245, 245, 247), width=max(3, H // 90))
    x = x0 + 2 * r + gap; y = cy - text_h / 2
    for (t, f, col), h in zip(lines, heights):
        d.text((x, y), t, font=f, fill=col); y += h + spacing
    im.save(f'{out}/{name}', optimize=True); print(name, im.size)
tile(440, 280, 'promo-small-440x280.png'); tile(1400, 560, 'promo-large-1400x560.png')
