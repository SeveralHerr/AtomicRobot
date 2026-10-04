---
name: juicy-screen-review
description: Redo a Godot menu/select screen for game juice, then run a 4-judge panel (game feel, art, arcade UX, code) and a 10-round screenshot validation loop. Use when asked to "redo", "juice up", or "review with judges" any front-end screen.
---
## Build (keeps tests green)
- Characterize first: run the screen's existing tests, note the public API they touch
  (focus owner on open, what A/locked/footer do). Move them to `test_<screen>.gd` and
  re-point them at the new API (`card_for(name)`, `exit_button`), not node paths.
- Build UI in code under `scripts/ui/<screen>/`; root `.tscn` holds only the script.
  Every animated piece is a FREE child: Button (in HBox, focus owner) > `drop` (intro)
  > `visual` (hot lift/tilt). Containers reset scale/rotation of their children.
- One tween owner per node: keep the Tween in a field, `kill()` before starting another.
  Shakes take an explicit `rest` position (re-shake mid-shake otherwise drifts).
- Explicit `focus_neighbor_*` for strips; geometric search breaks once cards lift/tilt.
- Read `startscreen.tscn` before picking a background: users want the title art reused.
- `get_image()` is a GPU readback: cache per texture (Pi stalls otherwise).

## Judges (parallel, read-only `general-purpose` agents, <400 words each)
Game-feel (hitstop, anticipation, sound), art director (contrast through the CRT),
arcade UX (pad-only, prompt honesty vs the InputMap, touch, mash safety), Godot code
(tween lifetimes, await-after-free, dead code, vacuous tests). Give each the screenshot
dir + file list; ask for score /10 + ranked fixes with file and numbers.

## Validation loop
`scratchpad/shot.gd` drives the real flow with `InputEventAction` and snaps every state;
`sheet.py` makes a 2-col contact sheet; `round.sh N [--resolution 1688x780]` does both.
Each round = 3 fixes (judge findings first) + run suite + shoot + look. Last round at
phone resolution. Then mutation-check new guards (`mut.py`, KILLED/SURVIVED per mutant).

## Gotchas hit
- Test `InputEventAction` doesn't change "last device"; inject `InputEventKey` for that.
- Stub subclasses set grace/timers to 0 in `_init()` (runs on `set_script`).
- Flash overlay sits above the stage, but a card with `z_index = 1` draws over it.

## Through the CRT (end card redo, 2026-10-04)
- Force `CRTOverlay.set_enabled(true)` in capture scripts: a worktree's settings.cfg may
  have it off, and every "it reads fine" shot was taken without the tube.
- The CRT's 512x320 pixel grid eats text under ~40 px. Fix readability per screen with
  `CRTOverlay.tune_in(true)` / `reset_focus()` (FOCUS preset) rather than shrinking content.
- Scanlines/grille at a fine grid alias into wavy moiré on white cards — zero them in focus.
- Smooth GIFs: run the capture under `--write-movie m.avi --fixed-fps 30` and cut with
  ffmpeg palettegen; PNG-per-frame captures run at ~4 fps wall clock and drop the juice.
- Capture waits: boss_room's intro fades the HUD back in at ~7 s; emit end signals after 9 s.
- An empty `create_tween()` (no tweeners) is an engine error the autoplay gate catches.
