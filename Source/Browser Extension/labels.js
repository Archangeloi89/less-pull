// Wording shared with the Mac app: an inherited choice shows what it resolves to.
export const words = { 1: 'On', 2: 'Off' };
export function defaultLabel(inherited, effect) {
  const value = inherited?.[effect];
  return words[value] ? `Use default (${words[value]})` : 'Use default';
}
export function warmthLabel(inherited) {
  const value = Number(inherited?.warmth);
  if (!Number.isFinite(value) || inherited?.warmth === undefined) return 'Use default warmth';
  return `Use default warmth (${value > 0 ? `${Math.round(value)}%` : 'Off'})`;
}
