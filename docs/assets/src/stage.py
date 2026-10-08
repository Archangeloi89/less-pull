# Places the two real screenshots side by side on one plain drawn backdrop. Screenshot pixels are not altered,
# only cropped to the window shape.
import sys
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
src, out = sys.argv[1], sys.argv[2]
S = 4
def rmask(w, h, r):
    m = Image.new('L', (w * S, h * S), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, w * S - 1, h * S - 1], r * S, fill=255)
    return m.resize((w, h), Image.LANCZOS)
def stage(w, h):
    g = np.linspace(0, 1, h)[:, None]
    top, bot = np.array([58, 62, 70]), np.array([33, 35, 41])
    arr = (top * (1 - g) + bot * g)[:, None, :].repeat(w, 1).reshape(h, w, 3).astype('uint8')
    im = Image.fromarray(arr, 'RGB').convert('RGBA'); im.putalpha(rmask(w, h, 40)); return im
def shadow(base, x, y, mask, blur=36, dy=22, alpha=150):
    sh = Image.new('L', base.size, 0); sh.paste(mask.point(lambda v: v * alpha // 255), (x, y + dy))
    sh = sh.filter(ImageFilter.GaussianBlur(blur)); black = Image.new('RGBA', base.size, (0, 0, 0, 255)); black.putalpha(sh)
    a = base.getchannel('A'); res = Image.alpha_composite(base, black); res.putalpha(a); return res

# --- crop the menu-bar dropdown and its icon ---
m = Image.open(f'{src}/menu-bar.png').convert('RGB')
menu = m.crop((80, 62, 846, 1024)); mm = rmask(766, 962, 27)
pill = m.crop((87, 6, 171, 54)); pm = rmask(84, 48, 24)
# --- settings window: the capture has white baked in outside the rounded window; recover the shape ---
s = Image.open(f'{src}/settings.png').convert('RGB'); sw, sh_ = s.size
arr = np.asarray(s).astype(int); mn = arr.min(2); spread = arr.max(2) - mn
alpha = np.full((sh_, sw), 255, 'uint8'); R = 50
for (y0, x0) in [(0, 0), (0, sw - R), (sh_ - R, 0), (sh_ - R, sw - R)]:
    blk = mn[y0:y0 + R, x0:x0 + R]; yy, xx = np.mgrid[0:R, 0:R]
    cy, cx = (R if y0 == 0 else 0), (R if x0 == 0 else 0)
    outer = (np.hypot(yy - cy, xx - cx) > R - 9) & (blk > 60) & (spread[y0:y0 + R, x0:x0 + R] < 24)
    alpha[y0:y0 + R, x0:x0 + R] = np.where(outer, np.clip(255 - (blk - 40) * 255 // 215, 0, 255), 255)
wm = Image.fromarray(alpha, 'L')
dark = np.array(arr, 'uint8'); dark[alpha < 250] = [36, 35, 32]
win = Image.fromarray(dark, 'RGB')
# --- one stage: menu bar strip on top, dropdown on the left, settings window on the right ---
PAD, GAP, TOP = 96, 112, 124
W = PAD + 766 + GAP + sw + PAD; H = TOP + sh_ + 96
st = stage(W, H)
bar = Image.new('RGBA', st.size, (0, 0, 0, 0)); bar.paste(Image.new('RGBA', (W, 60), (0, 0, 0, 90)), (0, 0))
a = st.getchannel('A'); st = Image.alpha_composite(st, bar); st.putalpha(a)
dx = PAD - 80
st.paste(pill, (87 + dx, 6), pm)
st = shadow(st, PAD, 62, mm); st.paste(menu, (PAD, 62), mm)
x = PAD + 766 + GAP
st = shadow(st, x, TOP, wm); st.paste(win, (x, TOP), wm)
st.save(f'{out}/interfaces.png', optimize=True)
print(st.size)
