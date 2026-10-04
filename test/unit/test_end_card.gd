extends RefCounted

# The end-of-run card (scripts/ui/end_card.gd): its list, fonts, and the card in the
# real levels. Initials input is covered by test_initials_entry.gd.
# The card is the ONLY end screen: these tests also pin that nothing else is shown
# beside or on top of it.

var _T

const BOSS_ROOM := "res://scenes/boss_room.tscn"
const MAIN := "res://scenes/main.tscn"
const TEST_SAVE := "user://test_scores_card.cfg"

var _nodes: Array[Node] = []
var _saved_path: String


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _add(node: Node) -> Node:
	_tree().root.add_child(node)
	_nodes.append(node)
	return node


func setup() -> void:
	_saved_path = ScoreSystem.save_path
	ScoreSystem.save_path = TEST_SAVE
	ScoreSystem.clear_records()


func teardown() -> void:
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		Input.action_release(a)
	var f := _tree().root.gui_get_focus_owner()
	if f:
		f.release_focus()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	ScoreSystem.begin_stage("")
	ScoreSystem.running = false
	ScoreSystem.clear_records()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	ScoreSystem.save_path = _saved_path
	ScoreSystem.reload()
	await _frames()


## A bare InitialsEntry in a plain host, open on AAA.
func _entry(start: String = "AAA") -> InitialsEntry:
	var host := _add(Control.new())
	var e := InitialsEntry.new()
	host.add_child(e)
	e.open(start)
	return e


func _armed_entry(start: String = "AAA") -> InitialsEntry:
	var e := _entry(start)
	await _tree().create_timer(InitialsEntry.ARM_DELAY + 0.05).timeout
	return e


## Inputs are injected at the top of a frame, before _process, the way real input is
## flushed. Injected straight after a timer callback they would land AFTER this
## frame's _process and be released before the next one ever polled them.
func _pad(index: JoyButton) -> void:
	await _frames(1)
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = index
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await _frames(1)


func _key(code: Key, unicode: int = 0) -> void:
	await _frames(1)
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await _frames(1)


## A death plays the DeathBeat (slow-mo, grey) before the card: wait it out.
func _beat(card: EndCard) -> void:
	while card.beat.running:
		await _tree().process_frame
	await _frames()


func _type(text: String) -> void:
	for c in text:
		await _key(OS.find_keycode_from_string(c), c.to_lower().unicode_at(0))


# --- Score list ---------------------------------------------------------------

func test_table_rows_use_pinball_format() -> String:
	var t := _add(ScoreTableView.new()) as ScoreTableView
	t.show_entries([HighScoreTable.make_entry("JDH", 2450000, "S"), HighScoreTable.make_entry("AL", 50)], 1)
	var r: String = _T.assert_eq([t._rows[0][1].text, t._rows[0][2].text, t._rows[0][3].text],
		["1", "JDH", "2,450,000"], "row reads 1 JDH 2,450,000")
	if r != "":
		return r
	r = _T.assert_eq(t._rows[HighScoreTable.SIZE - 1][2].text, "---", "empty place dashed")
	if r != "":
		return r
	r = _T.assert_eq(t._rows[HighScoreTable.SIZE - 1][1].text, str(HighScoreTable.SIZE), "places run to 10")
	if r != "":
		return r
	var lit = t._rows[1][0].get_theme_stylebox("panel")
	return _T.assert_true(lit is StyleBoxFlat, "saved row is lit")


func test_format_score_and_badge() -> String:
	for pair in [[0, "0"], [999, "999"], [1000, "1,000"], [1650000, "1,650,000"], [-1234, "-1,234"]]:
		var r: String = _T.assert_eq(ComicStyle.format_score(pair[0]), pair[1], "format %d" % pair[0])
		if r != "":
			return r
	var r2: String = _T.assert_eq(ComicStyle.badge_text(0), "NEW HIGH SCORE!", "1st")
	if r2 != "":
		return r2
	r2 = _T.assert_eq(ComicStyle.badge_text(2), "YOU PLACED #3!", "3rd")
	if r2 != "":
		return r2
	return _T.assert_eq(ComicStyle.badge_text(-1), "", "not placed: no badge")


## Every character the card can show must be in the face that draws it (the web build
## has no fallback font). Derived from the alphabet and the real strings.
func test_card_fonts_draw_every_character() -> String:
	var display_text := HighScoreTable.ALPHABET + "0123456789,-SABCD"
	var label_text := InitialsEntry.hint_text(true) + InitialsEntry.hint_text(false) \
		+ "ENTER YOUR INITIALS HIGH SCORES RANK FINAL SCORE RESTART EXIT GAME OK" \
		+ ComicStyle.badge_text(0) + ComicStyle.badge_text(4) + "0123456789,+:" \
		+ RunSummary.breakdown_text({"fight_score": 1, "street_score": 1, "seconds": 61.0, "perfect": true,
			"secret_totals": {"wall": 2, "news": 5}}) + RunSummary.breakdown_text({"fight_score": 1}) 		+ RunSummary.unlock_text({"unlocks": ["Robot", "Cody"]})
	for pair in [[ComicStyle.DISPLAY, display_text + "GAME OVER YOU WIN!"], [ComicStyle.LABEL, label_text]]:
		for c in String(pair[1]):
			if c.unicode_at(0) > 32 and not pair[0].has_char(c.unicode_at(0)):
				return "%s cannot draw '%s'" % [pair[0].resource_path, c]
	return ""


# --- The card in a real level -------------------------------------------------

func _level(path: String = BOSS_ROOM, score: int = 800) -> EndCard:
	var level := _add((load(path) as PackedScene).instantiate())
	await _frames()
	ScoreSystem.current_scene_path = path
	ScoreSystem.begin_stage(path)
	ScoreSystem.score = score
	return level.get_node("UI/EndCard") as EndCard


## The card is the only end screen: no other CanvasItem in the level's UI may be
## showing a game-over/win screen beside it.
func test_level_has_one_end_screen() -> String:
	for path in [MAIN, BOSS_ROOM]:
		var level := (load(path) as PackedScene).instantiate()
		var ui := level.get_node("UI")
		var r: String = _T.assert_true(ui.get_node_or_null("EndCard") is EndCard, "%s has an EndCard" % path)
		if r == "":
			for old in ["GameOverContainer", "WinContainer"]:
				if ui.get_node_or_null(old) != null:
					r = "%s still has the old %s" % [path, old]
		level.free()
		if r != "":
			return r
	return ""


func test_death_with_high_score_shows_entry_in_the_card() -> String:
	var card: EndCard = await _level()
	Globals.player_death.emit()
	await _beat(card)
	var r: String = _T.assert_true(card.visible, "card shows on death")
	if r != "":
		return r
	r = _T.assert_eq(card.summary.title.text, "GAME OVER", "death title")
	if r != "":
		return r
	r = _T.assert_true(card.entry.visible, "initials inside the card")
	if r != "":
		return r
	r = _T.assert_false(card.table.visible, "list waits for the initials")
	if r != "":
		return r
	r = _T.assert_false(card._buttons.visible, "RESTART hidden while entering, like pinball")
	if r != "":
		return r
	r = _T.assert_false(card.summary.rank_row.visible, "no rank on a death")
	if r != "":
		return r
	return _T.assert_eq(card.summary.badge_label.text, "NEW HIGH SCORE!", "badge for 1st place")


func test_saving_swaps_entry_for_lit_list_then_restart() -> String:
	var card: EndCard = await _level()
	Globals.player_death.emit()
	await _beat(card)
	await _tree().create_timer(InitialsEntry.ARM_DELAY + 0.05).timeout
	await _type("ZAP")
	await _pad(JOY_BUTTON_A)
	var r: String = _T.assert_false(card.entry.visible, "entry gone after save")
	if r != "":
		return r
	r = _T.assert_true(card.table.visible, "list in the same spot")
	if r != "":
		return r
	r = _T.assert_eq(card.table.highlight, 0, "new row lit")
	if r != "":
		return r
	r = _T.assert_eq(String(ScoreSystem.high_scores[0]["initials"]), "ZAP", "saved")
	if r != "":
		return r
	r = _T.assert_true(card._buttons.visible, "buttons back")
	if r != "":
		return r
	r = _T.assert_true(card.restart_button.has_focus(), "RESTART takes focus")
	if r != "":
		return r
	var restarted := [false]
	card.restart_game = func() -> void: restarted[0] = true
	await _tree().create_timer(EndCard.ARM_DELAY + 0.05).timeout
	await _pad(JOY_BUTTON_A)
	return _T.assert_true(restarted[0], "A on RESTART restarts")


func test_clear_shows_rank_stamp_and_breakdown() -> String:
	var card: EndCard = await _level(BOSS_ROOM, 26400)
	var player := card.get_tree().get_first_node_in_group("player")
	# boss_room.gd holds the player still until its intro plays; release it the way
	# the intro does, so the freeze below is the card's doing.
	player.set_process(true)
	player.set_physics_process(true)
	var r: String = _T.assert_true(player.is_physics_processing(), "player live before the clear")
	if r != "":
		return r
	Globals.boss_death.emit()
	await _frames()
	r = _T.assert_eq(card.summary.title.text, "YOU WIN!", "win title")
	if r != "":
		return r
	r = _T.assert_true(card.summary.rank_row.visible, "rank stamp on a clear")
	if r != "":
		return r
	r = _T.assert_eq(card.summary.stamp_label.text, String(ScoreSystem.last_run["rank"]), "stamp shows the rank")
	if r != "":
		return r
	r = _T.assert_true(card.summary.breakdown.visible and card.summary.breakdown.get_child_count() > 0, "breakdown shown")
	if r != "":
		return r
	return _T.assert_false(player.is_physics_processing(), "player frozen on a clear")


func test_non_qualifier_sees_list_and_restart_at_once() -> String:
	for i in HighScoreTable.SIZE:
		HighScoreTable.insert(ScoreSystem.high_scores, HighScoreTable.make_entry("TOP", 1_000_000))
	var card: EndCard = await _level(BOSS_ROOM, 10)
	Globals.player_death.emit()
	await _beat(card)
	var r: String = _T.assert_false(card.entry.visible, "no entry")
	if r != "":
		return r
	r = _T.assert_true(card.table.visible, "list shown")
	if r != "":
		return r
	r = _T.assert_false(card.summary.badge_holder.visible, "no badge when not placed")
	if r != "":
		return r
	return _T.assert_true(card.restart_button.has_focus(), "RESTART focused")


## Integration, not stacking: the card fits the 1280x800 screen and draws above the
## score HUD (which the level UI layer covers).
func test_card_fits_screen_and_covers_hud() -> String:
	var card: EndCard = await _level(BOSS_ROOM, 26400)
	Globals.boss_death.emit()
	await _frames(4)
	var panel := card.find_child("Card", true, false) as Control
	var rect := panel.get_global_rect()
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 800))
	if not screen.encloses(rect.grow(-12)):
		return "card %s spills off the 1280x800 screen" % rect
	var hud_layer: int = (load("res://scenes/score_ui.tscn") as PackedScene).instantiate().layer
	var ui_layer: int = card.get_parent().layer
	return _T.assert_gt(ui_layer, hud_layer, "level UI (card) layer above the score HUD")


## The boss room adds its HP card and banner to the same UI layer after the EndCard;
## the card (and a death's grey-out) must still draw over them.
func test_card_draws_over_the_boss_hud() -> String:
	for sig in ["player_death", "boss_death"]:
		var card: EndCard = await _level(BOSS_ROOM)
		var ui := card.get_parent()
		Globals.emit_signal(sig)
		await _frames()
		var r: String = _T.assert_eq(card.get_index(), ui.get_child_count() - 1, "%s: card is the last UI child" % sig)
		if r != "":
			return r
		for n in _nodes:
			n.free()
		_nodes.clear()
	return ""


## Tree order is not enough: a z_index wins over it. The HUD orbs (hp_1.tscn,
## z_index 2) drew over the card's top edge once the card grew tall enough to reach
## them. Derived: every CanvasItem in the UI layer, not just the ones known today.
func test_card_z_beats_every_ui_item() -> String:
	var card: EndCard = await _level(BOSS_ROOM)
	Globals.boss_death.emit()
	await _frames()
	for node in card.get_parent().find_children("*", "CanvasItem", true, false):
		if node == card or card.is_ancestor_of(node):
			continue
		var item := node as CanvasItem
		if item.visible and _abs_z(item) > card.z_index:
			return "%s (z %d) draws over the card (z %d)" % [card.get_parent().get_path_to(item), _abs_z(item), card.z_index]
	return ""


func _abs_z(item: CanvasItem) -> int:
	var z := 0
	var n: Node = item
	while n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return z


## Something joining the UI layer after the card is up (the boss intro's letterbox
## bars, a phase flash during the death beat) must not draw over it. CI's slow
## frames let the intro land mid-test and buried the card under its bars.
func test_card_stays_on_top_of_later_ui() -> String:
	var card: EndCard = await _level(BOSS_ROOM)
	var ui := card.get_parent()
	Globals.player_death.emit()
	await _frames()
	var late := ColorRect.new()
	ui.add_child(late)
	await _frames()
	return _T.assert_eq(card.get_index(), ui.get_child_count() - 1, "card stays the last UI child")


func test_card_turns_off_touch_controls() -> String:
	var card: EndCard = await _level()
	var mobile := card.get_parent().get_node("MobileUI")
	Globals.player_death.emit()
	await _frames()
	var r: String = _T.assert_false(mobile.visible, "touch controls hidden under the card")
	if r != "":
		return r
	return _T.assert_false(mobile.is_processing_input(), "and no longer claim touches")


func test_hud_hides_when_the_run_ends() -> String:
	var level := _add((load(BOSS_ROOM) as PackedScene).instantiate())
	var hud := (load("res://scenes/score_ui.tscn") as PackedScene).instantiate()
	level.add_child(hud)
	await _frames()
	Globals.player_death.emit()
	var r: String = _T.assert_false(hud.hud.visible, "rolling HUD score hidden behind the card")
	if r != "":
		return r
	ScoreSystem.stage_started.emit("")
	return _T.assert_true(hud.hud.visible, "back for the next stage")


# --- Title-screen attract loop -------------------------------------------------

func _title() -> Node:
	load("res://scripts/startscreen.gd").splash_played = true  # no logo over the attract loop
	var s := _add((load("res://scenes/startscreen.tscn") as PackedScene).instantiate())
	await _frames()
	return s


func test_title_attract_shows_card_then_title() -> String:
	HighScoreTable.insert(ScoreSystem.high_scores, HighScoreTable.make_entry("ACE", 4000, "C"))
	var s: Node = await _title()
	s._attract = s.ATTRACT_SECONDS
	await _frames()
	var r: String = _T.assert_true(s.board.visible, "list cycles in when idle")
	if r != "":
		return r
	r = _T.assert_eq(s.table._rows[0][2].text, "ACE", "shows the saved list")
	if r != "":
		return r
	r = _T.assert_false(s.table._rows[1][0].visible, "title card hides empty places")
	if r != "":
		return r
	s._attract = s.ATTRACT_SECONDS
	await _frames()
	return _T.assert_false(s.board.visible, "title cycles back")


func test_title_attract_skips_empty_list() -> String:
	var s: Node = await _title()
	s._attract = s.ATTRACT_SECONDS
	await _frames()
	return _T.assert_false(s.board.visible, "no empty list in the attract loop")


# --- Readability through the CRT (user: "too noisy, hard to read with CRT on") ---

func test_card_tunes_the_crt_in_and_out() -> String:
	CRTOverlay.reset_focus()
	var card: EndCard = await _level()
	card.present(true)
	await _tree().create_timer(CRTOverlay.TUNE_SECONDS + 0.1).timeout
	var r: String = _T.assert_float_eq(CRTOverlay.focus, 1.0, 0.001, "tube tuned in under the card")
	card.get_parent().remove_child(card)
	card.queue_free()
	if r != "":
		return r
	return _T.assert_float_eq(CRTOverlay.focus, 0.0, 0.001, "normal look back when the card leaves")


func test_card_list_hides_empty_places() -> String:
	var card: EndCard = await _level()
	ScoreSystem.high_scores = [HighScoreTable.make_entry("TOP", 1_000_000)]
	ScoreSystem.awaiting_initials = false
	card.present(true)
	await _frames()
	var shown := 0
	for row in card.table._rows:
		if row[0].visible:
			shown += 1
	return _T.assert_eq(shown, 1, "one saved score, one row; no column of dashes")


## Footage: the HP orbs and the boss portrait sat above the card, more to read past.
func test_card_fades_the_hud_out() -> String:
	return await _fades_hud(MAIN)


func test_card_fades_the_boss_room_hud_out() -> String:
	return await _fades_hud(BOSS_ROOM)


func _fades_hud(path: String) -> String:
	var card: EndCard = await _level(path)
	var orbs: Array = _tree().get_nodes_in_group(HudFade.CINEMATIC)
	var names := orbs.map(func(n: Node) -> String: return n.name)
	var r: String = _T.assert_true("HealthContainer" in names, "HP orbs fade with the HUD in %s" % path)
	if r != "":
		return r
	card.present(true)
	await _tree().create_timer(EndCard.HUD_FADE_SECONDS + 0.1).timeout
	for n in orbs:
		if is_instance_valid(n) and (n as CanvasItem).modulate.a > 0.01:
			HudFade.release(_tree(), HudFade.CINEMATIC)
			return "%s still showing (a=%.2f)" % [n.name, (n as CanvasItem).modulate.a]
	HudFade.release(_tree(), HudFade.CINEMATIC)
	return ""
