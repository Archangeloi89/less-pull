# Crops the menu captures to their panels and places them on the plain backdrop.
# Panel rectangles were read off the captures (2x PNGs from the system screenshot tool).
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
    sh = sh.filter(ImageFilter.GaussianBlur(blur)); black = Image.new('RGBA', base.size, (0, 0, 0, 255)).copy(); black.putalpha(sh)
    a = base.getchannel('A'); res = Image.alpha_composite(base, black); res.putalpha(a); return res
def panel(name, rects, pill=None):
    """rects: list of (x0,y0,x1,y1) panels in the capture; returns (image, mask) of their bounding box."""
    im = Image.open(f'{src}/{name}').convert('RGB')
    x0 = min(r[0] for r in rects); y0 = min(r[1] for r in rects); x1 = max(r[2] for r in rects); y1 = max(r[3] for r in rects)
    if pill: y0 = min(y0, pill[1]); x0 = min(x0, pill[0])
    crop = im.crop((x0, y0, x1, y1)); mask = Image.new('L', crop.size, 0)
    for r in rects: mask.paste(rmask(r[2] - r[0], r[3] - r[1], 26), (r[0] - x0, r[1] - y0))
    if pill: mask.paste(rmask(pill[2] - pill[0], pill[3] - pill[1], 24), (pill[0] - x0, pill[1] - y0))
    return crop, mask
which = sys.argv[3]
if which == 'interfaces':
    # the menu with its icon, beside the General tab
    menu, mm = panel('menu-app.png', [(135, 62, 753, 709)], pill=(145, 4, 228, 54))
    general = Image.open(f'{src}/general.jpg').convert('RGB'); general = general.crop((2, 2, general.width - 2, general.height - 2)); gm = rmask(general.width, general.height, 26)
    PAD, GAP = 96, 112; W = PAD + menu.width + GAP + general.width + PAD; H = PAD + max(menu.height, general.height) + PAD
    st = stage(W, H); st = shadow(st, PAD, PAD, mm); st.paste(menu, (PAD, PAD), mm)
    x = PAD + menu.width + GAP; st = shadow(st, x, PAD + 56, gm); st.paste(general, (x, PAD + 56), gm)
elif which == 'exceptions':
    app, am = panel('menu-app.png', [(135, 62, 753, 709), (755, 523, 1304, 1268)])
    site, sm = panel('menu-site.png', [(67, 62, 685, 758), (687, 571, 1236, 1481)])
    PAD, GAP = 96, 96; W = PAD + app.width + GAP + site.width + PAD; H = PAD + max(app.height, site.height) + PAD
    st = stage(W, H); st = shadow(st, PAD, PAD, am); st.paste(app, (PAD, PAD), am)
    x = PAD + app.width + GAP; st = shadow(st, x, PAD, sm); st.paste(site, (x, PAD), sm)
elif which == 'grayscale-off':
    g, gm = panel('menu-grayscale-off.png', [(77, 62, 706, 709), (696, 180, 1104, 343)])
    PAD = 80; st = stage(g.width + 2 * PAD, g.height + 2 * PAD); st = shadow(st, PAD, PAD, gm); st.paste(g, (PAD, PAD), gm)
st.save(out, optimize=True); print(out, st.size)
