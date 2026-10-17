"""Play one autoplay scenario windowed at several screen sizes; build a states x aspects sheet.

    python tools/aspect_sweep.py                       # tools/aspect/tour.json at every ASPECTS size
    python tools/aspect_sweep.py my.json --sizes 1024x768,1688x780
    python tools/aspect_sweep.py --crt                 # same, CRT overlay forced on

stretch aspect "expand" grows the 1280x800 canvas along the free axis, so each size shows
a differently shaped screen. Tiles keep their real shape (same height), so a HUD that
drifts or a backdrop that stops short shows up as a ragged column. Snaps of one run are
named `<name>_<label>.png`; every size gets its own name so runs never overwrite.
Output: autoplay_out/aspect/sheet.png (+ one PNG per state row).
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "autoplay_out"
TOUR = REPO / "tools" / "aspect" / "tour.json"
## Picade 4:3, 5:4 monitor, 16:10 design (must match the old look), 16:9, landscape phone.
ASPECTS = ["1024x768", "1280x1024", "1280x800", "1920x1080", "1688x780"]
TILE_H = 300


def run(scenario: dict, size: str, crt: bool) -> tuple[str, str]:
    sc = dict(scenario)
    sc["name"] = f"{scenario.get('name', 'aspect')}_{size}"
    for old in OUT.glob(f"{sc['name']}_*.png"):
        old.unlink()  # a stale snap from an earlier run would pass for this one
    if crt:
        sc["steps"] = ["crt on"] + list(sc.get("steps", []))
    proc = subprocess.run([sys.executable, str(REPO / "tools" / "autoplay.py"), "--inline", json.dumps(sc),
                           "--window", "--resolution", size], capture_output=True, text=True)
    last = [ln for ln in proc.stdout.splitlines() if ln.startswith("[")]
    return sc["name"], (last[-1] if last else proc.stdout[-300:])


def sheet(names: dict[str, str], labels: list[str]) -> Path:
    rows = []
    for label in labels:
        tiles = []
        for size, name in names.items():
            png = OUT / f"{name}_{label}.png"
            if png.exists():
                im = Image.open(png).convert("RGB")
                im = im.resize((round(im.width * TILE_H / im.height), TILE_H))
            else:
                im = Image.new("RGB", (TILE_H * 4 // 3, TILE_H), (60, 0, 0))
            ImageDraw.Draw(im).text((6, 4), f"{label} {size}", fill=(255, 255, 0))
            tiles.append(im)
        row = Image.new("RGB", (sum(t.width for t in tiles) + 8 * len(tiles), TILE_H), (20, 20, 20))
        x = 0
        for t in tiles:
            row.paste(t, (x, 0))
            x += t.width + 8
        (OUT / "aspect").mkdir(exist_ok=True)
        row.save(OUT / "aspect" / f"row_{label}.png")
        rows.append(row)
    out = Image.new("RGB", (max(r.width for r in rows), (TILE_H + 8) * len(rows)), (20, 20, 20))
    for i, r in enumerate(rows):
        out.paste(r, (0, i * (TILE_H + 8)))
    path = OUT / "aspect" / "sheet.png"
    out.save(path)
    return path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scenario", nargs="?", default=str(TOUR))
    ap.add_argument("--sizes", default=",".join(ASPECTS))
    ap.add_argument("--crt", action="store_true", help="force the CRT overlay on (it hides ~40px of each edge)")
    args = ap.parse_args()
    scenario = json.loads(Path(args.scenario).read_text(encoding="utf-8"))
    names = {}
    for size in args.sizes.split(","):
        names[size], status = run(scenario, size, args.crt)
        print(f"{size:>10}  {status}")
    # Named snaps plus `snap_every` ones (t0045...): rows are every label any size produced.
    labels = sorted({p.stem[len(n) + 1:] for n in names.values() for p in OUT.glob(f"{n}_*.png")})
    print("sheet:", sheet(names, labels))
    return 0


if __name__ == "__main__":
    sys.exit(main())
