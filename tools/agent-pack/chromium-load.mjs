// Loads an unpacked extension into a Chromium browser (Brave, Chrome, Opera, Edge) that was
// launched with --remote-debugging-port=<port>, by dropping the folder onto its extensions page.
// Usage: node chromium-load.mjs <port> "<extension folder>"   (needs the playwright package)
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url); const { chromium } = require('playwright');
const [port, folder] = process.argv.slice(2);
if (!port || !folder) { console.error('usage: node chromium-load.mjs <port> "<extension folder>"'); process.exit(2); }
const browser = await chromium.connectOverCDP(`http://127.0.0.1:${port}`);
const ctx = browser.contexts()[0] || await browser.newContext(); const page = await ctx.newPage();
await page.goto('chrome://extensions', { waitUntil: 'domcontentloaded' }).catch(() => {}); await page.waitForTimeout(1200);
const texts = await page.evaluate(() => { const out = []; const walk = r => { for (const el of r.querySelectorAll('*')) { if (el.shadowRoot) walk(el.shadowRoot); const t = (el.innerText || '').trim(); if (t && t.length < 40) out.push(t); } }; walk(document); return out; });
if (!texts.includes('Load unpacked')) { console.error('Turn on Developer mode on the extensions page first, then run this again.'); process.exit(1); }
const cdp = await ctx.newCDPSession(page); const { w, h } = await page.evaluate(() => ({ w: innerWidth, h: innerHeight }));
const data = { items: [{ mimeType: 'text/uri-list', data: 'file://' + encodeURI(folder) }], files: [folder], dragOperationsMask: 1 };
for (const type of ['dragEnter', 'dragOver', 'drop']) { await cdp.send('Input.dispatchDragEvent', { type, x: w / 2, y: h / 2, data }); await page.waitForTimeout(300); }
await page.waitForTimeout(2500);
const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
console.log(targets.some(t => /chrome-extension:\/\/.*background/.test(t.url)) ? 'extension loaded' : 'drop sent; check the extensions page');
await page.close(); await browser.close();
