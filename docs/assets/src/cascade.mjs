import { text, look, svg, width } from './lib.mjs';

// Each effect resolves on its own: the most specific rule that sets it wins.
export function cascade(t) {
  const W = 1200, left = 330, colW = (W - left) / 3, rowH = 104, top = 84;
  const cols = ['Grayscale', 'Extra Warmth', 'Night Shift'];
  const rows = [
    { name: 'Global', src: 'your defaults', v: ['On', '40%', 'On'] },
    { name: 'App', src: 'Brave', v: [null, null, null] },
    { name: 'Domain', src: 'example.com', v: ['Off', null, null] },
    { name: 'Exact URL', src: 'example.com/reading', v: [null, '70%', null] },
  ];
  const cx = j => left + colW * j + colW / 2, cy = i => top + rowH * i + rowH / 2;
  const warm = look(70, false)('#ffffff');
  let b = '';
  cols.forEach((c, j) => { b += text(c, cx(j), 40, { size: 27, weight: 600, fill: t.ink, anchor: 'middle', tracking: -6 }); });
  rows.forEach((row, i) => {
    b += `<line x1="0" x2="${W}" y1="${top + rowH * i}" y2="${top + rowH * i}" stroke="${t.hair}" stroke-width="1.5"/>`;
    b += text(row.name, 0, cy(i) - 2, { size: 27, weight: 600, fill: t.ink, tracking: -6 }) + text(row.src, 0, cy(i) + 28, { size: 20, weight: 'm400', fill: t.sub });
  });
  const resY = top + rowH * 4 + 20, resH = 112;
  b += `<rect x="1" y="${resY}" width="${W - 2}" height="${resH}" rx="20" fill="${t.surface}" stroke="${t.faint}" stroke-width="1.5"/>`;
  b += text('You see', 28, resY + resH / 2 - 2, { size: 27, weight: 600, fill: t.ink, tracking: -6 }) + text('this tab in front', 28, resY + resH / 2 + 28, { size: 20, weight: 400, fill: t.sub });
  const pill = (x, y, s, kind) => {
    const w = Math.max(92, width(s, { size: 24, weight: 600 }) + 44), h = 46;
    const fill = kind === 'win' ? t.ink : 'none', stroke = kind === 'win' ? t.ink : t.faint, ink = kind === 'win' ? t.on : t.sub;
    return `<rect x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}" rx="${h / 2}" fill="${kind === 'win' ? fill : t.page}" stroke="${stroke}" stroke-width="2"/>` + text(s, x, y + 8.5, { size: 24, weight: 600, fill: ink, anchor: 'middle' }) +
      (kind === 'lose' ? `<line x1="${x - w / 2 + 16}" x2="${x + w / 2 - 16}" y1="${y}" y2="${y}" stroke="${t.sub}" stroke-width="2"/>` : '');
  };
  [0, 1, 2].forEach(j => {
    const set = rows.map((r, i) => r.v[j] ? i : -1).filter(i => i >= 0), win = set[set.length - 1];
    // muted line down to the winner, solid from the winner to the result
    b += `<line x1="${cx(j)}" x2="${cx(j)}" y1="${cy(0)}" y2="${cy(win)}" stroke="${t.faint}" stroke-width="2.5" stroke-dasharray="3 8" stroke-linecap="round"/>`;
    b += `<line x1="${cx(j)}" x2="${cx(j)}" y1="${cy(win)}" y2="${resY + 18}" stroke="${t.ink}" stroke-width="2.5"/>`;
    b += `<path d="M${cx(j) - 8} ${resY + 8}l8 12l8-12Z" fill="${t.ink}"/>`;
    rows.forEach((r, i) => {
      if (r.v[j]) b += pill(cx(j), cy(i), r.v[j], i === win ? 'win' : 'lose');
      else { const lab = 'inherits', w = width(lab, { size: 20, weight: 400 }) + 24; b += `<rect x="${cx(j) - w / 2}" y="${cy(i) - 17}" width="${w}" height="34" rx="17" fill="${t.page}"/>` + text(lab, cx(j), cy(i) + 7, { size: 20, weight: 400, fill: t.sub, anchor: 'middle' }); }
    });
  });
  const res = [['Color', null], ['Warmth 70%', warm], ['Night Shift on', null]];
  res.forEach(([s, dot], j) => {
    const w = width(s, { size: 27, weight: 600, tracking: -6 }) + (dot ? 34 : 0), x0 = cx(j) - w / 2, y = resY + resH / 2 + 22;
    if (dot) b += `<circle cx="${x0 + 11}" cy="${y - 9}" r="11" fill="${dot}"/>`;
    b += text(s, x0 + (dot ? 34 : 0), y, { size: 27, weight: 600, fill: t.ink, tracking: -6 });
  });
  return svg(W, resY + resH + 2, 'Diagram of how a website tab resolves its settings. Grayscale, Extra Warmth and Night Shift each inherit separately through Global, App, Domain and Exact URL. In the example, the domain turns Grayscale off, the exact URL sets Warmth to 70 percent, and Night Shift stays on from the global setting, so the tab shows in color at 70 percent warmth with Night Shift on.', b);
}
