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
	signal wave_cleared(index: int, total: int)
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
	return _T.assert_true(shown, "the STREET CLEAR! payoff stays up after the lock drops")


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
		"Payoff burst top %.0f must sit below the combo line (%.0f)" % [top, COMBO_BOTTOM])


func test_announcer_clear_burst_stays_off_the_player() -> String:
	# Walkway-lane heads stand at ~0.6 of the screen (validation captures).
	var bottom := _clear_burst_rect().end.y
	return _T.assert_true(bottom <= BASE_H * 0.6,
		"Payoff burst bottom %.0f must stay above the fighters' heads" % bottom)


## Mid-door waves get their own, smaller beat; STREET CLEAR! is the door's payoff.
func test_announcer_mid_door_wave_says_wave_clear() -> String:
	var rig := _rig()
	rig[0].wave_cleared.emit(1, 2)
	var mid: String = rig[1].banner._title.text
	var mid_k: float = rig[1].banner.size_k
	rig[0].squad_cleared.emit()
	var last: String = rig[1].banner._title.text
	rig[0].free()
	var r: String = _T.assert_eq(mid, A.WAVE_CLEAR_TITLE, "wave 1/2 down")
	if r != "":
		return r
	r = _T.assert_true(mid != last, "a wave clear never reads as the street clear")
	if r != "":
		return r
	r = _T.assert_eq(last, "STREET CLEAR!", "the last wave pays off")
	if r != "":
		return r
	return _T.assert_true(mid_k < A.CLEAR_SIZE_K, "the mid-door beat is smaller than the payoff")


func test_announcer_wave_banner_keeps_its_size_after_a_clear() -> String:
	var rig := _rig()
	rig[0].squad_cleared.emit()
	rig[0].wave_started.emit(1, 2)
	var k: float = rig[1].banner.size_k
	rig[0].free()
	return _T.assert_eq(k, A.SIZE_K, "a wave slam uses the wave size, not the payoff's")


# --- The payoff burst vs the HUD column, laid out for real ----------------------

const SCORE_UI := preload("res://scenes/score_ui.tscn")
## Desktop/cabinet window and a landscape phone (the validation-loop sizes).
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 800), Vector2i(1688, 780)]


## The canvas the game lays out on in `window`. Stretch mode canvas_items with
## aspect "keep" letterboxes every window to the base size; "expand" grows the short
## side. Anything else is a new layout rule this test has not been taught.
func _canvas_for(window: Vector2i) -> Vector2:
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect", "keep")
	assert(aspect in ["keep", "expand"], "teach _canvas_for the '%s' aspect" % aspect)
	if aspect == "keep":
		return base
	return Vector2(window) / minf(window.x / base.x, window.y / base.y)


## Lay the HUD column out on a `canvas`-sized viewport with every power-up running
## and a combo up, fire the payoff, and return [burst rect, {row name: [rect, ducked]}].
func _hud_under_burst(canvas: Vector2) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = Vector2i(canvas)
	tree.root.add_child(vp)
	var hud: CanvasLayer = SCORE_UI.instantiate()
	vp.add_child(hud)
	hud.set_process(false)  # keep the stand-in text below; no buff is really running
	var lines: Array[String] = []
	for id in PowerupRules.IDS:
		lines.append("%s 8.0" % PowerupRules.label(id))
	hud.powerup_label.text = "\n".join(lines)
	hud.combo_label.text = "88 HITS!"
	var enc := FakeEncounter.new()
	vp.add_child(enc)
	var a: EncounterAnnouncer = A.new()
	enc.add_child(a)
	a.watch(enc)
	# The payoff is the bigger of the two clears; its burst bounds the wave clear's.
	enc.squad_cleared.emit()
	await tree.process_frame
	await tree.process_frame
	var b: BossBanner = a.banner
	var r := BossBanner.burst_radii(b.size_k, b._title.get_minimum_size().x)
	var c := Vector2(b.size.x * 0.5, b.size.y * A.CLEAR_Y)
	var rows := {}
	for row: Control in hud.get_node("Hud/Rows").get_children():
		rows[row.name] = [row.get_global_rect(), row.is_in_group(HudFade.POWERUPS)]
	vp.free()
	return [Rect2(c - r, r * 2.0), rows]


## Every HUD row the payoff burst reaches must be one that ducks out while it shows
## (the power-up timer stack); the score and the combo line must clear it outright.
## Derived from the HUD's own rows, so a row added later is checked too.
func test_announcer_clear_burst_covers_only_ducked_hud_rows() -> String:
	for window in WINDOWS:
		var got: Array = await _hud_under_burst(_canvas_for(window))
		var burst: Rect2 = got[0]
		for row_name in got[1]:
			var rect: Rect2 = got[1][row_name][0]
			var ducked: bool = got[1][row_name][1]
			if rect.intersects(burst) and not ducked:
				return _T.assert_true(false, "%s: burst %s covers HUD row %s %s, which stays up" % [
					window, burst, row_name, rect])
	return ""


## The WAVE n/N stripe (STRIPE_Y, 0.8 size) spans the whole timer stack too: duck it
## so the timers don't flicker at the stripe's edges as it sweeps in and out.
func test_announcer_wave_stripe_ducks_the_powerup_timers() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var timers := Control.new()
	timers.add_to_group(HudFade.POWERUPS)
	tree.root.add_child(timers)
	var rig := _rig()
	await tree.process_frame  # soak up a post-load hitch frame
	rig[0].wave_started.emit(2, 2)
	await tree.create_timer(0.3, true, false, true).timeout
	var during := timers.modulate.a
	rig[0].free()
	timers.free()
	return _T.assert_true(during < 0.05, "timers ducked under the wave stripe (a=%.2f)" % during)


func test_announcer_clear_ducks_the_powerup_timers_then_restores_them() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var timers := Control.new()
	timers.add_to_group(HudFade.POWERUPS)
	tree.root.add_child(timers)
	var rig := _rig()
	await tree.process_frame  # soak up a post-load hitch frame (the duck runs on real time)
	rig[0].squad_cleared.emit()
	await tree.create_timer(0.4, true, false, true).timeout
	var during := timers.modulate.a
	await tree.create_timer(A.clear_hold() + 1.0, true, false, true).timeout
	var after := timers.modulate.a
	rig[0].free()
	timers.free()
	var r: String = _T.assert_true(during < 0.05, "timers ducked under the burst (a=%.2f)" % during)
	if r != "":
		return r
	return _T.assert_float_eq(after, 1.0, 0.01, "timers back once the burst is gone")


func _wait_real(seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await tree.process_frame


## Footage (2026-10-04 run, 2:20): a quick WAVE CLEAR! overtook the WAVE 1/3 stripe
## mid-hold, and the stripe's "HERE THEY COME!" tag hung on under the new burst.
func test_announcer_overtaking_slam_drops_the_old_subtitle() -> String:
	var rig := _rig()
	rig[0].wave_started.emit(1, 3)
	await _wait_real(0.45)  # stripe landed, sub tag slid in, still holding
	var tag_up: bool = rig[1].banner._sub_tag.modulate.a > 0.5
	rig[0].wave_cleared.emit(1, 3)
	await _wait_real(0.4)  # the burst has landed; it has no subtitle of its own
	var stale: float = rig[1].banner._sub_tag.modulate.a
	rig[0].free()
	var r: String = _T.assert_true(tag_up, "precondition: the wave tag was showing")
	if r != "":
		return r
	return _T.assert_eq(stale, 0.0, "the overtaken slam's subtitle is gone")
