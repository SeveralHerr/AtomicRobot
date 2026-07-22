# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment (this machine)

- Godot **4.7.1** is NOT on PATH. Use the full path:
  `C:\Users\gotmi\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe` (console build —
  prefer it for CLI/headless; the windowed exe is beside it). Treat `godot` in any
  command below as an alias for that path.
- Python 3.12 is installed user-scope (`python`, not `python3`). If a shell can't find
  it, it lives at `%LOCALAPPDATA%\Programs\Python\Python312\python.exe`.
- After pulling changes that touch images/resources, run
  `godot --headless --path . --import` once to refresh the import/UID cache.
- If lint reports `uid mismatch` errors (stale `uid://` refs after reimports), run
  `godot --headless --path . --script res://tools/fix_uids.gd` to rewrite them.

## Development Commands

**Running the Game:**

- Open project in Godot editor and press F5 to run
- Command line: `godot --path .` (add `--mute` for automated runs)

**Exporting:**

- Web: `godot --export-release "Web" bin/index.html`
- Windows: `godot --export-release "Windows Desktop" path/to/output.exe`

**Testing/linting:** headless runners exist — see the Self-Test Harness section below.

## Deep-dive docs (read these before non-trivial changes)

- `docs/ARCHITECTURE.md` — scene flow, autoloads, signals, player/enemy state machines,
  characters, physics layers, known quirks
- `docs/LEVELS.md` — how main.tscn/boss_room are structured, where ground collision
  actually lives (TileSet physics layers), how to inspect/edit tilemaps
- `docs/LANE_REFACTOR.md` — planned TMNT-style multi-lane movement: complete catalogue
  of single-ground-plane assumptions to change, plus pre-existing bugs to fix first
- `tools/dump_level.gd` — headless JSON dump of any scene's geometry:
  `godot --headless --path . --script res://tools/dump_level.gd -- --scene res://scenes/main.tscn --out dump.json`

## Architecture Overview

### State Machine Architecture

The game uses a comprehensive state machine pattern for both player and enemy behavior:

- **Base Classes**: `scripts/states/state.gd` and `scripts/states/state_machine.gd`
- **Player States**: idle, run, jump, fall, attack, crouch, climb, knockback, dead
- **Enemy States**: patrol, chase_player, attack_player, find_meter, dead

### Global Singletons (Autoloaded)

These are globally accessible throughout the game:

- **Globals**: Core game state, character management, global signals, progress tracking
- **Utils**: Utility functions and screen effects
- **AudioManager**: Sound and music management
- **EnemySpawner**: Enemy lifecycle management
- **ScreenShake**: Screen shake effects
- **ChatBubble**: Dialog system

### Character System

Character switching is managed through `Globals.character_dict` with unlockable characters:

- Robot (Atomic Robot mascot)
- Cody (Shop owner)
- Ryan (Employee)

Each character has associated sprite frames and unlock conditions.

### Game State Management

`Globals.gd` tracks:

- Current selected character
- Player position and health
- Meter maid kill counts
- Boss fight status
- Destroyed nodes persistence
- Global event states

### Signal System

Global signals for major game events:

- `player_death`, `meter_maid_death`, `meter_maid_boss_death`
- `unlocked(name, description)` for character/feature unlocks
- `boss_fight(status)`, `event(status)`, `newspaper(status)`

### Physics Configuration

- Viewport: 1280x800 with canvas item stretching
- Physics layers: Player (1), Ground (2), Enemy (3), Platforms (6), Wall (7)
- Input: WASD + Arrow keys, F (Attack), E (Interact), Shift (Run)

## Key Development Notes

### State Transitions

When working with player/enemy behavior, states are managed through the StateMachine class. State changes are logged to console for debugging.

### Node Destruction Persistence

The game tracks destroyed objects via `Globals.destroyed_nodes` to maintain state across scene reloads.

### Bug Tracking

Current known issues are tracked in README.md including character highlighting bugs, collision issues, and health system problems.

### Mobile Support

Virtual joystick addon is included in `addons/virtual_joystick/` for mobile/web builds.

### Asset Organization

- `sprites/`: Character animations and UI elements
- `Tiles/`: Environment tilesets and backgrounds
- `Sounds/`: Audio files with Godot import settings
- `scenes/`: Game objects and level scenes
- `scripts/`: All GDScript code organized by function

<!-- BEGIN godot-selftest-harness -->
## Self-Test Harness (godot-selftest-harness)

This project ships a **self-test harness**: a file-based DevTools bridge (control a
running game from the CLI), headless lint + unit-test runners (no game needed), and a
diff-aware **`/verify`** pre-commit gate. It is game-agnostic; project-specific behavior
is discovered at runtime or read from the config file below.

### DEVELOPMENT RULE (REQUIRED)
After **any** gameplay, script, or scene change, run **`/verify`** before considering the
work complete — don't wait for a commit request. It runs lint + tests, launches the game
muted, and asserts your actual diff at runtime (catching errors lint/tests can't).
Headless lint and unit tests need **no running game**; run them anytime:

```bash
godot --headless --path . --script res://tools/lint_project.gd   # UID + scene lint
godot --headless --path . --script res://tools/run_tests.gd      # unit tests (test_dir)
```

### Command cheat-sheet (`python3 tools/devtools.py <verb>`)
Launch first: `godot --path . --mute &` then `sleep 5 && python3 tools/devtools.py ping`.

| Verb | Use |
|---|---|
| `ping` / `quit` | Confirm bridge is live / shut game down cleanly |
| `scene-tree` | Discover root scene name + node paths (don't assume names) |
| `get-state --node PATH` | Read a node's properties (verbose — prefer one property) |
| `set-state --node PATH --property N --value V` | Set raw property (bypasses setters/signals) |
| `run-method --node PATH --method N --args "[...]"` | Call a method — preferred when a signal should fire |
| `node-bounds PATH` | Exact position/size (deterministic layout ground truth) |
| `ui-snapshot` / `ui-snapshot-diff` / `save-ui-baseline` | Structured UI state vs baseline |
| `validate-all` / `validate-ui` | Scene + UI layout validation (expect 0 issues) |
| `performance` | FPS vs `fps_min`, orphan nodes vs `orphan_max` |
| `input <press\|release\|tap\|clear\|list\|sequence>` | Simulate input actions |
| `set-game-speed N` / `wait-frames N` | Speed up / step time deterministically |
| `clear-nodes --group G` (or `--method`/`--class`) | Free matching nodes |
| `screenshot` | Visual check only (`sleep 0.5`–`1` after a state change) |
| `list-commands` | Discover all registered verbs (generic + project) |
| `cmd <verb> --args '{...}'` | Invoke any project-registered verb |

### Add project-specific debug verbs
Register domain verbs in `res://devtools_ext/commands.gd` (loaded after generic verbs,
last-writer-wins). Each handler returns exactly `{success:bool, message:String, data:Dictionary}`.

```gdscript
func register_commands(dev: Node) -> void:
    dev.register_command("spawn_enemy", func(args): 
        return {"success": true, "message": "ok", "data": {}})
```

Reach them from the CLI via `cmd spawn_enemy --args '{"count":3}'`; discover them via
`list-commands`. Use these for setup/trigger steps the generic primitives can't express.

### Config
`res://addons/godot_selftest/devtools_config.json` holds thresholds and hooks:
`fps_min`, `orphan_max`, `mute`, `main_scene`, `entry_hook {node_path, method}` (advances
past a menu into the playable scene), `test_dir`, `scan_root`, `hud_layer_name`.

### Token-aware
- Prefer `node-bounds` / `ui-snapshot` (compact, deterministic) over `screenshot`; only
  open a screenshot PNG when a genuine **visual** regression is suspected.
- `get-state` dumps all node properties — read the specific property you need.
- Run `/verify` **inline**; don't wrap routine validation in subagents/workflows.
- Launch with `--mute` for automated testing.

### (Re)install
Run **`/scaffold-godot-harness`** to install or refresh the harness. Re-running it also
refreshes this very section in place (it never duplicates it).
<!-- END godot-selftest-harness -->
