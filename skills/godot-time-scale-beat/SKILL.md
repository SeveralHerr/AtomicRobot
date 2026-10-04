---
name: godot-time-scale-beat
description: Add a slow-mo / freeze "beat" (death beat, finale, hit-stop) or a scene fade to a Godot 4 game without leaking Engine.time_scale or pause state. Use when a feature writes Engine.time_scale, pauses the tree for a fade, or delays a screen until an effect finishes.
---
# Time-scale beats and scene fades

Reference: `scripts/ui/death_beat.gd`, `scripts/autoload/transition.gd`, tests
`test/unit/test_death_beat.gd`, `test/unit/test_transition.gd`.

## Rules (each was a real bug or a surviving mutant)
- Delay the CONSUMER (the card awaits the beat), not the global signal: score, enemies and
  encounters rely on the signal firing on the blow.
- One owner per beat; it re-asserts `Engine.time_scale` every `_process` while active
  (a hit-stop or another ticketed slow-mo ending writes 1.0 mid-beat).
- Guard `_process` with a flag: Godot re-enables processing at READY for any script that
  defines `_process`, so `set_process(false)` in `_init` does nothing -> slow-mo forever.
- `NOTIFICATION_PAUSED` / `EXIT_TREE` -> 1.0, only while YOUR beat runs (don't cancel the boss's).
- Real-time waits: `create_timer(s, false, false, true)` (pausable, ignores time scale);
  tweens `.set_ignore_time_scale(true)`.
- A fade that pauses the tree must also be vetoed by anything that toggles pause by polling
  (`PauseMenu._process` checks `Transition.busy`).
- Wait 2 frames after `change_scene_*` before fading in: the load lands in one frame's delta.
- Desaturate under a card by giving the card's existing dim rect a `hint_screen_texture`
  shader (`shaders/end_card_dim.gdshader`) — no second overlay; `move_to_front()` the card so
  later-added siblings (boss HUD) are greyed too.

## Tests that kill the mutants
time scale during/after the beat, pause mid-beat (1.0) and unpause (slow again), external
reset re-asserted, leave mid-beat (use a level whose `_exit_tree` does NOT reset time itself),
pause outside a beat leaves another slow-mo alone, second signal doesn't restart (grey still
1.0 after), win during beat not overwritten. Transition: swap only at alpha 1 + paused,
second request dropped, failed swap recovers, time reset at swap, source grep for direct
`change_scene_*` callers (allow-list checked both ways).
