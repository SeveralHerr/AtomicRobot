---
name: godot-draw-order
description: Fix "X draws on top of Y" bugs in Atomic Robot (player/maid over a tree, prop over a body). Use when a screenshot shows wrong layering between bodies and level props.
---
# Draw-order bugs

1. Reproduce at the spot: `tools/level_pan.py` to match the screenshot, then a scenario in
   your scratchpad (NOT autoplay_out — the report overwrites a same-named scenario):
   `lane 0` first (teleport keeps the current lane), `teleport X Y` above the floor, `wait 0.8`, `snap`.
2. Ask what the player expects if the depth is ambiguous ("on the ledge" vs "on the sidewalk"
   look identical in a phone shot).
3. Dump effective z (sum z_index up the z_as_relative chain) of every z!=0 CanvasItem in the
   level. Ties lose to tree order; `LaneSortLayer` is the scene's last child, so bodies win ties.
4. Body z lives in `Lanes.depth_z` (street lane 0 = 1, raised ground = `RAISED_Z` 0, road
   lanes 10+). Fix there, used by both Player and `enemy_lane_mover`, never per prop.
5. Test derived from the level (every tree.tscn in main/boss_room), see
   `test/unit/test_raised_draw_order.gd`; A/B by flipping the constant and re-snapping.
