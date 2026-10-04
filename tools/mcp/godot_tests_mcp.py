"""Minimal stdio MCP server: run this project's Godot test suites and get a short summary.

Dependency-free (no `mcp` package): speaks newline-delimited JSON-RPC 2.0 on stdio.
Tools:
  run_unit_tests(filter?)   -> "Total: ..." line plus every FAIL/BROKEN/SCRIPT ERROR line
  run_sandbox_selftests()   -> the sandbox runner's per-scenario table
  run_autoplay(filter?)     -> bot-playthrough summaries (test/autoplay/*.json name substrings)
  audit_lane_walls()        -> Wall-layer colliders that block the road lanes (invisible walls)
  record_autoplay(filter)   -> one scenario recorded to autoplay_out/<filter>.mp4 (Movie Maker)
  contact_sheet(run, t_from, t_to) -> one JPEG of a windowed run's snaps between two game times
  level_pan(x_from?, x_to?, step?) -> one JPEG, a labelled snap per world x (map a screenshot to x)

Godot path: $GODOT, else the path documented in CLAUDE.md.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.environ.get(
    "GODOT",
    r"C:\Users\gotmi\Downloads\Godot_v4.7.1_fixed\Godot_v4.7.1-stable_win64_console.exe",
)
# Filters are test-method substrings; refuse anything else so no argument can smuggle
# extra command-line flags into the Godot process.
FILTER_RE = re.compile(r"^[A-Za-z0-9_]{0,80}$")

TOOLS = [
    {
        "name": "run_unit_tests",
        "description": "Run test/unit/test_*.gd headless. Optional filter = test-method substring.",
        "inputSchema": {"type": "object", "properties": {"filter": {"type": "string"}}},
    },
    {
        "name": "run_sandbox_selftests",
        "description": "Boot every test/scenes sandbox for ~5s of real physics and report pass/fail.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "run_autoplay",
        "description": "Run autoplay bot scenarios headless (test/autoplay/*.json). Optional filter = "
                       "scenario-name substring, e.g. full_run. Returns each run's summary.",
        "inputSchema": {"type": "object", "properties": {"filter": {"type": "string"}}},
    },
    {
        "name": "record_autoplay",
        "description": "Record ONE autoplay scenario (name substring, e.g. completionist) to "
                       "autoplay_out/<filter>.mp4 with sound, windowed. Real-time-ish: ~3 min for a full run.",
        "inputSchema": {"type": "object", "properties": {"filter": {"type": "string"}},
                        "required": ["filter"]},
    },
    {
        "name": "contact_sheet",
        "description": "Tile a windowed autoplay run's snaps (autoplay_out/<run>_f*.png) between "
                       "t_from and t_to game seconds into one labelled JPEG; returns its path to Read.",
        "inputSchema": {"type": "object", "properties": {
            "run": {"type": "string"}, "t_from": {"type": "number"}, "t_to": {"type": "number"}},
            "required": ["run", "t_from", "t_to"]},
    },
    {
        "name": "level_pan",
        "description": "Teleport the bot along the street and tile one snap per world x into a "
                       "labelled JPEG (find where a player's screenshot was taken). Defaults "
                       "-1400..7800 step 450; returns the sheet path to Read.",
        "inputSchema": {"type": "object", "properties": {
            "x_from": {"type": "integer"}, "x_to": {"type": "integer"}, "step": {"type": "integer"}}},
    },
    {
        "name": "audit_lane_walls",
        "description": "List always-on Wall-layer colliders in main.tscn that reach the road lanes "
                       "(invisible walls). Barriers/boundaries are reported as expected.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def run_unit_tests(filter_: str = "") -> str:
    if not FILTER_RE.match(filter_):
        return "filter must be letters, digits or _ only"
    cmd = [GODOT, "--headless", "--path", ROOT, "--script", "res://tools/run_tests.gd"]
    if filter_:
        cmd += ["--", "--filter", filter_]
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                         errors="replace", timeout=900).stdout
    keep = [l for l in out.splitlines()
            if re.match(r"\s*(FAIL|BROKEN)", l) or "SCRIPT ERROR" in l or l.startswith("Total:")]
    return "\n".join(keep) or out[-2000:]


def run_sandbox_selftests() -> str:
    out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "run_sandbox_selftests.py")],
                         cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                         errors="replace", timeout=900)
    return "\n".join((out.stdout + out.stderr).splitlines()[-15:])


def _py(script: str, *args: str) -> str:
    out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", script), *args],
                         cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                         errors="replace", timeout=1800)
    return out.stdout + out.stderr


def run_autoplay(filter_: str = "") -> str:
    if not FILTER_RE.match(filter_):
        return "filter must be letters, digits or _ only"
    out = _py("autoplay.py", *([filter_] if filter_ else []))
    keep = [l for l in out.splitlines()
            if re.match(r"(AUTOPLAY|\s+(reason|scenes|end|combat|stuck|errors|FAIL)|\[|all |\d+/)", l)]
    return "\n".join(keep) or out[-2000:]


def record_autoplay(filter_: str) -> str:
    # Same allow-list as the other filters: the name also becomes the output file name.
    if not filter_ or not FILTER_RE.match(filter_):
        return "filter must be 1-80 letters, digits or _"
    out = _py("autoplay.py", filter_, "--record", os.path.join(ROOT, "autoplay_out", filter_ + ".mp4"))
    keep = [l for l in out.splitlines() if re.match(r"(AUTOPLAY|\s+(reason|combat|errors)|video:|\[|--record)", l)]
    return "\n".join(keep) or out[-2000:]


def contact_sheet(run: str, t_from, t_to) -> str:
    # The run name becomes a glob and a file name: same allow-list as the filters.
    if not run or not FILTER_RE.match(run):
        return "run must be 1-80 letters, digits or _"
    try:
        lo, hi = float(t_from), float(t_to)
    except (TypeError, ValueError):
        return "t_from / t_to must be numbers"
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import contact_sheet as cs
    return cs.build(run, lo, hi)


def level_pan(x_from=-1400, x_to=7800, step=450) -> str:
    try:
        lo, hi, st = int(x_from), int(x_to), int(step)
    except (TypeError, ValueError):
        return "x_from / x_to / step must be integers"
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import level_pan as lp
    try:
        return lp.build(lo, hi, st)
    except ValueError as e:
        return str(e)


def audit_lane_walls() -> str:
    return _py("lane_wall_audit.py")[-3000:]


def handle(msg: dict):
    method = msg.get("method")
    if method == "initialize":
        return {"protocolVersion": msg.get("params", {}).get("protocolVersion", "2024-11-05"),
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "godot-tests", "version": "1.0"}}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        p = msg.get("params", {})
        args = p.get("arguments") or {}
        if p.get("name") == "run_unit_tests":
            text = run_unit_tests(str(args.get("filter", "")))
        elif p.get("name") == "run_sandbox_selftests":
            text = run_sandbox_selftests()
        elif p.get("name") == "run_autoplay":
            text = run_autoplay(str(args.get("filter", "")))
        elif p.get("name") == "record_autoplay":
            text = record_autoplay(str(args.get("filter", "")))
        elif p.get("name") == "contact_sheet":
            text = contact_sheet(str(args.get("run", "")), args.get("t_from"), args.get("t_to"))
        elif p.get("name") == "level_pan":
            text = level_pan(args.get("x_from", -1400), args.get("x_to", 7800), args.get("step", 450))
        elif p.get("name") == "audit_lane_walls":
            text = audit_lane_walls()
        else:
            return {"content": [{"type": "text", "text": "unknown tool"}], "isError": True}
        return {"content": [{"type": "text", "text": text}]}
    if method == "ping":
        return {}
    return None


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "id" not in msg:  # notification
            continue
        try:
            result = handle(msg)
            reply = ({"jsonrpc": "2.0", "id": msg["id"], "result": result} if result is not None else
                     {"jsonrpc": "2.0", "id": msg["id"], "error": {"code": -32601, "message": "method not found"}})
        except Exception as e:  # report, never crash the server
            reply = {"jsonrpc": "2.0", "id": msg["id"], "error": {"code": -32000, "message": str(e)}}
        sys.stdout.write(json.dumps(reply) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
