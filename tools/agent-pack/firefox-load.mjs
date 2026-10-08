// Installs an unpacked extension into Firefox launched with --remote-debugging-port 9222 (WebDriver BiDi). Usage: node firefox-load.mjs "<folder>"
// Installs the unpacked Less Pull extension into the running Firefox through WebDriver BiDi.
const path = process.argv[2];
const ws = new WebSocket('ws://127.0.0.1:9222/session');
let id = 0; const pending = new Map();
const send = (method, params) => new Promise((resolve, reject) => { const n = ++id; pending.set(n, { resolve, reject }); ws.send(JSON.stringify({ id: n, method, params })); });
ws.addEventListener('message', e => { const m = JSON.parse(e.data); const p = pending.get(m.id); if (!p) return; pending.delete(m.id); m.type === 'error' ? p.reject(new Error(m.message)) : p.resolve(m.result); });
ws.addEventListener('open', async () => {
  try {
    await send('session.new', { capabilities: {} });
    const r = await send('webExtension.install', { extensionData: { type: 'path', path } });
    console.log('installed', JSON.stringify(r));
  } catch (e) { console.error('failed:', e.message); process.exitCode = 1; }
  ws.close();
});
ws.addEventListener('error', e => { console.error('cannot connect', e.message || ''); process.exitCode = 1; });
