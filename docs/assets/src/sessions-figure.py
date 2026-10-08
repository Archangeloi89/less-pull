# The session, drawn: the menu-bar icon through a session (ring filling, the count past the end, the wait for the
# call back), and the two panels. Same backdrop and type as the other figures. Usage: sessions-figure.py out.png
import sys, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
out = sys.argv[1]; W, H = 1280, 640
def font(size, bold=False):
    for path in ['/System/Library/Fonts/HelveticaNeue.ttc', '/System/Library/Fonts/Helvetica.ttc']:
        try: return ImageFont.truetype(path, size, index=1 if bold else 0)
        except Exception: pass
    return ImageFont.load_default()
g = np.linspace(0, 1, H)[:, None]; top, bot = np.array([44, 46, 52]), np.array([24, 25, 29])
im = Image.fromarray((top * (1 - g) + bot * g)[:, None, :].repeat(W, 1).reshape(H, W, 3).astype('uint8'), 'RGB').convert('RGBA')
INK, DIM, LIGHT, ORANGE = (248, 248, 250), (150, 153, 160), (190, 192, 198), (236, 140, 72)
d = ImageDraw.Draw(im)
d.text((40, 30), 'A session, in the menu bar', font=font(30, True), fill=INK)
d.text((40, 72), 'Start it, work, let the end come to you. Nothing to dismiss.', font=font(20), fill=DIM)
# --- the icon through a session
def icon(x, y, ring, over=False, away=False, label='', scale=2.6, alpha=255):
    r = 9 * scale; cx, cy = x, y
    if ring is not None:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(90, 92, 100), width=int(1.2 * scale))
        col = ORANGE if over else (LIGHT if not away else (120, 122, 130))
        if ring > 0: d.arc((cx - r, cy - r, cx + r, cy + r), start=-90, end=-90 + 360 * (1 if over else ring), fill=col, width=int(1.6 * scale))
        r2 = 5.5 * scale
    else: r2 = 7 * scale
    d.pieslice((cx - r2, cy - r2, cx + r2, cy + r2), 90, 270, fill=INK); d.ellipse((cx - r2, cy - r2, cx + r2, cy + r2), outline=INK, width=int(1.4 * scale))
    if label:
        col = (ORANGE[0], ORANGE[1], ORANGE[2], alpha) if over else ((120, 122, 130) if away else INK)
        d.text((cx + r + 8 * scale / 2.6, cy - 12 * scale / 2.6 - 4), label, font=font(int(13 * scale)), fill=col)
y0 = 150; xs = [120, 340, 560, 790, 1030]
states = [(None, False, False, '', 'At rest'), (0.0, False, False, '25', 'A 25-minute session starts'), (0.55, False, False, '11', 'The ring fills as it runs'),
          (1.0, True, False, '−4', 'Past the end: the count breathes'), (0.4, False, True, '9', 'Away, until the call back')]
for (ring, over, away, label, cap), x in zip(states, xs):
    icon(x, y0, ring, over, away, label)
    f = font(17); w = d.textlength(cap, font=f); d.text((x - w / 2 + (18 if label else 0), y0 + 44), cap, font=f, fill=LIGHT)
# --- the two panels
def panel(x, y, w, h):
    global im
    sh = Image.new('RGBA', im.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).rounded_rectangle((x, y + 10, x + w, y + h + 10), 20, fill=(0, 0, 0, 160)); im = Image.alpha_composite(im, sh.filter(ImageFilter.GaussianBlur(16)))
    ImageDraw.Draw(im).rounded_rectangle((x, y, x + w, y + h), 20, fill=(52, 54, 60), outline=(80, 82, 90), width=2)
def chip(x, y, w, t, strong=False):
    d.rounded_rectangle((x, y, x + w, y + 30), 9, fill=(96, 98, 106) if not strong else (236, 140, 72)); f = font(15, True); tw = d.textlength(t, font=f); d.text((x + (w - tw) / 2, y + 7), t, font=f, fill=INK if not strong else (30, 20, 12))
def center(x, y, t, f, fill): d.text((x - d.textlength(t, font=f) / 2, y), t, font=f, fill=fill)
px, py, pw, ph = 120, 260, 440, 300
panel(px, py, pw, ph); d = ImageDraw.Draw(im)
center(px + pw / 2, py + 24, 'A session', font(26), INK); center(px + pw / 2, py + 62, 'Focused work with a gentle end. How long?', font(15), DIM)
for k, t in enumerate(['25 min', '45 min', '60 min', '90 min']): chip(px + 24 + k * 100, py + 100, 90, t)
d.text((px + 24, py + 152), 'or', font=font(14), fill=(110, 112, 120)); d.rounded_rectangle((px + 52, py + 160, px + 330, py + 164), 2, fill=(96, 98, 106)); d.rounded_rectangle((px + 52, py + 160, px + 170, py + 164), 2, fill=LIGHT); d.ellipse((px + 162, py + 153, px + 180, py + 171), fill=INK)
d.text((px + 346, py + 150), '35 min', font=font(16, True), fill=INK)
d.rectangle((px + 24, py + 196, px + 38, py + 210), outline=LIGHT, width=2); d.text((px + 46, py + 194), 'Add to presets', font=font(14), fill=LIGHT); chip(px + 300, py + 188, 116, 'Start 35 min')
d.text((px + 300, py + 246), 'Not now', font=font(14), fill=(110, 112, 120)); d.ellipse((px + 386, py + 244, px + 404, py + 262), outline=(110, 112, 120), width=2)
center(px + pw / 2, py + ph + 14, 'Start a session… in the menu: the panel grows out of the icon', font(15), DIM)
qx, qy, qw, qh = 720, 260, 440, 300
panel(qx, qy, qw, qh); d = ImageDraw.Draw(im)
center(qx + qw / 2, qy + 18, '−4:12', font(34), ORANGE); center(qx + qw / 2, qy + 62, 'That was 25 minutes.', font(15), DIM)
center(qx + qw / 2, qy + 92, 'Leaving? Call me back in', font(14), DIM)
for k, t in enumerate(['5 min', '9 min', '13 min', '33 min']): chip(qx + 24 + k * 100, qy + 118, 90, t)
d.text((qx + 24, qy + 168), 'or', font=font(14), fill=(110, 112, 120)); d.rounded_rectangle((qx + 52, qy + 176, qx + 330, qy + 180), 2, fill=(96, 98, 106)); d.rounded_rectangle((qx + 52, qy + 176, qx + 110, qy + 180), 2, fill=LIGHT); d.ellipse((qx + 102, qy + 169, qx + 120, qy + 187), fill=INK)
d.text((qx + 346, qy + 166), '7 min', font=font(16, True), fill=INK)
chip(qx + 24, qy + 212, 110, 'Keep going'); d.text((qx + 280, qy + 218), 'Leave quietly', font=font(14), fill=(110, 112, 120)); d.ellipse((qx + 386, qy + 216, qx + 404, qy + 234), outline=(110, 112, 120), width=2)
center(qx + qw / 2, qy + qh + 14, 'After the end: a click on the icon, and the way back is one tap', font(15), DIM)
# the glow, hinted between the panels
gx, gy = 640, 410
glow = Image.new('RGBA', im.size, (0, 0, 0, 0)); ImageDraw.Draw(glow).ellipse((gx - 90, gy - 60, gx + 90, gy + 60), fill=(255, 190, 120, 70)); im = Image.alpha_composite(im, glow.filter(ImageFilter.GaussianBlur(30)))
d = ImageDraw.Draw(im); center(gx, gy - 12, 'a glow', font(15), (255, 215, 170)); center(gx, gy + 8, '+ a soft gong', font(15), (255, 215, 170))
im.convert('RGB').save(out, optimize=True); print(out, im.size)
