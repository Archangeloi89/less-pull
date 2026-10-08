# The three session sounds, synthesized: pure harmonic tones on the 432 Hz reference and the
# solfeggio pitches (396, 528 Hz and their octaves), in whole-number ratios so they never clash.
# A soft attack, a long even fall, a touch of room. Low and short.
# Run: python3 make-sounds.py (needs NumPy).
import numpy as np, wave, struct, os
rate = 44100
rng = np.random.default_rng(11)
def tone(f0, seconds, attack=0.10, decay=2.4, gain=1.0, start=0.0):
    # harmonic partials only (1, 2, 3, 4), each slightly detuned so the tone breathes instead of ringing like a sine
    t = np.linspace(0, seconds, int(rate * seconds), endpoint=False)
    out = np.zeros_like(t)
    for k, a in zip((1, 2, 3, 4), (1.0, 0.32, 0.12, 0.05)):
        for d in (0.9992, 1.0008):
            out += a * np.sin(2 * np.pi * f0 * k * d * t + rng.uniform(0, 6.28)) * np.exp(-t * k / (decay * 1.4))
    env = (1 - np.exp(-t / attack)) * np.exp(-t / decay)
    env *= (1 - np.exp(-(seconds - t) / 0.12))
    sig = out * env * gain
    full = np.zeros(int(rate * (seconds + start)))
    full[int(rate * start): int(rate * start) + len(sig)] += sig
    return full
def room(sig, seconds=0.9, mix=0.22):
    n = int(rate * seconds); tail = rng.standard_normal(n) * np.exp(-np.linspace(0, 1, n) * 6)
    tail = np.convolve(tail, np.ones(24) / 24, mode='same')           # soften the room itself
    wet = np.convolve(sig, tail)[: len(sig)] / (np.abs(tail).sum() + 1e-9) * 40
    return sig + mix * wet
def soften(sig, cutoff=2600.0):
    a = np.exp(-2 * np.pi * cutoff / rate); out = np.zeros_like(sig); y = 0.0
    for i, x in enumerate(sig): y = a * y + (1 - a) * x; out[i] = y
    return out
def mix(*parts):
    n = max(len(p) for p in parts); out = np.zeros(n)
    for p in parts: out[: len(p)] += p
    return out
def write(name, sig, gain=0.2):
    sig = soften(room(sig)); sig = sig / max(1e-9, np.max(np.abs(sig))) * gain
    with wave.open(os.path.join(os.path.dirname(__file__), name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(struct.pack('<%dh' % len(sig), *(np.clip(sig, -1, 1) * 32767).astype(np.int16)))
    print(name, '%.1fs' % (len(sig) / rate))
# The end, like a small gong: 132, 198 and 264 Hz (2 : 3 : 4, a fifth and a fourth, an octave down), a slow bloom,
# the 264 a breath later, a faint 396 shimmer on top, and a long even fall.
write('session-end.wav', mix(tone(132.0, 6.5, attack=0.16, decay=3.8), tone(198.0, 6.0, attack=0.16, decay=3.4, gain=0.7, start=0.06), tone(264.0, 5.6, attack=0.2, decay=3.0, gain=0.5, start=0.55), tone(396.0, 4.5, attack=0.3, decay=2.2, gain=0.16, start=0.9)), gain=0.24)
# A reminder: the same gong, quieter and shorter, from the next room.
write('session-remind.wav', mix(tone(132.0, 4.2, attack=0.16, decay=2.4), tone(198.0, 3.8, attack=0.16, decay=2.2, gain=0.7, start=0.06), tone(264.0, 3.4, attack=0.2, decay=2.0, gain=0.5, start=0.5)), gain=0.13)
# The call back: no strike at all. A warm chord that breathes in over a second (264 and 396 Hz, a fifth),
# the 528 joining a moment later like a small lift, then a long easy release. An invitation, not a call.
write('session-back.wav', mix(tone(264.0, 5.6, attack=0.9, decay=2.6), tone(396.0, 5.4, attack=1.0, decay=2.4, gain=0.6, start=0.1), tone(528.0, 4.6, attack=0.8, decay=2.2, gain=0.35, start=0.9)), gain=0.19)
