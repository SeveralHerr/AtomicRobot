extends RefCounted

# Headless tests for BuildingDoorEncounter.lane_for_index — the pure function that
# decides which lane each enemy takes as it pours out of the door.

var _T
const E = preload("res://scripts/building_door_encounter.gd")
const L = preload("res://scripts/lane_system.gd")


func test_round_robin_covers_every_lane() -> String:
	var seen := {}
	for i in range(L.LANE_COUNT):
		seen[E.lane_for_index(i)] = true
	return _T.assert_eq(seen.size(), L.LANE_COUNT, "one squad cycle touches every lane")


func test_round_robin_starts_at_the_walkway() -> String:
	return _T.assert_eq(E.lane_for_index(0), L.BACK_LANE, "first enemy out takes the walkway")


func test_round_robin_wraps() -> String:
	var r: String = _T.assert_eq(
		E.lane_for_index(L.LANE_COUNT), E.lane_for_index(0), "wraps after a full cycle")
	if r != "":
		return r
	return _T.assert_eq(
		E.lane_for_index(L.LANE_COUNT + 2), E.lane_for_index(2), "stays in phase")


func test_every_index_yields_a_valid_lane() -> String:
	for i in range(32):
		if not L.is_valid_lane(E.lane_for_index(i)):
			return "lane_for_index(%d) returned an out-of-range lane" % i
	return ""


func test_explicit_pattern_is_honoured() -> String:
	var pattern := [2, 0, 3]
	var r: String = _T.assert_eq(E.lane_for_index(0, pattern), 2, "pattern[0]")
	if r != "":
		return r
	r = _T.assert_eq(E.lane_for_index(1, pattern), 0, "pattern[1]")
	if r != "":
		return r
	return _T.assert_eq(E.lane_for_index(3, pattern), 2, "pattern cycles")


func test_out_of_range_pattern_entries_are_clamped() -> String:
	var pattern := [-4, 99]
	var r: String = _T.assert_eq(E.lane_for_index(0, pattern), L.BACK_LANE, "clamps low")
	if r != "":
		return r
	return _T.assert_eq(E.lane_for_index(1, pattern), L.FRONT_LANE, "clamps high")


# --- Lifecycle (real encounter scene + real player, fast timings) -----------------
# Characterises the trigger -> lock -> spawn -> clear -> release loop that the wave
# rework must keep, then pins the waves themselves.

const ENC_SCENE := preload("res://scenes/building_door_encounter.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _stage: Node2D
var _enc
var _p: Player
var _old_scene: Node
var _finished: int = 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Fresh stage per test: spawn_enemy_at parents to current_scene, so point it at
## a throwaway node and restore it in teardown.
func _make(count: int, wave_count: int = 1) -> void:
	_finished = 0
	_stage = Node2D.new()
	_tree().root.add_child(_stage)
	_old_scene = _tree().current_scene
	_tree().current_scene = _stage
	_p = PLAYER_SCENE.instantiate()
	_stage.add_child(_p)
	_p.set_process(false)
	_p.set_physics_process(false)
	_enc = ENC_SCENE.instantiate()
	_enc.enemy_count = count
	if "waves" in _enc:
		_enc.waves = wave_count
	_enc.arm_seconds = 0.02
	_enc.spawn_interval = 0.01
	_enc.walk_out_seconds = 0.02
	if "wave_gap_seconds" in _enc:
		_enc.wave_gap_seconds = 0.02
	_stage.add_child(_enc)
	_enc.encounter_finished.connect(func(): _finished += 1)


func teardown() -> void:
	if _stage == null:
		return
	_tree().current_scene = _old_scene
	for e in _enc._spawned:
		if is_instance_valid(e):
			Globals.release_attack_slot(e)
	await _tree().process_frame
	_stage.free()
	_stage = null


## Waits (bounded) until `cond` holds; true if it did.
func _until(cond: Callable, seconds: float = 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _alive() -> int:
	return _enc._spawned.filter(func(e): return is_instance_valid(e) and not e.is_dead).size()


## Marks every live spawned enemy dead (what the encounter polls), freezing its AI.
func _kill_live() -> int:
	var n := 0
	for e in _enc._spawned:
		if is_instance_valid(e) and not e.is_dead:
			e.is_dead = true
			e.process_mode = Node.PROCESS_MODE_DISABLED
			n += 1
	return n


func _barriers_on() -> bool:
	return not _enc.left_wall.disabled and not _enc.right_wall.disabled


func test_door_trigger_locks_arena_and_spawns_the_squad() -> String:
	_make(3)
	_enc._on_body_entered(_p)
	var ok: bool = await _until(func(): return _alive() == 3 and not _enc._spawning)
	if not ok:
		return "squad of 3 never finished spawning (alive=%d)" % _alive()
	await _tree().physics_frame
	return _T.assert_true(_barriers_on(), "arena barriers up while the squad lives")


func test_door_clearing_the_squad_releases_the_arena_once() -> String:
	_make(2)
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2 and not _enc._spawning)
	_kill_live()
	var ok: bool = await _until(func(): return _finished > 0)
	await _tree().physics_frame
	var r: String = _T.assert_true(ok, "encounter_finished after the last kill")
	if r != "":
		return r
	r = _T.assert_eq(_finished, 1, "finished exactly once")
	if r != "":
		return r
	return _T.assert_false(_barriers_on(), "barriers drop on clear")


func test_door_player_death_mid_fight_releases() -> String:
	_make(2)
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2)
	_enc._on_player_death()
	await _tree().physics_frame
	var r: String = _T.assert_eq(_finished, 1, "death ends the encounter")
	if r != "":
		return r
	r = _T.assert_true(Globals.player_death.is_connected(_enc._on_player_death), "listens for player death")
	if r != "":
		return r
	return _T.assert_false(_barriers_on(), "death never leaves barriers up")


func test_door_watchdog_releases_a_stuck_fight() -> String:
	_make(2)
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2 and not _enc._spawning)
	var r: String = _T.assert_false(_enc._watchdog.is_stopped(), "watchdog armed during the fight")
	if r != "":
		return r
	_enc._on_watchdog()
	await _tree().physics_frame
	r = _T.assert_eq(_finished, 1, "watchdog ends the encounter")
	if r != "":
		return r
	return _T.assert_false(_barriers_on(), "watchdog drops the barriers")
