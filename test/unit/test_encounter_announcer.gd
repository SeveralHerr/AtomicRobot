extends RefCounted

# EncounterAnnouncer: the comic callouts over a door encounter's waves.

var _T
const A = preload("res://scripts/encounter_announcer.gd")


func test_announcer_one_wave_squad_gets_no_wave_banner() -> String:
	return _T.assert_eq(A.wave_title(1, 1), "", "a lone wave just bursts out")


func test_announcer_wave_titles_count_up() -> String:
	var r: String = _T.assert_eq(A.wave_title(1, 3), "WAVE 1/3", "first of three")
	if r != "":
		return r
	return _T.assert_eq(A.wave_title(3, 3), "WAVE 3/3", "last of three")


func test_announcer_last_wave_is_called_out() -> String:
	var r: String = _T.assert_eq(A.wave_subtitle(2, 2), "LAST ONES!", "final wave")
	if r != "":
		return r
	return _T.assert_true(A.wave_subtitle(1, 2) != A.wave_subtitle(2, 2), "first wave reads differently")


## A stand-in encounter with just the three signals the announcer listens to.
class FakeEncounter extends Node:
	signal wave_started(index: int, total: int)
	signal squad_cleared
	signal encounter_finished


func _rig() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var enc := FakeEncounter.new()
	tree.root.add_child(enc)
	var a: EncounterAnnouncer = A.new()
	enc.add_child(a)
	a.watch(enc)
	return [enc, a]


func test_announcer_forced_end_cuts_the_banner() -> String:
	var rig := _rig()
	rig[0].wave_started.emit(1, 2)
	rig[0].encounter_finished.emit()
	var hidden: bool = not rig[1].visible
	rig[0].free()
	return _T.assert_true(hidden, "death/watchdog hides a WAVE banner mid-slam")


func test_announcer_clear_survives_the_release() -> String:
	var rig := _rig()
	rig[0].squad_cleared.emit()
	rig[0].encounter_finished.emit()
	var shown: bool = rig[1].visible and rig[1].banner != null
	rig[0].free()
	return _T.assert_true(shown, "the BUSTED! payoff stays up after the lock drops")


## Bottom of the HUD's combo slot (scenes/score_ui.tscn: Hud offset_top 126 +
## ScoreLabel 47 + ComboSlot 64, at the 1280x800 base viewport). The clearing blow
## has just bumped the combo, so the payoff must not cover it.
const COMBO_BOTTOM := 239.0
const BASE_H := 800.0


func _clear_burst_rect() -> Rect2:
	var rig := _rig()
	rig[0].squad_cleared.emit()
	var b: BossBanner = rig[1].banner
	var r := BossBanner.burst_radii(b.size_k, b._title.get_minimum_size().x)
	var cy: float = A.CLEAR_Y * BASE_H
	rig[0].free()
	return Rect2(Vector2(-r.x, cy - r.y), r * 2.0)


func test_announcer_clear_burst_clears_the_combo_line() -> String:
	var top := _clear_burst_rect().position.y
	return _T.assert_true(top >= COMBO_BOTTOM,
		"BUSTED! burst top %.0f must sit below the combo line (%.0f)" % [top, COMBO_BOTTOM])


func test_announcer_clear_burst_stays_off_the_player() -> String:
	# Walkway-lane heads stand at ~0.6 of the screen (validation captures).
	var bottom := _clear_burst_rect().end.y
	return _T.assert_true(bottom <= BASE_H * 0.6,
		"BUSTED! burst bottom %.0f must stay above the fighters' heads" % bottom)


func test_announcer_wave_banner_keeps_its_size_after_a_clear() -> String:
	var rig := _rig()
	rig[0].squad_cleared.emit()
	rig[0].wave_started.emit(1, 2)
	var k: float = rig[1].banner.size_k
	rig[0].free()
	return _T.assert_eq(k, A.SIZE_K, "a wave slam uses the wave size, not the payoff's")
