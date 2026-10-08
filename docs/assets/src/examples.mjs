import { text, look, svg, width } from './lib.mjs';
import { writer, editor, browser } from './scene.mjs';

// Three example rules: what is in front, what you set, what the screen shows.
export function examples(t) {
  const W = 1200, cw = 376, gap = 36, th = 292;
  const tiles = [
    { win: writer, box: [56, 64, 420, 372], c: look(0, true), title: 'A writing app', set: 'Nothing', plain: true, see: 'Grayscale, your default' },
    { win: editor, box: [372, 118, 462, 352], c: look(0, false), title: 'A photo editor', set: 'Grayscale: Off', see: 'Color' },
    { win: browser, box: [716, 56, 400, 388], c: look(30, true), title: 'news.example', set: 'Extra Warmth: 30%', see: 'Amber-tinted grayscale' },
  ];
  let b = '', defs = `<filter id="blur" x="-20%" y="-20%" width="140%" height="150%"><feGaussianBlur stdDeviation="9"/></filter>`;
  tiles.forEach((k, i) => {
    const x = i * (cw + gap), c = k.c, [bx, by, bw, bh] = k.box;
    const s = Math.min((th - 52) / bh, (cw - 56) / bw), ox = x + (cw - bw * s) / 2 - bx * s, oy = (th - bh * s) / 2 - by * s - 3;
    defs += `<clipPath id="e${i}"><rect x="${x}" y="0" width="${cw}" height="${th}" rx="20"/></clipPath><linearGradient id="g${i}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${c('#0f6e8c')}"/><stop offset=".55" stop-color="${c('#3559b8')}"/><stop offset="1" stop-color="${c('#6b3fa0')}"/></linearGradient>`;
    b += `<g clip-path="url(#e${i})"><rect x="${x}" y="0" width="${cw}" height="${th}" fill="url(#g${i})"/>` +
      `<circle cx="${x + cw * .12}" cy="${th * 1.05}" r="${th * .5}" fill="${c('#17b890')}" opacity=".55"/><circle cx="${x + cw * .95}" cy="${th * .95}" r="${th * .42}" fill="${c('#f25f8b')}" opacity=".5"/><circle cx="${x + cw * .6}" cy="${-th * .12}" r="${th * .4}" fill="${c('#ffb347')}" opacity=".38"/>` +
      `<g transform="translate(${ox.toFixed(2)} ${oy.toFixed(2)}) scale(${s.toFixed(4)})">${k.win(c, true)}</g></g>`;
    b += text(k.title, x + 4, th + 50, { size: 30, weight: 600, fill: t.ink, tracking: -8 });
    const ry = th + 100, lx = x + 4, vx = x + 104;
    b += text('You set', lx, ry, { size: 21, weight: 400, fill: t.sub });
    const pw = width(k.set, { size: 21, weight: 600 }) + 30;
    b += k.plain
      ? `<rect x="${vx + .75}" y="${ry - 25.25}" width="${pw - 1.5}" height="36.5" rx="18.25" fill="none" stroke="${t.faint}" stroke-width="1.5"/>` + text(k.set, vx + pw / 2, ry, { size: 21, weight: 600, fill: t.sub, anchor: 'middle' })
      : `<rect x="${vx}" y="${ry - 26}" width="${pw}" height="38" rx="19" fill="${t.ink}"/>` + text(k.set, vx + pw / 2, ry, { size: 21, weight: 600, fill: t.on, anchor: 'middle' });
    b += text('You see', lx, ry + 48, { size: 21, weight: 400, fill: t.sub }) + text(k.see, vx, ry + 48, { size: 21, weight: 600, fill: t.ink });
  });
  return svg(W, th + 164, 'Three examples. With a writing app in front and no rule set, the screen shows grayscale, your default. With a photo editor in front and Grayscale set to Off for it, the screen shows color. With the website news.example in front and Extra Warmth set to 30 percent for it, the screen shows grayscale with an amber tint.', b, defs);
}
