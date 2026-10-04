extends Node2D
class_name EnemySandbox

## One-scene-per-scenario harness for enemy AI. Open any scene in test/scenes/ and
## press F6 — it builds its own ground, player, props and enemies from scratch, so
## there is no dependency on main.tscn's tilemaps, encounters or level layout.
##
## Everything lives in one script with a `scenario` switch; the .tscn files are
## one-node wrappers that just set the enum. Adding a scenario = a case in
## _build_scenario() plus a two-line .tscn.
##
## test/scenes/ is registered with Lanes.scene_has_lanes(), so lane movement,
## lane-gated combat and lane-agnostic coins all behave exactly as they do in the
## street level.
##
## Keys: R reset · K clear enemies · C send a car · Space spawn a wave · H hide HUD

enum Scenario {
	MELEE_CLUSTER,
	RANGED_CLUSTER,
	MIXED_CLUSTER,
	COIN_REFILL,
	WINDOW_MAIDS,
	NO_LINE_OF_SIGHT,
	SPAWN_EVENT,
	CAR_VS_CROWD,
	PLATFORM_PATROL,
	COIN_LANE_DODGE,
	POINT_BLANK_RANGED,
	POINT_BLANK_MELEE,
}

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const METER_SCENE := preload("res://scenes/meter.tscn")
const CAR_SCENE := preload("res://scenes/car.tscn")
const WINDOW_MAID_SCENE := preload("res://scenes/meter_maid_window.tscn")
const PLATFORM_MAID_SCENE := preload("res://scenes/meter_maid_platform.tscn")
const DOOR_ENCOUNTER_SCENE := preload("res://scenes/building_door_encounter.tscn")

## Y of the walkway surface — every lane floor is measured down from here.
const GROUND_Y := 0.0
## Half-length of the ground slab. Wide enough that Enemy.is_too_far() (1500px)
## purges strays before they can run off the end.
const GROUND_HALF_WIDTH := 2400.0
## The slab reaches well below the walkway, mirroring main.tscn's tiles: road-lane
## bodies sit inside it and switch their Ground/Platforms mask off instead of
## standing on anything (see Enemy._set_ground_collision).
const GROUND_DEPTH := 400.0

@export var scenario: Scenario = Scenario.MIXED_CLUSTER
@export var character: String = "Ryan"
## Ambient EnemyManager-style waves on top of whatever the scenario places.
@export var ambient_waves: bool = false

var player: Player
var _hud: Label
var _title: String = ""
var _notes: PackedStringArray = []
var _wave_timer: Timer
var _car_timer: Timer


func _ready() -> void:
	# Meters are appended to a plain Array on an autoload that outlives scene
	# reloads, so without this every reset leaves stale freed meters behind and
	# nearest_meter() starts handing maids a dangling target.
	Globals.reset()
	if Globals.character_dict.has(character):
		Globals.selected_character = character

	_build_ground()
	_build_player()
	_build_hud()
	_build_scenario()
	_maybe_attach_selftest()


## `godot --headless --path . res://test/scenes/<x>.tscn -- --sandbox-selftest`
## runs the scenario for a few seconds and exits non-zero if the AI looks stuck.
func _maybe_attach_selftest() -> void:
	if not OS.get_cmdline_user_args().has("--sandbox-selftest"):
		return
	var checker := SandboxSelfTest.new()
	checker.sandbox = self
	add_child(checker)


# --------------------------------------------------------------- arena pieces

func _build_ground() -> void:
	var body := StaticBody2D.new()
	body.name = "Ground"
	body.collision_layer = 0
	body.set_collision_layer_value(2, true)  # Ground
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(GROUND_HALF_WIDTH * 2.0, GROUND_DEPTH)
	shape.shape = rect
	shape.position = Vector2(0, GROUND_Y + GROUND_DEPTH * 0.5)
	body.add_child(shape)
	add_child(body)


## A solid wall on the `wall` layer (7). The sight ray masks it, so this is what
## makes an enemy genuinely unable to see the player rather than merely far away.
func _build_wall(at_x: float, height: float = 160.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Wall"
	body.collision_layer = 0
	body.set_collision_layer_value(7, true)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, height)
	shape.shape = rect
	body.add_child(shape)
	body.global_position = Vector2(at_x, GROUND_Y - height * 0.5)
	add_child(body)

	var marker := ColorRect.new()
	marker.color = Color(0.35, 0.2, 0.2, 0.9)
	marker.size = Vector2(24, height)
	marker.position = Vector2(-12, -height)
	body.add_child(marker)
	return body


## A raised ledge on the Platforms layer (6) for PlatformMeterMaid to patrol.
func _build_platform(at_x: float, width: float, top_y: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Platform"
	body.collision_layer = 0
	body.set_collision_layer_value(6, true)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 16)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	body.add_child(shape)
	body.global_position = Vector2(at_x, top_y)
	add_child(body)

	var marker := ColorRect.new()
	marker.color = Color(0.25, 0.3, 0.4, 1.0)
	marker.size = Vector2(width, 16)
	marker.position = Vector2(-width * 0.5, 0)
	body.add_child(marker)
	return body


func _build_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(0, GROUND_Y - 40)
	# player.tscn sets top_level, so the instance ignores this node's transform —
	# which is fine here (the sandbox root sits at the origin) but worth knowing if
	# a scenario ever needs to offset the whole arena.
	player.camera_2d.limit_left = int(-GROUND_HALF_WIDTH)
	player.camera_2d.limit_right = int(GROUND_HALF_WIDTH)


func _spawn_maid(at_x: float, lane: int, melee: bool) -> Enemy:
	var enemy: Enemy = EnemySpawner.spawn_enemy_at(self, player, at_x, lane, melee)
	# spawn_enemy_at derives the lane floor from the player's captured walkway
	# baseline, which is still INF on the first frame — seed it so enemies placed
	# during _ready land on the right lane instead of all stacking on the walkway.
	# GROUND_Y is the walkway SURFACE, which is exactly what a lane baseline is.
	if enemy != null:
		enemy.lane_floor_y = GROUND_Y
		enemy.starting_lane = Lanes.clamp_lane(lane)
		enemy.global_position = Vector2(
			at_x, Lanes.stand_y(GROUND_Y, lane, Lanes.measure_foot_offset(enemy)))
		enemy.persist = true  # never auto-purge in a sandbox
	return enemy


func _spawn_meter(at_x: float) -> Node2D:
	var meter := METER_SCENE.instantiate()
	add_child(meter)
	meter.global_position = Vector2(at_x, GROUND_Y)
	return meter


func _send_car(lane: int = -1) -> void:
	if player == null:
		return
	var use_lane: int = lane if Lanes.is_valid_lane(lane) and lane != Lanes.GROUND_LANE \
		else randi_range(Lanes.GROUND_LANE + 1, Lanes.FRONT_LANE)
	var car := CAR_SCENE.instantiate()
	add_child(car)
	car.lane = use_lane
	car.z_index = Lanes.z_for(use_lane)
	# Cars ride the player's standing line, not the walkway floor — see
	# Streetlight._car_road_y for why.
	var road_y: float = player.lane_stand_y(use_lane) if player.lane_floor_y != INF \
		else GROUND_Y - 40 + Lanes.y_offset(use_lane)
	car.global_position = Vector2(player.global_position.x + 700.0, road_y)
	car.speed = 0
	car.start = true


# ------------------------------------------------------------------ scenarios

func _build_scenario() -> void:
	match scenario:
		Scenario.MELEE_CLUSTER:
			_title = "Melee cluster"
			_notes = PackedStringArray([
				"5 melee maids close from both sides across all 4 lanes.",
				"Watch: they face the way they walk, and only connect in YOUR lane.",
			])
			for i in 4:
				_spawn_maid(-320.0 - i * 70.0, i, true)
			_spawn_maid(300.0, Lanes.GROUND_LANE, true)

		Scenario.RANGED_CLUSTER:
			_title = "Ranged cluster"
			_notes = PackedStringArray([
				"5 coin throwers, 2 coins each, one meter behind you.",
				"Watch: each throws, backs to Chase, and leaves for the meter when dry.",
			])
			for i in 4:
				_spawn_maid(340.0 + i * 70.0, i, false)
			_spawn_maid(-360.0, Lanes.GROUND_LANE, false)
			_spawn_meter(-140.0)

		Scenario.MIXED_CLUSTER:
			_title = "Mixed cluster (melee + ranged, both sides)"
			_notes = PackedStringArray([
				"Melee pressure in front, coin throwers behind, spread over the lanes.",
				"Watch: enemy separation keeps them from stacking on one X.",
			])
			for i in 4:
				_spawn_maid(-300.0 - i * 60.0, i, true)
			for i in 4:
				_spawn_maid(320.0 + i * 60.0, Lanes.FRONT_LANE - i, false)
			_spawn_meter(200.0)

		Scenario.COIN_REFILL:
			_title = "Coin refill run"
			_notes = PackedStringArray([
				"3 throwers start EMPTY with meters either side.",
				"Watch: they walk to a meter FACING it, play refill, then re-engage.",
			])
			_spawn_meter(-420.0)
			_spawn_meter(420.0)
			for i in 3:
				var maid := _spawn_maid(-260.0 + i * 240.0, i, false)
				if maid != null:
					maid.coins = 0

		Scenario.WINDOW_MAIDS:
			_title = "Window maids (lane-locked, coins hit every lane)"
			_notes = PackedStringArray([
				"3 maids mounted above the street; they smash out on sight.",
				"Watch: they keep firing after you change lanes, AND they can be killed.",
			])
			# Inside the 210px detector radius from the player's start, so the
			# scenario engages on its own instead of only after you walk under one.
			for i in 3:
				var maid: Enemy = WINDOW_MAID_SCENE.instantiate()
				add_child(maid)
				maid.global_position = Vector2(-180.0 + i * 180.0, GROUND_Y - 120.0)
				maid.persist = true

		Scenario.NO_LINE_OF_SIGHT:
			_title = "Blocked line of sight"
			_notes = PackedStringArray([
				"Walls between you and the squad. Sight is blocked; distance is not.",
				"Watch: they keep CLOSING (no more freezing) but hold fire until clear.",
			])
			_build_wall(-220.0, 200.0)
			_build_wall(240.0, 200.0)
			for i in 3:
				_spawn_maid(-560.0 - i * 60.0, i, i % 2 == 0)
			for i in 2:
				_spawn_maid(560.0 + i * 60.0, i + 1, false)

		Scenario.SPAWN_EVENT:
			_title = "Spawn events (door burst + ambient waves)"
			_notes = PackedStringArray([
				"Walk right into the crack to trigger a BuildingDoorEncounter burst.",
				"Ambient EnemySpawner waves run alongside it. Space forces a wave.",
			])
			var encounter := DOOR_ENCOUNTER_SCENE.instantiate()
			add_child(encounter)
			encounter.global_position = Vector2(360.0, GROUND_Y)
			_spawn_meter(-300.0)
			ambient_waves = true

		Scenario.CAR_VS_CROWD:
			_title = "Car vs. crowd"
			_notes = PackedStringArray([
				"A crowd parked across the road lanes; a car every 3s in a random lane.",
				"Watch: only same-lane bodies get hit, and knockback doesn't wedge the AI.",
			])
			for lane in range(Lanes.GROUND_LANE + 1, Lanes.FRONT_LANE + 1):
				for i in 3:
					_spawn_maid(120.0 + i * 90.0, lane, i % 2 == 0)
			_car_timer = Timer.new()
			_car_timer.wait_time = 3.0
			_car_timer.timeout.connect(func() -> void: _send_car())
			add_child(_car_timer)
			_car_timer.start()

		Scenario.PLATFORM_PATROL:
			_title = "Platform patrol"
			_notes = PackedStringArray([
				"A maid patrolling a ledge overhead, plus melee pressure on the street.",
				"Watch: she turns at both ledge ends and still throws when you change lane.",
			])
			_build_platform(160.0, 320.0, GROUND_Y - 170.0)
			var maid: Enemy = PLATFORM_MAID_SCENE.instantiate()
			add_child(maid)
			maid.global_position = Vector2(160.0, GROUND_Y - 200.0)
			maid.persist = true
			_spawn_maid(-260.0, Lanes.GROUND_LANE, true)
			_spawn_maid(-330.0, 2, true)

		Scenario.COIN_LANE_DODGE:
			_title = "Coin lane dodge"
			_notes = PackedStringArray([
				"One thrower in your lane. Step a lane during her wind-up.",
				"Watch: the coin keeps to HER lane and sails past you.",
			])
			var thrower := _spawn_maid(110.0, Lanes.GROUND_LANE, false)
			if thrower != null:
				thrower.set_deferred("coins", 99)  # after MeterMaid._ready sets 2

		Scenario.POINT_BLANK_RANGED, Scenario.POINT_BLANK_MELEE:
			var melee := scenario == Scenario.POINT_BLANK_MELEE
			_title = "Point blank (%s)" % ("melee" if melee else "ranged")
			_notes = PackedStringArray([
				"The maid spawns right where you stand (as after landing on her).",
				"Watch: she still swings instead of idling under you forever.",
			])
			var maid := _spawn_maid(0.0, Lanes.GROUND_LANE, melee)
			if maid != null:
				maid.set_deferred("coins", 99)  # after MeterMaid._ready sets 2
				# Short cooldown so a stall shows inside the sample window; the
				# first swing can fire mid-fall, before the player lands on her.
				maid.attack_cooldown = 1.0

	if ambient_waves and _wave_timer == null:
		_wave_timer = Timer.new()
		_wave_timer.wait_time = 6.0
		_wave_timer.timeout.connect(_spawn_ambient_wave)
		add_child(_wave_timer)
		_wave_timer.start()


func _spawn_ambient_wave() -> void:
	if player == null or player.is_dead:
		return
	EnemySpawner.spawn_enemy(self, player, get_viewport_rect().size, -50)


# ----------------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"  # devtools_config hud_layer_name
	layer.layer = 10
	add_child(layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(8, 8)
	panel.modulate = Color(1, 1, 1, 0.92)
	layer.add_child(panel)

	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 13)
	panel.add_child(_hud)


func _process(_delta: float) -> void:
	if _hud == null or not _hud.visible:
		return
	var lines: PackedStringArray = PackedStringArray(["[%s]" % _title])
	for note in _notes:
		lines.append("  " + note)
	if player != null:
		lines.append("player  lane %d  hp %d  %s" % [
			player.current_lane, player.health, _state_name(player.state_machine)])
	lines.append("R reset · K clear · C car · Space wave · H hide")
	lines.append("")

	var enemies := get_tree().get_nodes_in_group("enemies")
	lines.append("enemies: %d" % enemies.size())
	for node in enemies:
		if not is_instance_valid(node) or node is not Enemy:
			continue
		var e: Enemy = node
		lines.append("  %-18s L%d %s %-16s coins %d  hp %d  %s%s" % [
			e.name.left(18),
			e.lane,
			"->" if e.facing > 0 else "<-",
			_state_name(e.enemy_state_machine),
			e.coins,
			e.health,
			e.animated_sprite_2d.animation if e.animated_sprite_2d else "?",
			"  IN-RANGE" if e.is_player_in_attack_range else "",
		])
	_hud.text = "\n".join(lines)


func _state_name(machine) -> String:
	if machine == null or machine.current_state == null:
		return "-"
	var script: Script = machine.current_state.get_script()
	return script.resource_path.get_file().trim_suffix(".gd") if script else "?"


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			get_tree().reload_current_scene()
		KEY_K:
			for e in get_tree().get_nodes_in_group("enemies"):
				e.queue_free()
		KEY_C:
			_send_car()
		KEY_SPACE:
			_spawn_ambient_wave()
		KEY_H:
			if _hud != null:
				_hud.visible = not _hud.visible
				_hud.get_parent().visible = _hud.visible
