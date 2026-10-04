"""Find always-on colliders that wall off the ROAD lanes of main.tscn.

Road-lane bodies (lanes 1-3) drop Ground/Meter/Platforms from their mask but keep Wall
(64), so a walkway prop on the Wall layer blocks every lane while its art sits only on
the walkway: an invisible wall. That was the crate stack at x~2858 (layer 66).

    python tools/lane_wall_audit.py            # exit 1 if any unexpected body is found

Door-encounter barriers and the level-edge boundaries are expected (barriers are only
enabled during a lock-in) and are listed separately.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get(
    "GODOT",
    r"C:\Users\gotmi\Downloads\Godot_v4.7.1_fixed\Godot_v4.7.1-stable_win64_console.exe",
)
WALL_BIT = 64
# Road-lane player boxes span roughly y -30 (lane 1 head) .. +72 (lane 3 feet).
ROAD_TOP_Y = -20.0
EXPECTED = ("/Barriers/", "Boundary/")


def scan(dump: dict) -> tuple[list[str], list[str]]:
    bad, expected = [], []
    for b in dump["collision_bodies"]:
        if not b["collision_layer"] & WALL_BIT or b.get("one_way"):
            continue
        sh, (x, y) = b["shape"], b["world_position"]
        if sh.get("type") != "Rectangle":
            bad.append(f"{b['path']}: non-rect {sh.get('type')} on Wall layer - check by hand")
            continue
        w, h = sh["size"]
        if y + h / 2 <= ROAD_TOP_Y:
            continue
        line = f"{b['path']}  x={x - w / 2:.0f}..{x + w / 2:.0f}  y={y - h / 2:.0f}..{y + h / 2:.0f}  layer={b['collision_layer']}"
        (expected if any(k in b["path"] for k in EXPECTED) else bad).append(line)
    return bad, expected


def main() -> int:
    out = os.path.join(tempfile.gettempdir(), "lane_wall_dump.json")
    subprocess.run([GODOT, "--headless", "--path", ROOT, "--script", "res://tools/dump_level.gd",
                    "--", "--scene", "res://scenes/main.tscn", "--out", out],
                   capture_output=True, timeout=300)
    with open(out, encoding="utf-8") as f:
        bad, expected = scan(json.load(f))
    print(f"expected (barriers/boundaries): {len(expected)}")
    for line in bad:
        print("INVISIBLE WALL?", line)
    print("OK: no road-lane walls" if not bad else f"{len(bad)} suspect body(ies)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
