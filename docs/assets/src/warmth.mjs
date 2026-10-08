import { text, look, svg, r } from './lib.mjs';
import { photo } from './scene.mjs';

// Rows: Color / Grayscale. Columns: the slider's own stops, Off 25 50 75 Red.
export function warmth(t) {
  const W = 1200, left = 190, cw = 190, gap = 13, ch = 132, stops = [0, 25, 50, 75, 100], names = ['Off', '25', '50', '75', 'Red'];
  const x = i => left + i * (cw + gap), top = 124;
  let b = '';
  b += text('Extra Warmth', 0, 34, { size: 28, weight: 600, fill: t.ink, tracking: -6 });
  // slider track, drawn with the real curve applied to white
  const tx0 = x(0) + cw / 2, tx1 = x(4) + cw / 2;
  let grad = '';
  for (let i = 0; i <= 24; i++) grad += `<stop offset="${r(i / 24)}" stop-color="${look(i / 24 * 100, true)('#f2f2f2')}"/>`;
  b += `<rect x="${tx0 - 10}" y="22" width="${tx1 - tx0 + 20}" height="12" rx="6" fill="url(#ramp)" stroke="${t.faint}" stroke-width="1"/>`;
  stops.forEach((s, i) => {
    const cx = x(i) + cw / 2;
    b += `<circle cx="${cx}" cy="52" r="2.5" fill="${t.sub}"/>` + text(names[i], cx, 88, { size: 25, weight: 'm500', fill: t.ink, anchor: 'middle' });
  });
  [['Color', false, 'Grayscale off'], ['Grayscale', true, 'Grayscale on']].forEach(([label, gray, sub], row) => {
    const y = top + row * (ch + gap);
    b += text(label, 0, y + ch / 2 + 2, { size: 28, weight: 600, fill: t.ink, tracking: -6 });
    b += text(sub, 0, y + ch / 2 + 32, { size: 20, weight: 400, fill: t.sub });
    stops.forEach((s, i) => { b += photo(x(i), y, cw, ch, look(s, gray), 10); });
  });
  // the shared endpoint
  const by = top + 2 * ch + gap + 12;
  b += `<path d="M${x(4) + 8} ${by}v10h${cw - 16}v-10" fill="none" stroke="${t.sub}" stroke-width="1.5"/>`;
  b += text('same red endpoint', x(4) + cw / 2, by + 38, { size: 20, weight: 400, fill: t.sub, anchor: 'middle' });
  return svg(W, by + 50, 'Illustrative grid: the same picture at Extra Warmth Off, 25, 50, 75 and Red, in color and in grayscale. Warmth moves through amber to red; both rows meet at the same red endpoint.', b, `<linearGradient id="ramp">${grad}</linearGradient>`);
}
