---
name: godot-door-mouth
description: Place, restyle or juice an Atomic Robot door encounter mouth (BuildingDoorEncounter -> DoorMouthFx WallMouth/BushMouth), or author pixel-art FX from the game's own art. Use when a crack/breach/bush burst looks wrong, sits on a window/sidewalk, or a new encounter is added to a building group.
---
# Door mouths

Code: `scripts/door_mouth_fx.gd` (base: rumble, jitter, dust, particle helpers),
`door_mouth_wall.gd` (crack -> brick breach), `door_mouth_bush.gd` (shrub -> torn halves),
art `sprites/door_breach.png` (hole|rim|rubble) and `sprites/door_bush.png`
(clump|hollow|litter|left|right), all 64x56 bottom-aligned. Tests: `test_door_mouth.gd`.

## Placing an encounter
- Pick per placement in the group scene: `mouth_style` (WALL/BUSH), `wall_color` (sample the
  wall next to the mouth from a screenshot), `foliage_shade` (the hedge sprite's modulate,
  0.73 for dimmed Bush sprites), `mouth_scale` for tight piers. Move the mouth with a
  `DoorMouth` override, never the encounter (arena/trigger stay put). Add the new x to
  `STYLES` in test_door_mouth.gd.
- Overrides go AFTER all the encounter's own properties: inserting `[node name="DoorMouth" ...]`
  mid-block silently moved `enemy_count`/`waves` onto DoorMouth (caught only by the
  street-waves ramp test).
- Look wide first (camera zoom 1.5): a breach must sit on brick between ground and the lowest
  window; a bush mouth needs hedge >= 56 px tall behind it.

## Art from the game's own pixels
- Wall rim/rubble are neutral greys where 128 = the wall: modulate by `wall_color * 2`. One
  sheet fits every wall.
- Bush clump is cut from `Background_bush2.png`, lifted 1.14x with a dark contour so it reads
  in front of the hedge (an identical crop was invisible). Halves split down a zig-zag so they
  rebuild the clump exactly (tested pixel for pixel); outline every pixel that borders the
  other half or the torn edge reads as a dashed line.
- Generators lived in the scratchpad (PIL); keep the sheet layout if you redraw.

## Gotchas
- Changed a PNG? `godot --headless --path . --import` before capturing: the windowed
  `--script` run uses the stale import and you review old art.
- `CPUParticles2D` has no `amount_ratio` (GPUParticles2D only).
- Python edits of .gd/.tscn: `open(p, encoding='utf-8', newline='\n')`; the Windows default
  codepage wrote em dashes as 0x97 and broke the file.
- A spawned enemy on the burst frame hides the burst: keep `burst_beat_seconds`.
- Capture stills at fixed fractions of the telegraph: a blink that lands on the snap hides
  the eyes; one late blink only.

## Validation recipe
Throwaway SceneTree script: load main, mark every encounter `_fired`, own Camera2D at zoom 3
on `door_mouth`, call `_telegraph(true)` / `_burst()` / `_telegraph(false)`, snap 600x420
crops per state; PIL contact sheet. Real flow GIF: teleport the player 95 px left of the
mouth and save every 2nd frame (wall clock) cropped on `door_mouth`.
