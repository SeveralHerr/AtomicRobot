"""Audit every fighter's SpriteFrames against the roster: animation set, loop flags, fps,
and where each frame stands in its cell (feet line, leg centre). The player's collision
and hit area are shared, so a new sheet must stand where the others do.

    python tools/fighter_frames_audit.py                 # every sprites/*_sprite_frames.tres
    python tools/fighter_frames_audit.py sprites/payton_sprite_frames.tres

Per animation: frames, loop, fps, then "legs dx / feet dy" from the cell centre for the
first 3 frames. Regions may hang off the atlas (a negative x shifts art right); the
missing part reads as transparent, as Godot draws it.
"""
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def parse(path: Path) -> dict:
    t = path.read_text(encoding="utf8")
    ext = {m[1]: m[0] for m in re.findall(r'path="res://([^"]+)" id="([^"]+)"', t)}
    subs = {}
    for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([^)]*)\)', t):
        subs[m[1]] = (ext[m[2]], [float(v) for v in m[3].split(",")])
    anims = {}
    for m in re.finditer(r'"frames": \[(.*?)\],\s*"loop": (\w+),\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)', t, re.S):
        ids = re.findall(r'SubResource\("([^"]+)"\)', m[1])
        anims[m[3]] = dict(loop=m[2] in ("true", "1"), fps=float(m[4]), frames=[subs[i] for i in ids])
    return anims


_imgs: dict = {}


def cell(img_path: str, x: float, y: float, w: float, h: float) -> np.ndarray:
    if img_path not in _imgs:
        _imgs[img_path] = np.array(Image.open(ROOT / img_path).convert("RGBA"))[..., 3]
    a = _imgs[img_path]
    out = np.zeros((int(h), int(w)), a.dtype)
    x0, y0 = int(x), int(y)
    sx0, sy0 = max(x0, 0), max(y0, 0)
    sx1, sy1 = min(x0 + int(w), a.shape[1]), min(y0 + int(h), a.shape[0])
    if sx1 > sx0 and sy1 > sy0:
        out[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = a[sy0:sy1, sx0:sx1]
    return out


def stance(alpha: np.ndarray) -> str:
    ys, xs = np.nonzero(alpha)
    if not len(xs):
        return "EMPTY"
    legs = ys > ys.max() - 10
    h, w = alpha.shape
    return f"legs{(xs[legs].min() + xs[legs].max()) / 2 - w / 2:+.0f}/feet{ys.max() - h / 2:+.0f}"


def main() -> None:
    paths = [Path(p) for p in sys.argv[1:]] or sorted((ROOT / "sprites").glob("*_sprite_frames.tres"))
    for p in paths:
        anims = parse(p if p.is_absolute() else ROOT / p)
        print(f"== {p.name}")
        for name in sorted(anims):
            a = anims[name]
            st = " ".join(stance(cell(img, *r)) for img, r in a["frames"][:3])
            print(f"  {name:7} n={len(a['frames']):2} loop={int(a['loop'])} fps={a['fps']:4.1f}  {st}")


if __name__ == "__main__":
    main()
