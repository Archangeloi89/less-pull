const $ = id => document.getElementById(id);
let current, target, scope = 'domain', rules = {}, loading = 0;
async function ask(message) {
 const r = await chrome.runtime.sendMessage(message);
 if (!r?.ok) throw new Error(r?.error || 'The extension could not connect.');
 return r;
}
function status(text, error = false) { $('status').textContent = text; $('status').classList.toggle('error', error); }
function warmth() { $('warmth').disabled = $('inherit').checked; $('percent').textContent = `${$('warmth').value}%`; $('reset').disabled = $('inherit').checked || +$('warmth').value === 0; }
function ruleKey() { return scope === 'domain' ? target?.domain : target?.url; }
async function load() {
 const ticket = ++loading; scope = $('scope').value;
 const key = ruleKey(); $('site').textContent = key || 'Open a normal website to add an exception.';
 $('save').disabled = !key; $('remove').disabled = !key;
 if (!key) { status(current?.private ? 'Website exceptions are excluded in private tabs.' : 'Open a normal website to add an exception.'); return; }
 try {
  const { rule } = await ask({ type: 'get', scope, site: key });
  if (ticket !== loading) return;
  $('gray').value = rule?.grayMode || 0; $('night').value = rule?.nightMode || 0;
  $('inherit').checked = !rule?.customWarmth; $('warmth').value = rule?.warmth || 0; warmth();
  $('remove').disabled = !rule; status(rule ? 'Saved exception ready to edit.' : 'Choose settings, then save this exception.');
 } catch (e) { status(`${e.message} Open Less Pull and choose Install Browser Extension in Settings if this is your first use.`, true); $('save').disabled = true; }
}
async function list() {
 const response = await ask({ type: 'list' }); rules = response.rules;
 $('saved').replaceChildren(new Option('Choose a saved exception…', ''));
 for (const key of Object.keys(rules).sort()) $('saved').add(new Option(key, key));
}
$('current').addEventListener('click', async () => {
 try { current = (await ask({ type: 'active' })).tab; target = current.private ? null : current; $('saved').value = ''; await load(); }
 catch (e) { status(e.message, true); }
});
$('saved').addEventListener('change', async () => {
 const key = $('saved').value; if (!key) { status(current?.private ? 'Website exceptions are excluded in private tabs.' : 'Open a normal website to add an exception.'); return; }
 if (key.startsWith('http://') || key.startsWith('https://')) { target = { domain: new URL(key).hostname, url: key }; $('scope').value = 'url'; }
 else { target = { domain: key, url: null }; $('scope').value = 'domain'; }
 await load();
});
$('scope').addEventListener('change', load);
$('reset').addEventListener('click', () => { $('warmth').value = 0; warmth(); });
$('inherit').addEventListener('change', warmth); $('warmth').addEventListener('input', warmth);
$('form').addEventListener('submit', async event => {
 event.preventDefault(); $('save').disabled = true;
 try { await ask({ type: 'set', scope, site: ruleKey(), rule: { grayMode: +$('gray').value, nightMode: +$('night').value, customWarmth: !$('inherit').checked, warmth: +$('warmth').value } }); await list(); $('remove').disabled = false; status('Saved. Less Pull applies this when the website is foreground.'); }
 catch (e) { status(e.message, true); } finally { $('save').disabled = false; }
});
$('remove').addEventListener('click', async () => {
 try { await ask({ type: 'remove', scope, site: ruleKey() }); await list(); await load(); status('Removed. Default settings apply.'); }
 catch (e) { status(e.message, true); }
});
try { current = (await ask({ type: 'active' })).tab; target = current.private ? null : current; await list(); await load(); }
catch (e) { status(`${e.message} Open Less Pull and choose Install Browser Extension in Settings.`, true); $('save').disabled = true; $('remove').disabled = true; }
