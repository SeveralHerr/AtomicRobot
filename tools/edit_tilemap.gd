@tool
extends SceneTree

# Headless batch TileMapLayer editor. Applies a JSON edit plan to a scene's
# TileMapLayer, then surgically replaces ONLY that node's tile_map_data line in
# the .tscn text (never re-serializes the whole scene, so diffs stay minimal and
# instance overrides are untouched).
#
# Usage:
#   godot --headless --path . --script res://tools/edit_tilemap.gd -- --plan res://plan.json [--dry-run]
#
# Plan JSON:
# {
#   "scene": "res://scenes/main.tscn",
#   "layer": "SceneItemsBackground/TileMapLayer",   # node path under scene root
#   "edits": [
#     {"op": "set",  "x": 10, "y": 1, "source": 5, "ax": 0, "ay": 0, "alt": 0},
#     {"op": "rect", "x0": -72, "x1": 302, "y0": 1, "y1": 2, "source": 5, "ax": 0, "ay": 0,
#      "skip_occupied": true},
#     {"op": "erase", "x": 10, "y": 1},
#     {"op": "erase_rect", "x0": 0, "x1": 5, "y0": 0, "y1": 2}
#   ]
# }
# Cell coords are in the layer's own cell space (same values dump_level.gd reports).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var plan_path := ""
	var dry_run := false
	for i in args.size():
		match args[i]:
			"--plan":
				if i + 1 < args.size():
					plan_path = args[i + 1]
			"--dry-run":
				dry_run = true

	if plan_path == "":
		printerr("Missing --plan <file.json>")
		quit(1)
		return

	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	if plan == null or not plan is Dictionary:
		printerr("Failed to parse plan JSON: " + plan_path)
		quit(1)
		return

	var scene_path: String = plan.get("scene", "res://scenes/main.tscn")
	var layer_path: String = plan.get("layer", "")
	var edits: Array = plan.get("edits", [])
	if layer_path == "" or edits.is_empty():
		printerr("Plan needs 'layer' and non-empty 'edits'")
		quit(1)
		return

	var ps: PackedScene = load(scene_path)
	if ps == null:
		printerr("Failed to load scene: " + scene_path)
		quit(1)
		return

	var root := ps.instantiate()
	var layer := root.get_node_or_null(layer_path)
	if layer == null or not layer is TileMapLayer:
		printerr("Layer not found or not a TileMapLayer: " + layer_path)
		for child in _find_tilemap_layers(root):
			printerr("  available: " + String(root.get_path_to(child)))
		root.free()
		quit(1)
		return

	var tm: TileMapLayer = layer
	var set_count := 0
	var erase_count := 0
	var skipped := 0

	for e in edits:
		match String(e.get("op", "set")):
			"set":
				tm.set_cell(Vector2i(int(e.x), int(e.y)), int(e.source), Vector2i(int(e.get("ax", 0)), int(e.get("ay", 0))), int(e.get("alt", 0)))
				set_count += 1
			"erase":
				tm.erase_cell(Vector2i(int(e.x), int(e.y)))
				erase_count += 1
			"rect":
				var skip_occupied: bool = e.get("skip_occupied", false)
				for cy in range(int(e.y0), int(e.y1) + 1):
					for cx in range(int(e.x0), int(e.x1) + 1):
						var c := Vector2i(cx, cy)
						if skip_occupied and tm.get_cell_source_id(c) != -1:
							skipped += 1
							continue
						tm.set_cell(c, int(e.source), Vector2i(int(e.get("ax", 0)), int(e.get("ay", 0))), int(e.get("alt", 0)))
						set_count += 1
			"erase_rect":
				for cy in range(int(e.y0), int(e.y1) + 1):
					for cx in range(int(e.x0), int(e.x1) + 1):
						if tm.get_cell_source_id(Vector2i(cx, cy)) != -1:
							tm.erase_cell(Vector2i(cx, cy))
							erase_count += 1
			var unknown:
				printerr("Unknown op: " + unknown)

	print("Applied: %d set, %d erased, %d skipped (occupied). Layer now %d cells, rect %s" % [set_count, erase_count, skipped, tm.get_used_cells().size(), tm.get_used_rect()])

	var new_b64 := Marshalls.raw_to_base64(tm.tile_map_data)
	root.free()

	if dry_run:
		print("Dry run — scene NOT saved")
		quit(0)
		return

	if not _patch_tscn(scene_path, layer_path, new_b64):
		quit(1)
		return
	print("Saved " + scene_path)
	quit(0)


## Replaces the tile_map_data line inside the matching [node ...] section of the
## .tscn text. Only that one line changes.
func _patch_tscn(scene_path: String, layer_path: String, b64: String) -> bool:
	var text := FileAccess.get_file_as_string(scene_path)
	if text == "":
		printerr("Failed to read " + scene_path)
		return false

	var segs := layer_path.split("/")
	var node_name := segs[-1]
	segs.remove_at(segs.size() - 1)
	var parent := "/".join(segs) if segs.size() > 0 else "."

	var header := '[node name="%s"' % node_name
	var parent_attr := 'parent="%s"' % parent
	var lines := text.split("\n")
	var in_section := false
	var patched := false
	for i in lines.size():
		var line := lines[i]
		if line.begins_with("[node "):
			in_section = line.begins_with(header) and line.contains(parent_attr)
		elif in_section and line.begins_with("tile_map_data = PackedByteArray("):
			lines[i] = 'tile_map_data = PackedByteArray("%s")' % b64
			patched = true
			break

	if not patched:
		printerr("Could not find tile_map_data line for node '%s' (parent '%s') in %s" % [node_name, parent, scene_path])
		printerr("If the layer is empty in the scene file, add a tile_map_data line manually once.")
		return false

	var f := FileAccess.open(scene_path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	return true


func _find_tilemap_layers(node: Node) -> Array:
	var out := []
	var stack := [node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is TileMapLayer:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out
