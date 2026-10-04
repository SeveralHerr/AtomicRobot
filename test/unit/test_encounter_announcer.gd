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
	signal street_cleared
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
	rig[0].street_cleared.emit()
	rig[0].encounter_finished.emit()
	var shown: bool = rig[1].visible and rig[1].banner != null
	rig[0].free()
	return _T.assert_true(shown, "STREET CLEAR! stays up after the lock drops")
