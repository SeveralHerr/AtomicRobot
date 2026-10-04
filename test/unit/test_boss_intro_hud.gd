extends RefCounted

# The boss intro is a cinematic: the HUD (HP orbs, portrait, score column) fades
# out under the letterbox and back in as the fight starts. Driven through the real
# flow — the player walks into the EntranceTrigger — not by calling the fade.

var _T

const BOSS_ROOM := preload("res://scenes/boss_room.tscn")
const SCORE_UI := preload("res://scenes/score_ui.tscn")
## Longest the intro may take before the test gives up waiting for the fight.
const INTRO_TIMEOUT := 12.0

var _room: Node
var _hud: CanvasLayer


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _real(seconds: float) -> void:
	await _tree().create_timer(seconds, true, false, true).timeout


func setup() -> void:
	_room = BOSS_ROOM.instantiate()
	_tree().root.add_child(_room)
	_hud = SCORE_UI.instantiate()
	_room.add_child(_hud)
	await _tree().process_frame
	await _tree().process_frame


func teardown() -> void:
	_room.free()
	BossJuice.reset_time()


## HUD pieces the cinematic must clear, by what a player sees.
func _pieces() -> Dictionary:
	return {
		"HP orbs": _room.ui.get_node("HealthContainer"),
		"portrait": _room.ui.get_node("MarginContainer"),
		"score column": _hud.hud,
	}


func _walk_in() -> void:
	_room.entrance_trigger.body_entered.emit(_room.player)


func test_boss_intro_fades_the_hud_under_the_letterbox() -> String:
	_walk_in()
	await _real(0.8)
	var pieces := _pieces()
	for what in pieces:
		var a: float = pieces[what].modulate.a
		if a > 0.05:
			return _T.assert_true(false, "%s still up under the letterbox (a=%.2f)" % [what, a])
	return ""


func test_boss_intro_brings_the_hud_back_for_the_fight() -> String:
	_walk_in()
	var waited := 0.0
	while (_room.boss == null or not _room.boss.fighting) and waited < INTRO_TIMEOUT:
		await _real(0.25)
		waited += 0.25
	var r: String = _T.assert_true(_room.boss != null and _room.boss.fighting, "the fight starts")
	if r != "":
		return r
	await _real(0.5)
	var pieces := _pieces()
	for what in pieces:
		r = _T.assert_float_eq(pieces[what].modulate.a, 1.0, 0.01, "%s back for the fight" % what)
		if r != "":
			return r
	return _T.assert_float_eq(_room.bar.modulate.a, 1.0, 0.01, "boss HP card never faded")
