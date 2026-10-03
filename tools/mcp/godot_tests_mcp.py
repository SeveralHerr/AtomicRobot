"""Minimal stdio MCP server: run this project's Godot test suites and get a short summary.

Dependency-free (no `mcp` package): speaks newline-delimited JSON-RPC 2.0 on stdio.
Tools:
  run_unit_tests(filter?)   -> "Total: ..." line plus every FAIL/BROKEN/SCRIPT ERROR line
  run_sandbox_selftests()   -> the sandbox runner's per-scenario table

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
