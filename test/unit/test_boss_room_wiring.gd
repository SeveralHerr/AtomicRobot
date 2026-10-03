extends RefCounted

## boss_room.gd freezes the player in _ready and only releases them from the boss
## intro, which its EntranceTrigger starts. When the scene was split into subscenes
## (5c91484) the trigger moved under Triggers/ and the background under
## Environment/, the script's $paths went null, and the boss room became a soft
## lock: frozen player, no boss. Found by the autoplay bot (test/autoplay/).

var _T

const BOSS_ROOM := preload("res://scenes/boss_room.tscn")

var _room: Node


func setup() -> void:
	_room = BOSS_ROOM.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(_room)


func teardown() -> void:
	_room.free()
	_room = null


func test_entrance_trigger_resolves() -> String:
	return _T.assert_true(_room.entrance_trigger != null, "boss_room.gd finds its EntranceTrigger")


func test_entrance_trigger_starts_the_intro() -> String:
	var r: String = _T.assert_true(_room.entrance_trigger != null, "trigger resolves")
	if r != "":
		return r
	return _T.assert_true(_room.entrance_trigger.body_entered.is_connected(_room._on_player_entered),
		"walking into the trigger plays the intro that unfreezes the player")


func test_background_sprite_resolves() -> String:
	return _T.assert_true(_room.boss_room_background_sprite != null,
		"falling briefcases spawn across the background sprite")
