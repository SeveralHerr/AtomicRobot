@tool
extends SceneTree

# Headless level/scene inspector. Dumps a scene's gameplay-relevant structure as JSON
# without running any game logic (nodes are instantiated but never added to the tree):
#   - TileMapLayer: used_rect, cell counts per source, top-surface profile (per column),
#     optionally every cell (--cells)
#   - Collision bodies/areas: class, layers/masks, shape geometry in WORLD coords
#   - Camera2D limits/zoom, instanced sub-scenes, markers, scripts
#
# Usage:
#   godot --headless --path . --script res://tools/dump_level.gd
#   godot --headless --path . --script res://tools/dump_level.gd -- --scene res://scenes/boss_room.tscn
#   ... -- --cells            include full per-cell tile listing (large!)
#   ... -- --out FILE.json    write to file instead of stdout

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := "res://scenes/main.tscn"
	var include_cells := false
	var out_file := ""
	for i in args.size():
		match args[i]:
			"--scene":
				if i + 1 < args.size():
					scene_path = args[i + 1]
			"--cells":
				include_cells = true
			"--out":
				if i + 1 < args.size():
					out_file = args[i + 1]

	var ps: PackedScene = load(scene_path)
	if ps == null:
		printerr("Failed to load scene: " + scene_path)
		quit(1)
		return

	var root := ps.instantiate()
	var result := {
		"scene": scene_path,
		"root": {"name": root.name, "class": root.get_class(), "script": _script_of(root)},
		"tilemap_layers": [],
		"collision_bodies": [],
		"areas": [],
		"cameras": [],
		"instances": [],
		"markers": [],
		"scripted_nodes": [],
	}
	_walk(root, Transform2D.IDENTITY, "", result, include_cells)
	root.free()

	var json := JSON.stringify(result, "  ")
	if out_file != "":
		var f := FileAccess.open(out_file, FileAccess.WRITE)
		f.store_string(json)
		f.close()
		print("Wrote " + out_file)
	else:
		print(json)
	quit(0)


func _walk(node: Node, parent_xf: Transform2D, path: String, out: Dictionary, include_cells: bool) -> void:
	var my_path := path + "/" + String(node.name) if path != "" else String(node.name)
	var xf := parent_xf
	if node is Node2D:
		xf = parent_xf * (node as Node2D).transform
	# CanvasLayer children live in layer space; keep accumulating from identity there.
	if node is CanvasLayer:
		xf = Transform2D.IDENTITY

	if node is TileMapLayer:
		out["tilemap_layers"].append(_dump_tilemap(node, xf, my_path, include_cells))
	elif node is CollisionShape2D or node is CollisionPolygon2D:
		var parent := node.get_parent()
		var entry := {
			"path": my_path,
			"body_class": parent.get_class() if parent else "?",
			"collision_layer": parent.collision_layer if parent and "collision_layer" in parent else null,
			"collision_mask": parent.collision_mask if parent and "collision_mask" in parent else null,
			"one_way": node.one_way_collision if node is CollisionShape2D else false,
			"world_position": _v2(xf.origin),
		}
		if node is CollisionShape2D and node.shape != null:
			entry["shape"] = _dump_shape(node.shape)
		elif node is CollisionPolygon2D:
			entry["shape"] = {"type": "Polygon", "points": node.polygon.size()}
		if parent is Area2D:
			entry["is_area"] = true
			entry["area_script"] = _script_of(parent)
			out["areas"].append(entry)
		else:
			out["collision_bodies"].append(entry)
	elif node is Camera2D:
		out["cameras"].append({
			"path": my_path,
			"zoom": _v2(node.zoom),
			"limits": {"left": node.limit_left, "right": node.limit_right, "top": node.limit_top, "bottom": node.limit_bottom},
			"world_position": _v2(xf.origin),
		})
	elif node is Marker2D or String(node.name).containsn("position") or String(node.name).containsn("spawn"):
		if node is Node2D:
			out["markers"].append({"path": my_path, "class": node.get_class(), "world_position": _v2(xf.origin)})

	if node.scene_file_path != "" and path != "":
		out["instances"].append({
			"path": my_path,
			"scene": node.scene_file_path,
			"world_position": _v2(xf.origin) if node is Node2D else null,
			"z_index": node.z_index if node is Node2D else null,
		})
	elif _script_of(node) != null and path != "":
		out["scripted_nodes"].append({"path": my_path, "class": node.get_class(), "script": _script_of(node)})

	for child in node.get_children():
		_walk(child, xf, my_path, out, include_cells)


func _dump_tilemap(tm: TileMapLayer, xf: Transform2D, path: String, include_cells: bool) -> Dictionary:
	var used := tm.get_used_cells()
	var rect := tm.get_used_rect()
	var tile_size: Vector2i = tm.tile_set.tile_size if tm.tile_set else Vector2i(32, 32)
	var source_counts := {}
	# Top surface profile: highest (min y) occupied cell per column — the walkable skyline.
	var surface := {}
	for c in used:
		var sid := tm.get_cell_source_id(c)
		source_counts[str(sid)] = source_counts.get(str(sid), 0) + 1
		if not surface.has(c.x) or c.y < surface[c.x]:
			surface[c.x] = c.y
	var surface_arr := []
	var xs := surface.keys()
	xs.sort()
	for x in xs:
		surface_arr.append([x, surface[x]])

	var entry := {
		"path": path,
		"visible": tm.visible,
		"z_index": tm.z_index,
		"tile_set": tm.tile_set.resource_path if tm.tile_set else null,
		"tile_size": [tile_size.x, tile_size.y],
		"world_offset": _v2(xf.origin),
		"used_rect_cells": {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y},
		"used_rect_world": {
			"x": xf.origin.x + rect.position.x * tile_size.x,
			"y": xf.origin.y + rect.position.y * tile_size.y,
			"w": rect.size.x * tile_size.x,
			"h": rect.size.y * tile_size.y,
		},
		"cell_count": used.size(),
		"cells_per_source": source_counts,
		"top_surface_profile": surface_arr,
	}
	if include_cells:
		var cells := []
		for c in used:
			var ac := tm.get_cell_atlas_coords(c)
			cells.append([c.x, c.y, tm.get_cell_source_id(c), ac.x, ac.y, tm.get_cell_alternative_tile(c)])
		entry["cells"] = cells
	return entry


func _dump_shape(shape: Shape2D) -> Dictionary:
	if shape is RectangleShape2D:
		return {"type": "Rectangle", "size": _v2(shape.size)}
	if shape is CircleShape2D:
		return {"type": "Circle", "radius": shape.radius}
	if shape is CapsuleShape2D:
		return {"type": "Capsule", "radius": shape.radius, "height": shape.height}
	if shape is WorldBoundaryShape2D:
		return {"type": "WorldBoundary", "normal": _v2(shape.normal), "distance": shape.distance}
	if shape is SegmentShape2D:
		return {"type": "Segment", "a": _v2(shape.a), "b": _v2(shape.b)}
	if shape is ConvexPolygonShape2D:
		return {"type": "ConvexPolygon", "points": shape.points.size()}
	return {"type": shape.get_class()}


func _script_of(node: Node):
	var s = node.get_script()
	return s.resource_path if s != null else null


func _v2(v: Vector2) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
