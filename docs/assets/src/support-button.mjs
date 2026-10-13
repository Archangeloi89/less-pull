import { writeFileSync } from 'node:fs';
import { text, width, mark, svg } from './lib.mjs';
// The README's "Support my work" button, in the website's colors: an amber pill, dark ink, the Less Pull circle.
const amber = '#e8894a', ink = '#1d1208', H = 88, label = 'Support my work', size = 34, weight = 600;
const tw = width(label, { size, weight }), R = 17, padL = 30, gap = 16, padR = 36;
const W = Math.round(padL + 2 * R + gap + tw + padR);
let b = `<rect width="${W}" height="${H}" rx="${H / 2}" fill="${amber}"/>`;
b += mark(padL + R, H / 2, R, ink, 3.4);
b += text(label, padL + 2 * R + gap, H / 2 + size * 0.36, { size, weight, fill: ink });
writeFileSync('../support-button.svg', svg(W, H, 'Support my work', b));
console.log('support-button.svg', W, 'x', H);
