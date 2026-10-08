import { text, look, svg, width } from './lib.mjs';
import { photo } from './scene.mjs';

// Three steps from broad to narrow. Each step changes one setting and keeps the rest.
export function levels(t) {
  const W = 1200, cw = 368, gap = 48, ch = 462;
  const cards = [
    { title: 'Everywhere', sub: 'your defaults', mono: false, look: look(0, true), rows: [['Grayscale', 'On', 1], ['Extra Warmth', 'Off', 1], ['Night Shift', 'On', 1]] },
    { title: 'On example.com', sub: 'a website exception', mono: false, look: look(0, false), rows: [['Grayscale', 'Off', 1], ['Extra Warmth', 'Off', 0], ['Night Shift', 'On', 0]] },
    { title: 'On one page', sub: 'example.com/reading', mono: true, look: look(30, false), rows: [['Grayscale', 'Off', 0], ['Extra Warmth', '30%', 1], ['Night Shift', 'On', 0]] },
  ];
  const arrow = (x, y, c) => `<path d="M${x + 16} ${y}H${x + 1}m6-6l-6 6l6 6" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`;
  let b = '';
  cards.forEach((c, i) => {
    const x = i * (cw + gap);
    b += `<rect x="${x + .75}" y=".75" width="${cw - 1.5}" height="${ch - 1.5}" rx="20" fill="${t.surface}" stroke="${t.faint}" stroke-width="1.5"/>`;
    b += photo(x + 14, 14, cw - 28, 168, c.look, 10);
    b += text(c.title, x + 24, 232, { size: 29, weight: 600, fill: t.ink, tracking: -8 });
    b += text(c.sub, x + 24, 263, { size: c.mono ? 19 : 21, weight: c.mono ? 'm400' : 400, fill: t.sub });
    c.rows.forEach(([k, v, set], j) => {
      const y = 322 + j * 50;
      b += `<line x1="${x + 24}" x2="${x + cw - 24}" y1="${y - 31}" y2="${y - 31}" stroke="${t.faint}" stroke-width="1"/>`;
      b += text(k, x + 24, y, { size: 22, weight: 400, fill: t.ink });
      if (set) { const w = width(v, { size: 22, weight: 600 }) + 30; b += `<rect x="${x + cw - 24 - w}" y="${y - 25}" width="${w}" height="36" rx="18" fill="${t.ink}"/>` + text(v, x + cw - 24 - w / 2, y, { size: 22, weight: 600, fill: t.on, anchor: 'middle' }); }
      else { const w = width(v, { size: 22, weight: 500 }); b += text(v, x + cw - 30, y, { size: 22, weight: 500, fill: t.sub, anchor: 'end' }) + arrow(x + cw - 30 - w - 28, y - 7, t.sub); }
    });
    if (i < 2) { const ax = x + cw + gap / 2, ay = 98; b += `<path d="M${ax - 9} ${ay}H${ax + 9}m-7-7l7 7l-7 7" fill="none" stroke="${t.sub}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>`; }
  });
  // legend
  const ly = ch + 44;
  b += `<rect x="0" y="${ly - 25}" width="62" height="36" rx="18" fill="${t.ink}"/>` + text('On', 31, ly, { size: 22, weight: 600, fill: t.on, anchor: 'middle' }) + text('set at this level', 76, ly, { size: 22, weight: 400, fill: t.sub });
  b += arrow(330, ly - 7, t.sub) + text('On', 356, ly, { size: 22, weight: 500, fill: t.sub }) + text('kept from the level before', 356 + width('On', { size: 22, weight: 500 }) + 14, ly, { size: 22, weight: 400, fill: t.sub });
  return svg(W, ly + 16, 'Three cards from broad to narrow. Everywhere: Grayscale on, Extra Warmth off, Night Shift on, so the picture is gray. On example.com: Grayscale is set to off, so the site shows in color, and warmth and Night Shift are kept. On the single page example.com/reading: Extra Warmth is set to 30 percent, so the picture is in warm color, and Night Shift is kept.', b);
}
