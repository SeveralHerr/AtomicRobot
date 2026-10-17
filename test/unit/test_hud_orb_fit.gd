extends RefCounted

## Player report: "If the player collects too many hearts, they overlap the logo."
## Each HP orb is as tall as the "HP" label (~98 px), so a full row of
## Player.MAX_ORBS ran under the ART logo at the top right. The row now shrinks its
## orbs just enough to stop short of the logo, and only when it has to.

var _T

const LEVELS := ["res://scenes/main.tscn", "res://scenes/boss_room.tscn"]

var _level: Node


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func teardown() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null


func _load(path: String) -> Dictionary:
	_level = (load(path) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	for i in 3:
		await _tree().process_frame
	return {
		"player": _level.get_node("Player"),
		"row": _level.get_node("UI/HealthContainer/Health/HBoxContainer"),
		"label": _level.get_node("UI/HealthContainer/Health/Label"),
		"logo": _level.get_node("UI/MarginContainer/TextureRect"),
	}


func _set_hp(n: Dictionary, hp: int) -> void:
	n.player.health = hp
	n.player.player_health_updated.emit(hp)
	for i in 3:
		await _tree().process_frame


func _visible_orbs(row: Control) -> Array:
	return row.get_children().filter(func(c: Node) -> bool: return c is Control and c.visible)


func test_full_row_stops_short_of_the_logo() -> String:
	for path in LEVELS:
		var n := await _load(path)
		await _set_hp(n, Player.max_health())
		var orbs := _visible_orbs(n.row)
		var r: String = _T.assert_eq(orbs.size(), Player.MAX_ORBS, "%s: every orb shows" % path)
		if r != "":
			return r
		var right: float = (orbs[-1] as Control).get_global_rect().end.x
		var logo_left: float = (n.logo as Control).get_global_rect().position.x
		r = _T.assert_true(right <= logo_left, "%s: orbs end at %.0f, logo starts at %.0f" % [path, right, logo_left])
		teardown()
		if r != "":
			return r
	return ""


func test_a_short_row_keeps_full_size_orbs() -> String:
	for path in LEVELS:
		var n := await _load(path)
		await _set_hp(n, 4 * Player.HITS_PER_ORB)
		var orbs := _visible_orbs(n.row)
		var want: float = (n.label as Control).size.y
		var got: float = (orbs[0] as Control).size.y
		var r: String = _T.assert_float_eq(got, want, 1.0, "%s: 4 orbs stay label-height" % path)
		teardown()
		if r != "":
			return r
	return ""


func test_orbs_stay_square() -> String:
	var n := await _load(LEVELS[0])
	await _set_hp(n, Player.max_health())
	for o in _visible_orbs(n.row):
		var s: Vector2 = (o as Control).size
		if absf(s.x - s.y) > 1.0:
			return "orb %s is not square" % s
	return ""
