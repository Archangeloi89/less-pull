// Shared helpers for the Less Pull README artwork.
// Text is converted to outlines so the SVGs look identical on every machine
// (GitHub serves README SVGs as images, where web fonts cannot load).
import opentype from 'opentype.js';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);

const load = p => { const b = readFileSync(require.resolve(p)); return opentype.parse(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)); };
const sg = w => load(`@fontsource/schibsted-grotesk/files/schibsted-grotesk-latin-${w}-normal.woff`);
const pm = w => load(`@fontsource/ibm-plex-mono/files/ibm-plex-mono-latin-${w}-normal.woff`);
export const fonts = { 400: sg(400), 500: sg(500), 600: sg(600), 700: sg(700), m400: pm(400), m500: pm(500) };

const r2 = n => Math.round(n * 100) / 100;
export function width(str, { size = 24, weight = 400, tracking = 0 } = {}) {
  return fonts[weight].getAdvanceWidth(str, size, { tracking, features: { liga: false, rlig: false } });
}
export function text(str, x, y, { size = 24, weight = 400, fill = '#000', anchor = 'start', tracking = 0, opacity, extra = '' } = {}) {
  const f = fonts[weight];
  const w = f.getAdvanceWidth(str, size, { tracking, features: { liga: false, rlig: false } });
  const x0 = anchor === 'middle' ? x - w / 2 : anchor === 'end' ? x - w : x;
  const d = f.getPath(str, x0, y, size, { tracking, features: { liga: false, rlig: false } }).toPathData(2);
  return `<path d="${d}" fill="${fill}"${opacity != null ? ` opacity="${opacity}"` : ''}${extra ? ' ' + extra : ''}/>`;
}

// ---- The app's warmth curve, ported 1:1 from Source/WarmthCurve.h ----
export function warmthGains(strength) {
  strength = Math.max(0, Math.min(3, strength));
  let g, b;
  if (strength <= 1) { g = 1 - .45 * strength; b = 1 - .88 * strength; }
  else if (strength <= 2) { g = .55 * Math.pow(.20 / .55, strength - 1); b = .12 * Math.pow(.005 / .12, strength - 1); }
  else { const rem = 3 - strength; g = .20 * Math.pow(rem, -Math.log(.20 / .55)); b = .005 * Math.pow(rem, -Math.log(.005 / .12)); }
  return [1, g, b];
}
const hex2 = v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0');
export function parse(hex) { const h = hex.replace('#', ''); return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16)); }
// percent: 0..100 as shown in the app (strength = percent/100*3)
export function look(percent, grayscale) {
  const strength = percent / 100 * 3, gains = warmthGains(strength), mix = grayscale ? 1 : strength / 3;
  return hex => {
    const [r, g, b] = parse(hex), l = .30 * r + .59 * g + .11 * b, src = [r, g, b];
    return '#' + src.map((c, i) => hex2(((1 - mix) * c + mix * l) * gains[i])).join('');
  };
}
export const identity = h => h;

export const themes = {
  light: { name: 'light', ink: '#1f2328', sub: '#59636e', faint: '#d1d9e0', hair: '#e4e8ec', surface: '#f6f8fa', page: '#ffffff', on: '#ffffff' },
  dark: { name: 'dark', ink: '#f0f6fc', sub: '#9198a1', faint: '#3d444d', hair: '#2a313c', surface: '#151b23', page: '#0d1117', on: '#0d1117' },
};
export const r = r2;

// The half-filled circle: ring + filled right half... the app uses SF Symbol
// circle.lefthalf.filled; this is an original redraw of the same idea.
export function mark(cx, cy, R, color, sw = R * 0.16) {
  const ri = R - sw / 2;
  return `<circle cx="${cx}" cy="${cy}" r="${r2(ri)}" fill="none" stroke="${color}" stroke-width="${r2(sw)}"/><path d="M${cx} ${r2(cy - ri)}a${r2(ri)} ${r2(ri)} 0 0 0 0 ${r2(2 * ri)}z" fill="${color}"/>`;
}
export const svg = (w, h, title, body, defs = '', style = '') =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-label="${title}"><title>${title}</title>${style ? `<style>${style}</style>` : ''}${defs ? `<defs>${defs}</defs>` : ''}${body}</svg>\n`;
