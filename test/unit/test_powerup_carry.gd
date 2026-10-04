extends RefCounted

## A buff earned on the street used to be gone by the time the boss fight started:
## the boss room's own Player re-attached to PowerupSystem (which wipes the active
## set for a new run), and even a kept buff ticked down through the ~5 s intro the
## player can't move in. The door now carries buffs like it carries health, and the
## countdown holds while the boss room has the player frozen.

var _T

const BOSS_ROOM := preload("res://scenes/boss_room.tscn")
const RAGE := PowerupRules.RAGE


func teardown() -> void:
	PowerupSystem.hold(false)
	PowerupSystem.clear_all()
	PowerupSystem.attach(null)


func test_new_player_starts_without_buffs() -> String:
	PowerupSystem.grant(RAGE)
	PowerupSystem.attach(null)
	return _T.assert_false(PowerupSystem.is_active(RAGE), "a fresh run drops the old life's buff")


func test_boss_door_carries_buffs_to_the_next_player() -> String:
	PowerupSystem.grant(RAGE)
	PowerupSystem.carry_through_door()
	PowerupSystem.attach(null)
	return _T.assert_eq(PowerupSystem.remaining(RAGE), PowerupRules.duration(RAGE), "rage survives the door, untouched")


func test_carry_is_used_once() -> String:
	PowerupSystem.grant(RAGE)
	PowerupSystem.carry_through_door()
	PowerupSystem.attach(null)
	PowerupSystem.attach(null)
	return _T.assert_false(PowerupSystem.is_active(RAGE), "a restart after the boss room starts clean")


func test_hold_freezes_the_countdown() -> String:
	PowerupSystem.grant(RAGE)
	var full := PowerupRules.duration(RAGE)
	PowerupSystem.hold(true)
	PowerupSystem._process(1.0)
	var r: String = _T.assert_eq(PowerupSystem.remaining(RAGE), full, "no tick while held")
	if r != "":
		return r
	PowerupSystem.hold(false)
	PowerupSystem._process(1.0)
	return _T.assert_eq(PowerupSystem.remaining(RAGE), full - 1.0, "ticks again once released")


func test_boss_room_holds_buffs_while_the_player_is_frozen() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var room: Node = BOSS_ROOM.instantiate()
	tree.root.add_child(room)
	var held_in_intro := PowerupSystem.is_held()
	room._set_player_frozen(false)
	var held_in_fight := PowerupSystem.is_held()
	room._set_player_frozen(true)
	room.free()
	var r: String = _T.assert_true(held_in_intro, "intro (player frozen) holds the countdown")
	if r == "":
		r = _T.assert_false(held_in_fight, "FIGHT! releases it")
	if r == "":
		r = _T.assert_false(PowerupSystem.is_held(), "leaving the room never strands a hold")
	return r
