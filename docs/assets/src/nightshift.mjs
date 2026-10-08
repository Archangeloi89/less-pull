import { text, look, svg, r } from './lib.mjs';

// One example day, noon to noon. Night Shift schedule 22:00-07:00 is an example.
export function nightshift(t) {
  const W = 1200, left = 250, right = W - 6, span = right - left;
  const X = h => left + ((h - 12 + 24) % 24 || (h === 12 ? 0 : 24)) / 24 * span; // hours since noon
  const xh = k => left + k / 24 * span; // k = hours after noon
  const on = 10, off = 19; // 22:00 and 07:00 as hours after noon
  const amber = look(40, true)('#ffffff');
  const nightFill = t.name === 'light' ? '#eef1f4' : '#151b23';
  let b = '';
  const rowY = [112, 232, 352], rowH = 84, bottom = 452;
  // night band
  b += `<rect x="${xh(on)}" y="56" width="${xh(off) - xh(on)}" height="${bottom - 56}" fill="${nightFill}"/>`;
  b += text('day', (xh(0) + xh(on)) / 2, 40, { size: 21, weight: 400, fill: t.sub, anchor: 'middle' });
  b += text('night', (xh(on) + xh(off)) / 2, 40, { size: 21, weight: 400, fill: t.sub, anchor: 'middle' });
  b += text('day', (xh(off) + xh(24)) / 2, 40, { size: 21, weight: 400, fill: t.sub, anchor: 'middle' });
  // rows
  const label = (i, a, s) => text(a, 0, rowY[i] + 36, { size: 27, weight: 600, fill: t.ink, tracking: -6 }) + text(s, 0, rowY[i] + 66, { size: 20, weight: 400, fill: t.sub });
  [0, 1, 2].forEach(i => { b += `<line x1="0" x2="${right}" y1="${rowY[i] - 18}" y2="${rowY[i] - 18}" stroke="${t.hair}" stroke-width="1.5"/>`; });
  // 1 Night Shift (macOS)
  b += label(0, 'Night Shift', 'macOS schedule');
  const y0 = rowY[0] + 22;
  b += `<line x1="${xh(0)}" x2="${xh(24)}" y1="${y0 + 20}" y2="${y0 + 20}" stroke="${t.faint}" stroke-width="3" stroke-linecap="round"/>`;
  b += `<rect x="${xh(on)}" y="${y0}" width="${xh(off) - xh(on)}" height="40" rx="20" fill="${t.ink}"/>` + text('on', (xh(on) + xh(off)) / 2, y0 + 28, { size: 22, weight: 600, fill: t.on, anchor: 'middle' });
  b += text('off', (xh(0) + xh(on)) / 2, y0 + 10, { size: 20, weight: 400, fill: t.sub, anchor: 'middle' }) + text('off', (xh(off) + xh(24)) / 2, y0 + 10, { size: 20, weight: 400, fill: t.sub, anchor: 'middle' });
  // 2 Extra Warmth follows
  b += label(1, 'Extra Warmth', 'following Night Shift');
  const base = rowY[1] + 70, hi = rowY[1] + 14, f = 6;
  b += `<path d="M${xh(on)} ${base}L${xh(on) + f} ${hi}H${xh(off) - f}L${xh(off)} ${base}Z" fill="${amber}" opacity="${t.name === 'light' ? .28 : .3}"/>`;
  b += `<path d="M${xh(0)} ${base}H${xh(on)}L${xh(on) + f} ${hi}H${xh(off) - f}L${xh(off)} ${base}H${xh(24)}" fill="none" stroke="${amber}" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>`;
  b += text('your saved amount', (xh(on) + xh(off)) / 2, hi + 36, { size: 21, weight: 600, fill: t.ink, anchor: 'middle' });
  b += text('0%', (xh(0) + xh(on)) / 2, base - 14, { size: 20, weight: 400, fill: t.sub, anchor: 'middle' }) + text('0%', (xh(off) + xh(24)) / 2, base - 14, { size: 20, weight: 400, fill: t.sub, anchor: 'middle' });
  // 3 Grayscale
  b += label(2, 'Grayscale', 'your choice');
  const y2 = rowY[2] + 22, g = t.name === 'light' ? '#8c959f' : '#6e7681';
  b += `<rect x="${xh(0)}" y="${y2}" width="${span}" height="40" rx="20" fill="${g}"/>` + text('stays as you set it, day and night', (xh(0) + xh(24)) / 2, y2 + 28, { size: 22, weight: 600, fill: '#ffffff', anchor: 'middle' });
  // time axis
  b += `<line x1="${xh(0)}" x2="${xh(24)}" y1="${bottom}" y2="${bottom}" stroke="${t.faint}" stroke-width="1.5"/>`;
  [[0, '12:00', 'start'], [on, '22:00', 'middle'], [off, '07:00', 'middle'], [24, '12:00', 'end']].forEach(([k, s, a]) => {
    b += `<line x1="${xh(k)}" x2="${xh(k)}" y1="${bottom}" y2="${bottom + 8}" stroke="${t.sub}" stroke-width="1.5"/>` + text(s, xh(k), bottom + 36, { size: 21, weight: 'm400', fill: (k === on || k === off) ? t.ink : t.sub, anchor: a });
  });
  return svg(W, bottom + 48, 'Timeline of one example day. Night Shift is on from 22:00 to 07:00. Extra Warmth, when following Night Shift, is 0% by day and returns to your saved amount at night. Grayscale stays as you set it, day and night.', b);
}
