import { text, mark, look, themes, svg, width } from './lib.mjs';
import { scene } from './scene.mjs';

export function hero(t) {
  const W = 1200, H = 1058;
  const dispY = 318, dispH = 528, pad = 14, sw = W - 2 * pad, sh = dispH - 2 * pad;
  const states = [
    { front: 'writer', app: 'Writing app', c: look(0, true), title: 'Writing app', kind: 'Global settings', value: 'Grayscale' },
    { front: 'editor', app: 'Photo editor', c: look(0, false), title: 'Photo editor', kind: 'App exception', value: 'Color' },
    { front: 'browser', app: 'Browser', c: look(30, true), title: 'news.example', kind: 'Website exception', value: 'Warmth 30%' },
  ];
  const amber = look(30, true)('#ffffff');
  let b = '';
  // wordmark
  b += mark(21, 30, 21, t.ink) + text('Less Pull', 56, 41, { size: 33, weight: 600, fill: t.ink, tracking: -10 });
  b += text('macOS menu-bar app', W, 39, { size: 21, weight: 'm400', fill: t.sub, anchor: 'end' });
  // headline
  b += text('Quiet the screen.', -3, 150, { size: 78, weight: 600, fill: t.ink, tracking: -28 });
  b += text('Keep color where it matters.', -3, 236, { size: 78, weight: 600, fill: t.sub, tracking: -28 });
  b += text('Grayscale and extra warmth, with separate settings for each app and website.', 0, 288, { size: 28, weight: 400, fill: t.sub });
  // display
  const bez = t.name === 'light' ? '#16181c' : '#010409';
  b += `<rect x="0" y="${dispY}" width="${W}" height="${dispH}" rx="30" fill="${bez}" stroke="${t.name === 'light' ? '#16181c' : '#3d444d'}" stroke-width="1.5"/>`;
  b += `<g transform="translate(${pad} ${dispY + pad})" clip-path="url(#screen)">`;
  states.forEach((s, i) => { b += `<g class="s s${i}">${scene({ c: s.c, front: s.front, app: s.app, W: sw, H: sh })}</g>`; });
  b += '</g>';
  // rule chips
  const cy = dispY + dispH + 28, cw = 384, ch = 136, gap = (W - 3 * cw) / 2;
  states.forEach((s, i) => {
    const x = i * (cw + gap);
    b += `<rect x="${x + .75}" y="${cy + .75}" width="${cw - 1.5}" height="${ch - 1.5}" rx="18" fill="none" stroke="${t.faint}" stroke-width="1.5"/>`;
    b += `<g class="c c${i}"><rect x="${x + 1.5}" y="${cy + 1.5}" width="${cw - 3}" height="${ch - 3}" rx="17.5" fill="${t.surface}" stroke="${t.ink}" stroke-width="3"/>` +
      text('in front', x + cw - 26, cy + 46, { size: 19, weight: 500, fill: t.ink, anchor: 'end' }) + `<circle cx="${x + cw - 26 - width('in front', { size: 19, weight: 500 }) - 14}" cy="${cy + 39}" r="5.5" fill="${t.ink}"/></g>`;
    b += text(s.title, x + 26, cy + 48, { size: 28, weight: 600, fill: t.ink, tracking: -8 });
    b += text(s.kind, x + 26, cy + 84, { size: 21, weight: 400, fill: t.sub });
    const sample = [look(0, true)('#4aa8ff'), '#4aa8ff', amber][i];
    b += i === 1
      ? ['#e5484d', '#ffd166', '#2a9d6f', '#3b82f6'].map((col, k) => `<circle cx="${x + 36 + k * 15}" cy="${cy + 108}" r="10" fill="${col}" stroke="${t.page}" stroke-width="2"/>`).join('')
      : `<circle cx="${x + 36}" cy="${cy + 108}" r="10" fill="${sample}"/>`;
    b += text(s.value, x + (i === 1 ? 104 : 58), cy + 116, { size: 23, weight: 600, fill: t.ink });
  });
  const T = 12, f = 0.5 / T * 100, q = n => (n / T * 100).toFixed(2);
  const style = `
.s1,.s2,.c1,.c2{opacity:0}
@media (prefers-reduced-motion:no-preference){
.s1{animation:s1 ${T}s linear infinite}.s2{animation:s2 ${T}s linear infinite}
.c0{animation:c0 ${T}s linear infinite}.c1{animation:c1 ${T}s linear infinite}.c2{animation:c2 ${T}s linear infinite}
}
@keyframes s1{0%,${q(4)}%{opacity:0}${q(4.5)}%,${q(8.5)}%{opacity:1}${q(8.51)}%,100%{opacity:0}}
@keyframes s2{0%,${q(8)}%{opacity:0}${q(8.5)}%,${q(11.5)}%{opacity:1}100%{opacity:0}}
@keyframes c0{0%,${q(4)}%{opacity:1}${q(4.5)}%,${q(11.5)}%{opacity:0}100%{opacity:1}}
@keyframes c1{0%,${q(4)}%{opacity:0}${q(4.5)}%,${q(8)}%{opacity:1}${q(8.5)}%,100%{opacity:0}}
@keyframes c2{0%,${q(8)}%{opacity:0}${q(8.5)}%,${q(11.5)}%{opacity:1}100%{opacity:0}}`;
  const defs = `<clipPath id="screen"><rect width="${sw}" height="${sh}" rx="17"/></clipPath><filter id="blur" x="-20%" y="-20%" width="140%" height="150%"><feGaussianBlur stdDeviation="9"/></filter>`;
  return svg(W, 1012, 'Less Pull. Quiet the screen, keep color where it matters. An illustrated display turns grayscale for a writing app, returns to color for a photo editor, and turns warm amber at 30% warmth for the website news.example.', b, defs, style);
}
