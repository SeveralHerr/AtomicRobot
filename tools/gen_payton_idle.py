"""Build sprites/payton_idle_breath.png: Payton's second idle frame (his sheet has one).

The roster's idles are 2 frames at 4 fps with the feet planted and the upper body
bobbing 1-3 px (Robot, Cass, Caitlyn, Sara). This takes his idle cell (Payton.png
row 0, col 0) and sinks everything above the waist - head, torso, the fireball hand,
and the left fist that hangs past the waist - by BOB px, legs untouched.

    python tools/gen_payton_idle.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "sprites" / "Payton.png"
OUT = ROOT / "sprites" / "payton_idle_breath.png"
CELL = 128
BOB = 1
WAIST_Y = 82   # first pants row (green starts here)
FIST_X = 33    # left of the pants: the hanging fist reaches down to FIST_BOTTOM
FIST_BOTTOM = 90


def breath_frame(cell: np.ndarray) -> np.ndarray:
    h, w = cell.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    upper = (ys < WAIST_Y) | ((xs < FIST_X) & (ys < FIST_BOTTOM))
    out = cell.copy()
    out[upper] = 0                      # lift the upper body off...
    moved = np.zeros_like(cell)
    moved[BOB:][upper[:-BOB]] = cell[:-BOB][upper[:-BOB]]
    over = moved[..., 3] > 0            # ...and set it back down BOB px lower
    out[over] = moved[over]
    return out


if __name__ == "__main__":
    sheet = np.array(Image.open(SRC).convert("RGBA"))
    Image.fromarray(breath_frame(sheet[0:CELL, 0:CELL])).save(OUT)
    print(f"wrote {OUT}")
