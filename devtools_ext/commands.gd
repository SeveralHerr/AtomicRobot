extends RefCounted

## Atomic Robot project DevTools verbs.
##
## Loaded by addons/godot_selftest/dev_tools.gd after the generic verbs.
## Every handler returns EXACTLY { "success": bool, "message": String, "data": Dictionary }.
## Invoke from CLI: python tools/devtools.py cmd player_state
##                  python tools/devtools.py cmd teleport_player --args '{"x": 100, "y": -21}'
## Discover:        python tools/devtools.py list-commands

var _dev: Node


func register_commands(dev: Node) -> void:
	_dev = dev
	_dev.register_command("start_game", _cmd_start_game)
	_dev.register_command("player_state", _cmd_player_state)
	_dev.register_command("teleport_player", _cmd_teleport_player)
	_dev.register_command("set_player_health", _cmd_set_player_health)
	_dev.register_command("spawn_enemy", _cmd_spawn_enemy)
	_dev.register_command("list_enemies", _cmd_list_enemies)
	_dev.register_command("kill_enemies", _cmd_kill_enemies)
	_dev.register_command("throw_coin", _cmd_throw_coin)
	_dev.register_command("list_encounters", _cmd_list_encounters)
	_dev.register_command("trigger_encounter", _cmd_trigger_encounter)
	_dev.register_command("level_info", _cmd_level_info)
	_dev.register_command("dump_tilemap", _cmd_dump_tilemap)
	_dev.register_command("list_meters", _cmd_list_meters)
	_dev.register_command("teleport_enemy", _cmd_teleport_enemy)
	_dev.register_command("set_enemy_state", _cmd_set_enemy_state)
	_dev.register_command("debug_find_meter", _cmd_debug_find_meter)


func _player() -> Node:
	var players := _dev.get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null


func _fail(msg: String) -> Dictionary:
	return {"success": false, "message": msg, "data": {}}


## Skip menus straight into the playable level. args: {"character": "Ryan", "scene": optional}
func _cmd_start_game(args: Dictionary) -> Dictionary:
	var globals := _dev.get_node_or_null("/root/Globals")
	if globals == null:
		return _fail("Globals autoload not found")
	globals.debug_start_game(args.get("character", "Ryan"), args.get("scene", "res://scenes/main.tscn"))
	return {"success": true, "message": "starting game", "data": {"character": globals.selected_character}}


## Throw a coin at the player without waiting on maid AI — the deterministic way to
## test projectile/lane behaviour. args: {"lane": int (default player's lane),
## "agnostic": bool, "from_x": float, "from_y": float} (offsets from the player).
func _cmd_throw_coin(args: Dictionary) -> Dictionary:
	var p := _player()
	if p == null:
		return _fail("no node in group 'player' (still in a menu? run: cmd start_game)")
	var from: Vector2 = p.global_position + Vector2(
		float(args.get("from_x", 120.0)), float(args.get("from_y", -8.0)))
	var coin: Bullet = Utils.throw_coin(
		from,
		p.enemy_attack_position.global_position,
		p.get_parent(),
		bool(args.get("arc", false)),
		int(args.get("lane", p.current_lane)),
		bool(args.get("agnostic", false)))
	return {"success": true, "message": "coin thrown", "data": {
		"path": String(coin.get_path()),
		"lane": coin.lane,
		"lane_agnostic": coin.lane_agnostic,
		"has_virtual_floor": is_finite(coin.virtual_floor_y),
		"virtual_floor_y": coin.virtual_floor_y if is_finite(coin.virtual_floor_y) else 0.0,
		"masks_ground": coin.get_collision_mask_value(2),
		"z_index": coin.z_index,
		"position": [coin.global_position.x, coin.global_position.y],
	}}


## Every BuildingDoorEncounter in the scene, with enough state to assert a burst.
func _cmd_list_encounters(_args: Dictionary) -> Dictionary:
	var out := []
	for n in _walk_scene():
		if n is BuildingDoorEncounter:
			var cam: Camera2D = n.player.camera_2d if n.player != null else null
			out.append({
				"path": String(_dev.get_tree().current_scene.get_path_to(n)),
				"door_x": n.door_mouth.global_position.x,
				"fired": n._fired,
				"active": n._active,
				"alive_spawned": n._spawned.filter(func(e): return is_instance_valid(e)).size(),
				"enemy_count": n.enemy_count,
				"lock_arena": n.lock_arena,
				"barriers_up": not n.left_wall.disabled,
				"camera_limit_left": cam.limit_left if cam != null else 0,
				"camera_limit_right": cam.limit_right if cam != null else 0,
			})
	return {"success": true, "message": "%d encounters" % out.size(), "data": {"encounters": out}}


## Fire an encounter without walking into it. args: {"path": "relative/or/name"}
## (omit to fire the first one found).
func _cmd_trigger_encounter(args: Dictionary) -> Dictionary:
	var want: String = args.get("path", "")
	var p := _player()
	if p == null:
		return _fail("no node in group 'player' (still in a menu? run: cmd start_game)")
	for n in _walk_scene():
		if n is not BuildingDoorEncounter:
			continue
		var rel := String(_dev.get_tree().current_scene.get_path_to(n))
		if want != "" and not rel.ends_with(want):
			continue
		if n._fired:
			return _fail("encounter %s already fired" % rel)
		n._on_body_entered(p)
		return {"success": true, "message": "triggered %s" % rel, "data": {"path": rel}}
	return _fail("no matching BuildingDoorEncounter found")


func _cmd_player_state(_args: Dictionary) -> Dictionary:
	var p := _player()
	if p == null:
		return _fail("no node in group 'player' (still in a menu? run: cmd start-game)")
	var state_name := "?"
	if p.state_machine != null and p.state_machine.current_state != null:
		state_name = p.state_machine.current_state.get_script().resource_path.get_file()
	return {"success": true, "message": "ok", "data": {
		"position": [p.global_position.x, p.global_position.y],
		"velocity": [p.velocity.x, p.velocity.y],
		"state": state_name,
		"health": p.health,
		"damage": p.damage,
		"on_floor": p.is_on_floor(),
		"facing": p.last_dir,
		"character": _dev.get_node("/root/Globals").selected_character,
		"is_dead": p.is_dead,
		"lane": p.current_lane,
		"is_changing_lane": p.is_changing_lane,
		"lane_baseline_y": p.lane_baseline_y,
	}}


## args: {"x": float, "y": float} (either optional — keeps current axis if omitted)
func _cmd_teleport_player(args: Dictionary) -> Dictionary:
	var p := _player()
	if p == null:
		return _fail("no player in scene")
	var pos: Vector2 = p.global_position
	pos.x = float(args.get("x", pos.x))
	pos.y = float(args.get("y", pos.y))
	p.global_position = pos
	p.velocity = Vector2.ZERO
	return {"success": true, "message": "teleported", "data": {"position": [pos.x, pos.y]}}


## args: {"health": int}
func _cmd_set_player_health(args: Dictionary) -> Dictionary:
	var p := _player()
	if p == null:
		return _fail("no player in scene")
	if not args.has("health"):
		return _fail("missing arg: health")
	p.health = int(args["health"])
	p.player_health_updated.emit(p.health)
	return {"success": true, "message": "health set", "data": {"health": p.health}}


## args: {"count": int=1, "force_right": bool=false, "offset": float=50}
func _cmd_spawn_enemy(args: Dictionary) -> Dictionary:
	var p := _player()
	if p == null:
		return _fail("no player in scene")
	var spawner := _dev.get_node_or_null("/root/EnemySpawner")
	if spawner == null:
		return _fail("EnemySpawner autoload not found")
	var scene := _dev.get_tree().current_scene
	var viewport_size := _dev.get_viewport().get_visible_rect().size
	var count := int(args.get("count", 1))
	var spawned := []
	for i in count:
		var e = spawner.spawn_enemy(scene, p, viewport_size, float(args.get("offset", 50.0)), bool(args.get("force_right", false)))
		spawned.append([e.global_position.x, e.global_position.y])
	return {"success": true, "message": "spawned %d" % count, "data": {"positions": spawned}}


func _cmd_list_enemies(_args: Dictionary) -> Dictionary:
	var enemies := []
	for n in _walk_scene():
		if n is Enemy:
			enemies.append({
				"path": String(_dev.get_tree().current_scene.get_path_to(n)),
				"class": n.get_class(),
				"script": n.get_script().resource_path.get_file() if n.get_script() else "?",
				"position": [n.global_position.x, n.global_position.y],
				"health": n.health,
				"lane": n.lane,
			})
	return {"success": true, "message": "%d enemies" % enemies.size(), "data": {"enemies": enemies}}


## Frees every Enemy in the current scene (no death FX/signals — hard delete).
func _cmd_kill_enemies(_args: Dictionary) -> Dictionary:
	var count := 0
	for n in _walk_scene():
		if n is Enemy:
			n.queue_free()
			count += 1
	return {"success": true, "message": "freed %d enemies" % count, "data": {"count": count}}


func _cmd_level_info(_args: Dictionary) -> Dictionary:
	var scene := _dev.get_tree().current_scene
	if scene == null:
		return _fail("no current scene")
	var globals := _dev.get_node("/root/Globals")
	var p := _player()
	var enemy_count := 0
	var tilemap_paths := []
	for n in _walk_scene():
		if n is Enemy:
			enemy_count += 1
		elif n is TileMapLayer:
			tilemap_paths.append(String(scene.get_path_to(n)))
	return {"success": true, "message": "ok", "data": {
		"scene": scene.scene_file_path,
		"root": String(scene.name),
		"player_position": [p.global_position.x, p.global_position.y] if p else null,
		"enemy_count": enemy_count,
		"tilemap_layers": tilemap_paths,
		"meters_registered": globals.meters.size(),
		"meter_maids_killed": globals.meter_maids_killed,
	}}


## args: {"path": optional NodePath under scene root — defaults to all layers, summary only,
##        "cells": bool=false — include per-cell data for the selected layer}
func _cmd_dump_tilemap(args: Dictionary) -> Dictionary:
	var scene := _dev.get_tree().current_scene
	if scene == null:
		return _fail("no current scene")
	var layers := []
	for n in _walk_scene():
		if n is TileMapLayer:
			if args.has("path") and String(scene.get_path_to(n)) != String(args["path"]):
				continue
			var used: Array = n.get_used_cells()
			var rect: Rect2i = n.get_used_rect()
			var entry := {
				"path": String(scene.get_path_to(n)),
				"cell_count": used.size(),
				"used_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
				"world_offset": [n.global_position.x, n.global_position.y],
				"tile_set": n.tile_set.resource_path if n.tile_set else null,
			}
			if bool(args.get("cells", false)):
				var cells := []
				for c in used:
					var ac: Vector2i = n.get_cell_atlas_coords(c)
					cells.append([c.x, c.y, n.get_cell_source_id(c), ac.x, ac.y])
				entry["cells"] = cells
			layers.append(entry)
	return {"success": true, "message": "%d layers" % layers.size(), "data": {"layers": layers}}


## Every registered Meter (Globals.meters), with global position — the generic
## scene-tree/get-state verbs can't resolve these back to node paths easily.
func _cmd_list_meters(_args: Dictionary) -> Dictionary:
	var globals := _dev.get_node("/root/Globals")
	var out := []
	for m in globals.meters:
		if not is_instance_valid(m):
			continue
		out.append({
			"path": String(_dev.get_tree().current_scene.get_path_to(m)),
			"position": [m.global_position.x, m.global_position.y],
		})
	return {"success": true, "message": "%d meters" % out.size(), "data": {"meters": out}}


## Find an Enemy by path suffix (as returned by list_enemies) and set its global_position.
## args: {"path": "EnemyManager/MeterMaid", "x": float, "y": float}
func _cmd_teleport_enemy(args: Dictionary) -> Dictionary:
	var want: String = args.get("path", "")
	if want == "":
		return _fail("missing arg: path")
	for n in _walk_scene():
		if n is Enemy and String(_dev.get_tree().current_scene.get_path_to(n)) == want:
			var pos: Vector2 = n.global_position
			pos.x = float(args.get("x", pos.x))
			pos.y = float(args.get("y", pos.y))
			n.global_position = pos
			n.velocity = Vector2.ZERO
			return {"success": true, "message": "teleported", "data": {"position": [pos.x, pos.y]}}
	return _fail("no enemy at path %s" % want)


## Force an Enemy's state machine to a named state. args: {"path": "...", "state": "FindMeterState"}
func _cmd_set_enemy_state(args: Dictionary) -> Dictionary:
	var want: String = args.get("path", "")
	var state: String = args.get("state", "")
	if want == "" or state == "":
		return _fail("missing arg: path and/or state")
	for n in _walk_scene():
		if n is Enemy and String(_dev.get_tree().current_scene.get_path_to(n)) == want:
			if not n.has_state(state):
				return _fail("enemy has no state: %s" % state)
			n.enemy_state_machine.change_state(state)
			return {"success": true, "message": "state set", "data": {"state": state}}
	return _fail("no enemy at path %s" % want)


## Introspect a live FindMeterState instance (not itself in the scene tree, so
## the generic get-state node-path lookup can't reach it). args: {"path": "..."}
func _cmd_debug_find_meter(args: Dictionary) -> Dictionary:
	var want: String = args.get("path", "")
	if want == "":
		return _fail("missing arg: path")
	for n in _walk_scene():
		if n is Enemy and String(_dev.get_tree().current_scene.get_path_to(n)) == want:
			var st = n.enemy_state_machine.states.get("FindMeterState")
			if st == null:
				return _fail("enemy has no FindMeterState")
			return {"success": true, "message": "ok", "data": {
				"stand_still": st.stand_still,
				"dir": [st.dir.x, st.dir.y],
				"meter_path": String(_dev.get_tree().current_scene.get_path_to(st.meter)) if st.meter else null,
				"meter_pos": [st.meter.global_position.x, st.meter.global_position.y] if st.meter else null,
				"current_state_matches": n.enemy_state_machine.current_state == st,
				"is_changing_lane": n.is_changing_lane,
				"lane": n.lane,
				"coins": n.coins,
				"velocity": [n.velocity.x, n.velocity.y],
				"enemy_pos": [n.global_position.x, n.global_position.y],
			}}
	return _fail("no enemy at path %s" % want)


func _walk_scene() -> Array:
	var out := []
	var scene := _dev.get_tree().current_scene
	if scene == null:
		return out
	var stack := [scene]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out
