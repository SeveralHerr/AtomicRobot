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
    python3 tools/devtools.py set-state --node "/root/Main/Player" --property health --value 100
    python3 tools/devtools.py list-commands            # Discover all registered verbs
    python3 tools/devtools.py cmd my_project_verb --args '{"foo": 1}'
    python3 tools/devtools.py quit

Project selection:
    Run from the project root or pass --project/-p <path>.

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
from pathlib import Path
from typing import Optional  # noqa: F401


COMMANDS_FILE = "devtools_commands.json"
RESULTS_FILE = "devtools_results.json"
LOG_FILE = "devtools_log.jsonl"

# Set once in main() from the global --userdata flag. Takes priority over
# every other user-data resolution mechanism when non-empty.
_USERDATA_OVERRIDE: Optional[str] = None


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


def send_command(project_path: Path, action: str, args: dict = None, timeout: float = 30.0) -> dict:
    """Send a command to the running Godot instance and wait for the result."""
    user_data = get_user_data_path(project_path)
    user_data.mkdir(parents=True, exist_ok=True)

    commands_path = user_data / COMMANDS_FILE
    results_path = user_data / RESULTS_FILE

    # Clear any existing result
    if results_path.exists():
        results_path.unlink()

    # Write command
    args = dict(args or {})
    if "node_path" in args:
        args["node_path"] = normalize_node_path(args["node_path"])
    command = {"action": action, "args": args}
    commands_path.write_text(json.dumps(command), encoding="utf-8")

    # Wait for result
    start_time = time.time()
    while time.time() - start_time < timeout:
        if results_path.exists():
            try:
                result = json.loads(results_path.read_text(encoding="utf-8"))
                results_path.unlink()
                return result
            except json.JSONDecodeError:
                pass
        time.sleep(0.1)

    raise TimeoutError(f"No response from Godot after {timeout}s. Is the game running with DevTools?")


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
    result = send_command(project_path, "performance")
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
        print(f"Orphan nodes:     {int(data['orphan_nodes'])}")
        print(f"Physics 2D objs:  {int(data['physics_2d_active_objects'])}")
        print(f"Physics 3D objs:  {int(data['physics_3d_active_objects'])}")
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
        sys.exit(1)


def cmd_get_state(args, project_path: Path):
    """Get node state."""
    result = send_command(project_path, "get_state", {"node_path": args.node} if args.node else {})
    if result["success"]:
        print(json.dumps(result["data"], indent=2))
    else:
        print(f"Failed: {result['message']}", file=sys.stderr)
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
    p.set_defaults(func=cmd_performance)

    # get-state
    p = subparsers.add_parser("get-state", help="Get node state")
    p.add_argument("--node", "-n", help="Node path")
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

    global _USERDATA_OVERRIDE
    _USERDATA_OVERRIDE = args.userdata

    project_path = Path(args.project).resolve()
    args.func(args, project_path)


if __name__ == "__main__":
    main()
