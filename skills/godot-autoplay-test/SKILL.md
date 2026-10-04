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
python tools/autoplay.py my.json --window --resolution 1688x780         # landscape-phone snaps
python tools/autoplay_sweep.py --chars Ryan,Robot --seeds 1,2   # balance table, no god mode
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
off their lane floor, lane unchanged) · `brain advance|clear|monkey [S] [X]` (X: advance
fights forward and the step ends on arrival at x=X — route scripting between secrets) · `menu [S]`
· `snap [NAME]` · `dump [NAME]` · `assert METRIC OP VALUE`.
A step that can't do its job (`walk_to`/`lane`/`menu` timeout, `spawn` with no player)
FAILS the run with `step failed: ...`. Once the player dies, the run stops at the first step
that needs a live player; `wait tap menu snap dump assert` still run, so `menu` can drive the
GAME OVER card -> RESTART -> back into main (`test/autoplay/death_restart.json`).

Metrics: `t frames scene x y lane hp max_hp state kills damage_taken hits_taken heals powerups
deaths won boss_reached enemies_near max_stuck_s stuck_spots step_failures errors
engine_errors warnings score boss_hp secret_walls secret_news headlines cutscenes` (`boss_hp` = -1
until the boss spawns; how far a lost fight got; `secret_*` count `Globals.secret_found`
once per id, `headlines` = distinct newspaper headlines read; `secret` events name them). `scene`/`state` take `==`/`!=`; the rest are numbers.
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

## Recording a video
`python tools/autoplay.py <one scenario> --record out.mp4` (MCP `record_autoplay`) does all of
this; full review workflow in `skills/godot-speedrun-review/SKILL.md`. By hand, Movie Maker:
`godot --path . --write-movie out.avi --fixed-fps 60 -- --autoplay x.json --autoplay-out DIR`
(windowed; omit `--mute` to keep audio; ~9 MB/s MJPEG; hitstop is wall-clock, so frames differ from headless). Encode with the ffmpeg bundled
in `pip install imageio-ffmpeg` (`imageio_ffmpeg.get_ffmpeg_exe()`): libx264 + aac.
Reports log `powerup` (id) and `unlock` events. Interact (`tap Interact`) is scripted —
the brain never presses it; cracks need ~0.6 s between `tap Attack` (taps mid-swing drop).

## Gotchas
- A script that fails to PARSE never runs, so `errors` stays 0; autoplay.py scans stdout and
  reports `SCRIPT-ERROR`. Most common cause: a NEW `class_name` not yet in the class cache —
  run `godot --headless --path . --import` after adding one.
- Auto-snaps are named `f<frame>` so `snap_every` < 1 doesn't overwrite. GIF recipe:
  `snap_every 0.125` windowed, then PIL `quantize(96)` + `save(save_all=True, duration=125)`.
- Balance: `hurt` events carry `near` (closest enemy) — count them per source to see which
  attack is doing the damage before touching numbers. Pin the result with a seeded mortal
  scenario both ways (`boss_balance_ryan` must win, `boss_balance_cass` must reach half).
  Whole-route table: `autoplay_sweep.py --base test/autoplay/full_run_mortal.json --seeds 1,2,3,4`
  adds street_hits / boss_hits / door_hp. `near` is only the NEAREST enemy: ceiling drops
  and fans next to the boss all read `city_council_boss`. One mortal route run is ~6 s wall.
- `--record` (windowed Movie Maker) does NOT replay the headless run: same seed, different
  route timing (boss at 260 s vs 165 s once). Read its own report for times before cutting frames.
- The bot sees hearts through the `atomic_hearts` group (runtime drops included); it skips
  a heart after `HEAL_GIVE_UP_S` of chasing — mortal runs used to soft-lock on the crate heart.
- `--fixed-fps 60`: deterministic and faster than real time. Same seed = same frames. If
  a rerun diverges, something reads the wall clock or calls `randomize()`.
- Main street x≈2811-2906: a crate stack on the walkway (Ground layer only). Road lanes
  pass in front of it; lane 0 is solid both sides and `lane 0` is refused while
  overlapping it (`Lanes.walkway_blocked`). A walkway prop on the Wall layer (64)
  walls off EVERY lane — invisible on the road. `crate_lanes.json` pins this.
- `god on` tests the ROUTE (soft locks, progression); a run without it tests difficulty.
- `run_tests.gd --filter` matches test METHOD names, not files (`--filter autoplay` = 0 tests).
- A `--script` SceneTree driver can't reference autoloads/class_names; this autoload can.
