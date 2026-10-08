// Writes the README illustrations (light and dark) into docs/assets.
import { writeFileSync } from 'node:fs';
import { themes } from './lib.mjs';
const out = '..';
const only = process.argv[2];
for (const name of ['hero', 'warmth', 'nightshift', 'levels']) {
  if (only && only !== name) continue;
  let mod; try { mod = await import(`./${name}.mjs`); } catch (e) { if (e.code === 'ERR_MODULE_NOT_FOUND' && e.message.includes(`${name}.mjs`)) continue; throw e; }
  for (const t of Object.values(themes)) { const s = await mod[name](t); writeFileSync(`${out}/${name}-${t.name}.svg`, s); console.log(name, t.name, (s.length / 1024).toFixed(0) + 'KB'); }
}
