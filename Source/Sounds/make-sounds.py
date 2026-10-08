# The session sounds, synthesized: pure harmonic tones on the 432 Hz reference and the solfeggio pitches
# (132, 198, 264, 396, 528 Hz: whole-number ratios, nothing clashes), a rounded rise with no corner, a long
# natural fade, and a touch of room that dies on its own. Two styles, chosen by ear with the author:
#   strokes: the end gong spread over a breath, the call back as two warm notes rising
#   chord:   each as one chord, struck softly all at once
# Run: python3 make-sounds.py (needs NumPy).
import numpy as np, wave, struct, os
rate = 44100
rng = np.random.default_rng(11)
def tone(f0, seconds, attack=0.3, decay=2.0, gain=1.0, start=0.0):
    t = np.linspace(0, seconds, int(rate * seconds), endpoint=False)
    out = np.zeros_like(t)
    for k, a in zip((1, 2, 3, 4), (1.0, 0.32, 0.12, 0.05)):           # harmonic partials, each slightly detuned so the tone breathes
        for d in (0.9992, 1.0008):
            out += a * np.sin(2 * np.pi * f0 * k * d * t + rng.uniform(0, 6.28)) * np.exp(-t * k / (decay * 1.4))
    rise = np.where(t < attack, 0.5 - 0.5 * np.cos(np.pi * t / attack), 1.0)                    # raised cosine: no corner at the start
    fade_len = seconds * 0.6                                                                       # the second half fades on a slow curve
    fade = np.where(t > seconds - fade_len, 0.5 + 0.5 * np.cos(np.pi * (t - (seconds - fade_len)) / fade_len), 1.0)
    sig = out * rise * np.exp(-t / decay) * fade * gain
    full = np.zeros(int(rate * (seconds + start + 1.8)))                                           # room for the tail to settle
    full[int(rate * start): int(rate * start) + len(sig)] += sig
    return full
def room(sig, seconds=0.9, mix=0.22):
    n = int(rate * seconds); tail = rng.standard_normal(n) * np.exp(-np.linspace(0, 1, n) * 6)
    tail = np.convolve(tail, np.ones(24) / 24, mode='same')
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
def write(name, sig, gain=0.24):
    sig = soften(room(sig)); n = int(rate * 1.6); sig[-n:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n))
    sig = sig / max(1e-9, np.max(np.abs(sig))) * gain
    with wave.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(struct.pack('<%dh' % len(sig), *(np.clip(sig, -1, 1) * 32767).astype(np.int16)))
    print(name, '%.1fs' % (len(sig) / rate))
# --- strokes
write('session-end-strokes.wav', mix(tone(132.0, 6.0, attack=0.2, decay=3.4), tone(198.0, 5.6, attack=0.2, decay=3.0, gain=0.7, start=0.06), tone(264.0, 5.2, attack=0.24, decay=2.6, gain=0.5, start=0.55), tone(396.0, 4.2, attack=0.3, decay=2.0, gain=0.16, start=0.9)))
write('session-remind-strokes.wav', mix(tone(132.0, 4.0, attack=0.2, decay=2.2), tone(198.0, 3.6, attack=0.2, decay=2.0, gain=0.7, start=0.06), tone(264.0, 3.2, attack=0.24, decay=1.8, gain=0.5, start=0.5)), gain=0.13)
write('session-back-strokes.wav', mix(tone(132.0, 4.0, attack=0.2, decay=2.0, gain=0.6), tone(198.0, 3.8, attack=0.18, decay=1.7, gain=0.9), tone(264.0, 4.2, attack=0.18, decay=2.1, gain=1.0, start=0.4), tone(528.0, 3.4, attack=0.3, decay=1.5, gain=0.26, start=0.46)))
# --- chord
write('session-end-chord.wav', mix(tone(132.0, 5.6, attack=0.35, decay=2.6), tone(198.0, 5.4, attack=0.35, decay=2.3, gain=0.7), tone(264.0, 5.2, attack=0.38, decay=2.1, gain=0.5), tone(396.0, 4.4, attack=0.45, decay=1.7, gain=0.16)))
write('session-remind-chord.wav', mix(tone(132.0, 4.0, attack=0.35, decay=1.9), tone(198.0, 3.8, attack=0.35, decay=1.7, gain=0.7), tone(264.0, 3.6, attack=0.38, decay=1.5, gain=0.5)), gain=0.13)
write('session-back-chord.wav', mix(tone(132.0, 4.6, attack=0.3, decay=1.9, gain=0.6), tone(198.0, 4.4, attack=0.3, decay=1.8, gain=0.9), tone(264.0, 4.6, attack=0.3, decay=2.0, gain=1.0), tone(528.0, 3.8, attack=0.4, decay=1.5, gain=0.26)))
