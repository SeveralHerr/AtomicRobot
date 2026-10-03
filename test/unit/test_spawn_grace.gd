extends RefCounted

# Enemies that burst out of a building (BuildingDoorEncounter) used to be able to
# attack on their first physics tick — at the doorway, before fanning out — so the
# player got swarmed. Enemy.spawn_grace bars attacking (only attacking) until the
# squad has walked out to its lanes.

var _T

const MAID_SCENE := preload("res://scenes/meter_maid_melee.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENCOUNTER := preload("res://scripts/building_door_encounter.gd")

var _e: Enemy
var _p: Player


func setup() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_p = PLAYER_SCENE.instantiate()
	tree.root.add_child(_p)
	_p.set_process(false)
	_p.set_physics_process(false)
	_e = MAID_SCENE.instantiate()
	tree.root.add_child(_e)
	_e.set_process(false)
	_e.set_physics_process(false)
	_e.player = _p
	_e.lane = _p.current_lane
	_e.attack_timer.stop()


func teardown() -> void:
	# Let Enemy._ready's deferred Lanes.join_sort_layer land before freeing.
	await (Engine.get_main_loop() as SceneTree).process_frame
	Globals.release_attack_slot(_e)
	_e.free()
	_p.free()


## Everything else about the enemy says "attack now"; only grace differs.
func _ready_to_swing(grace: float) -> bool:
	_e.spawn_grace = grace
	_e.is_player_in_attack_range = true
	return _e.can_attack()


func test_control_enemy_without_grace_can_attack() -> String:
	return _T.assert_true(_ready_to_swing(0.0), "fixture must allow an attack, or the grace tests prove nothing")


func test_grace_blocks_attack() -> String:
	return _T.assert_false(_ready_to_swing(0.5), "a freshly-spawned enemy must not attack during grace")


func test_grace_ticks_down_and_releases_attack() -> String:
	_e.spawn_grace = 0.5
	_e._physics_process(0.3)
	var r: String = _T.assert_float_eq(_e.spawn_grace, 0.2, 0.001, "grace counts down with physics delta")
	if r != "":
		return r
	_e._physics_process(0.3)
	r = _T.assert_float_eq(_e.spawn_grace, 0.0, 0.0001, "grace clamps at zero")
	if r != "":
		return r
	return _T.assert_true(_ready_to_swing(_e.spawn_grace), "attacks resume once grace runs out")


func test_door_encounter_grace_outlasts_the_walk_out() -> String:
	var enc = ENCOUNTER.new()
	var grace: float = enc.attack_grace_seconds()
	var walk: float = enc.walk_out_seconds
	enc.free()
	return _T.assert_gt(grace, walk, "squad must reach its lanes before anyone may attack")
