const HOST = 'local.less_pull.browser';
let port, nextId = 1, revision = 0;
const pending = new Map();
function connection() {
  if (port) return port;
  const p = chrome.runtime.connectNative(HOST); port = p;
  p.onMessage.addListener(message => {
    const task = pending.get(message.id);
    if (task) { pending.delete(message.id); clearTimeout(task.timer); task.resolve(message); }
  });
  p.onDisconnect.addListener(() => {
    const error = chrome.runtime.lastError?.message || 'The local connection closed.';
    if (port === p) port = undefined;
    for (const task of pending.values()) { clearTimeout(task.timer); task.reject(new Error(error)); }
    pending.clear();
  });
  return p;
}
function native(message) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error('Less Pull did not respond.')); }, 6000);
    pending.set(id, { resolve, reject, timer });
    try { connection().postMessage({ ...message, id }); }
    catch (error) { clearTimeout(timer); pending.delete(id); reject(error); }
  });
}
export function identity(url) {
  try {
    const page = new URL(url);
    if (!['http:', 'https:'].includes(page.protocol) || page.username || page.password) return null;
    page.hash = '';
    return { domain: page.hostname.toLowerCase(), url: page.href };
  } catch { return null; }
}
async function active() {
  const tabs = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  const tab = tabs[0];
  const window = tab ? await chrome.windows.get(tab.windowId) : null;
  return { ...identity(tab?.url), focused: !!window?.focused, private: !!tab?.incognito };
}
// The native app owns foreground gating. Browser popups can briefly report
// their main window as unfocused; retain its active tab through that transition.
async function refresh() {
  const ticket = ++revision;
  try {
    const tab = await active();
    if (ticket !== revision) return;
    await native({ type: 'context', site: tab.private ? '' : (tab.domain || ''), url: tab.private ? '' : (tab.url || ''), focused: !!tab.domain && !tab.private });
  } catch {
    // An inaccessible/private window must not keep the previous public tab active.
    try { await native({ type: 'context', site: '', url: '', focused: false }); } catch {}
  }
}
chrome.tabs.onActivated.addListener(refresh);
chrome.tabs.onUpdated.addListener((_id, change, tab) => { if (tab.active && (change.url || change.status === 'complete')) refresh(); });
chrome.tabs.onRemoved.addListener(refresh);
chrome.windows.onFocusChanged.addListener(refresh);
chrome.runtime.onStartup.addListener(refresh);
chrome.runtime.onInstalled.addListener(refresh);
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id || sender.tab) return false;
  (async () => {
    if (message.type === 'active') return { ok: true, tab: await active() };
    if (!['get', 'set', 'remove', 'list'].includes(message.type)) throw new Error('Unsupported request.');
    const response = await native(message);
    if (['set', 'remove'].includes(message.type) && response.ok) await refresh();
    return response;
  })().then(sendResponse, error => sendResponse({ ok: false, error: error.message }));
  return true;
});
setInterval(refresh, 20000);
refresh();
