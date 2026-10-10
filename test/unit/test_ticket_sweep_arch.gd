extends RefCounted

## TICKET SWEEP! at the arch: placement and timing against its neighbours, all derived
## from the real level (main.tscn doors and meters, the JOBS table, the arch cut scene)
## so moving any of them re-checks the fit. The street there runs:
##   x 6080 hedge door (arena to 6400) -> arch cut scene (6250) -> TICKET SWEEP!
##   -> x 6949 hedge door (trigger from ~6839)

var _T
const MD = preload("res://scripts/objectives/meter_defense.gd")
const ENC_SCENE := preload("res://scenes/building_door_encounter.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const METER_SCENE := "res://scenes/meter.tscn"
## Clear road between the last parked car and the next door's trigger: a player
## fighting at the last car must not brush the door (it holds anyway, belt and braces).
const DOOR_MARGIN := 40.0
## The play camera's half width (zoom 2.5 shows 512 px of world).
const HALF_VIEW := 256.0
## A car's own meter stands on the walkway beside it, within this of its centre.
const METER_REACH := 80.0

var _stage: Node2D
var _old_scene: Node
var _saved_events := 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func teardown() -> void:
	StreetCutscenes.enabled = false
	StreetCutscenes.seen.clear()
	if _stage == null:
		return
	Globals._active_events = _saved_events
	_tree().current_scene = _old_scene
	for e in _tree().get_nodes_in_group("enemies"):
		Globals.release_attack_slot(e)
	await _tree().process_frame
	_stage.free()
	_stage = null


# --- The level, read once per test ------------------------------------------------------

func _sweep() -> Dictionary:
	for entry: Dictionary in StreetObjectives.JOBS:
		if entry["on"] and entry["script"] == MD:
			return entry["props"]
	return {}


func _car_xs() -> Array:
	return _sweep()["car_xs"]


## Every door as {mouth, arena: [lo, hi], trigger: [lo, hi]} in world x, sorted.
func _doors(level: Node) -> Array:
	var found: Array = []
	_collect(level, func(n): return n is BuildingDoorEncounter, found)
	var out: Array = []
	for d in found:
		var x := _world_x(d)
		var mouth: float = x + d.get_node("DoorMouth").position.x
		var shape := d.get_node("Trigger/CollisionShape2D") as CollisionShape2D
		var half: float = (shape.shape as RectangleShape2D).size.x * 0.5
		var tx: float = x + d.get_node("Trigger").position.x + shape.position.x
		out.append({"mouth": mouth, "arena": [mouth - d.arena_half_width, mouth + d.arena_half_width],
			"trigger": [tx - half, tx + half]})
	out.sort_custom(func(a, b): return a["mouth"] < b["mouth"])
	return out


func _meters(level: Node) -> Array:
	var found: Array = []
	_collect(level, func(n): return n.scene_file_path == METER_SCENE, found)
	return found.map(func(m): return _world_x(m))


func _collect(n: Node, pick: Callable, out: Array) -> void:
	if pick.call(n):
		out.append(n)
	for c in n.get_children():
		_collect(c, pick, out)


func _world_x(n: Node) -> float:
	var x := 0.0
	while n != null:
		if n is Node2D:
			x += (n as Node2D).position.x
		n = n.get_parent()
	return x


## The doors either side of the sweep's trigger.
func _neighbours(doors: Array, trigger_x: float) -> Array:
	var before: Dictionary = {}
	var after: Dictionary = {}
	for d in doors:
		if d["mouth"] < trigger_x:
			before = d
		elif after.is_empty():
			after = d
	return [before, after]


# --- Placement --------------------------------------------------------------------------

func test_sweep_is_on_and_set_at_the_arch() -> String:
	var props := _sweep()
	if props.is_empty():
		return "TICKET SWEEP! is not an enabled JOBS row"
	return _T.assert_eq(props.get("after_cutscene", ""), "arch", "waits for the arch reveal")


func test_sweep_stretch_fits_between_the_arch_doors() -> String:
	var level: Node = load("res://scenes/main.tscn").instantiate()
	var props := _sweep()
	var pair := _neighbours(_doors(level), props["trigger_x"])
	level.free()
	var before: Dictionary = pair[0]
	var after: Dictionary = pair[1]
	if before.is_empty() or after.is_empty():
		return "sweep is not between two doors"
	var first: float = _car_xs().min() - Car.HALF_LEN
	var last: float = _car_xs().max() + Car.HALF_LEN
	if props["trigger_x"] < before["arena"][1]:
		return "trigger %.0f inside the x %.0f door's arena (to %.0f)" % [props["trigger_x"], before["mouth"], before["arena"][1]]
	if first < before["arena"][1]:
		return "first car (from %.0f) pokes into the x %.0f door's locked view (to %.0f)" % [first, before["mouth"], before["arena"][1]]
	if last + DOOR_MARGIN > after["trigger"][0]:
		return "last car (to %.0f) within %.0f px of the x %.0f door's trigger (%.0f)" % [last, DOOR_MARGIN, after["mouth"], after["trigger"][0]]
	return ""


func test_sweep_every_car_has_its_own_meter() -> String:
	var level: Node = load("res://scenes/main.tscn").instantiate()
	var meters := _meters(level)
	level.free()
	var used := {}
	for car: float in _car_xs():
		var mine: Array = meters.filter(func(m): return absf(m - car) <= METER_REACH and not used.has(m))
		if mine.is_empty():
			return "car at %.0f has no meter within %.0f px" % [car, METER_REACH]
		used[mine[0]] = true
	return ""


## A meter behind a car body is drawn under it (the car sits on the nearer lane): it
## has to stand clear of the bumpers to read as the car's meter.
func test_sweep_meters_stand_clear_of_the_car_bodies() -> String:
	var level: Node = load("res://scenes/main.tscn").instantiate()
	var meters := _meters(level)
	level.free()
	for m: float in meters:
		for car: float in _car_xs():
			if absf(m - car) < Car.HALF_LEN + 4.0:
				return "meter at %.0f hidden behind the car at %.0f" % [m, car]
	return ""


## Cars park PARK_AHEAD before the mark, while the player is still walking up to the
## x 6080 door: they must be off the right edge of the screen then.
func test_sweep_cars_pull_in_unseen() -> String:
	var props := _sweep()
	var park_px: float = props["trigger_x"] - MD.PARK_AHEAD
	var first: float = _car_xs().min() - Car.HALF_LEN
	return _T.assert_gt(first, park_px + HALF_VIEW, "first car off screen when the cars park")


func test_sweep_squad_marches_in_from_off_screen() -> String:
	var props := _sweep()
	var d := MD.new()
	var spawn: float = _car_xs().max() + d.spawn_past
	d.free()
	return _T.assert_gt(spawn - props["trigger_x"], HALF_VIEW + 20.0, "first maid spawns out of view")


# --- The arch cut scene -----------------------------------------------------------------

func test_arch_reveal_comes_before_the_sweep_and_the_next_door() -> String:
	var level: Node = load("res://scenes/main.tscn").instantiate()
	var props := _sweep()
	var after: Dictionary = _neighbours(_doors(level), props["trigger_x"])[1]
	level.free()
	var arch: float = CutsceneShots.scene("arch")["trigger_x"]
	var r: String = _T.assert_gt(props["trigger_x"], arch, "the reveal's mark comes first")
	if r != "":
		return r
	# Forced at the latest FORCE_AFTER past its mark: always before the next door can fire.
	return _T.assert_gt(after["trigger"][0], arch + CutsceneShots.FORCE_AFTER, "reveal forced before the next door")


## The arch reveal is the sweep's set-up: some shot of it frames all three cars.
func test_arch_reveal_frames_the_parked_cars() -> String:
	var lo: float = _car_xs().min() - Car.HALF_LEN
	var hi: float = _car_xs().max() + Car.HALF_LEN
	for shot: Dictionary in CutsceneShots.scene("arch")["shots"]:
		var c := CutsceneShots.clamp_center(shot["at"], shot["zoom"])
		var half := CutsceneShots.half_view(shot["zoom"]).x
		if c.x - half <= lo and c.x + half >= hi:
			return ""
	return "no arch shot frames the cars (%.0f-%.0f)" % [lo, hi]


# --- Timing rules -----------------------------------------------------------------------

func test_job_cutscene_gate_rule() -> String:
	var cases := [
		["", true, {}, true],
		["arch", false, {}, true],
		["arch", true, {}, false],
		["arch", true, {"opening": true}, false],
		["arch", true, {"arch": true}, true],
	]
	for c in cases:
		if StreetObjective.cutscene_cleared(c[0], c[1], c[2]) != c[3]:
			return "cutscene_cleared%s wrong" % [c.slice(0, 3)]
	return ""


func _make_stage() -> Player:
	_saved_events = Globals._active_events
	Globals._active_events = 0
	_stage = Node2D.new()
	_tree().root.add_child(_stage)
	_old_scene = _tree().current_scene
	_tree().current_scene = _stage
	var p: Player = PLAYER_SCENE.instantiate()
	_stage.add_child(p)
	p.set_process(false)
	p.set_physics_process(false)
	p.lane_floor_y = 0.0
	return p


func test_sweep_waits_for_the_arch_reveal_when_cut_scenes_are_on() -> String:
	var p := _make_stage()
	var d := MD.new()
	d.after_cutscene = "arch"
	d.car_xs = [5100.0]
	_stage.add_child(d)
	d._park(0.0)
	StreetCutscenes.enabled = true
	StreetCutscenes.seen.clear()
	var r: String = _T.assert_false(d._ready_to_start(p), "held before the reveal")
	if r != "":
		return r
	StreetCutscenes.seen["arch"] = true
	return _T.assert_true(d._ready_to_start(p), "free once the reveal has played")


## The street stays the job's through its payoff callout, then frees itself.
func test_job_holds_the_street_through_its_payoff() -> String:
	var p := _make_stage()
	var d := MD.new()
	d.car_xs = [5100.0]
	d.maid_count = 0
	_stage.add_child(d)
	d._park(0.0)
	d.start(p)
	var r: String = _T.assert_true(StreetObjective.any_busy(_tree()), "busy while running")
	if r != "":
		return r
	d.finish(true)
	r = _T.assert_true(StreetObjective.any_busy(_tree()), "still busy under CARS SAVED!")
	if r != "":
		return r
	await _tree().create_timer(StreetObjective.payoff_seconds(true) + 0.15).timeout
	return _T.assert_false(StreetObjective.any_busy(_tree()), "free once the payoff is gone")


func _busy_marker() -> Node:
	var n := Node.new()
	_stage.add_child(n)
	n.add_to_group(StreetObjective.BUSY)
	return n


func _door(p: Player, player_x: float) -> BuildingDoorEncounter:
	var enc: BuildingDoorEncounter = ENC_SCENE.instantiate()
	enc.lock_arena = false
	enc.arm_seconds = 0.02
	_stage.add_child(enc)
	p.global_position = Vector2(player_x, -20.0)
	return enc


func test_door_holds_while_a_job_has_the_street_then_fires() -> String:
	var p := _make_stage()
	var busy := _busy_marker()
	var enc := _door(p, 0.0)
	for i in 4:
		await _tree().physics_frame
	var r: String = _T.assert_false(enc._fired, "held while the job runs")
	if r != "":
		return r
	busy.free()
	for i in 3:
		await _tree().process_frame
	return _T.assert_true(enc._fired, "fires once the street is free, player still in")


func test_door_held_and_left_waits_for_the_player_to_come_back() -> String:
	var p := _make_stage()
	var busy := _busy_marker()
	var enc := _door(p, 0.0)
	for i in 4:
		await _tree().physics_frame
	p.global_position = Vector2(2000.0, -20.0)
	for i in 3:
		await _tree().physics_frame
	busy.free()
	for i in 3:
		await _tree().process_frame
	var r: String = _T.assert_false(enc._fired, "no door behind a player who walked off")
	if r != "":
		return r
	p.global_position = Vector2(0.0, -20.0)
	for i in 4:
		await _tree().physics_frame
	return _T.assert_true(enc._fired, "walking back in fires it")
