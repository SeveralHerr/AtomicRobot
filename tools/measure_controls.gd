extends SceneTree

# Headless layout probe for text-heavy UI scenes.
#   godot --headless --path . --script res://tools/measure_controls.gd -- res://scenes/controls_splash.tscn
# Reports, per Label: rect, line count, font height and the *actual* per-line advance
# (label height minus font height, divided by the gaps). An advance smaller than the
# font height means the lines overlap on screen.

func _walk(n: Node, out: Array) -> void:
	if n is Label:
		var l: Label = n
		var lines: int = l.get_line_count()
		var font_h: float = 0.0
		if l.label_settings and l.label_settings.font:
			font_h = l.label_settings.font.get_height(l.label_settings.font_size)
		var advance: float = font_h
		if lines > 1:
			advance = (l.size.y - font_h) / float(lines - 1)
		out.append({
			"path": String(l.get_path()),
			"rect": Rect2(l.global_position, l.size),
			"lines": lines,
			"font_h": font_h,
			"advance": advance,
		})
	for c in n.get_children():
		_walk(c, out)

func _initialize() -> void:
	var scene_path: String = "res://scenes/controls_splash.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("res://"):
			scene_path = a
	var root: Control = (load(scene_path) as PackedScene).instantiate()
	root.set_script(null)  # skip scene transitions / input handling
	get_root().add_child(root)
	get_root().size = Vector2i(1280, 800)
	for i in 3:
		await process_frame
	var out: Array = []
	_walk(root, out)
	var bad: int = 0
	for d in out:
		var flag: String = ""
		if d.advance < d.font_h - 1.0:
			flag = "  <-- OVERLAPPING LINES"
			bad += 1
		if d.rect.position.y < 0.0 or d.rect.end.y > 800.0:
			flag += "  <-- OFF SCREEN"
			bad += 1
		print("%s\n   rect=%s lines=%d font_h=%.1f advance=%.1f%s" % [d.path, d.rect, d.lines, d.font_h, d.advance, flag])
	print("RESULT: %d label problem(s)" % bad)
	quit(1 if bad > 0 else 0)
