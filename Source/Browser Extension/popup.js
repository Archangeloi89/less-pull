import { defaultLabel, warmthLabel } from './labels.js';
import { rampGradient } from './warmth.js';
const $ = id => document.getElementById(id);
let current, target, scope = 'domain', rules = {}, loading = 0;
document.documentElement.style.setProperty('--ramp', rampGradient());
async function ask(message) {
 const r = await chrome.runtime.sendMessage(message);
 if (!r?.ok) throw new Error(r?.error || 'The extension could not connect.');
 return r;
}
function status(text, error = false) { $('status').textContent = text; $('status').classList.toggle('error', error); }
function segmentValue(id) { return $(id).querySelector('[aria-checked="true"]')?.dataset.value; }
function setSegment(id, value) { for (const b of $(id).querySelectorAll('[role=radio]')) b.setAttribute('aria-checked', String(b.dataset.value === String(value))); }
for (const id of ['scope', 'gray', 'night']) $(id).addEventListener('click', e => { const b = e.target.closest('[role=radio]'); if (!b) return; setSegment(id, b.dataset.value); if (id === 'scope') load(); });
function warmth() { $('warmth').disabled = $('inherit').checked; $('percent').textContent = `${$('warmth').value}%`; $('reset').disabled = $('inherit').checked || +$('warmth').value === 0; }
function ruleKey() { return scope === 'domain' ? target?.domain : target?.url; }
function showInherited(inherited) { $('gray-default').textContent = defaultLabel(inherited, 'grayMode'); $('night-default').textContent = defaultLabel(inherited, 'nightMode'); $('inherit-label').textContent = warmthLabel(inherited); }
function onCurrent() { return !!current && !current.private && !!target && target.url === current.url && target.domain === current.domain; }
function backButton() { $('current').hidden = !current || current.private || onCurrent(); }
async function load() {
 const ticket = ++loading; scope = segmentValue('scope');
 const key = ruleKey(); $('site').textContent = key || 'No website open'; $('scope-note').textContent = scope === 'domain' ? 'Also covers subdomains.' : 'Only this address, with its path and query; the part after # is ignored.';
 $('scope').querySelector('[data-value=url]').disabled = !target?.url; backButton();
 $('save').disabled = !key; $('remove').disabled = !key;
 if (!key) { status(current?.private ? 'Private tabs are left alone; no exceptions there.' : 'Open a normal website to add an exception.'); return; }
 try {
  const { rule, inherited } = await ask({ type: 'get', scope, site: key });
  if (ticket !== loading) return;
  showInherited(inherited);
  setSegment('gray', rule?.grayMode || 0); setSegment('night', rule?.nightMode || 0);
  $('inherit').checked = !rule?.customWarmth; $('warmth').value = rule?.warmth || 0; warmth();
  $('remove').disabled = !rule; status(rule ? 'This site has its own settings. Change them and save.' : 'Set what should differ here, then save.');
 } catch (e) { status(`${e.message} Open Less Pull and choose Install Browser Extension in Settings → Websites if this is your first use.`, true); $('save').disabled = true; }
}
async function list() {
 const response = await ask({ type: 'list' }); rules = response.rules;
 const keys = Object.keys(rules).sort(); $('saved-section').hidden = !keys.length;
 $('saved').replaceChildren(...keys.map(key => { const li = document.createElement('li'); li.tabIndex = 0; li.dataset.key = key;
  const name = document.createElement('span'); name.className = 'name'; name.textContent = key;
  const kind = document.createElement('span'); kind.className = 'kind'; kind.textContent = key.includes('://') ? 'exact page' : 'domain';
  li.append(name, kind); return li; }));
}
function choose(key) {
 if (key.startsWith('http://') || key.startsWith('https://')) { target = { domain: new URL(key).hostname, url: key }; setSegment('scope', 'url'); }
 else { target = { domain: key, url: null }; setSegment('scope', 'domain'); }
 load();
}
$('saved').addEventListener('click', e => { const li = e.target.closest('li'); if (li) choose(li.dataset.key); });
$('saved').addEventListener('keydown', e => { const li = e.target.closest('li'); if (li && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); choose(li.dataset.key); } });
$('current').addEventListener('click', () => { target = current && !current.private ? current : null; setSegment('scope', 'domain'); load(); });
$('reset').addEventListener('click', () => { $('warmth').value = 0; warmth(); });
$('inherit').addEventListener('change', warmth); $('warmth').addEventListener('input', warmth);
$('form').addEventListener('submit', async event => {
 event.preventDefault(); $('save').disabled = true;
 try { await ask({ type: 'set', scope, site: ruleKey(), rule: { grayMode: +segmentValue('gray'), nightMode: +segmentValue('night'), customWarmth: !$('inherit').checked, warmth: +$('warmth').value } }); await list(); $('remove').disabled = false; status('Saved. Less Pull applies this while the site is in front.'); }
 catch (e) { status(e.message, true); } finally { $('save').disabled = false; }
});
$('remove').addEventListener('click', async () => {
 try { await ask({ type: 'remove', scope, site: ruleKey() }); await list(); await load(); status('Removed. The site uses the default settings again.'); }
 catch (e) { status(e.message, true); }
});
try { current = (await ask({ type: 'active' })).tab; target = current.private ? null : current; await list(); await load(); }
catch (e) { status(`${e.message} Open Less Pull and choose Install Browser Extension in Settings → Websites.`, true); $('save').disabled = true; $('remove').disabled = true; }
