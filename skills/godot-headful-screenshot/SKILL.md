---
name: godot-headful-screenshot
description: Capture PNGs of a Godot UI state or a timed gameplay sequence (death blink, effect) for the validation loop. Use when asked to screenshot/verify a menu, HUD or in-game visual change.
---
Headless renders nothing; run the windowed console build with `--mute` and a throwaway SceneTree script
(keep it in scratch `tools/tmp/`, delete after):

```gdscript
extends SceneTree
func _initialize() -> void:
	await process_frame            # autoloads ready
	var pm = root.get_node("PauseMenu")
	pm.toggle_pause(); pm._show_controls()   # drive to the state under test
	for i in 10: await process_frame         # let containers lay out
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
```
`godot --path . --mute --script res://tools/tmp/shot.gd -- <abs.png>` then Read the PNG.
The CRT overlay autoload is in the shot - judge legibility through it, it is what players see.

## Gameplay sequences (death anims, blinks, effects over time)
- Boot a sandbox: `change_scene_to_file("res://test/scenes/<x>.tscn")`, `await create_timer(2).timeout`.
- **No class_name types in the script** (`var m: MeterMaidWindow`, `n is Enemy`): the --script compiles
  before autoloads register -> "Identifier not found: Globals" cascade. Duck-type (`has_method`).
- Snap at timestamps relative to the trigger; `await RenderingServer.frame_post_draw` before
  `get_texture().get_image()`. Crop around the node (`get_global_transform_with_canvas().origin`,
  160px box, `resize(x3, INTERPOLATE_NEAREST)`) - small sprites are unreadable full-frame.
- Script may live in the session scratchpad (absolute path works with `--script`).

## Animated proof (GIF for an artifact)
- Save every Nth frame (`f_%04d.png`) for a few seconds, then Pillow:
  `frames[0].save("x.gif", save_all=True, append_images=frames[1:], duration=200, loop=0)`
  after `thumbnail((640,640))`. ~70 frames at 640px ≈ 7 MB — fine for an Artifact `files` entry (16 MB cap).
- Disable hazards that knock the player out of the shot (e.g. window maids) in the capture script only.

## Gotchas
- New `class_name` scripts (from you or a parallel agent) are unknown to `run_tests.gd` until
  `godot --headless --path . --import` refreshes the global class cache -> "Identifier not declared".
- Opening the editor/import can reorder `project.godot` sections; revert if the diff is order-only.
- `--resolution 1688x780` with stretch `canvas_items` saves a 1248x780 viewport image (letterboxed
  content), not 1688 wide: judge fit on that, the bars are outside the viewport texture.
- Snap timing: scene loads block the main loop, so a "t=0.27" snap can land at 0.9s. Print the
  state you are judging (fade alpha, `Engine.time_scale`) beside each SNAP line instead of trusting t.
- `InputEventAction` does not satisfy `any_button.gd` (keys/joy only): send `InputEventKey` ENTER.
- `print_stack()`/`get_stack()` print nothing without a debugger; trace with plain `print`.

## Phone-size rounds (verified 2026-10-03)
- `--resolution 1688x780` on a throwaway `--script` SceneTree capture does NOT change the
  captured image. Use the bot instead: `python tools/autoplay.py my.json --window --resolution 1688x780`
  with `snap_every` — snaps come out at the aspect-fit viewport size (1248x780 for 1688x780),
  which is what a landscape phone actually shows.
- Or, in the `--script` capture itself, call `DisplayServer.window_set_size(Vector2i(1688, 780))`
  before the first `await process_frame` (verified 2026-10-04): snaps come out 1248x780, so one
  script can shoot desktop and phone rounds of states the bot cannot reach (e.g. emitted signals).
- `get_tree().root` z-order: a `z_index` beats tree order inside a CanvasLayer, so `move_to_front()`
  does not guarantee "on top" (hp_1.tscn orbs, z 2, drew over the end card). Check effective z.
- Pin layout clearances numerically too (e.g. `BossBanner.burst_radii` vs the HUD combo slot
  in `test_encounter_announcer.gd`) — a screenshot only proves the frame you caught.
