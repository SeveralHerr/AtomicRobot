---
name: godot-lane-collision
description: Diagnose and fix "invisible wall", "can't walk past X", "stuck on the road", or a prop that blocks lanes it isn't drawn on in Atomic Robot's TMNT-style lanes. Use before placing any solid prop on the street, when autoplay reports a stuck spot, or when a lane step embeds a body in scenery.
---
# Lane collision

Lane 0 (walkway) rides real collision. Road lanes 1-3 drop Ground(2)/Meter(4)/Platforms(6)
from their mask (`Player._set_ground_collision`, `enemy._set_ground_collision`) but KEEP
Wall(64). So a prop's layer decides which lanes it blocks:

| prop layer | blocks |
|---|---|
| Ground (2) | walkway only (road lanes walk in front) — right for walkway props |
| Wall (64) | EVERY lane — only for level edges and door-arena barriers |
| Platforms (32), one-way | nothing sideways; stand-on only |

## Find it
1. `python tools/lane_wall_audit.py` (or MCP `audit_lane_walls`): lists Wall-layer bodies
   reaching the road strip. Barriers/boundaries are expected; anything else is suspect.
2. Autoplay `stuck_spots` give x/lane. `tools/dump_level.gd` → filter `collision_bodies`
   by x ± 150 to see who owns that x.
3. Look in the SUBSCENE (`scenes/building_group_*.tscn`), not main.tscn — the level is split.

## Fix
- Walkway prop on Wall → set `collision_layer = 2`.
- Stepping UP onto the walkway while overlapping that prop would re-enable Ground with the
  body inside it. `Lanes.walkway_blocked(body, shape, stand_pos)` refuses it (Player
  `try_change_lane`, enemy `_lane_chase`). Probe mask is Ground only: one-way awnings
  overhead (layer 32, y≈-58) gave false positives.
- Teleporting into a prop's x range keeps the CURRENT lane; scenarios that then `lane 0`
  there now fail by design — start past the prop.

## Pin it
- Scenario like `test/autoplay/crate_lanes.json`: walk each road lane past, assert a
  refused `tap ui_up` inside the prop, assert walkway blocked from both sides.
- `max_stuck_s < 60` on a mortal full run catches regressions the god run hides.
- Prove each guard: stash the fix file, rerun with the scenario/filter, see it fail.
