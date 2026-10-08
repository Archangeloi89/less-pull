# Places the two real screenshots side by side on one plain drawn backdrop. Screenshot pixels are not altered,
# only cropped to the window shape. Captures are 2x (Retina) PNGs taken with the system screenshot tool.
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
# --- the menu-bar dropdown (build 16 capture: menu bar strip on top, dropdown below) ---
m = Image.open(f'{src}/menu-bar.png').convert('RGB')
MENU = (34, 58, 650, 660); menu = m.crop(MENU); mw, mh = menu.size; mm = rmask(mw, mh, 26)
PILL = (34, 2, 124, 50); pill = m.crop(PILL); pm = rmask(PILL[2] - PILL[0], PILL[3] - PILL[1], 24)
# --- the Settings window (General tab) ---
s = Image.open(f'{src}/settings.png').convert('RGB')
WIN = (72, 52, 1068, 1192); win = s.crop(WIN); sw, sh_ = win.size; wm = rmask(sw, sh_, 24)
# --- one stage: menu bar strip on top, dropdown on the left, settings window on the right ---
PAD, GAP, TOP = 96, 112, 124
W = PAD + mw + GAP + sw + PAD; H = TOP + sh_ + 96
st = stage(W, H)
bar = Image.new('RGBA', st.size, (0, 0, 0, 0)); bar.paste(Image.new('RGBA', (W, 60), (0, 0, 0, 90)), (0, 0))
a = st.getchannel('A'); st = Image.alpha_composite(st, bar); st.putalpha(a)
st.paste(pill, (PAD + 2, 6), pm)
st = shadow(st, PAD, 62, mm); st.paste(menu, (PAD, 62), mm)
x = PAD + mw + GAP
st = shadow(st, x, TOP, wm); st.paste(win, (x, TOP), wm)
st.save(f'{out}/interfaces.png', optimize=True)
print(st.size)
