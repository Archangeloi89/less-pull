// A port of Source/WarmthCurve.h: what white becomes at each warmth strength (0..3).
export function warmthGains(strength) {
  const s = Math.max(0, Math.min(3, strength));
  if (s <= 1) return [1, 1 - 0.45 * s, 1 - 0.88 * s];
  if (s <= 2) return [1, 0.55 * Math.pow(0.20 / 0.55, s - 1), 0.12 * Math.pow(0.005 / 0.12, s - 1)];
  const remaining = 3 - s;
  return [1, 0.20 * Math.pow(remaining, -Math.log(0.20 / 0.55)), 0.005 * Math.pow(remaining, -Math.log(0.005 / 0.12))];
}
export function rampGradient(steps = 24) {
  const stops = [];
  for (let i = 0; i <= steps; i++) {
    const [r, g, b] = warmthGains(3 * i / steps).map(v => Math.round(v * 255));
    stops.push(`rgb(${r},${g},${b}) ${(100 * i / steps).toFixed(1)}%`);
  }
  return `linear-gradient(to right, ${stops.join(', ')})`;
}
