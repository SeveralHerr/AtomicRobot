"""Synthesize sounds/fireball.wav, Payton's weapon sound (deterministic, seeded).

Timed to his Attack animation: the weapon sound starts on swing frame 0 and the
fireball leaves his hand on frame 4 (attack_frame), 4 / (15 fps * AttackChain.ANIM_SPEED
1.4) = 0.19 s later. So: a crackling ignition while he winds up, the big WHOOSH at
RELEASE_S, then a roaring tail that fades as the shot flies off.

    python tools/gen_fireball_sfx.py            # writes sounds/fireball.wav
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
LENGTH_S = 0.62
RELEASE_S = 4 / (15 * 1.4)
PEAK = 0.72  # matches throw.wav, Cass's weapon sound
OUT = Path(__file__).resolve().parent.parent / "sounds" / "fireball.wav"


def lowpass(x: np.ndarray, cutoff_hz: np.ndarray) -> np.ndarray:
    """One-pole lowpass with a per-sample cutoff (a sweep)."""
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff_hz / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def bandish(x: np.ndarray, lo: np.ndarray, hi: np.ndarray) -> np.ndarray:
    """Crude band: lowpass at `hi` minus lowpass at `lo`."""
    return lowpass(x, hi) - lowpass(x, lo)


def synth(seed: int = 7) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(SR * LENGTH_S)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    after = np.clip(t - RELEASE_S, 0, None)
    before = t < RELEASE_S

    # Ignition: a soft rising fwoom while the fireball is held.
    ign_env = np.where(before, (t / RELEASE_S) ** 1.6 * 0.8, 0.8 * np.exp(-after / 0.05))
    ign = bandish(noise, np.full(n, 250.0), 400.0 + 1600.0 * np.clip(t / RELEASE_S, 0, 1)) * ign_env

    # Release whoosh: a bright burst that darkens as the shot flies away.
    attack = np.clip((t - RELEASE_S + 0.012) / 0.012, 0, 1)
    whoosh_env = attack * np.exp(-after / 0.16)
    whoosh = lowpass(noise, 600.0 + 5200.0 * np.exp(-after / 0.09)) * whoosh_env * 1.6

    # Roar: a low flame rumble, noise-modulated so it never reads as a tone.
    wobble = lowpass(rng.uniform(-1, 1, n), np.full(n, 30.0)) * 6.0
    freq = 55.0 + 60.0 * np.exp(-after / 0.08)
    phase = 2 * np.pi * np.cumsum(freq * (1.0 + 0.15 * wobble)) / SR
    roar = np.sin(phase) * attack * np.exp(-after / 0.22) * 0.5

    # Crackle: sparse pops, denser at the release, fading in the tail.
    density = np.where(before, 0.002, 0.012 * np.exp(-after / 0.18))
    pops = (rng.uniform(0, 1, n) < density) * rng.uniform(-1, 1, n)
    crackle = lowpass(pops, np.full(n, 3500.0)) * 2.5

    mix = ign + whoosh + roar + crackle
    fade = np.clip((LENGTH_S - t) / 0.04, 0, 1)  # no click at the end
    mix *= fade
    return mix / np.abs(mix).max() * PEAK


def write(samples: np.ndarray, path: Path) -> None:
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    write(synth(), out)
    print(f"wrote {out} ({LENGTH_S:.2f}s, release at {RELEASE_S:.3f}s)")
