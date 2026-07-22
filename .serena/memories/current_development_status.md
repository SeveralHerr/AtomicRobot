# Current Development Status

As of 2026-07-21 (after commits `969b289` dev tools, `89af1a5` Godot 4.7 upgrade, and
the project-enablement commits that followed):

- Engine: **Godot 4.7.1** (GL Compatibility). Binary at
  `C:\Users\gotmi\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe` (not on PATH).
- Self-test harness installed (`addons/godot_selftest` + `tools/devtools.py` +
  `/verify`); project devtools verbs live in `devtools_ext/commands.gd`;
  entry hook `Globals.debug_start_game` skips menus for automated runs.
- Lint and unit tests are green (7 tests in `test/unit/`). 176 stale UID refs from the
  4.7 upgrade were fixed; `tools/fix_uids.gd` exists for recurrences.
- Docs: `docs/ARCHITECTURE.md`, `docs/LEVELS.md`, `docs/LANE_REFACTOR.md`.

## Next major initiative
**TMNT-style multi-lane movement** (depth lanes in addition to left/right).
`docs/LANE_REFACTOR.md` catalogues every single-ground-plane assumption (player physics,
enemy AI, spawner, projectiles, tilemaps, z-ordering) and pre-existing bugs to fix first
(KnockbackState enter/exit naming bug, dead ClimbState, static_attack_state legacy code).
