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
