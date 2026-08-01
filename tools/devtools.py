#!/usr/bin/env python3
"""
devtools.py - Generic CLI for interacting with a running Godot instance via the
godot-selftest-harness DevTools autoload.

Commands are written as JSON to user://devtools_commands.json and results are
read back from user://devtools_results.json. The DevTools autoload polls for
commands and writes results. This client is completely game-agnostic: it ships
only the generic verbs the harness core registers, plus two escape hatches
(`cmd` and `list-commands`) so any project-registered verb is reachable without
editing this file.

Usage:
    python3 tools/devtools.py ping                     # Check if game is running
    python3 tools/devtools.py screenshot               # Capture screenshot
    python3 tools/devtools.py validate-all             # Validate all scenes
    python3 tools/devtools.py scene-tree               # Get node hierarchy
    python3 tools/devtools.py performance              # Get FPS, memory, etc.
    python3 tools/devtools.py get-state --node "/root/Main/Player"
    python3 tools/devtools.py get-state --node "/root/Main/HUD" --property visible --property size
    python3 tools/devtools.py set-state --node "/root/Main/Player" --property health --value 100
    python3 tools/devtools.py step-time --seconds 0.3   # Advance the paused tree
    python3 tools/devtools.py touch press --index 0 --pos 640,360
    python3 tools/devtools.py set-feature --touchscreen true
    python3 tools/devtools.py list-commands            # Discover all registered verbs
    python3 tools/devtools.py cmd my_project_verb --args '{"foo": 1}'
    python3 tools/devtools.py quit

Project selection:
    Run from the project root or pass --project/-p <path>.

Liveness precheck:
    The DevTools autoload deletes the command file the moment it picks it up, so
    a command file that is still on disk a couple of seconds later means nothing
    is polling that directory. Every command therefore fails fast with
    "game not running" instead of blocking for the full timeout. Pass
    --no-precheck to disable it.

Concurrency:
    The bridge is a single command/result file pair, so it is still one in-flight
    command at a time. Each request now carries a unique "id" and the client
    refuses to return a reply stamped with somebody else's id, which turns a
    crossed reply from silent data corruption into a clear error.

User data path resolution (highest priority first):
    1. --userdata <path>                                (global CLI flag)
    2. GODOT_USERDATA environment variable
    3. project.godot: application/config/use_custom_user_dir +
       application/config/custom_user_dir_name
    4. Per-platform default: <data dir>/Godot|godot/app_userdata/<config name>
"""

import argparse
import json
import os
import re
import sys
import time
import uuid
from pathlib import Path
from typing import Optional  # noqa: F401


COMMANDS_FILE = "devtools_commands.json"
RESULTS_FILE = "devtools_results.json"
LOG_FILE = "devtools_log.jsonl"

# How long to wait for the game to *consume* the command file before declaring
# it dead. The autoload polls every ~100 ms, so 2.0s is ~20 poll cycles of
# slack: far more than a loaded machine, a GC pause, or a mid-frame hitch can
# eat, but ~15x faster than letting the default 30s response timeout fire.
PRECHECK_SECONDS = 2.0

# Poll interval while waiting for the command file to be picked up.
_PRECHECK_POLL = 0.05

# Set once in main() from the global --userdata flag. Takes priority over
# every other user-data resolution mechanism when non-empty.
_USERDATA_OVERRIDE: Optional[str] = None

# Cleared by the global --no-precheck flag.
_PRECHECK_ENABLED = True

# Arg keys whose value is a Godot node path and therefore needs un-mangling.
# See normalize_node_path(). "node_path" is used by get_state / set_state /
# run_method / get_node_bounds and by most project verbs; "node" is the key
# input_sequence assert steps use.
_NODE_PATH_KEYS = ("node_path", "node")


class BridgeError(TimeoutError):
    """Base for every "the bridge did not answer" failure.

    Subclasses TimeoutError so pre-existing `except TimeoutError` callers (and
    any project script wrapping this module) keep working unchanged.
    """


class GameNotRunningError(BridgeError):
    """The command file was never picked up: nothing is polling user://."""


class CrossedReplyError(BridgeError):
    """Replies arrived, but all of them were stamped for a different request."""


class NoReplyError(BridgeError):
    """The command was picked up but no reply ever appeared."""


def _parse_project_godot(project_file: Path) -> dict:
    """Extract the handful of application/config/* keys we care about.

    project.godot is an INI-like file. We only need a few flat keys from the
    [application] section, so a simple line scan (matching the `config/<key>=`
    prefix) is sufficient and avoids any INI-parser quirks with res:// values.
    """
    values: dict = {}
    with open(project_file, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            for key in ("config/name",
                        "config/use_custom_user_dir",
                        "config/custom_user_dir_name"):
                prefix = key + "="
                if line.startswith(prefix):
                    values[key] = line[len(prefix):].strip().strip('"')
    return values


def _sanitize_dir_name(name: str) -> str:
    """Mirror Godot's sanitization of custom_user_dir_name / project name.

    Godot strips characters that are invalid in a directory name. We keep it
    conservative: collapse anything outside [A-Za-z0-9_.-] into nothing (while
    preserving path separators, since Godot allows nested custom user dirs),
    which matches the common case for project names.
    """
    normalized = name.replace("\\", "/")
    return re.sub(r"[^A-Za-z0-9_.\- /]", "", normalized).strip()


def _platform_data_dir() -> Path:
    """Base OS data directory that Godot writes user data beneath."""
    if sys.platform == "win32":
        return Path(os.environ.get("APPDATA", str(Path.home())))
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support"
    else:  # Linux and other unix-likes
        return Path.home() / ".local" / "share"


def get_user_data_path(project_path: Path) -> Path:
    """Resolve the user:// directory for the Godot project.

    Resolution priority:
      1. --userdata CLI flag        (_USERDATA_OVERRIDE)
      2. GODOT_USERDATA env var
      3. project.godot custom user dir (use_custom_user_dir + custom_user_dir_name)
      4. per-platform default Godot app_userdata/<config name>
    """
    # 1. Explicit CLI override.
    if _USERDATA_OVERRIDE:
        return Path(_USERDATA_OVERRIDE).expanduser()

    # 2. Environment variable override.
    env_override = os.environ.get("GODOT_USERDATA")
    if env_override:
        return Path(env_override).expanduser()

    project_file = project_path / "project.godot"
    if not project_file.exists():
        raise FileNotFoundError(f"No project.godot found in {project_path}")

    cfg = _parse_project_godot(project_file)

    project_name = cfg.get("config/name") or project_path.name

    # 3. Custom user directory (application/config/use_custom_user_dir=true).
    use_custom = str(cfg.get("config/use_custom_user_dir", "")).lower() == "true"
    if use_custom:
        custom_name = cfg.get("config/custom_user_dir_name", "") or project_name
        custom_name = _sanitize_dir_name(custom_name)
        # Godot places a custom user dir directly under the platform data dir,
        # without the Godot/app_userdata prefix.
        return _platform_data_dir() / custom_name

    # 4. Per-platform default: <data dir>/<Godot|godot>/app_userdata/<name>.
    # Godot uses lowercase "godot" on Linux and "Godot" elsewhere.
    godot_dir = "godot" if sys.platform not in ("win32", "darwin") else "Godot"
    return _platform_data_dir() / godot_dir / "app_userdata" / _sanitize_dir_name(project_name)


_MANGLED_ROOT = re.compile(r"^[A-Za-z]:[\/].*?[\/](root[\/].*)$")


def normalize_node_path(path):
    """Undo MSYS/Git-Bash rewriting of an absolute Godot node path.

    Git Bash treats a leading "/" as a POSIX root and rewrites "/root/Globals" into
    something like "C:/Program Files/Git/root/Globals" before Python ever sees it, so
    the node lookup fails with a confusing Windows path in the error. Callers can also
    write "//root/..." to defeat the rewrite; both forms normalize back to "/root/...".
    """
    if not isinstance(path, str) or not path:
        return path
    m = _MANGLED_ROOT.match(path)
    if m:
        return "/" + m.group(1).replace("\\", "/")
    if path.startswith("//"):
        return "/" + path.lstrip("/")
    return path


def normalize_command_args(args: dict) -> dict:
    """Return a copy of `args` with every node-path-bearing value normalized.

    Only `node_path` used to be normalized, which left the same Git-Bash
    mangling in place for input_sequence steps (which carry `node` / `node_path`
    per step) and for project verbs driven through `cmd --args`. Anything not
    matching the mangled/double-slash shapes is returned untouched, so this is
    safe to apply to arbitrary args.
    """
    out = dict(args or {})
    for key in _NODE_PATH_KEYS:
        if key in out:
            out[key] = normalize_node_path(out[key])

    # input_sequence carries a list of step dicts, each of which may name a node.
    steps = out.get("steps")
    if isinstance(steps, list):
        normalized_steps = []
        for step in steps:
            if isinstance(step, dict):
                step = dict(step)
                for key in _NODE_PATH_KEYS:
                    if key in step:
                        step[key] = normalize_node_path(step[key])
            normalized_steps.append(step)
        out["steps"] = normalized_steps

    return out


def _wait_for_pickup(commands_path: Path, user_data: Path, action: str):
    """Liveness precheck: fail fast when nothing is polling the command file.

    The DevTools autoload reads the command file and immediately deletes it
    (`DirAccess.remove_absolute` in `_check_for_commands`), so the file still
    existing after the grace period is proof that no game is watching this
    directory. That distinguishes "game is dead" from "command is slow" without
    sending an extra ping.
    """
    deadline = time.time() + PRECHECK_SECONDS
    while time.time() < deadline:
        if not commands_path.exists():
            return
        time.sleep(_PRECHECK_POLL)

    if not commands_path.exists():
        return

    # Don't leave our command lying around for a future launch to pick up.
    try:
        commands_path.unlink()
    except OSError:
        pass

    raise GameNotRunningError(
        "game not running: '{action}' was never picked up "
        "({secs:.1f}s grace, ~{cycles:.0f} of the game's ~100ms poll cycles).\n"
        "  polling: {dir}\n"
        "The DevTools autoload deletes {file} as soon as it reads it, so a file "
        "still sitting there means nothing is polling that directory.\n"
        "Note that polling the WRONG user:// directory looks exactly like a dead "
        "game - set --userdata <path> or GODOT_USERDATA if the game is running.\n"
        "Pass --no-precheck to skip this check and wait the full timeout.".format(
            action=action,
            secs=PRECHECK_SECONDS,
            cycles=PRECHECK_SECONDS / 0.1,
            dir=user_data,
            file=COMMANDS_FILE,
        )
    )


def send_command(project_path: Path, action: str, args: dict = None, timeout: float = 30.0) -> dict:
    """Send a command to the running Godot instance and wait for the result.

    Every request carries a short unique `id`. A reply whose `id` is a non-empty
    string that differs from ours belongs to another client's request, so it is
    ignored rather than returned (returning it is what produced the historical
    "KeyError: 'enemies'" corruption). A reply with **no** `id` key at all is
    accepted: that is an older game build, and those still have to work.
    """
    user_data = get_user_data_path(project_path)
    user_data.mkdir(parents=True, exist_ok=True)

    commands_path = user_data / COMMANDS_FILE
    results_path = user_data / RESULTS_FILE

    # Clear any existing result
    if results_path.exists():
        results_path.unlink()

    # Write command
    request_id = uuid.uuid4().hex[:12]
    command = {"id": request_id, "action": action, "args": normalize_command_args(args)}
    commands_path.write_text(json.dumps(command), encoding="utf-8")

    # Liveness precheck: does not consume any of the response timeout, so a slow
    # command still gets its full budget once the game has taken the request.
    if _PRECHECK_ENABLED:
        _wait_for_pickup(commands_path, user_data, action)

    # Wait for result
    crossed_ids = []
    start_time = time.time()
    while time.time() - start_time < timeout:
        if results_path.exists():
            try:
                result = json.loads(results_path.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError):
                # Half-written file; try again on the next tick.
                time.sleep(0.1)
                continue

            reply_id = result.get("id") if isinstance(result, dict) else None
            if isinstance(reply_id, str) and reply_id and reply_id != request_id:
                # Somebody else's reply. Leave it on disk (it is theirs to
                # consume) and keep waiting for ours within the same timeout.
                if reply_id not in crossed_ids:
                    crossed_ids.append(reply_id)
                time.sleep(0.1)
                continue

            results_path.unlink()
            return result
        time.sleep(0.1)

    if crossed_ids:
        raise CrossedReplyError(
            "Crossed replies: saw {n} response(s) stamped for another request "
            "({ids}) but none for ours ({mine}) within {t}s.\n"
            "The bridge is one command file and one result file - another client "
            "or thread is driving the same game. Run one command at a time.".format(
                n=len(crossed_ids),
                ids=", ".join(crossed_ids),
                mine=request_id,
                t=timeout,
            )
        )

    if _PRECHECK_ENABLED:
        # The precheck proved the game consumed the command, so this is a
        # handler problem, not a liveness problem.
        raise NoReplyError(
            "No response from Godot after {t}s. The command WAS picked up (the "
            "game is alive) but '{action}' never answered - it is hung, still "
            "running, or it crashed mid-handler.".format(t=timeout, action=action)
        )
    raise NoReplyError(
        "No response from Godot after {t}s running '{action}'. The liveness "
        "precheck was disabled (--no-precheck), so this could be either a dead "
        "game or a hung handler; re-run without --no-precheck to tell them "
        "apart.".format(t=timeout, action=action)
    )


def cmd_screenshot(args, project_path: Path):
    """Take a screenshot of the running game."""
    result = send_command(project_path, "screenshot", {"filename": args.filename} if args.filename else {})
    if result["success"]:
        print(f"Screenshot saved: {result['data']['path']}")
        print(f"Size: {result['data']['width']}x{result['data']['height']}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_validate(args, project_path: Path):
    """Validate a specific scene."""
    if not args.scene:
        print("Error: --scene is required", file=sys.stderr)
        sys.exit(1)
    result = send_command(project_path, "validate_scene", {"path": args.scene})
    print_validation_result(result)


def cmd_validate_all(args, project_path: Path):
    """Validate all scenes in the project."""
    result = send_command(project_path, "validate_all", timeout=60.0)
    print_validation_result(result)


def print_validation_result(result: dict):
    """Pretty-print validation results."""
    if result["success"]:
        print("[OK] " + result["message"])
    else:
        print("[FAIL] " + result["message"])

    data = result.get("data", {})

    # Handle validate_all response: data.scenes is an array of {path, issues, valid}
    scenes = data.get("scenes", [])
    if scenes:
        for scene in scenes:
            if scene.get("issues"):
                print(f"\n{scene['path']}:")
                for issue in scene["issues"]:
                    severity = {"error": "ERROR", "warning": "WARN", "info": "INFO"}.get(issue["severity"], "???")
                    print(f"  [{severity}] {issue['code']}: {issue['message']}")
    else:
        # Handle single scene validate response: data.issues is a list
        issues = data.get("issues", [])
        if isinstance(issues, list):
            for issue in issues:
                severity = {"error": "ERROR", "warning": "WARN", "info": "INFO"}.get(issue["severity"], "???")
                print(f"  [{severity}] {issue['code']}: {issue['message']}")

    if not result["success"]:
        sys.exit(1)


def cmd_scene_tree(args, project_path: Path):
    """Get the current scene tree."""
    result = send_command(project_path, "scene_tree", {"depth": args.depth})
    if result["success"]:
        print(json.dumps(result["data"], indent=2))
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_performance(args, project_path: Path):
    """Get performance metrics."""
    cmd_args = {}
    if getattr(args, "reset_baseline", False):
        cmd_args["reset_baseline"] = True

    result = send_command(project_path, "performance", cmd_args)
    if result["success"]:
        data = result["data"]
        print(f"FPS:              {data['fps']:.1f}")
        print(f"Frame time:       {data['frame_time_ms']:.2f} ms")
        print(f"Physics FPS:      {int(data['physics_fps'])}")
        print(f"Draw calls:       {int(data['draw_calls'])}")
        print(f"Objects:          {int(data['objects'])}")
        print(f"Static memory:    {data['static_memory_mb']:.1f} MB")
        print(f"Video memory:     {data['video_memory_mb']:.1f} MB")
        print(f"Total nodes:      {int(data['nodes'])}")
        _print_orphans(data, cmd_args.get("reset_baseline", False))
        print(f"Physics 2D objs:  {int(data['physics_2d_active_objects'])}")
        print(f"Physics 3D objs:  {int(data['physics_3d_active_objects'])}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def _print_orphans(data: dict, reset_baseline: bool):
    """Print orphan growth (the actionable number) with the absolute alongside.

    A fresh launch legitimately reports dozens of orphans, so the absolute count
    can never be gated on; growth since the baseline can. Older game builds
    return only `orphan_nodes`, so fall back to the original single line rather
    than crashing on the missing keys.
    """
    absolute = int(data.get("orphan_nodes", 0))
    has_growth = "orphan_growth" in data or "orphan_baseline" in data
    if not has_growth:
        print(f"Orphan nodes:     {absolute}")
        return

    baseline = int(data.get("orphan_baseline", 0))
    growth = int(data.get("orphan_growth", absolute - baseline))
    print(f"Orphan growth:    {growth:+d}   (baseline {baseline}, absolute {absolute})")
    if reset_baseline:
        print(f"                  baseline reset to {baseline}")


def _format_value(value) -> str:
    """Render one property value on a single line."""
    if isinstance(value, str):
        return value
    if isinstance(value, bool) or value is None or isinstance(value, (int, float)):
        return json.dumps(value)
    # Vector2/Rect2/etc. arrive as small lists or dicts; keep them on one line.
    return json.dumps(value, separators=(", ", ": "))


def cmd_get_state(args, project_path: Path):
    """Get node state, optionally filtered to specific properties."""
    cmd_args = {}
    if args.node:
        cmd_args["node_path"] = args.node
    if args.properties:
        cmd_args["properties"] = args.properties

    result = send_command(project_path, "get_state", cmd_args)
    if not result["success"]:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)

    data = result["data"]
    if not args.properties:
        print(json.dumps(data, indent=2))
        return

    # Filtered read: print "name: value" per line instead of a JSON blob, in the
    # order the flags were given, so the output is diffable and greppable.
    values = data.get("properties")
    if not isinstance(values, dict):
        values = {k: v for k, v in data.items() if k not in ("missing", "properties")}

    missing = list(data.get("missing", []) or [])
    for name in args.properties:
        if name in values:
            print(f"{name}: {_format_value(values[name])}")
        elif name not in missing:
            # The game neither returned it nor listed it as missing.
            missing.append(name)

    if missing:
        node_label = args.node or "(current scene)"
        print(
            f"Unknown propert{'y' if len(missing) == 1 else 'ies'} on {node_label}: "
            f"{', '.join(str(m) for m in missing)}",
            file=sys.stderr,
        )
        print(
            "  (the node does not expose that name - check spelling, or drop "
            "--property to dump everything it does expose)",
            file=sys.stderr,
        )
        sys.exit(1)


def cmd_set_state(args, project_path: Path):
    """Set a node property."""
    value = args.value
    try:
        value = json.loads(args.value)
    except json.JSONDecodeError:
        try:
            value = int(args.value)
        except ValueError:
            try:
                value = float(args.value)
            except ValueError:
                pass

    result = send_command(project_path, "set_state", {
        "node_path": args.node,
        "property": args.property,
        "value": value
    })
    if result["success"]:
        print("State updated")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_run_method(args, project_path: Path):
    """Call a method on a node."""
    method_args = []
    if args.args:
        try:
            method_args = json.loads(args.args)
            if not isinstance(method_args, list):
                print("Error: --args must be a JSON array, e.g., '[25, \"name\"]'", file=sys.stderr)
                sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in --args: {e}", file=sys.stderr)
            sys.exit(1)

    result = send_command(project_path, "run_method", {
        "node_path": args.node,
        "method": args.method,
        "args": method_args
    })
    if result["success"]:
        print(f"Result: {result['data'].get('result')}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_logs(args, project_path: Path):
    """View DevTools logs."""
    user_data = get_user_data_path(project_path)
    log_path = user_data / LOG_FILE

    if not log_path.exists():
        print("No logs found")
        return

    lines = log_path.read_text(encoding="utf-8").strip().split("\n")

    if args.category:
        lines = [l for l in lines if f'"category":"{args.category}"' in l or f'"category": "{args.category}"' in l]

    if args.tail:
        lines = lines[-args.tail:]

    for line in lines:
        try:
            entry = json.loads(line)
            ts = time.strftime("%H:%M:%S", time.localtime(entry["timestamp"]))
            cat = entry["category"]
            msg = entry["message"]
            print(f"[{ts}] [{cat}] {msg}")
        except json.JSONDecodeError:
            print(line)


def cmd_ping(args, project_path: Path):
    """Check if Godot DevTools is responding."""
    try:
        result = send_command(project_path, "ping", timeout=5.0)
        if result["success"]:
            print(f"DevTools is running (timestamp: {result['data']['timestamp']:.0f})")
        else:
            print("DevTools responded but with error")
            sys.exit(1)
    except GameNotRunningError as e:
        # The precheck knows more than "no response" does - say what it knows.
        print(str(e), file=sys.stderr)
        sys.exit(1)
    except TimeoutError:
        print("No response - is the game running with DevTools autoload?")
        sys.exit(1)


def cmd_quit(args, project_path: Path):
    """Quit the running Godot instance."""
    try:
        send_command(project_path, "quit", {"exit_code": args.exit_code or 0}, timeout=5.0)
        print("Quit command sent")
    except TimeoutError:
        print("Quit command sent (no response expected)")


# ==================== GENERIC ESCAPE HATCHES ====================


def cmd_cmd(args, project_path: Path):
    """Send an arbitrary registered verb: {action:<action>, args:<json>}.

    Lets any project-registered handler be invoked without adding a dedicated
    subcommand. --args must be a JSON object (defaults to {}).
    """
    parsed_args: dict = {}
    if args.args:
        try:
            parsed_args = json.loads(args.args)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in --args: {e}", file=sys.stderr)
            sys.exit(1)
        if not isinstance(parsed_args, dict):
            print("Error: --args must be a JSON object, e.g., '{\"foo\": 1}'", file=sys.stderr)
            sys.exit(1)

    result = send_command(project_path, args.action, parsed_args, timeout=args.timeout)
    # Print the whole envelope so unknown verbs are fully observable.
    print(json.dumps(result, indent=2))
    if not result.get("success", False):
        sys.exit(1)


def cmd_list_commands(args, project_path: Path):
    """Discover and print all registered verbs (generic + project extensions)."""
    result = send_command(project_path, "list_commands")
    if not result["success"]:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)

    actions = result.get("data", {}).get("actions", [])
    if args.json:
        print(json.dumps(actions, indent=2))
        return

    print(f"Registered commands ({len(actions)}):")
    for action in actions:
        print(f"  {action}")


# ==================== INPUT SIMULATION ====================


def cmd_input_press(args, project_path: Path):
    """Press and hold an input action."""
    cmd_args = {"action": args.action}
    if args.strength is not None:
        cmd_args["strength"] = args.strength

    result = send_command(project_path, "input_press", cmd_args)
    if result["success"]:
        print(f"Pressed: {args.action}")
        if result.get("data", {}).get("active_inputs"):
            print(f"Active inputs: {', '.join(result['data']['active_inputs'])}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_release(args, project_path: Path):
    """Release an input action."""
    result = send_command(project_path, "input_release", {"action": args.action})
    if result["success"]:
        print(f"Released: {args.action}")
        if result.get("data", {}).get("active_inputs"):
            print(f"Active inputs: {', '.join(result['data']['active_inputs'])}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_tap(args, project_path: Path):
    """Tap (press and release) an input action."""
    cmd_args = {"action": args.action}
    if args.hold:
        cmd_args["seconds"] = args.hold
    if args.strength is not None:
        cmd_args["strength"] = args.strength

    result = send_command(project_path, "input_tap", cmd_args)
    if result["success"]:
        hold_info = f" (hold: {args.hold}s)" if args.hold else ""
        print(f"Tapped: {args.action}{hold_info}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_clear(args, project_path: Path):
    """Release all simulated inputs."""
    result = send_command(project_path, "input_clear")
    if result["success"]:
        cleared = result.get("data", {}).get("cleared", [])
        if cleared:
            print(f"Cleared {len(cleared)} inputs: {', '.join(cleared)}")
        else:
            print("No active inputs to clear")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_list(args, project_path: Path):
    """List available input actions."""
    cmd_args = {"include_builtin": args.all}
    result = send_command(project_path, "input_actions", cmd_args)
    if result["success"]:
        actions = result.get("data", {}).get("actions", [])
        if not actions:
            print("No actions found")
            return

        print(f"Available actions ({len(actions)}):")
        for action in actions:
            pressed = " [PRESSED]" if action.get("pressed") else ""
            events = ", ".join(action.get("events", [])) or "(no keys)"
            print(f"  {action['name']}{pressed}: {events}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_input_sequence(args, project_path: Path):
    """Execute an input sequence from a JSON file."""
    seq_path = Path(args.file)
    if not seq_path.exists():
        print(f"Error: Sequence file not found: {args.file}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(seq_path, encoding="utf-8") as f:
            seq_data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in sequence file: {e}", file=sys.stderr)
        sys.exit(1)

    steps = seq_data.get("steps", [])
    if not steps:
        print("Error: Sequence has no steps", file=sys.stderr)
        sys.exit(1)

    description = seq_data.get("description", "")
    if description:
        print(f"Running sequence: {description}")
    print(f"Executing {len(steps)} steps...")

    cmd_args = {"steps": steps}
    if args.timeout:
        cmd_args["timeout"] = args.timeout

    result = send_command(project_path, "input_sequence", cmd_args, timeout=args.timeout + 10 if args.timeout else 70)
    if result["success"]:
        print(f"Sequence started: {result.get('data', {}).get('sequence_id', 'unknown')}")
        print("Note: Sequence runs asynchronously. Check logs for completion.")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


# ==================== NODE / TIME CONTROL ====================


def cmd_clear_nodes(args, project_path: Path):
    """Free scene nodes matching a selector (group, method, or class).

    Forwards exactly one selector to the generic clear_nodes handler. The
    handler refuses to run without a selector so we never blindly free the
    whole tree.
    """
    cmd_args = {}
    if args.group is not None:
        cmd_args["group"] = args.group
    if args.method is not None:
        cmd_args["method"] = args.method
    if getattr(args, "class_name", None) is not None:
        cmd_args["class"] = args.class_name

    if not cmd_args:
        print("Error: Specify a selector: --group, --method, or --class", file=sys.stderr)
        sys.exit(1)

    result = send_command(project_path, "clear_nodes", cmd_args)
    if result["success"]:
        count = result.get("data", {}).get("count", 0)
        print(f"Cleared {count} node(s)")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_set_game_speed(args, project_path: Path):
    """Set game speed (time scale)."""
    result = send_command(project_path, "set_game_speed", {"scale": args.scale})
    if result["success"]:
        data = result["data"]
        print(f"Game speed: {data['previous_scale']:.1f} -> {data['current_scale']:.1f}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_wait_frames(args, project_path: Path):
    """Wait for N physics frames."""
    timeout = max(30, args.count / 10)
    result = send_command(project_path, "wait_frames", {"count": args.count}, timeout=timeout)
    if result["success"]:
        data = result["data"]
        print(f"Waited {data['frames']} frames ({data['elapsed_ms']}ms)")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_step_time(args, project_path: Path):
    """Advance the running game by roughly N game-seconds.

    It does NOT pause and step the tree — GDScript cannot tick the SceneTree. The
    game runs at normal speed with `Engine.time_scale` pinned to 1.0 and returns
    once enough time has passed: physics time is exact, process time (which is what
    a default Tween runs on) lands within about a frame. The game's own message is
    printed verbatim rather than this client claiming a precision it does not have.
    """
    # Stepping is bounded by how fast the game can run the frames, so give it
    # generous headroom over the requested game-time.
    timeout = max(30.0, args.seconds * 4 + 10)
    result = send_command(project_path, "step_time", {"seconds": args.seconds}, timeout=timeout)
    if not result["success"]:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)

    print(result.get("message", "") or f"Stepped {args.seconds}s")
    data = result.get("data", {}) or {}
    print(f"  Requested:      {args.seconds}s")
    if "physics_seconds" in data:
        print(f"  Physics time:   {float(data['physics_seconds']):.4f}s (exact)")
    if "process_seconds" in data:
        print(f"  Process time:   {float(data['process_seconds']):.4f}s (measured, +/- one frame)")
    if "frames_advanced" in data:
        print(f"  Frames:         {int(data['frames_advanced'])}")
    if data.get("tree_paused"):
        # A paused tree still emits frames while nothing advances, so this would
        # otherwise look like a successful step of a frozen game.
        print("  WARNING: the tree is paused — nothing actually advanced.")
    if data.get("budget_exhausted"):
        print("  WARNING: frame budget exhausted before the target was reached.")


# ==================== TOUCH SIMULATION ====================


def coord_pair(value: str):
    """Parse an "X,Y" coordinate flag into [x, y] floats.

    Shared by every --pos / --to flag so a malformed value fails the same way
    everywhere. Tolerates whitespace and wrapping parens/brackets, e.g.
    "640,360", "640, 360", "(640, 360)".
    """
    text = str(value).strip().strip("()[]").strip()
    parts = [p for p in re.split(r"[,\s]+", text) if p]
    if len(parts) != 2:
        raise argparse.ArgumentTypeError(
            f"expected two comma-separated numbers 'X,Y' (e.g. 640,360), got {value!r}"
        )
    try:
        return [float(parts[0]), float(parts[1])]
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"both coordinates must be numbers (e.g. 640,360), got {value!r}"
        )


def _format_position(pos) -> str:
    """Render a position the game reported back, whatever shape it used."""
    if isinstance(pos, dict):
        return f"({pos.get('x', '?')}, {pos.get('y', '?')})"
    if isinstance(pos, (list, tuple)) and len(pos) == 2:
        return f"({pos[0]}, {pos[1]})"
    return str(pos)


def _active_touches(result: dict):
    """Pull the active-touch list out of a reply, tolerating either key."""
    data = result.get("data", {}) or {}
    touches = data.get("touches")
    if touches is None:
        touches = data.get("active_touches")
    return touches or []


def _print_active_touches(result: dict):
    touches = _active_touches(result)
    if not touches:
        return
    labels = []
    for touch in touches:
        if isinstance(touch, dict):
            labels.append(f"{touch.get('index', '?')}@{_format_position(touch.get('position'))}")
        else:
            labels.append(str(touch))
    print(f"Active touches: {', '.join(labels)}")


def cmd_touch_press(args, project_path: Path):
    """Press a touch point (InputEventScreenTouch, pressed)."""
    result = send_command(project_path, "touch_press", {"index": args.index, "position": args.pos})
    if result["success"]:
        print(f"Touch {args.index} pressed at {args.pos[0]:g},{args.pos[1]:g}")
        _print_active_touches(result)
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_touch_release(args, project_path: Path):
    """Release a touch point."""
    cmd_args = {"index": args.index}
    if args.pos is not None:
        cmd_args["position"] = args.pos

    result = send_command(project_path, "touch_release", cmd_args)
    if result["success"]:
        print(f"Touch {args.index} released")
        _print_active_touches(result)
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_touch_drag(args, project_path: Path):
    """Drag a touch point (InputEventScreenDrag) to a new position."""
    cmd_args = {"index": args.index, "to": args.to}
    if args.pos is not None:
        cmd_args["from"] = args.pos
    if args.steps is not None:
        cmd_args["steps"] = args.steps

    result = send_command(project_path, "touch_drag", cmd_args)
    if result["success"]:
        origin = f"{args.pos[0]:g},{args.pos[1]:g}" if args.pos else "current position"
        steps_info = f" in {args.steps} steps" if args.steps else ""
        print(f"Touch {args.index} dragged from {origin} to {args.to[0]:g},{args.to[1]:g}{steps_info}")
        _print_active_touches(result)
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def _touch_label(entry):
    """Render one touch point as `index@(x, y)`, tolerating a bare index."""
    if not isinstance(entry, dict):
        return str(entry)
    pos = entry.get("position") or {}
    if isinstance(pos, dict) and "x" in pos:
        return f"{entry.get('index', '?')}@({pos['x']}, {pos['y']})"
    if isinstance(pos, (list, tuple)) and len(pos) == 2:
        return f"{entry.get('index', '?')}@({pos[0]}, {pos[1]})"
    return str(entry.get("index", entry))


def cmd_touch_clear(args, project_path: Path):
    """Release all simulated touch points."""
    result = send_command(project_path, "touch_clear")
    if result["success"]:
        data = result.get("data", {}) or {}
        # The core reports "released"; accept "cleared" too so a newer client
        # still reads an older game build.
        cleared = data.get("released", data.get("cleared", []))
        if cleared:
            print(f"Cleared {len(cleared)} touch(es): {', '.join(_touch_label(c) for c in cleared)}")
        else:
            print("No active touches to clear")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_touch_list(args, project_path: Path):
    """List currently-held simulated touch points."""
    result = send_command(project_path, "touch_list")
    if not result["success"]:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)

    touches = _active_touches(result)
    if not touches:
        print("No active touches")
        return

    print(f"Active touches ({len(touches)}):")
    for touch in touches:
        if isinstance(touch, dict):
            print(f"  [{touch.get('index', '?')}] {_format_position(touch.get('position'))}")
        else:
            print(f"  {touch}")


# ==================== ENGINE FEATURE OVERRIDES ====================


def bool_arg(value: str) -> bool:
    """Parse a true/false flag value."""
    text = str(value).strip().lower()
    if text in ("true", "1", "yes", "on"):
        return True
    if text in ("false", "0", "no", "off"):
        return False
    raise argparse.ArgumentTypeError(f"expected true or false, got {value!r}")


def cmd_set_feature(args, project_path: Path):
    """Override an engine feature probe (e.g. fake a touchscreen).

    Prints what the game reports as the *resulting* state: an override the
    engine refused must not read as success.
    """
    requested = {}
    if args.touchscreen is not None:
        requested["touchscreen"] = args.touchscreen

    if not requested:
        print("Error: Specify a feature: --touchscreen true|false", file=sys.stderr)
        sys.exit(1)

    result = send_command(project_path, "set_feature", requested)
    if not result["success"]:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)

    data = result.get("data", {}) or {}
    applied = data.get("applied", {}) or {}

    # Where the core reports the *resulting* engine state for each feature. This is
    # deliberately not the flag we asked it to set: the point of the check is to
    # catch an override the engine silently refused, so we read what the engine now
    # says, not what we requested.
    RESULT_KEYS = {"touchscreen": "touchscreen_available"}

    rejected = []
    for name, wanted in requested.items():
        result_key = RESULT_KEYS.get(name, name)
        if result_key in data:
            actual = data[result_key]
            print(f"{name}: {json.dumps(actual)}")
            if bool(actual) != bool(wanted):
                rejected.append(name)
        elif name in applied:
            # The core acknowledged the flag but reports no engine-level probe for
            # it — say so rather than implying it was verified.
            print(f"{name}: applied {json.dumps(applied[name])} (no engine-level probe to confirm it)")
        else:
            # Older build that doesn't echo the resulting state: report the
            # game's own message rather than asserting it took effect.
            print(f"{name}: requested {json.dumps(wanted)} (game reported no resulting state)")

    if data.get("unknown"):
        print(f"Warning: the game did not recognize: {', '.join(str(u) for u in data['unknown'])}",
              file=sys.stderr)

    if result.get("message"):
        print(result["message"])

    if rejected:
        print(
            "Failed: the game reports the override did not take effect for: "
            f"{', '.join(rejected)}",
            file=sys.stderr,
        )
        sys.exit(1)


# ==================== UI VALIDATION ====================


def cmd_validate_ui(args, project_path: Path):
    """Run all UI layout checks."""
    result = send_command(project_path, "validate_ui")
    print_validation_result(result)


def cmd_save_ui_baseline(args, project_path: Path):
    """Save current UI layout as baseline for diff comparison."""
    result = send_command(project_path, "save_ui_baseline")
    if result["success"]:
        print(f"Baseline saved: {result['data']['nodes_saved']} nodes")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_ui_snapshot_diff(args, project_path: Path):
    """Compare current UI layout against saved baseline."""
    result = send_command(project_path, "ui_snapshot_diff")
    if not result["success"]:
        if result.get("data", {}).get("status") == "drift_detected":
            print(f"[DRIFT] {result['message']}")
            for diff in result["data"].get("diffs", []):
                diff_type = diff.get("type", "changed")
                if diff_type == "new_node":
                    print(f"  + NEW: {diff['path']}")
                elif diff_type == "removed_node":
                    print(f"  - REMOVED: {diff['path']}")
                else:
                    print(f"  ~ CHANGED: {diff['path']}")
                    if "position_delta" in diff:
                        print(f"    pos delta: {diff['position_delta']}, size delta: {diff['size_delta']}")
            sys.exit(1)
        else:
            print(f"Failed: {result['message']}", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"[OK] {result['message']}")


def cmd_ui_snapshot(args, project_path: Path):
    """Get snapshot of all visible UI elements."""
    result = send_command(project_path, "get_ui_snapshot")
    if not result["success"]:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps(result["data"], indent=2))
        return

    data = result["data"]
    vp = data["viewport"]
    elements = data.get("elements", [])
    print(f"Viewport: {vp['width']}x{vp['height']}")
    print(f"UI Elements: {len(elements)}")
    print()
    for el in elements:
        r = el["global_rect"]
        vis = "visible" if el["visible"] else "hidden"
        text_preview = f' "{el["text"]}"' if el.get("text") else ""
        if len(text_preview) > 53:
            text_preview = text_preview[:50] + '..."'
        print(f"  {el['name']} ({el['type']}) [{r['x']:.0f},{r['y']:.0f} {r['w']:.0f}x{r['h']:.0f}] {vis} alpha={el['modulate_a']:.1f}{text_preview}")


def cmd_node_bounds(args, project_path: Path):
    """Get bounds for a specific node."""
    result = send_command(project_path, "get_node_bounds", {"node_path": args.node_path})
    if not result["success"]:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)

    data = result["data"]
    r = data["global_rect"]
    print(f"{data['name']} ({data['type']})")
    print(f"  Rect:         {r['x']:.0f}, {r['y']:.0f}, {r['w']:.0f}x{r['h']:.0f}")
    print(f"  Visible:      {data['visible']}")
    print(f"  Alpha:        {data['modulate_a']:.1f}")
    print(f"  In viewport:  {data['in_viewport']}")
    if data.get("text"):
        print(f"  Text:         \"{data['text']}\"")


def main():
    parser = argparse.ArgumentParser(description="DevTools CLI - interact with running Godot instance")
    parser.add_argument("--project", "-p", help="Path to Godot project", default=".")
    parser.add_argument("--userdata", "-u", help="Override user:// data directory (highest priority)")
    parser.add_argument(
        "--no-precheck",
        action="store_true",
        help=f"Skip the {PRECHECK_SECONDS:g}s 'is the game running' precheck and wait the full timeout",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # ping
    p = subparsers.add_parser("ping", help="Check if DevTools is running")
    p.set_defaults(func=cmd_ping)

    # screenshot
    p = subparsers.add_parser("screenshot", help="Take a screenshot")
    p.add_argument("--filename", "-f", help="Output filename")
    p.set_defaults(func=cmd_screenshot)

    # validate
    p = subparsers.add_parser("validate", help="Validate a scene")
    p.add_argument("--scene", "-s", help="Scene path (res://...)")
    p.set_defaults(func=cmd_validate)

    # validate-all
    p = subparsers.add_parser("validate-all", help="Validate all scenes")
    p.set_defaults(func=cmd_validate_all)

    # scene-tree
    p = subparsers.add_parser("scene-tree", help="Get scene tree")
    p.add_argument("--depth", "-d", type=int, default=10, help="Max depth")
    p.set_defaults(func=cmd_scene_tree)

    # performance
    p = subparsers.add_parser("performance", help="Get performance metrics")
    p.add_argument("--reset-baseline", action="store_true",
                   help="Re-baseline the orphan count at the current value")
    p.set_defaults(func=cmd_performance)

    # get-state
    p = subparsers.add_parser("get-state", help="Get node state")
    p.add_argument("--node", "-n", help="Node path")
    p.add_argument("--property", dest="properties", action="append", metavar="NAME",
                   help="Only report this property (repeatable). Exits 1 if a name is unknown.")
    p.set_defaults(func=cmd_get_state)

    # set-state
    p = subparsers.add_parser("set-state", help="Set node property")
    p.add_argument("--node", "-n", required=True, help="Node path")
    p.add_argument("--property", required=True, help="Property name")
    p.add_argument("--value", required=True, help="Property value")
    p.set_defaults(func=cmd_set_state)

    # run-method
    p = subparsers.add_parser("run-method", help="Call a method")
    p.add_argument("--node", "-n", required=True, help="Node path")
    p.add_argument("--method", "-m", required=True, help="Method name")
    p.add_argument("--args", "-a", help="Method arguments as JSON array")
    p.set_defaults(func=cmd_run_method)

    # logs
    p = subparsers.add_parser("logs", help="View logs")
    p.add_argument("--tail", "-t", type=int, help="Show last N entries")
    p.add_argument("--category", "-c", help="Filter by category")
    p.set_defaults(func=cmd_logs)

    # quit
    p = subparsers.add_parser("quit", help="Quit Godot")
    p.add_argument("--exit-code", type=int, help="Exit code")
    p.set_defaults(func=cmd_quit)

    # cmd - arbitrary registered verb
    p = subparsers.add_parser("cmd", help="Send an arbitrary registered verb")
    p.add_argument("action", help="Action name (any registered verb)")
    p.add_argument("--args", "-a", help="Args as a JSON object (default: {})")
    p.add_argument("--timeout", type=float, default=30.0, help="Response timeout in seconds")
    p.set_defaults(func=cmd_cmd)

    # list-commands - discover registered verbs
    p = subparsers.add_parser("list-commands", help="List all registered verbs")
    p.add_argument("--json", "-j", action="store_true", help="Output raw JSON")
    p.set_defaults(func=cmd_list_commands)

    # input - nested subcommands
    input_parser = subparsers.add_parser("input", help="Simulate input actions")
    input_sub = input_parser.add_subparsers(dest="input_command", required=True)

    # input press
    p = input_sub.add_parser("press", help="Press and hold an action")
    p.add_argument("action", help="Action name (e.g., move_left)")
    p.add_argument("--strength", type=float, help="Pressure strength 0.0-1.0 (default: 1.0)")
    p.set_defaults(func=cmd_input_press)

    # input release
    p = input_sub.add_parser("release", help="Release a held action")
    p.add_argument("action", help="Action name to release")
    p.set_defaults(func=cmd_input_release)

    # input tap
    p = input_sub.add_parser("tap", help="Press and release an action")
    p.add_argument("action", help="Action name to tap")
    p.add_argument("--hold", type=float, default=0, help="Hold duration in seconds before release")
    p.add_argument("--strength", type=float, help="Pressure strength 0.0-1.0 (default: 1.0)")
    p.set_defaults(func=cmd_input_tap)

    # input clear
    p = input_sub.add_parser("clear", help="Release all simulated inputs")
    p.set_defaults(func=cmd_input_clear)

    # input list
    p = input_sub.add_parser("list", help="List available input actions")
    p.add_argument("--all", "-a", action="store_true", help="Include built-in ui_* actions")
    p.set_defaults(func=cmd_input_list)

    # input sequence
    p = input_sub.add_parser("sequence", help="Execute input sequence from JSON file")
    p.add_argument("file", help="Path to sequence JSON file")
    p.add_argument("--timeout", type=float, default=60, help="Sequence timeout in seconds (default: 60)")
    p.set_defaults(func=cmd_input_sequence)

    # ==================== TOUCH SIMULATION ====================

    # touch - nested subcommands (InputEventScreenTouch / InputEventScreenDrag)
    touch_parser = subparsers.add_parser("touch", help="Simulate touch / multi-touch events")
    touch_sub = touch_parser.add_subparsers(dest="touch_command", required=True)

    # touch press
    p = touch_sub.add_parser("press", help="Press a touch point")
    p.add_argument("--index", "-i", type=int, default=0, help="Touch index (default: 0)")
    p.add_argument("--pos", type=coord_pair, required=True, metavar="X,Y", help="Screen position, e.g. 640,360")
    p.set_defaults(func=cmd_touch_press)

    # touch release
    p = touch_sub.add_parser("release", help="Release a touch point")
    p.add_argument("--index", "-i", type=int, default=0, help="Touch index (default: 0)")
    p.add_argument("--pos", type=coord_pair, metavar="X,Y", help="Release position (default: where it is)")
    p.set_defaults(func=cmd_touch_release)

    # touch drag
    p = touch_sub.add_parser("drag", help="Drag a held touch point")
    p.add_argument("--index", "-i", type=int, default=0, help="Touch index (default: 0)")
    p.add_argument("--pos", type=coord_pair, metavar="X,Y", help="Start position (default: where it is)")
    p.add_argument("--to", type=coord_pair, required=True, metavar="X,Y", help="End position, e.g. 640,360")
    p.add_argument("--steps", type=int, help="Number of intermediate drag events")
    p.set_defaults(func=cmd_touch_drag)

    # touch clear
    p = touch_sub.add_parser("clear", help="Release all simulated touches")
    p.set_defaults(func=cmd_touch_clear)

    # touch list
    p = touch_sub.add_parser("list", help="List active simulated touches")
    p.set_defaults(func=cmd_touch_list)

    # ==================== ENGINE FEATURE OVERRIDES ====================

    # set-feature
    p = subparsers.add_parser("set-feature", help="Override an engine feature probe")
    p.add_argument("--touchscreen", type=bool_arg, metavar="true|false",
                   help="Fake DisplayServer.is_touchscreen_available()")
    p.set_defaults(func=cmd_set_feature)

    # ==================== NODE / TIME CONTROL ====================

    # clear-nodes
    p = subparsers.add_parser("clear-nodes", help="Free scene nodes matching a selector")
    p.add_argument("--group", help="Free nodes in this group")
    p.add_argument("--method", help="Free nodes that have this method")
    p.add_argument("--class", dest="class_name", help="Free nodes of this class")
    p.set_defaults(func=cmd_clear_nodes)

    # set-game-speed
    p = subparsers.add_parser("set-game-speed", help="Set game speed (time scale)")
    p.add_argument("scale", type=float, help="Time scale (0=pause, 1=normal, 10=fast)")
    p.set_defaults(func=cmd_set_game_speed)

    # wait-frames
    p = subparsers.add_parser("wait-frames", help="Wait for N physics frames")
    p.add_argument("count", type=int, help="Number of frames to wait")
    p.set_defaults(func=cmd_wait_frames)

    # step-time
    p = subparsers.add_parser("step-time", help="Pause the tree and advance it by N game-seconds")
    p.add_argument("--seconds", "-s", type=float, required=True,
                   help="Game-seconds to advance (e.g. 0.05 to sample mid-tween)")
    p.set_defaults(func=cmd_step_time)

    # ==================== UI VALIDATION ====================

    # validate-ui
    p = subparsers.add_parser("validate-ui", help="Run UI layout validation checks")
    p.set_defaults(func=cmd_validate_ui)

    # save-ui-baseline
    p = subparsers.add_parser("save-ui-baseline", help="Save current UI layout as baseline")
    p.set_defaults(func=cmd_save_ui_baseline)

    # ui-snapshot-diff
    p = subparsers.add_parser("ui-snapshot-diff", help="Compare UI layout against saved baseline")
    p.set_defaults(func=cmd_ui_snapshot_diff)

    # ui-snapshot
    p = subparsers.add_parser("ui-snapshot", help="Get snapshot of all visible UI elements")
    p.add_argument("--json", "-j", action="store_true", help="Output raw JSON")
    p.set_defaults(func=cmd_ui_snapshot)

    # node-bounds
    p = subparsers.add_parser("node-bounds", help="Get bounds for a specific node")
    p.add_argument("node_path", help="Node path (e.g., /root/Main/HUD/TopBar/CurrencyLabel)")
    p.set_defaults(func=cmd_node_bounds)

    args = parser.parse_args()

    global _USERDATA_OVERRIDE, _PRECHECK_ENABLED
    _USERDATA_OVERRIDE = args.userdata
    _PRECHECK_ENABLED = not args.no_precheck

    project_path = Path(args.project).resolve()
    try:
        args.func(args, project_path)
    except BridgeError as e:
        # Bridge failures are expected operational states (dead game, crossed
        # replies, hung handler), not bugs: report them, don't traceback.
        print(str(e), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
