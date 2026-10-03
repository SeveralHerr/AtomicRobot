#!/usr/bin/env python3
"""Run autoplay bot scenarios (test/autoplay/*.json) and print their summaries.

The bot drives the real game with real key events (tools/autoplay/). Each run
prints a short summary and writes autoplay_out/<name>.json with the event log.

    python tools/autoplay.py                      # every scenario in test/autoplay/
    python tools/autoplay.py smoke boss           # name substrings
    python tools/autoplay.py path/to/x.json       # a specific file
    python tools/autoplay.py full_run --window    # windowed: screenshots work
    python tools/autoplay.py smoke --events hurt,stuck,death   # print those events
    python tools/autoplay.py smoke -v             # full Godot output

Exit code: 0 all passed, 1 a scenario failed, 2 a scenario was invalid (BROKEN).
Headless runs use --fixed-fps 60: deterministic game time, faster than real time.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

from run_sandbox_selftests import find_godot

REPO = Path(__file__).resolve().parent.parent
SCENARIO_DIR = REPO / "test" / "autoplay"
OUT_DIR = REPO / "autoplay_out"
WALL_TIMEOUT = 900

SUMMARY_RE = re.compile(r"^(AUTOPLAY |  \S|    \d|RESULT: )")
RESULT_RE = re.compile(r"^RESULT:\s*(PASS|FAIL|BROKEN)", re.M)
NAME_RE = re.compile(r"^AUTOPLAY (\S+)", re.M)


def targets(filters: list[str]) -> list[Path]:
    found = sorted(SCENARIO_DIR.glob("*.json"))
    if not filters:
        return found
    out = []
    for f in filters:
        p = Path(f)
        if p.suffix == ".json" and p.exists():
            out.append(p.resolve())
        else:
            out += [s for s in found if f.lower() in s.stem.lower() and s not in out]
    return out


def run_one(godot: str, source: str, window: bool, verbose: bool, resolution: str = "") -> tuple[str, str, str]:
    """Returns (status, report name, output to print)."""
    cmd = [godot, "--path", str(REPO), "--mute", "--fixed-fps", "60"]
    if not window:
        cmd.insert(1, "--headless")
    if resolution:
        cmd += ["--resolution", resolution]
    # `source` may be inline JSON: list-form argv passes it through unquoted-safe.
    cmd += ["--", "--autoplay", source, "--autoplay-out", str(OUT_DIR)]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=WALL_TIMEOUT,
                              encoding="utf-8", errors="replace")
    except subprocess.TimeoutExpired:
        return "TIMEOUT", "?", f"no result within {WALL_TIMEOUT}s wall clock"
    out = (proc.stdout or "") + (proc.stderr or "")
    m = RESULT_RE.search(out)
    status = m.group(1) if m else ("ERROR" if "SCRIPT ERROR" in out else "NO-RESULT")
    # A crash after the summary printed must not read as a pass.
    if status == "PASS" and proc.returncode != 0:
        status = f"EXIT-{proc.returncode}"
    # A script that fails to PARSE never runs, so the in-game error counter never sees
    # it — the run "passes" with the feature silently missing. Catch it from stdout.
    if status == "PASS" and ("Parse Error" in out or "Failed to load script" in out):
        status = "SCRIPT-ERROR"
    n = NAME_RE.search(out)
    name = n.group(1) if n else "?"
    if verbose:
        return status, name, out
    keep = [ln for ln in out.splitlines() if SUMMARY_RE.match(ln) or "scenario error" in ln]
    if status in ("ERROR", "NO-RESULT", "SCRIPT-ERROR"):
        keep += [ln for ln in out.splitlines() if "ERROR" in ln][:15]
    return status, name, "\n".join(keep)


def print_events(name: str, kinds: list[str]) -> None:
    report = OUT_DIR / f"{name}.json"
    if not report.exists():
        return
    for e in json.loads(report.read_text(encoding="utf-8"))["events"]:
        if e["ev"] in kinds:
            rest = " ".join(f"{k}={v}" for k, v in e.items() if k not in ("t", "ev"))
            print(f"    {e['t']:>8} {e['ev']:<12} {rest}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filters", nargs="*", help="scenario name substrings or .json paths")
    ap.add_argument("--inline", help="a scenario as a JSON string (bash quoting; in PowerShell use a file)")
    ap.add_argument("--window", action="store_true", help="run windowed so snaps are saved")
    ap.add_argument("--events", help="comma list of event kinds to print after each run, "
                                     "e.g. hurt,stuck,death,step_failed,why")
    ap.add_argument("--resolution", default="", help="windowed size WxH, e.g. 1688x780 (landscape phone)")
    ap.add_argument("-v", "--verbose", action="store_true", help="print full Godot output")
    args = ap.parse_args()

    godot = find_godot()
    OUT_DIR.mkdir(exist_ok=True)
    # Keep Godot from importing the screenshots as project assets.
    (OUT_DIR / ".gdignore").touch()
    sources: list[str] = []
    if args.inline:
        sources.append(args.inline)
    if args.filters or not args.inline:
        sources += [str(p) for p in targets(args.filters)]
    if not sources:
        print(f"no scenarios matched {args.filters} in {SCENARIO_DIR}")
        return 2

    failures, broken = [], False
    for src in sources:
        started = time.time()
        status, name, out = run_one(godot, src, args.window, args.verbose, args.resolution)
        print(out)
        if args.events:
            print_events(name, args.events.split(","))
        print(f"[{'ok  ' if status == 'PASS' else 'FAIL'}] {name} {status} ({time.time() - started:.0f}s wall)\n")
        if status != "PASS":
            failures.append(name)
            broken = broken or status == "BROKEN"
    if failures:
        print(f"{len(failures)}/{len(sources)} scenario(s) failed: {', '.join(failures)}")
        return 2 if broken else 1
    print(f"all {len(sources)} scenario(s) passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
