---
name: godot-level-pickups
description: Place a static reward (power-up, heart) on a ledge, platform top or scaffold in Atomic Robot and prove it is reachable, readable and not a balance problem. Use when the user circles a spot for a pickup, asks for "static/placed power-ups", "a heart up on the roof", or asks whether a pickup is too high / too many power-ups per run.
---
# Level-placed pickups

- Power-up: instance `scenes/powerup_pickup.tscn` with `placed = true` + `powerup_id`
  (rage|overclock). Placed = no lifetime/blink, keeps its authored parent (no
  LaneSortLayer reparent), adds a `PowerupGlow`. Lane = GROUND_LANE: platforms and
  scaffolds are ground-lane floors. Heart: `atomic_heart_pickup.tscn`, add a `Glow`
  child (`powerup_glow.gd`, exported `color`) if it sits near the HUD.
- Put it in the sub-scene that owns the geometry (e.g. `atomic_robot_building_group.tscn`,
  world = local + (-258,-97)); main.tscn is usually owned by someone else.

## Numbers that decide reach (Player.gd)
Jump vy -450, gravity 1200 (x1.5 falling) -> **~84px** straight up; air speed 204 px/s,
a same-height run-jump clears ~130px. Standing player origin = floor top - 20.
A pickup centre 15-25px above the floor top is touched by anyone standing there; a
plank 94px up is NOT standable, but a pickup just above it is grabbed at a jump's apex.

## Workflow
1. Floors: `tools/dump_level.gd` (collision rects in world coords; top = y - h/2).
   Trust a probe of `transform` chains over guessed parents (instance roots carry offsets).
2. Look first: autoplay `lane 0`, `teleport X Y` (Y onto raised geometry), `wait 1.2`, `snap`.
   Camera is zoom 2.5 (512x320 world view): anything ~95px above the player's floor
   lands in the HUD band (score, HP orbs, ART logo) — check at standing height.
3. Reach it for real in a scenario (`test/autoplay/placed_pickups.json`): jumps as
   `press ui_accept / wait 0.32 / release / wait 0.42`; `wait 0.4` after `walk_to` before
   a vertical jump or momentum carries you past a 60px platform.
4. Unit test against the real collision (`test/unit/test_placed_pickups.gd`), not numbers.
5. Balance: `autoplay_sweep.py --base <route> --chars Ryan,Cass --seeds 1,2,3,4`, count
   `powerups` per run and buff uptime (union of 8s windows / run time). The bot brain
   ignores pickups beyond MAX_DY, so only a scripted route (completionist) collects
   placed ones. Old drop-rate failure = buffed >50% of the time.
