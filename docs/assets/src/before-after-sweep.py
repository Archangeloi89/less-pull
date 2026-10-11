# The before/after, moving: the seam glides across the busy screen by itself, so it reads as
# an animation rather than a slider (a README cannot run code, so nothing there can be dragged).
# Usage: social-preview.py /tmp/screen --parts, then before-after-sweep.py /tmp/screen out.webp
import sys, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
parts, out = sys.argv[1], sys.argv[2]
color, quiet = Image.open(parts + '-color.png').convert('RGB'), Image.open(parts + '-quiet.png').convert('RGB')
W, H = 1280, 520; sw, sh = color.size; sx, sy = 80, 56; FPS = 25
def font(size, bold=False):
    for path in ['/System/Library/Fonts/HelveticaNeue.ttc', '/System/Library/Fonts/Helvetica.ttc']:
        try: return ImageFont.truetype(path, size, index=1 if bold else 0)
        except Exception: pass
    return ImageFont.load_default()
# backdrop with the screen's shadow, made once
base = Image.new('RGB', (W, H)); bd = ImageDraw.Draw(base)
for y in range(H):
    g = y / (H - 1); bd.line([(0, y), (W, y)], fill=tuple(int(a * (1 - g) + b * g) for a, b in zip((44, 46, 52), (24, 25, 29))))
base = base.convert('RGBA'); sh_ = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ImageDraw.Draw(sh_).rounded_rectangle((sx, sy + 18, sx + sw, sy + sh + 18), 24, fill=(0, 0, 0, 170)); base = Image.alpha_composite(base, sh_.filter(ImageFilter.GaussianBlur(28)))
d = ImageDraw.Draw(base)
d.text((sx + 24, sy + sh + 22), 'The screen as it is', font=font(26), fill=(170, 172, 178))
cap = 'With Less Pull: grayscale and a little warmth'; d.text((sx + sw - 24 - d.textlength(cap, font=font(26)), sy + sh + 22), cap, font=font(26), fill=(170, 172, 178))
mask = Image.new('L', (sw, sh), 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), 24, fill=255)
# the path of the seam: rest in the middle, glide right (more color), glide left (more quiet), back
ease = lambda t: .5 - .5 * math.cos(math.pi * t)
keys = [(.5, 1.0), (.8, 1.6), (.8, 1.0), (.2, 2.6), (.2, 1.0), (.5, 1.6)]  # (position, seconds to get there or hold)
path = []; p = .5
for target, secs in keys:
    n = int(secs * FPS)
    path += [p + (target - p) * ease((k + 1) / n) for k in range(n)]; p = target
frames = []
for p in path:
    cx = int(sw * p); scr = quiet.copy(); scr.paste(color.crop((0, 0, cx, sh)), (0, 0))
    im = base.copy(); im.paste(scr, (sx, sy), mask); d = ImageDraw.Draw(im); x = sx + cx
    d.rectangle((x - 2, sy, x + 2, sy + sh - 1), fill=(250, 250, 250))
    r = 40; cy = sy + sh // 2
    d.ellipse((x - r - 5, cy - r - 5, x + r + 5, cy + r + 5), fill=(36, 37, 42))
    d.pieslice((x - r, cy - r, x + r, cy + r), 90, 270, fill=(245, 245, 247)); d.pieslice((x - r, cy - r, x + r, cy + r), 270, 450, fill=(236, 140, 72))
    d.ellipse((x - r, cy - r, x + r, cy + r), outline=(245, 245, 247), width=4)
    frames.append(im.convert('RGB'))
frames[0].save(out, save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0, quality=82, method=6)
print(out, len(frames), 'frames')
