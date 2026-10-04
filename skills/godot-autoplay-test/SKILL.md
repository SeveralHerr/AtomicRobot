---
name: godot-autoplay-test
description: Self-test Atomic Robot by letting a bot play it — scripted scenarios or a full title-to-win run — and read back a short text summary, event log and optional screenshots. Use after any gameplay, level, enemy, menu or boss change to prove the game still plays end to end, to reproduce "player gets stuck / soft-locked / can't progress" reports, or to check a fix in the real scene instead of a unit stub.
---
# Autoplay bot

A debug-only autoload (`scripts/autoload/autoplay.gd`) that, launched from the project
with `-- --autoplay <scenario>`, drives the real game with REAL key events
(`Input.parse_input_event`, first key binding of each action) — menus, `_input`
handlers and polled `Input.is_action_pressed` all see it like a keyboard. Code lives in
`tools/autoplay/`. Exported builds can never run it (template check + export exclude).

```
python tools/autoplay.py                  # all test/autoplay/*.json, headless, ~15s
python tools/autoplay.py full_run         # title -> street -> boss -> YOU WIN (god mode)
python tools/autoplay.py my.json --window # windowed: `snap` steps / snap_every save PNGs
python tools/autoplay.py my.json --events hurt,stuck,step_failed,why   # print events
```
Exit 0 pass · 1 fail · 2 BROKEN (invalid scenario). Read the ~12-line summary first;
`--events` or `autoplay_out/<name>.json` (`events`) for detail. Headless runs skip snaps
(the summary says so). Scenarios: write to a FILE — PowerShell mangles `--inline` quotes.

## Scenario (JSON, every key optional)
`name` · `scene` (default main.tscn) · `boot` (start at title; use `menu`) · `character`
(Ryan Cody Sara Cass Caitlyn Robot) · `seed` · `timeout` (game s) · `snap_every` · `steps` · `expect`.
Everything is validated before the run (verbs, actions, lanes, metrics, numbers).

Steps (`"verb args"`): `wait S` · `hold ACTION S` · `tap ACTION` · `press/release ACTION`
· `walk_to X [T]` · `lane N` (0 walkway .. 3 front; main.tscn only) · `teleport X`
· `spawn melee|ranged [DX] [LANE]` · `god on|off` (survives scene changes) · `hp N` (raw;
3 per orb) · `kill_all` (not counted as kills) · `sink DY` (push live non-locked enemies DY px
off their lane floor, lane unchanged) · `brain advance|clear|monkey [S]` · `menu [S]`
· `snap [NAME]` · `dump [NAME]` · `assert METRIC OP VALUE`.
A step that can't do its job (`walk_to`/`lane`/`menu` timeout, `spawn` with no player)
FAILS the run with `step failed: ...`. Remaining steps are skipped once the player dies.

Metrics: `t frames scene x y lane hp max_hp state kills damage_taken hits_taken heals
deaths won boss_reached enemies_near max_stuck_s stuck_spots step_failures errors
engine_errors warnings score`. `scene`/`state` take `==`/`!=`; the rest are numbers.
`max_stuck_s` = longest time, during `brain advance` or `walk_to`, without a new best
position in the travel direction (fighting doesn't count). `errors` = script errors and
`push_error`; `engine_errors` = C++-side (e.g. missing animation).

```json
{"name": "heart_pickup", "timeout": 30,
 "steps": ["god on", "teleport 2880", "kill_all", "hp 3", "lane 0", "walk_to 2944 5", "wait 0.5"],
 "expect": ["heals >= 1", "hp == 6", "errors == 0"]}
```

## Brain (`brain advance`)
Pure `brain.gd: decide(snapshot, mem) -> intent`, unit tested. Ladder: close threat ->
heal (hp <= 6) -> pickup -> fight -> advance (on the road lanes), then unstick (jump ->
held lane step / remember road block -> seeded random back-off + running jump). The
report's `why` events are its decision trail — read them first when a run stalls.

## Gotchas
- `--fixed-fps 60`: deterministic and faster than real time. Same seed = same frames. If
  a rerun diverges, something reads the wall clock or calls `randomize()`.
- Main street x≈2700-2950: the door-encounter barrier and a crate stack whose collider
  also walls off the road lanes. `walk_to` can't pass it; `teleport` past or use `brain`.
- `god on` tests the ROUTE (soft locks, progression); a run without it tests difficulty.
- `run_tests.gd --filter` matches test METHOD names, not files (`--filter autoplay` = 0 tests).
- A `--script` SceneTree driver can't reference autoloads/class_names; this autoload can.
