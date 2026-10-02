---
name: godot-headful-screenshot
description: Capture a PNG of a Godot UI state (e.g. pause menu sub-screen) for the validation loop. Use when asked to screenshot/verify a menu or HUD change.
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
