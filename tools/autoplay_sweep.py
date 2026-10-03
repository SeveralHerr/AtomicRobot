"""Balance sweep: run one autoplay fight per (character, seed) WITHOUT god mode and
print a table of how far each got. Used to tune the boss (BossRules) — the bot never
dodges, so read it as a pessimistic floor: a fight the bot nearly wins is one a person
wins with a little dodging.

    python tools/autoplay_sweep.py                                # all chars, seed 1, boss room
    python tools/autoplay_sweep.py --chars Ryan,Robot --seeds 1,2,3
    python tools/autoplay_sweep.py --scene res://scenes/main.tscn --steps "brain advance 300"
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "autoplay_out"
CHARS = "Ryan,Cody,Sara,Cass,Caitlyn,Robot"
COLS = ["won", "boss_hp", "t", "hits_taken", "heals", "kills", "deaths", "errors", "engine_errors"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chars", default=CHARS)
    ap.add_argument("--seeds", default="1")
    ap.add_argument("--scene", default="res://scenes/boss_room.tscn")
    ap.add_argument("--steps", default="brain advance 140")
    ap.add_argument("--timeout", type=float, default=150)
    a = ap.parse_args()
    OUT.mkdir(exist_ok=True)
    print("char      seed " + " ".join(f"{c:>12}" for c in COLS))
    bad = False
    for c in a.chars.split(","):
        for s in a.seeds.split(","):
            name = f"sweep_{c}_{s}"
            path = OUT / f"{name}.scenario.json"
            path.write_text(json.dumps({"name": name, "scene": a.scene, "character": c, "seed": int(s),
                                        "timeout": a.timeout, "steps": [a.steps], "expect": []}))
            subprocess.run([sys.executable, str(REPO / "tools" / "autoplay.py"), str(path)],
                           capture_output=True, text=True)
            report = OUT / f"{name}.json"
            if not report.exists():
                print(f"{c:<9} {s:>4}  NO REPORT")
                bad = True
                continue
            m = json.loads(report.read_text(encoding="utf-8"))["metrics"]
            bad = bad or m["errors"] > 0 or m["engine_errors"] > 0
            print(f"{c:<9} {s:>4} " + " ".join(f"{m.get(k, ''):>12}" for k in COLS), flush=True)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
