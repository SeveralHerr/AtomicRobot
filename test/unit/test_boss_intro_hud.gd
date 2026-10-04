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
	var late: CanvasLayer = SCORE_UI.instantiate()
	_room.add_child(late)
	r = _T.assert_float_eq(late.hud.modulate.a, 1.0, 0.01, "a piece joining mid-fight is not held hidden")
	if r != "":
		return r
	return _T.assert_float_eq(_room.bar.modulate.a, 1.0, 0.01, "boss HP card never faded")


## The score column is injected by ScoreSystem a frame or more after the level
## loads, and the boss room plays its intro the moment the player spawns in the
## trigger: a HUD piece that joins mid-cinematic must come in faded too.
func test_boss_intro_fades_a_hud_piece_that_joins_late() -> String:
	_walk_in()
	await _real(0.8)
	var late: CanvasLayer = SCORE_UI.instantiate()
	_room.add_child(late)
	await _tree().process_frame
	return _T.assert_true(late.hud.modulate.a < 0.05,
		"late score column under the letterbox (a=%.2f)" % late.hud.modulate.a)


## Leaving mid-intro (quit to title) must not leave the next level's HUD hidden.
func test_leaving_mid_intro_releases_the_hud() -> String:
	_walk_in()
	await _real(0.8)
	_room.free()
	_room = BOSS_ROOM.instantiate()  # teardown frees this one
	var next := Control.new()
	next.add_to_group(HudFade.CINEMATIC)
	_tree().root.add_child(next)
	var a := next.modulate.a
	next.free()
	return _T.assert_float_eq(a, 1.0, 0.01, "a fresh HUD piece starts visible")


## The orbs draw above the bars (z_index 2), so they may only be back once the top
## bar has slid out past the CRT bezel (~40px), not while it is still leaving.
func test_boss_intro_orbs_never_show_over_the_top_bar() -> String:
	_walk_in()
	var orbs: CanvasItem = _room.ui.get_node("HealthContainer")
	var waited := 0.0
	var worst := 0.0
	while not (_room.boss != null and _room.boss.fighting and _bars().is_empty()) and waited < INTRO_TIMEOUT:
		for bar in _bars():
			if bar.position.y < 0.0 and bar.position.y + bar.size.y > 40.0:
				worst = maxf(worst, orbs.modulate.a)
		await _tree().process_frame
		waited += _tree().root.get_process_delta_time()
	return _T.assert_true(worst < 0.05, "orbs showed over the top bar (a=%.2f)" % worst)


## Letterbox bars on the room's UI layer: black, full-width ColorRects.
func _bars() -> Array:
	return _room.ui.get_children().filter(func(n: Node) -> bool:
		return n is ColorRect and n.color == Color.BLACK and n.position.y <= 0.0)
