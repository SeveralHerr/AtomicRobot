extends RefCounted

# The score/combo/power-up HUD column (scripts/score_ui.gd): what the combo line says.

var _T

const SCORE_UI := preload("res://scenes/score_ui.tscn")

var _hud: CanvasLayer


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func setup() -> void:
	ScoreSystem.begin_stage("")
	_hud = SCORE_UI.instantiate()
	_tree().root.add_child(_hud)


func teardown() -> void:
	_hud.free()
	_hud = null
	ScoreSystem.begin_stage("")
	ScoreSystem.running = false


## Land `n` hits through the real scoring path, then let the HUD animate a frame.
func _hits(n: int) -> void:
	for i in n:
		ScoreSystem.register_hit()
	await _tree().process_frame


func test_combo_line_counts_hits() -> String:
	await _hits(2)
	var r: String = _T.assert_eq(_hud.combo_label.text, "2 HITS!", "two hits read as a combo")
	if r != "":
		return r
	return _T.assert_true(_hud.combo_label.visible, "and show")


func test_combo_line_hides_with_no_combo() -> String:
	await _hits(2)
	ScoreSystem.register_player_damaged()
	await _tree().process_frame
	return _T.assert_false(_hud.combo_label.visible, "a broken combo leaves no line")
