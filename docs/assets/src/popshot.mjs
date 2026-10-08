// Renders the shipped extension popup with example data inside a drawn browser window.
import { createRequire } from 'node:module';
import http from 'node:http';
import { readFileSync } from 'node:fs';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const types = { html: 'text/html', css: 'text/css', js: 'text/javascript', png: 'image/png', woff: 'font/woff' };
const fontsMap = { 'sg500.woff': '@fontsource/schibsted-grotesk/files/schibsted-grotesk-latin-500-normal.woff', 'pm400.woff': '@fontsource/ibm-plex-mono/files/ibm-plex-mono-latin-400-normal.woff' };
const srv = http.createServer((q, s) => { try {
  const u = q.url.split('?')[0]; let f;
  if (u.startsWith('/ext/')) f = '../../../Browser Extension/' + decodeURIComponent(u.slice(5)); else if (u.startsWith('/fonts/')) f = require.resolve(fontsMap[u.slice(7)]); else f = 'frame.html';
  s.writeHead(200, { 'content-type': types[f.split('.').pop()] }); s.end(readFileSync(f)); } catch { s.writeHead(404); s.end(); } }).listen(8765);
// Example data only. Stands in for the native app the popup normally talks to.
const stub = () => {
  const rules = { 'example.com': { grayMode: 2, nightMode: 0, customWarmth: false, warmth: 0 }, 'https://example.com/reading': { grayMode: 0, nightMode: 0, customWarmth: true, warmth: 70 } };
  window.chrome = { runtime: { sendMessage: async m => {
    if (m.type === 'active') return { ok: true, tab: { domain: 'example.com', url: 'https://example.com/reading', focused: true, private: false } };
    if (m.type === 'list') return { ok: true, rules };
    if (m.type === 'get') return { ok: true, rule: rules[m.site] };
    return { ok: true };
  } } };
};
const b = await chromium.launch();
for (const theme of ['light', 'dark']) {
  const ctx = await b.newContext({ viewport: { width: 760, height: 700 }, deviceScaleFactor: 2, colorScheme: theme });
  await ctx.addInitScript(stub);
  const p = await ctx.newPage(); await p.goto('http://localhost:8765/'); 
  if (theme === 'dark') await p.evaluate(() => document.documentElement.classList.add('dark'));
  const fr = p.frames()[1]; await fr.waitForFunction(() => document.getElementById('status').textContent.includes('Choose') || document.getElementById('status').textContent.includes('Saved'));
  await fr.selectOption('#scope', 'url'); await fr.waitForFunction(() => document.getElementById('percent').textContent === '70%');
  await fr.evaluate(() => { document.body.style.maxHeight = 'none'; });
  const h = await fr.evaluate(() => document.documentElement.scrollHeight);
  await p.evaluate(h => { document.querySelector('iframe').style.height = h + 'px'; document.getElementById('stage').style.height = (98 + h + 40) + 'px'; }, h);
  await p.evaluate(() => document.fonts.ready);
  await (await p.$('#stage')).screenshot({ path: `../website-popup-${theme}.png`, omitBackground: true });
  console.log(theme, h); await ctx.close();
}
await b.close(); srv.close();
