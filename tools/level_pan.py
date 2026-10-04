#!/usr/bin/env python3
"""Pan the bot across the level and tile one labelled snap per world x into a sheet.

Answers "where on the map is this screenshot?" — match a player's phone screenshot
to the tile whose x label shows the same buildings, then read positions from
tools/dump_level.gd for that range.

    python tools/level_pan.py [--from -1400] [--to 7800] [--step 450] [--out PATH]

Windowed (snaps need a renderer): a few seconds of wall time for the whole street.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
OUT_DIR = REPO / "autoplay_out"
NAME = "level_pan"


def xs(x_from: int, x_to: int, step: int) -> list[int]:
    if step <= 0 or x_to < x_from:
        raise ValueError("need step > 0 and to >= from")
    out = list(range(x_from, x_to + 1, step))
    return out[:60]  # one bot run; 60 tiles is already a big sheet


def scenario(points: list[int]) -> dict:
    steps = ["god on", "kill_all"]
    for x in points:
        steps += [f"teleport {x}", "kill_all", "wait 0.6", f"snap x{x}"]
    return {"timeout": 30 + 2 * len(points), "steps": steps, "expect": []}


def build(x_from: int = -1400, x_to: int = 7800, step: int = 450, out: Path | None = None) -> str:
    points = xs(x_from, x_to, step)
    OUT_DIR.mkdir(exist_ok=True)
    spec = OUT_DIR / f"{NAME}.json"  # not test/autoplay: the report would overwrite it
    spec.write_text(json.dumps(scenario(points)))
    run = subprocess.run([sys.executable, str(REPO / "tools" / "autoplay.py"), str(spec), "--window"],
                         cwd=REPO, capture_output=True, text=True, encoding="utf-8", errors="replace")
    tiles = []
    for x in points:
        f = OUT_DIR / f"{NAME}_x{x}.png"
        if not f.exists():
            continue
        im = Image.open(f).convert("RGB")
        im = im.resize((im.width // 3, im.height // 3))
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 64, 16), fill=(0, 0, 0))
        d.text((3, 3), str(x), fill=(255, 255, 0))
        tiles.append(im)
    if not tiles:
        return "no snaps produced:\n" + (run.stdout + run.stderr)[-1500:]
    cols = 4
    w, h = tiles[0].size
    sheet = Image.new("RGB", (w * cols, h * ((len(tiles) + cols - 1) // cols)))
    for i, im in enumerate(tiles):
        sheet.paste(im, ((i % cols) * w, (i // cols) * h))
    out = out or OUT_DIR / f"{NAME}_sheet.jpg"
    sheet.save(out, quality=85)
    return str(out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--from", dest="x_from", type=int, default=-1400)
    ap.add_argument("--to", dest="x_to", type=int, default=7800)
    ap.add_argument("--step", type=int, default=450)
    ap.add_argument("--out", type=Path)
    a = ap.parse_args()
    print(build(a.x_from, a.x_to, a.step, a.out))
