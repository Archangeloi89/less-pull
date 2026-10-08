# Places window captures of the Settings tabs on one plain backdrop (2 by 2). Captures are
# JPEG window grabs from the app itself; pixels are only cropped to the window shape.
import sys
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
src, out = sys.argv[1], sys.argv[2]
S = 4
def rmask(w, h, r):
    m = Image.new('L', (w * S, h * S), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, w * S - 1, h * S - 1], r * S, fill=255)
    return m.resize((w, h), Image.LANCZOS)
def stage(w, h):
    g = np.linspace(0, 1, h)[:, None]; top, bot = np.array([58, 62, 70]), np.array([33, 35, 41])
    arr = (top * (1 - g) + bot * g)[:, None, :].repeat(w, 1).reshape(h, w, 3).astype('uint8')
    im = Image.fromarray(arr, 'RGB').convert('RGBA'); im.putalpha(rmask(w, h, 40)); return im
def shadow(base, x, y, mask, blur=30, dy=18, alpha=140):
    sh = Image.new('L', base.size, 0); sh.paste(mask.point(lambda v: v * alpha // 255), (x, y + dy))
    sh = sh.filter(ImageFilter.GaussianBlur(blur)); black = Image.new('RGBA', base.size, (0, 0, 0, 255)); black.putalpha(sh)
    a = base.getchannel('A'); res = Image.alpha_composite(base, black); res.putalpha(a); return res
def window(name):
    im = Image.open(f'{src}/{name}').convert('RGB'); im = im.crop((2, 2, im.width - 2, im.height - 2))  # drop the capture's anti-aliased edge
    return im, rmask(im.width, im.height, 26)
names = sys.argv[3:]  # e.g. shortcuts.jpg apps.jpg websites.jpg about.jpg
wins = [window(n) for n in names]
PAD, GAP = 80, 64; cols = 2
colw = max(w.width for w, _ in wins); rows = (len(wins) + cols - 1) // cols
rowh = [max(wins[i][0].height for i in range(r * cols, min(len(wins), (r + 1) * cols))) for r in range(rows)]
W = PAD * 2 + cols * colw + (cols - 1) * GAP; H = PAD * 2 + sum(rowh) + (rows - 1) * GAP
st = stage(W, H); y = PAD
for r in range(rows):
    for c in range(cols):
        i = r * cols + c
        if i >= len(wins): break
        im, m = wins[i]; x = PAD + c * (colw + GAP)
        st = shadow(st, x, y, m); st.paste(im, (x, y), m)
    y += rowh[r] + GAP
st.save(out, optimize=True); print(out, st.size)
