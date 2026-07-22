# Suggested Commands

> Godot 4.7.1 is NOT on PATH on this machine. `godot` below means
> `C:\Users\gotmi\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe`.
> Python 3.12 is installed as `python` (not `python3`).

## Development Commands

### Running the Game
- Editor: open project, F5
- CLI: `godot --path .` (add `--mute` for automated runs)

### Lint / tests (headless, no game window)
- `godot --headless --path . --script res://tools/lint_project.gd`
- `godot --headless --path . --script res://tools/run_tests.gd` (tests in `test/unit/`)
- `godot --headless --path . --script res://tools/fix_uids.gd` — repair stale uid:// refs
- `godot --headless --path . --script res://tools/dump_level.gd -- --scene res://scenes/main.tscn` — JSON dump of level geometry

### Runtime DevTools bridge (game running)
- Launch: `godot --path . --mute` then `python tools/devtools.py ping`
- Project verbs: `cmd start-game`, `cmd player-state`, `cmd teleport-player`,
  `cmd spawn-enemy`, `cmd list-enemies`, `cmd level-info`, `cmd dump-tilemap`
- Generic verbs + full cheat-sheet: see CLAUDE.md; discover with `list-commands`
- The `/verify` slash command runs the whole gate (lint + tests + runtime assertions)

### Exporting
- Web: `godot --export-release "Web" bin/index.html`
- Windows: `godot --export-release "Windows Desktop" path/to/output.exe`

## Authoritative docs
`CLAUDE.md` + `docs/ARCHITECTURE.md`, `docs/LEVELS.md`, `docs/LANE_REFACTOR.md`.
