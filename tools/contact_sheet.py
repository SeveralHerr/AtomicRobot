#!/usr/bin/env python3
"""Tile an autoplay run's snaps (autoplay_out/<run>_f<frame>.png) between two game
times into one labelled JPEG, for the validation loop's "look for 3 things" pass.

    python tools/contact_sheet.py <run> <t_from> <t_to> [--cols 5] [--width 360] [--out PATH]

Snaps are named by physics frame (60/s), so t = frame / 60. Read the event log for
the times first (`python tools/autoplay.py x.json --events cutscene,step`).
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
OUT_DIR = REPO / "autoplay_out"
FPS = 60


def build(run: str, t_from: float, t_to: float, cols: int = 5, width: int = 360, out: Path | None = None) -> str:
    snaps = []
    for f in sorted(OUT_DIR.glob(f"{run}_f*.png")):
        m = re.search(r"_f(\d+)\.png$", f.name)
        if m and t_from <= int(m.group(1)) / FPS <= t_to:
            snaps.append((int(m.group(1)) / FPS, f))
    if not snaps:
        return f"no snaps for {run} in {t_from}-{t_to}s (windowed run with snap_every?)"
    tiles = []
    for t, f in snaps:
        im = Image.open(f).convert("RGB")
        im = im.resize((width, int(im.height * width / im.width)))
        ImageDraw.Draw(im).text((6, 6), f"t={t:.2f}", fill=(255, 0, 255))
        tiles.append(im)
    h = tiles[0].height
    sheet = Image.new("RGB", (width * cols, h * ((len(tiles) + cols - 1) // cols)))
    for i, im in enumerate(tiles):
        sheet.paste(im, ((i % cols) * width, (i // cols) * h))
    out = out or OUT_DIR / f"{run}_sheet_{t_from:g}-{t_to:g}.jpg"
    sheet.save(out, quality=88)
    return f"{len(tiles)} tiles -> {out}"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    ap.add_argument("t_from", type=float)
    ap.add_argument("t_to", type=float)
    ap.add_argument("--cols", type=int, default=5)
    ap.add_argument("--width", type=int, default=360)
    ap.add_argument("--out")
    a = ap.parse_args()
    print(build(a.run, a.t_from, a.t_to, a.cols, a.width, Path(a.out) if a.out else None))


if __name__ == "__main__":
    main()
