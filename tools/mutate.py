#!/usr/bin/env python3
"""Hand-picked mutation check: apply one mutant at a time, run the unit tests that
should catch it, restore the file. Exit 1 if any mutant survives.

    python tools/mutate.py mutants.json

mutants.json is a list of [file, original, mutant, filter] rows; `filter` is a
run_tests.gd --filter substring of the test METHOD names that must kill it (a
filter that matches no test reports the mutant as SURVIVED, with Total: 0).
Files are read/written as UTF-8 bytes-exact (Windows' default codepage once
corrupted a script's em dashes).
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from run_sandbox_selftests import find_godot

REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    rows = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    godot = find_godot()
    survivors = 0
    for file, original, mutant, flt in rows:
        path = REPO / file
        src = path.read_bytes()
        text = src.decode("utf-8")
        if original not in text:
            print(f"MISSING  {file}: {original!r}")
            survivors += 1
            continue
        path.write_bytes(text.replace(original, mutant, 1).encode("utf-8"))
        try:
            proc = subprocess.run([godot, "--headless", "--path", str(REPO), "--script",
                                   "res://tools/run_tests.gd", "--", "--filter", flt],
                                  capture_output=True, text=True, encoding="utf-8", errors="replace")
        finally:
            path.write_bytes(src)
        total = next((l for l in proc.stdout.splitlines() if l.startswith("Total")), "no total")
        killed = proc.returncode != 0
        survivors += 0 if killed else 1
        print(f"{'KILLED  ' if killed else 'SURVIVED'} {file}: {mutant[:60]!r}  [{total}]")
    print(f"{len(rows) - survivors}/{len(rows)} killed")
    return 1 if survivors else 0


if __name__ == "__main__":
    sys.exit(main())
