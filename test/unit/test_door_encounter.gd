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
		_enc.rearm_seconds = 0.02
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


## The kill box frees an enemy outright (no death state). A typed filter callback
## errored on the freed object, the squad never emptied, and the arena stayed shut.
func test_door_freed_squad_member_still_releases_the_arena() -> String:
	_make(2)
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2 and not _enc._spawning)
	for e in _enc._spawned:
		if is_instance_valid(e):
			Globals.release_attack_slot(e)
			e.free()
	var ok: bool = await _until(func(): return _finished > 0)
	return _T.assert_true(ok, "encounter_finished once every squad member is freed")


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


# --- Waves -----------------------------------------------------------------------

func test_wave_sizes_sum_to_the_squad() -> String:
	for total in range(1, 10):
		for w in range(1, 4):
			var sizes: Array = E.wave_sizes(total, w)
			var sum := 0
			for s in sizes:
				if s < 1:
					return "wave_sizes(%d, %d) has an empty wave: %s" % [total, w, sizes]
				sum += s
			if sum != total:
				return "wave_sizes(%d, %d) = %s loses enemies" % [total, w, sizes]
	return ""


func test_wave_sizes_back_load_the_remainder() -> String:
	var r: String = _T.assert_eq(E.wave_sizes(5, 2), [2, 3], "the bigger wave comes last")
	if r != "":
		return r
	r = _T.assert_eq(E.wave_sizes(7, 3), [2, 2, 3], "7 over 3")
	if r != "":
		return r
	return _T.assert_eq(E.wave_sizes(4, 1), [4], "one wave = the whole squad")


func test_wave_sizes_clamp_wave_count() -> String:
	var r: String = _T.assert_eq(E.wave_sizes(2, 3), [1, 1], "never more waves than enemies")
	if r != "":
		return r
	r = _T.assert_eq(E.wave_sizes(6, 9), [2, 2, 2], "at most 3 waves")
	if r != "":
		return r
	return _T.assert_eq(E.wave_sizes(3, 0), [3], "at least 1 wave")


func _wave_signals() -> Array:
	var log: Array = []
	_enc.wave_started.connect(func(i, n): log.append("wave %d/%d" % [i, n]))
	_enc.wave_cleared.connect(func(i, n): log.append("wave %d/%d down" % [i, n]))
	_enc.squad_cleared.connect(func(): log.append("clear"))
	return log


func test_door_second_wave_follows_a_clear_and_holds_the_lock() -> String:
	_make(4, 2)
	var log := _wave_signals()
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2 and not _enc._spawning)
	await _tree().create_timer(0.1).timeout
	var r: String = _T.assert_eq(_enc._spawn_index, 2, "wave 1 is only its share of the squad")
	if r != "":
		return r
	_kill_live()
	var ok: bool = await _until(func(): return _alive() == 2 and not _enc._spawning)
	if not ok:
		return "wave 2 never arrived (alive=%d)" % _alive()
	await _tree().physics_frame
	r = _T.assert_eq(_finished, 0, "clearing wave 1 must not end the encounter")
	if r != "":
		return r
	r = _T.assert_true(_barriers_on(), "arena stays locked between waves")
	if r != "":
		return r
	_kill_live()
	await _until(func(): return _finished > 0)
	r = _T.assert_eq(_enc._spawn_index, 4, "both waves together are the whole squad")
	if r != "":
		return r
	r = _T.assert_eq(_finished, 1, "last wave cleared ends it once")
	if r != "":
		return r
	# STREET CLEAR! (squad_cleared) only for the door's last wave; earlier ones get
	# their own wave_cleared beat.
	return _T.assert_eq(log, ["wave 1/2", "wave 1/2 down", "wave 2/2", "clear"], "wave/clear signals in order")


func test_door_single_wave_still_pays_off_with_a_clear() -> String:
	_make(2, 1)
	var log := _wave_signals()
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2 and not _enc._spawning)
	_kill_live()
	await _until(func(): return _finished > 0)
	return _T.assert_eq(log, ["wave 1/1", "clear"], "one wave, then the payoff")


func test_door_watchdog_restarts_each_wave() -> String:
	_make(2, 2)
	_enc.watchdog_seconds = 2.0
	_enc._watchdog.wait_time = 2.0
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 1 and not _enc._spawning)
	await _tree().create_timer(0.7).timeout
	_kill_live()
	await _until(func(): return _alive() == 1 and not _enc._spawning)
	return _T.assert_gt(_enc._watchdog.time_left, 1.6, "wave 2 gets a fresh watchdog")


func test_door_death_between_waves_spawns_nothing_more() -> String:
	_make(4, 2)
	_enc.wave_gap_seconds = 0.3
	var log := _wave_signals()
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2 and not _enc._spawning)
	_kill_live()
	await _tree().create_timer(0.05).timeout
	_enc._on_player_death()
	await _tree().create_timer(0.6).timeout
	var r: String = _T.assert_eq(_enc._spawn_index, 2, "no wave 2 after the player died")
	if r != "":
		return r
	r = _T.assert_eq(_finished, 1, "released once")
	if r != "":
		return r
	r = _T.assert_false(_barriers_on(), "barriers down")
	if r != "":
		return r
	r = _T.assert_false(log.has("wave 2/2"), "no WAVE 2/2 callout after the player died")
	if r != "":
		return r
	return _T.assert_false(log.has("clear"), "no STREET CLEAR! payoff for a death")


func test_door_death_during_the_telegraph_never_bursts() -> String:
	_make(2, 1)
	_enc.arm_seconds = 0.3
	_enc._on_body_entered(_p)
	await _tree().create_timer(0.1).timeout
	_enc._on_player_death()
	await _tree().create_timer(0.4).timeout
	var r: String = _T.assert_eq(_enc._spawn_index, 0, "nobody steps out for a dead player")
	if r != "":
		return r
	return _T.assert_true(_enc.crack.frame < _enc._CRACK_BURST_FRAME, "the door never blows")


## Atomic hearts the encounter has knocked loose (live, uncollected).
func _hearts() -> int:
	return _stage.get_children().filter(func(c): return c.scene_file_path == HEART_PATH).size()


const HEART_PATH := "res://scenes/atomic_heart_pickup.tscn"


func test_door_reward_heart_drops_once_on_the_clear() -> String:
	_make(2, 2)
	_enc.reward_heart = true
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 1 and not _enc._spawning)
	_kill_live()
	await _until(func(): return _alive() == 1 and not _enc._spawning)
	var r: String = _T.assert_eq(_hearts(), 0, "no heart for an early wave")
	if r != "":
		return r
	_kill_live()
	await _until(func(): return _finished > 0)
	r = _T.assert_eq(_hearts(), 1, "one heart when the last wave goes down")
	if r != "":
		return r
	# Spawned at runtime, so the autoplay bot (which can't rescan the level every
	# frame) finds it through the group, as it does the boss room's phase hearts.
	return _T.assert_eq(_tree().get_nodes_in_group("atomic_hearts").size(), 1, "the heart is in the hearts group")


## Round-1 video: the heart landed ON the hole — drawn under the crack sprite
## (z 1), a black-outlined atom on a black hole. It must land out on the walkway.
func test_door_reward_heart_lands_clear_of_the_hole() -> String:
	_make(1, 1)
	var crack_half: float = _enc.crack.sprite_frames.get_frame_texture("default", 0).get_width() * 0.5 		* absf(_enc.crack.scale.x) if _enc.crack.sprite_frames.has_animation("default") else 24.0
	return _T.assert_true(absf(E.HEART_LAND.x - _enc.door_mouth.position.x) >= crack_half + 16.0,
		"heart lands %.0f px from the hole (crack half-width %.0f)" % [E.HEART_LAND.x, crack_half])


func test_door_without_reward_drops_no_heart() -> String:
	_make(2, 1)
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2 and not _enc._spawning)
	_kill_live()
	await _until(func(): return _finished > 0)
	return _T.assert_eq(_hearts(), 0, "reward is opt-in per encounter")


func test_door_watchdog_release_drops_no_heart() -> String:
	_make(2, 1)
	_enc.reward_heart = true
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2 and not _enc._spawning)
	_enc._on_watchdog()
	await _tree().physics_frame
	return _T.assert_eq(_hearts(), 0, "a forced release earns nothing")


func test_door_watchdog_release_is_not_a_clear() -> String:
	_make(2, 1)
	var log := _wave_signals()
	_enc._on_body_entered(_p)
	await _until(func(): return _alive() == 2 and not _enc._spawning)
	_enc._on_watchdog()
	await _tree().physics_frame
	return _T.assert_false(log.has("clear"), "a forced release is not a payoff")


# --- Level authoring: the real street's encounters --------------------------------

const MAIN_SCENE := preload("res://scenes/main.tscn")


## [x, waves, sizes] for every door encounter in main.tscn, in level order.
func _street_encounters() -> Array:
	var main := MAIN_SCENE.instantiate()
	var found: Array = []
	var stack: Array = [[main, 0.0]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var x: float = item[1] + (n.position.x if n is Node2D else 0.0)
		if n.get_script() == E:
			found.append([x, n.waves, E.wave_sizes(n.enemy_count, n.waves), n.get("reward_heart") == true])
		for c in n.get_children():
			stack.append([c, x])
	main.free()
	found.sort_custom(func(a, b): return a[0] < b[0])
	return found


func test_street_waves_ramp_from_one_to_three() -> String:
	var encs := _street_encounters()
	if encs.size() < 3:
		return "expected the street's door encounters, found %d" % encs.size()
	var r: String = _T.assert_eq(encs[0][1], 1, "first encounter is a single wave")
	if r != "":
		return r
	r = _T.assert_eq(encs[-1][1], 3, "last encounter is three waves")
	if r != "":
		return r
	for i in range(1, encs.size()):
		if encs[i][1] < encs[i - 1][1]:
			return "waves drop from %d to %d at x=%d" % [encs[i - 1][1], encs[i][1], encs[i][0]]
	return ""


func test_street_waves_never_send_a_lone_maid() -> String:
	for e in _street_encounters():
		for size in e[2]:
			if size < 2:
				return "encounter at x=%d has a 1-maid wave %s" % [e[0], e[2]]
	return ""


## The difficulty curve's last street beat: the fight right before the boss door is
## the street's biggest squad, and clearing it is the one encounter that pays out a
## heart — the refuel that lets a player who arrives low still face the boss.
func test_street_finale_is_the_biggest_squad_and_rewards_a_heart() -> String:
	var encs := _street_encounters()
	var last: Array = encs[-1]
	var last_total: int = last[2].reduce(func(a, b): return a + b, 0)
	for i in encs.size() - 1:
		var total: int = encs[i][2].reduce(func(a, b): return a + b, 0)
		if total >= last_total:
			return "encounter at x=%d (%d maids) matches the finale (%d)" % [encs[i][0], total, last_total]
		if encs[i][3]:
			return "encounter at x=%d rewards a heart; only the finale should" % encs[i][0]
	return _T.assert_true(last[3], "the finale knocks a heart loose")
