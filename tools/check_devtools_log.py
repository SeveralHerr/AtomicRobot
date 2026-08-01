#!/usr/bin/env python3
"""Claude Code `Stop` hook: keep the devtools gaps log honest.

Installed by `/scaffold-godot-harness`. On every Stop event it asks one question:
did this session touch Godot code without adding an entry to `log-devtools.md`?
If so it prints a `systemMessage` reminder. It is **advisory by default** — it
warns, it does not fail or restart the turn.

Why a hook at all: the "append a gap entry every response" convention is a
prompt-level instruction with no enforcement, so it silently decays. The hook is
the only part of the loop that cannot forget.

Config (all optional) is read from `addons/godot_selftest/devtools_config.json`:

    "log_files":        ["log-devtools.md"]   # files that must change alongside code
    "log_check_globs":  []                    # extra path substrings counted as "code"
    "log_check_block":  false                 # true -> block the Stop instead of warning

Set `log_check_block` to true only if the advisory reminder proves easy to ignore;
a blocking Stop hook forces the model to continue the turn, which costs a round trip
every time it fires.

Exit code is always 0 — a broken reminder must never break a session.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

DEFAULT_LOG_FILES = ["log-devtools.md"]

# Game-agnostic: match by file type and by the harness's own directories rather than
# by folder names like "scenes/" or "sprites/", which differ per project.
CODE_SUFFIXES = {
    ".gd", ".cs", ".tscn", ".tres", ".res", ".gdshader", ".shader",
    ".gdextension", ".import", ".cfg",
}
CODE_PATHS = ("addons/", "devtools_ext/", "tools/", "test/")
CODE_FILES = ("project.godot",)

GRACE = 10  # seconds; git must never hang a Stop hook


def _git(root, *args):
    try:
        out = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True, text=True, timeout=GRACE,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    return out.stdout


def _changed_files(root):
    """Every file this working session could plausibly have touched.

    Union of (a) the uncommitted working tree and (b) commits on this branch that
    are not on the base branch. (b) matters because the log entry and the code often
    land in different commits of the same session.
    """
    changed = set()

    status = _git(root, "status", "--porcelain", "--untracked-files=all")
    if status is None:
        return None  # not a git repo, or git unavailable -> stay silent
    for line in status.splitlines():
        path = line[3:].strip()
        if " -> " in path:  # renames: "old -> new"
            path = path.split(" -> ", 1)[1]
        if path:
            changed.add(path.strip('"'))

    base = None
    for ref in ("origin/main", "main", "origin/master", "master"):
        merge_base = _git(root, "merge-base", "HEAD", ref)
        if merge_base and merge_base.strip():
            base = merge_base.strip()
            break
    if base:
        diff = _git(root, "diff", "--name-only", base, "HEAD")
        if diff:
            changed.update(p for p in (l.strip() for l in diff.splitlines()) if p)

    return changed


def _is_code(path):
    p = path.replace("\\", "/")
    if p.endswith(".md"):
        return False
    if os.path.basename(p) in CODE_FILES:
        return True
    if Path(p).suffix.lower() in CODE_SUFFIXES:
        return True
    return any(seg in p for seg in CODE_PATHS)


def _load_config(root):
    cfg_path = root / "addons" / "godot_selftest" / "devtools_config.json"
    try:
        cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return DEFAULT_LOG_FILES, [], False
    logs = cfg.get("log_files") or DEFAULT_LOG_FILES
    extra = cfg.get("log_check_globs") or []
    block = bool(cfg.get("log_check_block", False))
    return list(logs), list(extra), block


def main():
    root = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    log_files, extra_paths, block = _load_config(root)

    changed = _changed_files(root)
    if not changed:
        return  # nothing changed, or not a git repo

    def is_code(path):
        return _is_code(path) or any(
            seg in path.replace("\\", "/") for seg in extra_paths
        )

    if not any(is_code(p) for p in changed):
        return  # docs-only turn; the convention still applies but is not enforceable here

    normalized = {p.replace("\\", "/") for p in changed}
    missing = [f for f in log_files if f not in normalized]
    if not missing:
        return

    msg = (
        "Devtools log reminder: this session changed Godot code but has not updated "
        + ", ".join(missing)
        + ". Append an entry describing any gaps in /verify or the devtools harness that "
        "would have helped with this task (plus a suggested improvement for each), or an "
        "explicit 'no gaps this turn' line. See the file's own Format section."
    )

    if block:
        print(json.dumps({"decision": "block", "reason": msg}))
    else:
        print(json.dumps({"systemMessage": msg}))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # never break a session over a reminder
        print(f"check_devtools_log: skipped ({exc})", file=sys.stderr)
    sys.exit(0)
