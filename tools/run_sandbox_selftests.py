#!/usr/bin/env python3
"""Run every enemy-behaviour sandbox in test/scenes/ headless and report.

The unit runner (tools/run_tests.gd) runs isolated tests in a bare tree. Enemy AI bugs are multi-frame — an enemy that stops moving, a swing that
never closes, a maid that walks backwards — so those are checked here instead, by
running each sandbox scene for a few seconds with real autoloads and asserting on
sampled behaviour (test/scenes/sandbox_selftest.gd).

    python tools/run_sandbox_selftests.py                 # all scenarios
    python tools/run_sandbox_selftests.py melee ranged    # name substrings
    python tools/run_sandbox_selftests.py -v              # full child output

Exit code is 0 only if every scenario reports PASS.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCENE_DIR = REPO / "test" / "scenes"

# Godot 4.7 is not on PATH on the dev machine (see CLAUDE.md); allow an override.
DEFAULT_GODOT = Path(r"C:\Users\gotmi\Downloads\Godot_v4.7.1_fixed\Godot_v4.7.1-stable_win64_console.exe")

# Each scenario samples for WARMUP + DURATION seconds of physics time; give it
# generous headroom for engine start-up and resource import.
PER_SCENE_TIMEOUT = 90

RESULT_RE = re.compile(r"RESULT:\s*(PASS|FAIL)")
NOISE_RE = re.compile(
    r"invalid UID|Concave polygon|Requested V-Sync|^Godot Engine|"
    r"were leaked at exit|resources still in use|^\s+at: |^Enemy state|"
    r"^Project FPS|^dead af|^hit player|^-?\d+$"
)


def find_godot() -> str:
    override = os.environ.get("GODOT")
    if override:
        return override
    if DEFAULT_GODOT.exists():
        return str(DEFAULT_GODOT)
    return "godot"


def scenes(filters: list[str]) -> list[Path]:
    found = sorted(SCENE_DIR.glob("*.tscn"))
    if not filters:
        return found
    return [p for p in found if any(f.lower() in p.stem.lower() for f in filters)]


def run_one(godot: str, scene: Path, verbose: bool) -> tuple[str, str]:
    """Returns (status, captured_output)."""
    res_path = "res://" + scene.relative_to(REPO).as_posix()
    cmd = [godot, "--headless", "--path", str(REPO), "--mute", res_path,
           "--", "--sandbox-selftest"]
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=PER_SCENE_TIMEOUT)
    except subprocess.TimeoutExpired:
        return "TIMEOUT", f"no RESULT within {PER_SCENE_TIMEOUT}s"

    out = (proc.stdout or "") + (proc.stderr or "")
    if verbose:
        return _status(out), out

    keep = [ln for ln in out.splitlines()
            if ln.strip() and not NOISE_RE.search(ln)]
    return _status(out), "\n".join(keep)


def _status(out: str) -> str:
    m = RESULT_RE.search(out)
    if m:
        return m.group(1)
    if "SCRIPT ERROR" in out or "Parse Error" in out:
        return "ERROR"
    return "NO-RESULT"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filters", nargs="*", help="scene-name substrings to run")
    ap.add_argument("-v", "--verbose", action="store_true",
                    help="print the full child process output")
    args = ap.parse_args()

    godot = find_godot()
    targets = scenes(args.filters)
    if not targets:
        print(f"no sandbox scenes matched {args.filters} in {SCENE_DIR}")
        return 2

    failures = []
    for scene in targets:
        started = time.time()
        status, out = run_one(godot, scene, args.verbose)
        elapsed = time.time() - started
        mark = "ok  " if status == "PASS" else "FAIL"
        print(f"[{mark}] {scene.stem:<20} {status:<10} {elapsed:5.1f}s")
        if status != "PASS":
            failures.append(scene.stem)
            for line in out.splitlines():
                print("        " + line)
        elif args.verbose:
            for line in out.splitlines():
                print("        " + line)

    print()
    if failures:
        print(f"{len(failures)}/{len(targets)} scenario(s) FAILED: {', '.join(failures)}")
        return 1
    print(f"all {len(targets)} sandbox scenarios passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
