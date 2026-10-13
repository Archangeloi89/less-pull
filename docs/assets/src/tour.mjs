import { text, width, mark, svg } from './lib.mjs';

// The tour on your own screen: the menu bar with the Less Pull circle, the guide (the cursor from lesspull.com)
// beside it with a real line from stop 2, and the tour bar with its seven stops, the pace switch and the line keys.
export function tour(t) {
  const W = 1200, H = 470, amber = '#e8894a', dark = t.name === 'dark';
  const bar = dark ? '#1c2129' : '#eef1f4', card = dark ? '#161b22' : '#ffffff', line = dark ? '#3d444d' : '#d1d9e0';
  let b = '';
  // the screen: a soft backdrop with the menu bar along the top
  b += `<rect x="0" y="0" width="${W}" height="${H}" rx="22" fill="${dark ? '#0f141a' : '#f6f8fa'}" stroke="${line}" stroke-width="1.5"/>`;
  b += `<path d="M0 22a22 22 0 0 1 22 -22h${W - 44}a22 22 0 0 1 22 22v28h-${W}z" fill="${bar}"/>`;
  // menu bar: an app's menus on the left, icons and the clock on the right, the circle among them
  let x = 28; for (const m of ['', 'Notes', 'File', 'Edit', 'Format', 'View', 'Window']) { if (!m) { b += `<circle cx="${x + 7}" cy="25" r="7" fill="${t.ink}"/>`; x += 34; continue; } b += text(m, x, 32, { size: 17, weight: m === 'Notes' ? 700 : 400, fill: t.ink }); x += width(m, { size: 17, weight: m === 'Notes' ? 700 : 400 }) + 22; }
  const clock = 'Thu 9:41', cw = width(clock, { size: 17, weight: 500 }); b += text(clock, W - 26 - cw, 32, { size: 17, weight: 500, fill: t.ink });
  const icons = [W - 60 - cw, W - 96 - cw, W - 132 - cw]; for (const ix of icons) b += `<rect x="${ix - 9}" y="16" width="18" height="18" rx="5" fill="none" stroke="${t.sub}" stroke-width="2"/>`;
  const cx = W - 176 - cw, cy = 25; b += mark(cx, cy, 10, t.ink, 2.2);
  // the ring around the circle, as the tour draws it
  b += `<circle cx="${cx}" cy="${cy}" r="19" fill="none" stroke="${amber}" stroke-width="3"/><circle cx="${cx}" cy="${cy}" r="27" fill="none" stroke="${amber}" stroke-width="2" opacity=".35"/>`;
  // the guide: an arrow pointer with its label, just below the circle, and its line in a bubble
  const gx = cx - 30, gy = 92;
  b += `<path d="M${gx} ${gy}l0 34l9 -8l7 15l6 -3l-7 -14l12 -1z" fill="${dark ? '#f0f6fc' : '#ffffff'}" stroke="${dark ? '#0d1117' : '#1f2328'}" stroke-width="2.4" stroke-linejoin="round" transform="rotate(-18 ${gx} ${gy})"/>`;
  b += `<rect x="${gx + 18}" y="${gy + 30}" width="64" height="24" rx="12" fill="${amber}"/>` + text('Guide', gx + 28, gy + 47, { size: 15, weight: 600, fill: '#1d1208' });
  const say1 = 'Your turn: click the circle.', say2 = 'The menu drops out of it.', sw = Math.max(width(say1, { size: 20, weight: 500 }), width(say2, { size: 20, weight: 500 })) + 40;
  const bx = gx - 40 - sw, by = gy + 6;
  b += `<path d="M${bx + sw - 6} ${by + 20}L${bx + sw + 20} ${by + 10}L${bx + sw - 6} ${by + 42}" fill="${card}" stroke="${line}" stroke-width="1.5" stroke-linejoin="round"/>`;  // the tail, toward the guide
  b += `<rect x="${bx}" y="${by}" width="${sw}" height="78" rx="18" fill="${card}" stroke="${line}" stroke-width="1.5"/><rect x="${bx + sw - 8}" y="${by + 21}" width="8" height="20" fill="${card}"/>`;
  b += text(say1, bx + 20, by + 33, { size: 20, weight: 500, fill: t.ink }) + text(say2, bx + 20, by + 60, { size: 20, weight: 400, fill: t.sub });
  // the tour bar, top left under the menu bar, as on the Mac
  const tx = 40, ty = 230, tw = 520, th = 200;
  b += `<rect x="${tx}" y="${ty}" width="${tw}" height="${th}" rx="22" fill="${card}" stroke="${line}" stroke-width="1.5"/>`;
  const n = 7, sx = tx + 56, gap = (tw - 112) / (n - 1), sy = ty + 42;
  b += `<line x1="${sx}" x2="${sx + gap * (n - 1)}" y1="${sy}" y2="${sy}" stroke="${line}" stroke-width="3" stroke-linecap="round"/><line x1="${sx}" x2="${sx + gap}" y1="${sy}" y2="${sy}" stroke="${amber}" stroke-width="3" stroke-linecap="round"/>`;
  for (let i = 0; i < n; i++) { const px = sx + gap * i; b += i < 1 ? `<circle cx="${px}" cy="${sy}" r="9" fill="${amber}"/>` : i === 1 ? `<circle cx="${px}" cy="${sy}" r="13" fill="${card}" stroke="${amber}" stroke-width="3.5"/><circle cx="${px}" cy="${sy}" r="5" fill="${amber}"/>` : `<circle cx="${px}" cy="${sy}" r="8" fill="${card}" stroke="${t.sub}" stroke-width="2.4"/>`; }
  b += text('Stop 2 of 7 · Less Pull', tx + 30, ty + 102, { size: 21, weight: 600, fill: t.ink });
  const end = 'End tour', ew = width(end, { size: 17, weight: 500 }) + 30; b += `<rect x="${tx + tw - 30 - ew}" y="${ty + 80}" width="${ew}" height="32" rx="9" fill="none" stroke="${line}" stroke-width="1.5"/>` + text(end, tx + tw - 15 - ew, ty + 102, { size: 17, weight: 500, fill: t.ink });
  // pace: Slow | Normal | Fast, Normal chosen; and the line keys
  const segs = ['Slow', 'Normal', 'Fast'], segW = segs.map(s => width(s, { size: 16, weight: 500 }) + 30); let px = tx + 30; const py = ty + 136;
  b += `<rect x="${px}" y="${py}" width="${segW.reduce((a, c) => a + c, 0)}" height="34" rx="9" fill="none" stroke="${line}" stroke-width="1.5"/>`;
  segs.forEach((s, i) => { if (i === 1) b += `<rect x="${px + 2}" y="${py + 2}" width="${segW[i] - 4}" height="30" rx="7" fill="${dark ? '#2d333b' : '#e4e8ec'}"/>`; b += text(s, px + 15, py + 23, { size: 16, weight: i === 1 ? 600 : 500, fill: i === 1 ? t.ink : t.sub }); px += segW[i]; });
  for (const [d, kx] of [[-1, tx + tw - 104], [1, tx + tw - 64]]) {  // the line keys, drawn: the font has no arrows
    const mx = kx + 17, my = py + 17, s = 7 * d;
    b += `<rect x="${kx}" y="${py}" width="34" height="34" rx="8" fill="none" stroke="${line}" stroke-width="1.5"/>`;
    b += `<path d="M${mx - s} ${my}H${mx + s}M${mx + s - 5 * d} ${my - 5}L${mx + s} ${my}L${mx + s - 5 * d} ${my + 5}" fill="none" stroke="${t.ink}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>`; }
  // what the stops are, beside the bar
  const stops = ['1  The Pull', '2  Less Pull', '3  Apps', '4  Websites', '5  Peek', '6  Sessions & nights', '7  Your turn'];
  stops.forEach((s, i) => { b += text(s, 640, 252 + i * 29, { size: 19, weight: i === 1 ? 600 : 400, fill: i === 1 ? t.ink : t.sub }); });
  b += text('You do each step yourself, on your own Mac.', 640, 456, { size: 17, weight: 500, fill: t.sub });
  return svg(W, H, 'The tour on your own screen: the guide, the cursor from lesspull.com, sits below the Less Pull circle in the menu bar and says: Your turn: click the circle. The menu drops out of it. Below, the tour bar shows Stop 2 of 7, Less Pull, with seven stops, End tour, the speed switch Slow, Normal, Fast and the keys for one line back or on. Beside it the seven stops: The Pull, Less Pull, Apps, Websites, Peek, Sessions and nights, Your turn.', b);
}
