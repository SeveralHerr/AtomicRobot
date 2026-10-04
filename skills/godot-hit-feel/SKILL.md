---
name: godot-hit-feel
description: Add or tune combat impact feel in Atomic Robot (or any Godot 4 brawler) — hitstop, camera shake, hit sparks, same-frame hit reactions — and prove it with frame-tagged screenshots. Use when hits "feel weak/laggy", a shake "does nothing" or is nauseating, or when touching ScreenShake, Utils.apply_hit_pause, HitFeel or Player.land_hit.
---
# Hit feel

Code: `scripts/combat/hit_feel.gd` (numbers), `scripts/autoload/screenshake.gd`,
`Utils.apply_hit_pause`, `scenes/hit_fx.tscn`. Every player blow funnels through
`Player.land_hit -> HitFeel.hit_landed`; don't add per-attack shakes elsewhere.

## Rules (each was a real bug)
- Shake: one at a time, strongest amplitude + longest remaining wins, quadratic falloff
  to 0, offset restored, real time (`delta / time_scale`), cap 16px (pinball's SHAKE_PX).
  Default duration 0.3s — callers without a duration (door encounter) get that.
- Hitstop: wall clock, extend never shorten, skip if `time_scale != 1` (BossJuice slow-mo
  owns time), restore only if still 0, off in headless (autoplay determinism).
  Re-check the wall clock after each timer: an ignore_time_scale timer can fire early.
- Reactions on the hit frame: no random delays; `AnimationPlayer.advance(0)` after
  `play("Hit")` or the freeze shows the unflashed sprite.
- Sparks: sibling above the target (`z_index + 1`), tinted (white vanishes into the
  white hit flash), start on the full-burst frame (hitstop freezes frame 0).

## Tests
`test_screenshake.gd` (fresh instance, injected camera, `step()` by hand),
`test_hit_pause.gd` (`allow_headless_hit_pause`, poll wall clock per frame — timer
waits fire early), `test_hit_feel.gd` (real Player/maid scenes; `last_hit_pause_request`).

## Validation capture
Autoplay snaps are game-time, so they can't see a hitstop. Use a windowed SceneTree
script that injects `InputEventAction` (Input.action_press doesn't reach state
`handle_input`), saves frames tagged `ts0/ts1` + shake strength, then crop a sheet.
Parallel agents share the session scratchpad: keep files in `scratchpad/<task>/`
with task-prefixed names; never `rm -rf` a generic dir like `shots/base`.
