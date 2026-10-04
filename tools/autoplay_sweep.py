"""Balance sweep: run one autoplay fight per (character, seed) WITHOUT god mode and
print a table of how far each got. Used to tune the boss (BossRules) — the bot never
dodges, so read it as a pessimistic floor: a fight the bot nearly wins is one a person
wins with a little dodging.

    python tools/autoplay_sweep.py                                # all chars, seed 1, boss room
    python tools/autoplay_sweep.py --chars Ryan,Robot --seeds 1,2,3
    python tools/autoplay_sweep.py --scene res://scenes/main.tscn --steps "brain advance 300"
    python tools/autoplay_sweep.py --base test/autoplay/full_run_mortal.json --chars Ryan,Cass --seeds 1,2,3,4

--base reruns a whole scenario (e.g. a mortal street-to-boss route) per char/seed; the
street_hits / boss_hits / door_hp columns then show where the run was lost.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "autoplay_out"
CHARS = "Ryan,Cody,Sara,Cass,Caitlyn,Robot"
COLS = ["won", "boss_hp", "t", "hits_taken", "car_hits", "heals", "kills", "deaths", "errors", "engine_errors"]
SPLIT = ["street_hits", "boss_hits", "door_hp"]


def split(events: list, start_hp) -> dict:
    """Hits taken before/after entering the boss room, and hp walking through its door."""
    out, hp, scene = {"street_hits": 0, "boss_hits": 0, "door_hp": "-"}, start_hp, ""
    for e in events:
        if e["ev"] == "scene":
            scene = e["scene"]
            if scene == "boss_room" and out["door_hp"] == "-":
                out["door_hp"] = hp
        elif e["ev"] in ("hurt", "heal"):
            hp = e["hp"]
            if e["ev"] == "hurt":
                out["boss_hits" if scene == "boss_room" else "street_hits"] += 1
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chars", default=CHARS)
    ap.add_argument("--seeds", default="1")
    ap.add_argument("--scene", default="res://scenes/boss_room.tscn")
    ap.add_argument("--steps", default="brain advance 140")
    ap.add_argument("--timeout", type=float, default=150)
    ap.add_argument("--base", help="scenario JSON to rerun per char/seed (overrides --scene/--steps/--timeout)")
    a = ap.parse_args()
    OUT.mkdir(exist_ok=True)
    print("char      seed " + " ".join(f"{c:>12}" for c in COLS + SPLIT))
    bad = False
    for c in a.chars.split(","):
        for s in a.seeds.split(","):
            name = f"sweep_{c}_{s}"
            path = OUT / f"{name}.scenario.json"
            sc = {"scene": a.scene, "timeout": a.timeout, "steps": [a.steps]}
            if a.base:
                sc = json.loads(Path(a.base).read_text(encoding="utf-8"))
            sc.update({"name": name, "character": c, "seed": int(s), "expect": []})
            path.write_text(json.dumps(sc))
            subprocess.run([sys.executable, str(REPO / "tools" / "autoplay.py"), str(path)],
                           capture_output=True, text=True)
            report = OUT / f"{name}.json"
            if not report.exists():
                print(f"{c:<9} {s:>4}  NO REPORT")
                bad = True
                continue
            r = json.loads(report.read_text(encoding="utf-8"))
            m = r["metrics"]
            m.update(split(r["events"], "start"))
            bad = bad or m["errors"] > 0 or m["engine_errors"] > 0
            print(f"{c:<9} {s:>4} " + " ".join(f"{m.get(k, ''):>12}" for k in COLS + SPLIT), flush=True)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
