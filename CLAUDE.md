# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment (this machine)

- Godot **4.7.1** is NOT on PATH. Use the full path:
  `C:\Users\gotmi\Documents\Godot_v4.7.1-stable_win64.exe`
  (no console build alongside it — this exe works fine for `--headless` runs). Treat
  `godot` in any command below as an alias for that path. Older 4.5.1/4.6.1 builds
  also sit in `Downloads\` — don't use them, the project targets 4.7.
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
godot --headless --path . --script res://tools/lint_project.gd   # UID + scene + dup-id lint
godot --headless --path . --script res://tools/run_tests.gd      # unit tests (test_dir)
```

Exit codes (both): `0` pass, `1` findings, `2` **the runner couldn't run** — a `2` means you
verified nothing. Redirect to a file and read it back; the Windows Godot build often prints
nothing to the console, so a failed run looks like silent success.
Lint flags (after `--`): `--strict` (warnings fail), `--baseline-write PATH` /
`--baseline PATH` (split findings into `NEW` vs `PRE-EXISTING` so repo debt isn't re-triaged
by hand), `--find-orphans` (public functions called only from tests — advisory).

**Writing tests.** Alongside `_T.assert_*`, use `await _T.instantiate_ui(scene, Vector2i(w, h))`
/ `_T.free_ui(node)` for anything `Control`-shaped: headless pumps no frames, so without it
`size` stays `(0, 0)` and `@onready` vars never initialize. Test methods may `await`.
**Always read stderr**: a runtime error inside a test aborts only that method and returns
`""` for a `-> String` test — identical to a pass. `[ERR]` lines are the only signal.

### DEVTOOLS LOG (REQUIRED)
At the end of **every** response, append an entry to `log-devtools.md` (create it if
missing) recording any gaps in `/verify` or the devtools harness that would have helped
with this task, each with a suggested improvement. If nothing was missing, write one
explicit "no gaps this turn" line — that is what makes an absent gap distinguishable
from a forgotten log.

```markdown
## YYYY-MM-DD — <what this response did>

- Gap: **<what was missing>** — <the command run, the output it gave, the workaround used>
  - Improvement: <the smallest change that would have closed it>
```

Quote real output; a gap without evidence can't be acted on later. This log is the
harness's feedback channel — entries here are what get upstreamed into
`godot-selftest-harness` itself, so a gap logged here becomes a fixed feature for every
project using it. A `Stop` hook (`tools/check_devtools_log.py`, wired in
`.claude/settings.json`) prints a reminder when a session changes code without touching
the log; it is advisory, not a gate.

### Command cheat-sheet (`python3 tools/devtools.py <verb>`)
Launch first: `godot --path . --mute &` then `sleep 5 && python3 tools/devtools.py ping`.

| Verb | Use |
|---|---|
| `ping` / `quit` | Confirm bridge is live / shut game down cleanly |
| `scene-tree` | Discover root scene name + node paths (don't assume names) |
| `get-state --node PATH [--property N ...]` | Read a node's properties. **Always pass `--property`** — an unfiltered `Label` is ~120 keys. Repeatable; unknown names are reported, not dropped |
| `set-state --node PATH --property N --value V` | Set raw property (bypasses setters/signals) |
| `run-method --node PATH --method N --args "[...]"` | Call a method — preferred when a signal should fire |
| `node-bounds PATH` | Exact position/size (deterministic layout ground truth) |
| `ui-snapshot` / `ui-snapshot-diff` / `save-ui-baseline` | Structured UI state vs baseline |
| `validate-all` / `validate-ui` | Scene + UI layout validation (expect 0 issues) |
| `performance [--reset-baseline]` | FPS vs `fps_min`, orphan **growth** vs `orphan_growth_max` |
| `input <press\|release\|tap\|clear\|list\|sequence>` | Simulate input actions |
| `touch <press\|release\|drag\|clear\|list> --index N --pos X,Y` | Real `InputEventScreenTouch`/`Drag` — the only way to exercise multi-touch |
| `set-feature --touchscreen true` | Makes touch UI show itself on desktop (it hides when no touchscreen is reported). Set it **before** the scene loads |
| `set-game-speed N` / `wait-frames N` | Speed up / advance N physics frames |
| `step-time --seconds N` | Advance ~N game-seconds with `time_scale` pinned to 1.0. Physics exact; process tweens land ±1 frame — it does not pause and step the tree |
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

**Attach liveness to every reply.** Register one status provider and its Dictionary is
merged into *every* response as `status` — the fact you need on every read and never
remember to ask for separately. Without it, a session that has silently died or frozen
keeps answering with well-formed zeros, which looks exactly like a clean pass.

```gdscript
    dev.register_status_provider(func(_args):
        var p = dev.get_tree().get_first_node_in_group("player")
        return {"player": "absent"} if p == null else {"player": "dead" if p.is_dead else "alive"})
```

Pair it with verbs that can *undo* the dead state (a `revive_player` that clears the
flag and leaves the death state, or a `god_mode` toggle). Restoring a health value is
usually not enough on its own — the death flag and state machine outlive it, so the
run stays frozen and unrescuable short of a relaunch.

**A setter verb must leave the game in a state the game itself can reach.** Writing one
half of an invariant pair is a latent trap — a `set_combo` that sets the count but not
the combo window tests nothing the moment the readout starts fading on that timer.

### Gotchas
- **One command at a time.** The bus is one command file / one result file. Requests
  carry an id the game echoes, so a crossed reply now errors (`Crossed replies: …`)
  instead of silently returning another request's data — detection, not concurrency.
- **`game not running` in ~2s** means a dead game *or* the wrong `user://` dir; the
  error can't tell them apart. Check `--userdata` before assuming a crash.
- **Assert transforms on `data.transform`, not the property dump.** Godot hides
  `position`/`scale`/`rotation` on container children, so a scale animation on a
  `VBoxContainer` child is invisible to a property read while working on screen.
- **A run that never changes is broken, not passing.** Check the `status` field.

### Config
`res://addons/godot_selftest/devtools_config.json` holds thresholds and hooks:
`fps_min`, `orphan_growth_max` (gate on this — `orphan_max: 0` is unreachable),
`safe_area_inset`, `mute`, `main_scene`, `entry_hook {node_path, method}` (advances past
a menu into the playable scene), `entry_points` (named alternates for scenes the default
hook can't reach), `test_dir`, `scan_root`, `hud_layer_name`.

### Token-aware
- Prefer `node-bounds` / `ui-snapshot` (compact, deterministic) over `screenshot`; only
  open a screenshot PNG when a genuine **visual** regression is suspected.
- `get-state` dumps ~120 keys for a `Label` — pass `--property NAME` (repeatable).
- Run `/verify` **inline**; don't wrap routine validation in subagents/workflows.
- Launch with `--mute` for automated testing.
- On Windows, probe Python by running it (`python3` may be a Store alias stub that
  exists and refuses to run).

### (Re)install
Run **`/scaffold-godot-harness`** to install or refresh the harness. Re-running it also
refreshes this very section in place (it never duplicates it).
<!-- END godot-selftest-harness -->


## Logging

- **Skills log**: At the end of every response, append an entry to `log.md` (create it if missing) listing any skills — from the available skills list for that session — that might have been useful for the task or would have been useful had they existed, each with a short (few-word) reason why. If none would have helped, note that briefly instead of skipping the entry. If a skill was actually used, also note a simple-words enhancement idea for it.
- **Devtools log**: At the end of every response, append an entry to `log-devtools.md` (create it if missing) with any gaps in the global `/verify` or devtools that might've helped with testing, plus a suggested improvement for each. 
