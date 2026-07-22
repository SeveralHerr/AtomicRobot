# Task Completion Checklist

## When a Task is Completed

### Required gate (automated — do NOT skip)
After any gameplay/script/scene change, run **`/verify`** (lint + unit tests + muted
runtime assertions via the DevTools bridge). Headless pieces can also run individually:

- Lint: `godot --headless --path . --script res://tools/lint_project.gd`
- Tests: `godot --headless --path . --script res://tools/run_tests.gd`

(`godot` = `C:\Users\gotmi\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe`.)

### Manual checks when relevant
- Character switching still works for all 6 characters (Cody, Ryan, Sara, Cass, Caitlyn, Robot)
- State transitions log to console — watch for unexpected states
- If resources/images changed: reimport (`godot --headless --path . --import`) and
  re-lint; run `tools/fix_uids.gd` on uid mismatches

### Documentation
- Keep `docs/ARCHITECTURE.md` / `docs/LEVELS.md` / `docs/LANE_REFACTOR.md` in sync with
  structural changes; README.md tracks user-facing bugs
