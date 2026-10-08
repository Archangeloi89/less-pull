// Illustrative desktop scene. Every colour goes through `c`, the app's matrix
// for a given look, so the whole "display" changes together, as in the app.
import { text, mark, r } from './lib.mjs';

let uid = 0;
const rect = (x, y, w, h, fill, rx = 0, extra = '') => `<rect x="${r(x)}" y="${r(y)}" width="${r(w)}" height="${r(h)}"${rx ? ` rx="${rx}"` : ''} fill="${fill}"${extra ? ' ' + extra : ''}/>`;

export function photo(x, y, w, h, c, rx = 0) {
  const id = `p${uid++}`;
  const sx = w / 370, sy = h / 250;
  const X = v => r(x + v * sx), Y = v => r(y + v * sy);
  return `<defs><linearGradient id="${id}s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c('#27408b')}"/><stop offset=".42" stop-color="${c('#c2477f')}"/><stop offset=".7" stop-color="${c('#ff8a4c')}"/><stop offset="1" stop-color="${c('#ffd166')}"/></linearGradient><clipPath id="${id}c"><rect x="${r(x)}" y="${r(y)}" width="${r(w)}" height="${r(h)}" rx="${rx}"/></clipPath></defs>` +
    `<g clip-path="url(#${id}c)">${rect(x, y, w, h, `url(#${id}s)`)}` +
    `<circle cx="${X(250)}" cy="${Y(128)}" r="${r(30 * sy)}" fill="${c('#fff3c4')}"/>` +
    `<path d="M${X(0)} ${Y(170)}L${X(70)} ${Y(96)}L${X(128)} ${Y(150)}L${X(176)} ${Y(112)}L${X(250)} ${Y(170)}Z" fill="${c('#4a2f7a')}"/>` +
    `<path d="M${X(150)} ${Y(170)}L${X(262)} ${Y(118)}L${X(318)} ${Y(146)}L${X(370)} ${Y(124)}L${X(370)} ${Y(170)}Z" fill="${c('#6b3fa0')}"/>` +
    rect(x, y + 168 * sy, w, h - 168 * sy, c('#1f6f8b')) +
    rect(X(214) - x + x, Y(184), 72 * sx, 5 * sy, c('#ffd166'), 2) + rect(X(228), Y(200), 44 * sx, 5 * sy, c('#ffb074'), 2) + rect(X(238), Y(216), 24 * sx, 5 * sy, c('#ff8a4c'), 2) +
    `<path d="M${X(0)} ${Y(250)}L${X(0)} ${Y(214)}Q${X(60)} ${Y(196)} ${X(120)} ${Y(222)}T${X(210)} ${Y(250)}Z" fill="${c('#2a9d6f')}"/></g>`;
}

function lights(x, y, c, front) {
  const cols = front ? ['#ff5f57', '#febc2e', '#28c840'] : ['#c4c7cc', '#c4c7cc', '#c4c7cc'];
  return cols.map((col, i) => `<circle cx="${x + i * 17}" cy="${y}" r="5.5" fill="${c(col)}"/>`).join('');
}
const shadow = (x, y, w, h, front) => `<rect x="${x - 2}" y="${y + (front ? 10 : 4)}" width="${w + 4}" height="${h}" rx="14" fill="#000" opacity="${front ? .34 : .16}" filter="url(#blur)"/>`;

function writer(c, front) {
  const x = 56, y = 64, w = 420, h = 372;
  const line = (ly, lw, col = '#c3c8cf') => rect(x + 44, ly, lw, 9, c(col), 4.5);
  return shadow(x, y, w, h, front) + rect(x, y, w, h, c('#fcfbf8'), 12) + lights(x + 22, y + 22, c, front) +
    rect(x + 44, y + 66, 232, 18, c('#22252a'), 4) + rect(x + 44, y + 96, 120, 9, c('#8b929b'), 4.5) +
    line(y + 134, 330) + line(y + 156, 312) + rect(x + 40, y + 172, 214, 21, c('#ffe27a'), 4) + line(y + 178, 206, '#6c5a12') + line(y + 200, 322) +
    line(y + 222, 180) + line(y + 262, 330) + line(y + 284, 150, '#2f6fed') + line(y + 306, 300) + line(y + 328, 236);
}
function editor(c, front) {
  const x = 372, y = 118, w = 462, h = 352;
  const sw = ['#e5484d', '#ff8a4c', '#ffd166', '#2a9d6f', '#3b82f6', '#8b5cf6'];
  return shadow(x, y, w, h, front) + rect(x, y, w, h, c('#26282d'), 12) + lights(x + 22, y + 22, c, front) +
    rect(x + 190, y + 15, 82, 14, c('#3a3d44'), 7) +
    sw.map((col, i) => rect(x + 22, y + 58 + i * 34, 24, 24, c(col), 6)).join('') +
    photo(x + 68, y + 52, w - 90, h - 74, c, 6) +
    rect(x + 22, y + h - 40, 24, 18, c('#3a3d44'), 5);
}
function browser(c, front) {
  const x = 716, y = 56, w = 400, h = 388, id = `b${uid++}`;
  const bar = (bx, by, bw, col = '#c3c8cf', bh = 9) => rect(bx, by, bw, bh, c(col), bh / 2);
  return shadow(x, y, w, h, front) + rect(x, y, w, h, c('#ffffff'), 12) +
    `<path d="M${x} ${y + 78}V${y + 12}a12 12 0 0 1 12-12H${x + w - 12}a12 12 0 0 1 12 12V${y + 78}Z" fill="${c('#e9ecf0')}"/>` + lights(x + 22, y + 22, c, front) +
    `<path d="M${x + 84} ${y + 38}v-20a8 8 0 0 1 8-8h104a8 8 0 0 1 8 8v20Z" fill="${c('#ffffff')}"/>` + rect(x + 98, y + 20, 12, 12, c('#e5484d'), 3) + bar(x + 118, y + 22, 62, '#8b929b', 8) +
    rect(x + 14, y + 44, w - 58, 26, c('#ffffff'), 13) + text('news.example', x + 30, y + 62.5, { size: 15, weight: 'm400', fill: c('#3f454d') }) +
    mark(x + w - 26, y + 57, 9, c('#3f454d')) +
    rect(x + 24, y + 98, 52, 20, c('#e5484d'), 10) + bar(x + 86, y + 104, 70, '#8b929b', 8) +
    rect(x + 24, y + 132, 300, 17, c('#22252a'), 4) + rect(x + 24, y + 157, 220, 17, c('#22252a'), 4) +
    `<defs><clipPath id="${id}"><rect x="${x + 24}" y="${y + 192}" width="204" height="118" rx="6"/></clipPath></defs><g clip-path="url(#${id})">${rect(x + 24, y + 192, 204, 118, c('#4aa8ff'))}<circle cx="${x + 176}" cy="${y + 226}" r="17" fill="${c('#ffd166')}"/><path d="M${x + 24} ${y + 310}v-34q52-40 104-10t100-22v66Z" fill="${c('#2a9d6f')}"/></g>` +
    rect(x + 244, y + 192, 132, 118, c('#d6409f'), 6) + rect(x + 262, y + 278, 64, 16, c('#ffffff'), 8) +
    bar(x + 24, y + 328, 352) + bar(x + 24, y + 348, 290) + bar(x + 24, y + 368, 110, '#2f6fed');
}

// W x H scene, `front` in {writer, editor, browser}, `app` shown in the menu bar.
export function scene({ c, front, app, W = 1172, H = 500, clock = '09:41' }) {
  const id = `w${uid++}`;
  const wins = { writer, editor, browser };
  const order = { writer: ['browser', 'editor', 'writer'], editor: ['writer', 'browser', 'editor'], browser: ['writer', 'editor', 'browser'] }[front];
  return `<defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${c('#0f6e8c')}"/><stop offset=".55" stop-color="${c('#3559b8')}"/><stop offset="1" stop-color="${c('#6b3fa0')}"/></linearGradient></defs>` +
    rect(0, 0, W, H, `url(#${id})`) +
    `<circle cx="${W * .16}" cy="${H * 1.02}" r="${H * .52}" fill="${c('#17b890')}" opacity=".55"/><circle cx="${W * .9}" cy="${H * .98}" r="${H * .44}" fill="${c('#f25f8b')}" opacity=".5"/><circle cx="${W * .56}" cy="${H * -.1}" r="${H * .4}" fill="${c('#ffb347')}" opacity=".38"/>` +
    rect(0, 0, W, 30, '#000', 0, 'opacity=".28"') +
    text(app, 20, 21, { size: 15.5, weight: 600, fill: c('#ffffff') }) +
    ['File', 'Edit', 'View'].reduce((a, t) => ({ s: a.s + text(t, a.x, 21, { size: 15.5, weight: 400, fill: c('#ffffff'), opacity: .82 }), x: a.x + 52 }), { s: '', x: 20 + Math.max(96, app.length * 9.4) + 16 }).s +
    mark(W - 104, 15, 8.5, c('#ffffff')) + text(clock, W - 20, 21, { size: 15.5, weight: 500, fill: c('#ffffff'), anchor: 'end' }) +
    order.map(n => wins[n](c, n === front)).join('');
}
