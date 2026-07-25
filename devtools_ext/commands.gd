extends RefCounted

## Atomic Robot project DevTools verbs.
##
## Loaded by addons/godot_selftest/dev_tools.gd after the generic verbs.
## Every handler returns EXACTLY { "success": bool, "message": String, "data": Dictionary }.
## Invoke from CLI: python tools/devtools.py cmd player_state
##                  python tools/devtools.py cmd teleport_player --args '{"x": 100, "y": -21}'
## Discover:        python tools/devtools.py list-commands

const POWERUP_PICKUP: PackedScene = preload("res://scenes/powerup_pickup.tscn")

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
	_dev.register_command("lane_report", _cmd_lane_report)
	_dev.register_command("grant_powerup", _cmd_grant_powerup)
	_dev.register_command("clear_powerups", _cmd_clear_powerups)
	_dev.register_command("drop_powerup", _cmd_drop_powerup)
	_dev.register_command("powerup_state", _cmd_powerup_state)
	_dev.register_command("score_state", _cmd_score_state)
	_dev.register_command("set_combo", _cmd_set_combo)
	_dev.register_command("finish_stage", _cmd_finish_stage)


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
		"lane_floor_y": p.lane_floor_y,
		"foot_offset": p.foot_offset(),
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
				"facing": n.facing,
				"scale_x": n.scale.x,
				"animation": n.animated_sprite_2d.animation if n.animated_sprite_2d else "",
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


## Depth geometry for every lane-aware body, plus the invariant that motivates it:
## bodies settled on the same ROAD lane must have their SOLES on the same line.
##
## This exists because that class of bug was invisible to the harness — node-bounds
## reports one node at a time, so a spawner-placed maid standing 7.25px lower than a
## self-baselined one on the same lane could only be caught by eye.
##
## GROUND_LANE is deliberately exempt: it rides real collision, so maids hand-placed
## on ledges and rooftops genuinely stand at different heights there (a live scene
## shows ~175px of spread). Only lanes 1-3 share one derived virtual floor, so only
## they can be checked. Their spread is still reported, just not failed on.
## args: {"tolerance": float = 1.0}
func _cmd_lane_report(args: Dictionary) -> Dictionary:
	var tolerance := float(args.get("tolerance", 1.0))
	var bodies := []
	var p := _player()
	if p != null:
		bodies.append(_lane_row(p, "player"))
	for n in _walk_scene():
		if n is Enemy:
			bodies.append(_lane_row(n, String(_dev.get_tree().current_scene.get_path_to(n))))

	# Only settled bodies with a known floor can be compared — one mid-tween is
	# between two lanes by definition, and one with no baseline hasn't landed yet.
	var by_lane := {}
	for row in bodies:
		if row["changing_lane"] or not row["has_floor"]:
			continue
		if not by_lane.has(row["lane"]):
			by_lane[row["lane"]] = []
		by_lane[row["lane"]].append(row)

	var violations := []
	var spreads := {}
	for lane in by_lane:
		var rows: Array = by_lane[lane]
		if rows.size() < 2:
			continue
		var lo := INF
		var hi := -INF
		for row in rows:
			var level: float = row["foot_y"] - row["depth_offset"]
			lo = minf(lo, level)
			hi = maxf(hi, level)
		spreads[lane] = hi - lo
		# hi/lo are measured with each body's deliberate in-lane jitter removed, so
		# this still fails on the bug it was written for (bodies whose baselines
		# disagree) without failing on the decoration layered on top of it.
		if lane != Lanes.GROUND_LANE and hi - lo > tolerance:
			violations.append({"lane": lane, "spread": hi - lo, "bodies": rows.size()})

	return {
		"success": violations.is_empty(),
		"message": "%d bodies, %d road lane(s) with mismatched foot lines" % [bodies.size(), violations.size()],
		"data": {
			"tolerance": tolerance,
			"bodies": bodies,
			"violations": violations,
			"foot_spread_by_lane": spreads,
		},
	}


## Untyped `body` so this takes both Player (current_lane, never jittered) and Enemy.
func _lane_row(body, label: String) -> Dictionary:
	var is_player := body is Player
	var lane: int = body.current_lane if is_player else body.lane
	var offset: float = body.foot_offset()
	var has_floor := is_finite(body.lane_floor_y)
	return {
		"node": label,
		"lane": lane,
		"y": body.global_position.y,
		"foot_offset": offset,
		"foot_y": body.global_position.y + offset,
		"depth_offset": 0.0 if is_player else body.lane_depth_offset,
		"z": body.z_index,
		"lane_floor_y": body.lane_floor_y if has_floor else 0.0,
		"has_floor": has_floor,
		"changing_lane": body.is_changing_lane,
		"sorted": body.get_parent() != null and body.get_parent().name == Lanes.SORT_LAYER_NAME,
	}


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
				# facing is +1/-1 (right/left); "facing_meter" is the assertion that
				# matters — the maid must look at the meter she's walking to, and the
				# sprite flip lives on the body's scale.x, not on the sprite's flip_h.
				"facing": n.facing,
				"scale_x": n.scale.x,
				"sprite_flip_h": n.animated_sprite_2d.flip_h if n.animated_sprite_2d else false,
				"animation": n.animated_sprite_2d.animation if n.animated_sprite_2d else "",
				# null once she's parked within the face deadzone — there is no "correct"
				# side to look at from on top of the meter, so don't report a failure.
				"facing_meter": _facing_meter(n, st.meter),
			}}
	return _fail("no enemy at path %s" % want)


## True/false when the maid is far enough from `meter` for facing to be meaningful,
## null inside Enemy.FACE_DEADZONE (standing on it — either side is fine).
func _facing_meter(n: Enemy, meter: Node2D) -> Variant:
	if meter == null:
		return null
	var dx: float = meter.global_position.x - n.global_position.x
	if absf(dx) < Enemy.FACE_DEADZONE:
		return null
	return signi(dx) == n.facing


# --- Power-ups and scoring ---------------------------------------------------
#
# The generic primitives can't reach these: the buff timers live in an autoload
# (not a scene node, so get-state can't find them), the visual proof of a buff is a
# set of shader uniforms on a material (not a node property), and the drop table is
# a random roll that a test has to be able to bypass entirely.


## Start a power-up on the player without waiting for a drop.
## args: {"id": "rage" | "overclock"} (omit for a weighted random pick)
func _cmd_grant_powerup(args: Dictionary) -> Dictionary:
	var id := String(args.get("id", PowerupRules.pick(randf())))
	if not PowerupRules.has_id(id):
		return _fail("unknown powerup id '%s' (known: %s)" % [id, ", ".join(PowerupRules.IDS)])
	if _player() == null:
		return _fail("no node in group 'player' (still in a menu? run: cmd start_game)")
	PowerupSystem.grant(id)
	return {"success": true, "message": "granted %s" % id, "data": {
		"id": id,
		"duration": PowerupRules.duration(id),
		"active": PowerupSystem.active_ids(),
	}}


func _cmd_clear_powerups(_args: Dictionary) -> Dictionary:
	PowerupSystem.clear_all()
	return {"success": true, "message": "cleared", "data": {"active": PowerupSystem.active_ids()}}


## Drop a collectable pickup near the player, bypassing the drop roll entirely — the
## deterministic way to test collection (including the same-lane rule).
## args: {"id": String, "lane": int = player's lane, "offset": float = 60 (px along X)}
func _cmd_drop_powerup(args: Dictionary) -> Dictionary:
	var p := _player()
	if p == null:
		return _fail("no node in group 'player' (still in a menu? run: cmd start_game)")
	var id := String(args.get("id", PowerupRules.pick(randf())))
	if not PowerupRules.has_id(id):
		return _fail("unknown powerup id '%s' (known: %s)" % [id, ", ".join(PowerupRules.IDS)])
	var scene := _dev.get_tree().current_scene
	if scene == null:
		return _fail("no current scene")
	var lane := Lanes.clamp_lane(int(args.get("lane", p.current_lane)))
	var pickup := POWERUP_PICKUP.instantiate()
	pickup.powerup_id = id
	pickup.lane = lane
	scene.add_child(pickup)
	# Same floor-line derivation as Utils.drop_powerup, so a devtools-placed pickup
	# hovers at exactly the height a real drop would.
	var floor_line: float = p.global_position.y + p.foot_offset()
	if is_finite(p.lane_floor_y):
		floor_line = Lanes.floor_y(p.lane_floor_y, lane)
	pickup.global_position = Vector2(
		p.global_position.x + float(args.get("offset", 60.0)),
		floor_line - PowerupPickup.HOVER_HEIGHT)
	return {"success": true, "message": "dropped %s on lane %d" % [id, lane], "data": {
		"id": id,
		"lane": lane,
		"position": [pickup.global_position.x, pickup.global_position.y],
		"player_lane": p.current_lane,
		"collectable_now": p.current_lane == lane,
	}}


## Everything a test needs to assert that a buff is actually in effect: the stat
## multipliers ON the player, and the shader uniforms actually written to the sprite
## material (the only proof the visual effect is live, since it is not a node property).
func _cmd_powerup_state(_args: Dictionary) -> Dictionary:
	var p := _player()
	if p == null:
		return _fail("no node in group 'player' (still in a menu? run: cmd start_game)")
	var active := []
	for id in PowerupSystem.active_ids():
		active.append({
			"id": id,
			"remaining": PowerupSystem.remaining(id),
			"duration": PowerupRules.duration(id),
			"strength": PowerupRules.ramp_strength(PowerupSystem.remaining(id), PowerupRules.duration(id)),
		})
	var shader := {}
	var mat := p.default_sprite.material as ShaderMaterial
	if mat != null:
		shader["shader_path"] = mat.shader.resource_path if mat.shader else ""
		for key in ["buff_value", "buff_pulse_hz", "buff_pixel_size", "buff_dither", "flash_value"]:
			shader[key] = mat.get_shader_parameter(key)
		var c = mat.get_shader_parameter("buff_color")
		shader["buff_color"] = [c.r, c.g, c.b] if c is Color else null
	var pickups := 0
	for n in _dev.get_tree().get_nodes_in_group("powerup_pickups"):
		if is_instance_valid(n):
			pickups += 1
	return {"success": true, "message": "%d active" % active.size(), "data": {
		"active": active,
		"base_damage": p.damage,
		"effective_damage": p.get_damage(),
		"damage_multiplier": p.damage_multiplier,
		"speed_multiplier": p.speed_multiplier,
		"effective_speed": p.get_speed(),
		"sprite_speed_scale": p.default_sprite.speed_scale,
		"kills_since_drop": PowerupSystem.kills_since_drop(),
		"pity_at": PowerupRules.PITY_KILLS,
		"pickups_in_scene": pickups,
		"shader": shader,
	}}


func _cmd_score_state(_args: Dictionary) -> Dictionary:
	var hud := _dev.get_tree().current_scene.find_child("ScoreUI", true, false) if _dev.get_tree().current_scene else null
	return {"success": true, "message": "ok", "data": {
		"running": ScoreSystem.running,
		"scene": ScoreSystem.current_scene_path,
		"scene_is_scored": ScoreRules.is_scored_scene(ScoreSystem.current_scene_path),
		"score": ScoreSystem.score,
		"combo": ScoreSystem.combo,
		"multiplier": ScoreSystem.multiplier(),
		"combo_fraction": ScoreSystem.combo_fraction(),
		"stage_seconds": ScoreSystem.stage_seconds,
		"damage_taken": ScoreSystem.damage_taken,
		"best": ScoreSystem.best_for(ScoreSystem.current_scene_path),
		"best_rank": ScoreSystem.best_rank_for(ScoreSystem.current_scene_path),
		"hud_present": hud != null,
	}}


## Force the combo count so a multiplier tier can be asserted without landing 36
## hits. args: {"combo": int}
func _cmd_set_combo(args: Dictionary) -> Dictionary:
	if not args.has("combo"):
		return _fail("missing arg: combo")
	ScoreSystem.combo = maxi(0, int(args["combo"]))
	ScoreSystem.combo_changed.emit(ScoreSystem.combo, ScoreSystem.multiplier())
	return {"success": true, "message": "combo set", "data": {
		"combo": ScoreSystem.combo,
		"multiplier": ScoreSystem.multiplier(),
	}}


## End the stage now and return the rank breakdown, without killing the boss.
func _cmd_finish_stage(_args: Dictionary) -> Dictionary:
	if not ScoreSystem.running:
		return _fail("no stage running (scene '%s' is not scored)" % ScoreSystem.current_scene_path)
	var result := ScoreSystem.finish_stage()
	return {"success": true, "message": "rank %s" % result.get("rank", "?"), "data": result}


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
