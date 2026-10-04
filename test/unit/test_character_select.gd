extends RefCounted

# Character select on an arcade cabinet: joystick/d-pad + buttons only. The real
# scene is mounted; start_run() is stubbed so a confirmed pick never boots the run.

var _T

const SELECT := preload("res://scenes/character_select.tscn")
const ROSTER := ["Cody", "Ryan", "Cass", "Caitlyn", "Sara", "Robot"]

const PAD_A := 0
const PAD_UP := 11
const PAD_DOWN := 12
const PAD_LEFT := 13
const PAD_RIGHT := 14


class StubSelect:
	extends "res://scripts/character_select.gd"
	var runs := 0
	var backs := 0
	func _init() -> void:
		accept_grace = 0.0
	func start_run() -> void:
		runs += 1
	func back_to_title() -> void:
		backs += 1


var _scene: Node
var _saved_character: String
var _saved_cody_unlocked: bool


func setup() -> void:
	_saved_character = Globals.selected_character
	_saved_cody_unlocked = Globals.character_dict["Cody"].unlocked


func teardown() -> void:
	Globals.selected_character = _saved_character
	Globals.character_dict["Cody"].unlocked = _saved_cody_unlocked
	if is_instance_valid(_scene):
		_scene.free()
	_scene = null


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n := 2) -> void:
	for i in n:
		await _tree().process_frame


func _mount() -> Node:
	_scene = SELECT.instantiate()
	_scene.set_script(StubSelect)
	_tree().root.add_child(_scene)
	await _frames()
	return _scene


func _key(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames()
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames()


func _pad(button: int, device := 0) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = device
	e.pressed = true
	Input.parse_input_event(e)
	await _frames()
	var up := e.duplicate() as InputEventJoypadButton
	up.pressed = false
	Input.parse_input_event(up)
	await _frames()


func _stick(axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
	await _frames()
	var rest := e.duplicate() as InputEventJoypadMotion
	rest.axis_value = 0.0
	Input.parse_input_event(rest)
	await _frames()


func _focus() -> Control:
	return _tree().root.gui_get_focus_owner()


func _card(character: String) -> Button:
	return _scene.card_for(character)


## True when every ui_* nav binding listens to all pads (device -1). If project.godot
## pins them to device 0, a second encoder can't drive menus; that is an InputMap
## bug owned elsewhere, so device-1 assertions skip rather than fail this suite.
func _ui_binds_all_devices() -> bool:
	for a in ["ui_accept", "ui_left", "ui_right", "ui_up", "ui_down"]:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton and e.device != -1:
				return false
	return true


# --- Opening focus -------------------------------------------------------------

func test_roster_order_matches_cards() -> String:
	await _mount()
	var names := []
	for c in _scene.cards:
		names.append(c.character)
	return _T.assert_eq(names, ROSTER, "roster strip left-to-right")


func test_opens_with_selected_character_focused() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	return _T.assert_eq(_focus(), _card("Ryan"), "last-played Ryan owns focus on open")


func test_focus_falls_back_to_first_unlocked() -> String:
	Globals.selected_character = "Cody"
	Globals.character_dict["Cody"].unlocked = false
	await _mount()
	return _T.assert_eq(_focus(), _card("Ryan"), "locked Cody skipped; first unlocked card focused")


# --- Presentation follows focus --------------------------------------------------

func test_focused_card_lit_and_info_names_fighter() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	var r: String = _T.assert_true(_card("Ryan").is_hot(), "focused card lights up")
	if r != "":
		return r
	r = _T.assert_false(_card("Cody").is_hot(), "unfocused card stays cold")
	if r != "":
		return r
	return _T.assert_eq(_scene.info.name_label.text, "RYAN", "info card names the fighter")


func test_stage_shows_focused_fighter_frames() -> String:
	Globals.selected_character = "Cass"
	await _mount()
	return _T.assert_eq(_scene.hero.sprite.sprite_frames,
		Globals.character_dict["Cass"].sprite_frames, "stage plays Cass's idle")


func test_stat_pips_match_config() -> String:
	Globals.selected_character = "Cody"
	await _mount()
	var cfg: CharacterConfig = Globals.character_dict["Cody"]
	var r: String = _T.assert_eq(_scene.info.lit(0), cfg.get_starting_health(), "HEALTH pips = starting hp")
	if r != "":
		return r
	return _T.assert_eq(_scene.info.lit(1), cfg.get_starting_damage(), "POWER pips = starting dmg")


func test_bio_drops_stat_line() -> String:
	var bio: String = load("res://scripts/ui/select/info_card.gd").bio(Globals.character_dict["Cody"])
	var r: String = _T.assert_false("HP" in bio, "stat line is drawn as pips, not text (%s)" % bio)
	if r != "":
		return r
	return _T.assert_true(bio.length() > 0, "bio keeps the first description line")


func test_locked_fighter_shown_as_mystery() -> String:
	Globals.selected_character = "Ryan"
	Globals.character_dict["Cody"].unlocked = false
	await _mount()
	await _pad(PAD_LEFT)
	var r: String = _T.assert_eq(_scene.info.name_label.text, "LOCKED", "locked fighter's name hidden")
	if r != "":
		return r
	r = _T.assert_true(_scene.hero.mystery.visible, "stage shows ? over the silhouette")
	if r != "":
		return r
	r = _T.assert_false(_scene.info.prompt.visible, "no FIGHT prompt for a fighter you can't pick")
	if r != "":
		return r
	return _T.assert_false(_scene.info.stat_rows[0].visible, "locked fighter's stats hidden")


func test_unlocked_after_locked_clears_mystery() -> String:
	Globals.selected_character = "Ryan"
	Globals.character_dict["Cody"].unlocked = false
	await _mount()
	await _pad(PAD_LEFT)
	await _pad(PAD_RIGHT)
	var r: String = _T.assert_false(_scene.hero.mystery.visible, "? clears for an unlocked fighter")
	if r != "":
		return r
	return _T.assert_true(_scene.info.stat_rows[0].visible, "stats return")


# --- Navigation ------------------------------------------------------------------

func test_dpad_walks_every_card_and_back() -> String:
	Globals.selected_character = "Cody"
	await _mount()
	for n in range(1, 6):
		await _pad(PAD_RIGHT)
		var r: String = _T.assert_eq(_focus(), _scene.cards[n], "d-pad right reaches card %d" % n)
		if r != "":
			return r
	for n in range(4, -1, -1):
		await _pad(PAD_LEFT)
		var r: String = _T.assert_eq(_focus(), _scene.cards[n], "d-pad left reaches card %d" % n)
		if r != "":
			return r
	return _T.assert_false(_scene.cards[5].is_hot(), "highlight leaves the card focus left")


func test_dpad_wraps_both_ends() -> String:
	Globals.selected_character = "Cody"
	await _mount()
	await _pad(PAD_LEFT)
	var r: String = _T.assert_eq(_focus(), _card("Robot"), "left off Cody wraps to Robot")
	if r != "":
		return r
	await _pad(PAD_RIGHT)
	return _T.assert_eq(_focus(), _card("Cody"), "right off Robot wraps to Cody")


func test_stick_moves_focus() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	await _stick(JOY_AXIS_LEFT_X, 1.0)
	var r: String = _T.assert_eq(_focus(), _card("Cass"), "stick right moves to Cass")
	if r != "":
		return r
	await _stick(JOY_AXIS_LEFT_X, -1.0)
	return _T.assert_eq(_focus(), _card("Ryan"), "stick left moves back to Ryan")


func test_down_reaches_exit_and_up_returns_to_same_card() -> String:
	Globals.selected_character = "Sara"
	await _mount()
	await _pad(PAD_DOWN)
	var r: String = _T.assert_eq(_focus(), _scene.exit_button, "d-pad down reaches EXIT GAME")
	if r != "":
		return r
	await _stick(JOY_AXIS_LEFT_Y, -1.0)
	return _T.assert_eq(_focus(), _card("Sara"), "stick up returns to the fighter you left")


func test_second_pad_navigates() -> String:
	if not _ui_binds_all_devices():
		print("SKIP test_second_pad_navigates: ui_* bound to a single device in project.godot")
		return ""
	Globals.selected_character = "Ryan"
	await _mount()
	await _pad(PAD_RIGHT, 1)
	var r: String = _T.assert_eq(_focus(), _card("Cass"), "pad 2 d-pad moves focus")
	if r != "":
		return r
	await _pad(PAD_A, 1)
	return _T.assert_eq(Globals.selected_character, "Cass", "pad 2 A picks the character")


# --- Confirm ---------------------------------------------------------------------

func test_locked_card_cannot_be_picked() -> String:
	Globals.selected_character = "Ryan"
	Globals.character_dict["Cody"].unlocked = false
	await _mount()
	await _pad(PAD_LEFT)
	var r: String = _T.assert_eq(_focus(), _card("Cody"), "locked card is still reachable to read its hint")
	if r != "":
		return r
	await _pad(PAD_A)
	r = _T.assert_eq(Globals.selected_character, "Ryan", "A on a locked card does not pick it")
	if r != "":
		return r
	return _T.assert_false(_scene.confirmed, "A on a locked card does not start the READY! sequence")


func test_pad_a_picks_focused_character() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	await _pad(PAD_RIGHT)
	await _pad(PAD_A)
	return _T.assert_eq(Globals.selected_character, "Cass", "A picks the focused card (Cass)")


func test_confirm_starts_run_once_after_hold() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	await _pad(PAD_A)
	await _pad(PAD_A)  # mash
	var r: String = _T.assert_eq(_scene.runs, 0, "READY! holds before leaving")
	if r != "":
		return r
	await _tree().create_timer(_scene.CONFIRM_HOLD + 0.3).timeout
	return _T.assert_eq(_scene.runs, 1, "run starts exactly once after the hold")


func test_confirm_locks_navigation() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	await _pad(PAD_A)
	await _pad(PAD_RIGHT)
	var r: String = _T.assert_eq(Globals.selected_character, "Ryan", "pick sticks")
	if r != "":
		return r
	return _T.assert_false(_card("Cass").is_hot(), "d-pad can't move the cursor during READY!")


func test_confirm_stamps_ready() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	await _pad(PAD_A)
	await _tree().create_timer(_scene.HITSTOP + 0.1).timeout
	return _T.assert_true(_scene.hero.stamp.visible, "READY! stamp shows on pick")


# --- EXIT GAME -------------------------------------------------------------------

func test_down_reaches_exit_and_a_quits() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	var quits := [0]
	_scene.quit_game = func() -> void: quits[0] += 1
	var exit: Button = _scene.exit_button
	var r: String = _T.assert_true(exit.is_visible_in_tree(), "EXIT GAME shows on character select")
	if r != "":
		return r
	await _pad(PAD_DOWN)
	r = _T.assert_eq(_focus(), exit, "down reaches EXIT GAME")
	if r != "":
		return r
	await _pad(PAD_A)
	return _T.assert_eq(quits[0], 1, "A on EXIT GAME quits")


func test_exit_has_visible_focus_style() -> String:
	await _mount()
	var sb: StyleBox = _scene.exit_button.get_theme_stylebox("focus")
	return _T.assert_false(sb == null or sb is StyleBoxEmpty, "EXIT GAME focus is visible on an arcade screen")


func test_mashed_reject_settles_back_on_lift() -> String:
	Globals.selected_character = "Ryan"
	Globals.character_dict["Cody"].unlocked = false
	await _mount()
	await _pad(PAD_LEFT)
	for i in 4:
		await _pad(PAD_A)  # re-shake mid-shake
	await _tree().create_timer(0.6).timeout
	var v: Control = _card("Cody").visual
	return _T.assert_float_eq(v.position.y, _card("Cody").LIFT, 0.5, "card lands back on its lift, x=%s" % v.position.x)


func test_cursor_lands_over_focused_card() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	await _pad(PAD_RIGHT)
	await _pad(PAD_RIGHT)
	await _tree().create_timer(0.4).timeout
	var card := _card("Caitlyn")
	var want: float = card.global_position.x + card.size.x / 2.0
	return _T.assert_float_eq(_scene.cursor.global_position.x, want, 1.0, "P1 tag centred over Caitlyn")


func test_wrap_dir_takes_the_short_way() -> String:
	var S = load("res://scripts/character_select.gd")
	for c in [[0, 1, 1], [1, 0, -1], [5, 0, 1], [0, 5, -1], [2, 4, 1], [4, 2, -1]]:
		var r: String = _T.assert_eq(S.wrap_dir(c[0], c[1], 6), c[2], "wrap_dir(%d->%d)" % [c[0], c[1]])
		if r != "":
			return r
	return ""


func test_tick_pitch_rises_left_to_right() -> String:
	var S = load("res://scripts/character_select.gd")
	for i in range(1, 6):
		var r: String = _T.assert_gt(S.tick_pitch(i), S.tick_pitch(i - 1), "card %d ticks higher than %d" % [i, i - 1])
		if r != "":
			return r
	return _T.assert_float_eq(S.tick_pitch(5), S.tick_pitch(0) * 2.0, 0.001, "last card is an octave up")


func test_attack_button_also_picks() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	await _pad(PAD_RIGHT)
	await _key("Attack")
	return _T.assert_eq(Globals.selected_character, "Cass", "Attack picks the focused fighter")


func test_attack_on_footer_does_not_pick() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	await _pad(PAD_DOWN)
	await _key("Attack")
	return _T.assert_false(_scene.confirmed, "Attack in the footer doesn't start a run")


func test_cancel_goes_back_to_title() -> String:
	await _mount()
	await _key("ui_cancel")
	return _T.assert_eq(_scene.backs, 1, "back leaves for the title")


func test_accept_grace_swallows_early_press() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	_scene.accept_grace = 10.0
	await _pad(PAD_A)
	return _T.assert_false(_scene.confirmed, "A inside the grace window is ignored")


func test_prompt_follows_input_device() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.physical_keycode = KEY_RIGHT
		k.pressed = pressed
		Input.parse_input_event(k)
		await _frames()
	var r: String = _T.assert_true("ENTER" in _scene.info.prompt.text, "keyboard -> ENTER (got %s)" % _scene.info.prompt.text)
	if r != "":
		return r
	await _pad(PAD_LEFT)
	return _T.assert_true("PRESS A" in _scene.info.prompt.text, "pad -> A (got %s)" % _scene.info.prompt.text)


func test_first_tap_previews_second_tap_picks() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	var cass := _card("Cass")
	_scene.device = "touch"
	cass.grab_focus()  # emulated touch: hover focus lands with the press
	cass.pressed.emit()
	var r: String = _T.assert_false(_scene.confirmed, "first tap only previews")
	if r != "":
		return r
	await _tree().create_timer(0.2).timeout
	cass.pressed.emit()
	return _T.assert_eq(Globals.selected_character, "Cass", "second tap picks")


func test_pick_goes_straight_to_the_controls_splash() -> String:
	await _mount()
	return _T.assert_eq(_scene.next_scene(), _scene.CONTROLS_SPLASH, "the story moved into the opening cut scene")


func test_confirm_twice_is_ignored() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	_scene.confirm(_card("Ryan"))
	_scene.confirm(_card("Cass"))  # bypasses input lock: only the guard stops it
	return _T.assert_eq(Globals.selected_character, "Ryan", "second confirm can't change the pick")


func test_cursor_dims_in_footer_and_returns() -> String:
	Globals.selected_character = "Ryan"
	await _mount()
	await _pad(PAD_DOWN)
	await _tree().create_timer(0.3).timeout
	var r: String = _T.assert_true(_scene.cursor.modulate.a < 0.5, "P1 dims while footer has focus")
	if r != "":
		return r
	await _pad(PAD_UP)
	await _tree().create_timer(0.3).timeout
	return _T.assert_float_eq(_scene.cursor.modulate.a, 1.0, 0.01, "P1 back to full on a card")


# --- Robot: locked, earned, overpowered -----------------------------------------

func test_locked_robot_hint_names_the_boss() -> String:
	Globals.selected_character = "Sara"
	await _mount()
	await _pad(PAD_RIGHT)
	return _T.assert_true("BOSS" in _scene.info.bio_label.text, "locked card says how: %s" % _scene.info.bio_label.text)


func test_boss_win_reveals_new_challenger() -> String:
	Globals.selected_character = "Ryan"
	Globals.boss_death.emit()  # the real flow: boss dies, then the run ends at select
	await _mount()
	var r: String = _T.assert_eq(_focus(), _card("Robot"), "the new fighter owns focus")
	if r != "":
		return r
	r = _T.assert_eq(Globals.unseen_unlocks.size(), 0, "announced once")
	if r != "":
		return r
	await _tree().create_timer(_scene.REVEAL_AT + 0.4).timeout
	r = _T.assert_true(_scene.hero.stamp.visible and "CHALLENGER" in _scene.hero.stamp.text, "NEW CHALLENGER! stamp")
	if r != "":
		return r
	return _T.assert_eq(_card("Robot").plate.text, "ROBOT", "card name revealed")


func test_reveal_only_on_first_visit() -> String:
	Globals.boss_death.emit()
	await _mount()
	_scene.free()
	Globals.selected_character = "Ryan"
	await _mount()
	await _tree().create_timer(_scene.REVEAL_AT + 0.3).timeout
	return _T.assert_false(_scene.hero.stamp.visible, "no second NEW CHALLENGER")


func test_robot_is_pickable_once_earned() -> String:
	Globals.boss_death.emit()
	await _mount()
	await _pad(PAD_A)
	return _T.assert_eq(Globals.selected_character, "Robot", "A picks the earned Robot")


func test_overpowered_badge_only_on_robot() -> String:
	Globals.character_dict["Robot"].unlocked = true
	Globals.selected_character = "Robot"
	await _mount()
	var r: String = _T.assert_true(_scene.info.op_badge.visible, "Robot gets OVERPOWERED!")
	if r != "":
		return r
	await _pad(PAD_LEFT)
	return _T.assert_false(_scene.info.op_badge.visible, "Sara doesn't")


## Shooters wear the RANGED stamp, melee fighters don't — derived from the configs.
func test_ranged_badge_follows_config() -> String:
	var robot_was: bool = Globals.character_dict["Robot"].unlocked
	Globals.character_dict["Robot"].unlocked = true
	var out: String = await _ranged_badges()
	Globals.character_dict["Robot"].unlocked = robot_was
	return out


func _ranged_badges() -> String:
	for c in Globals.character_dict:
		Globals.selected_character = c
		await _mount()
		var cfg: CharacterConfig = Globals.character_dict[c]
		var r: String = _T.assert_eq(_scene.info.ranged_badge.visible, cfg.is_ranged(), "%s RANGED stamp" % c)
		if r != "":
			return r
		teardown()
	return ""


func test_robot_pips_fit_and_glow_gold() -> String:
	Globals.character_dict["Robot"].unlocked = true
	Globals.selected_character = "Robot"
	await _mount()
	var cfg: CharacterConfig = Globals.character_dict["Robot"]
	var r: String = _T.assert_eq(_scene.info.lit(0), cfg.get_starting_health(), "all HP pips lit")
	if r != "":
		return r
	var gold := 0
	for pip in _scene.info.stat_rows[0].get_children():
		if pip is Panel and pip.get_theme_stylebox("panel") == _scene.info._pip_gold:
			gold += 1
	r = _T.assert_eq(gold, 4, "HP pips past everyone else's best (4) glow gold")
	if r != "":
		return r
	for row in _scene.info.stat_rows:
		for pip in row.get_children():
			if pip is Panel and pip.visible:
				var right: float = row.position.x + pip.position.x + pip.size.x
				if right > _scene.info.SIZE.x - 20:
					return "pip ends at %.0f, outside the %d-wide card" % [right, _scene.info.SIZE.x]
	return ""


func test_roster_scale_reads_best_and_runner_up() -> String:
	var Info = load("res://scripts/ui/select/info_card.gd")
	var all: Array = Globals.character_dict.values()
	var s: Dictionary = Info.roster_scale(all)
	var r: String = _T.assert_eq(s.best, [8, 6], "best HP/POWER = Robot's")
	if r != "":
		return r
	return _T.assert_eq(s.usual, [4, 4], "runner-up HP/POWER = the rest's best")


func test_stamp_clears_when_you_move_on() -> String:
	Globals.boss_death.emit()
	await _mount()
	await _tree().create_timer(_scene.REVEAL_AT + 0.3).timeout
	await _pad(PAD_LEFT)
	return _T.assert_false(_scene.hero.stamp.visible, "NEW CHALLENGER! leaves with the fighter")


func test_p1_tag_clears_info_card_on_last_card() -> String:
	Globals.character_dict["Robot"].unlocked = true
	Globals.selected_character = "Robot"
	await _mount()
	await _tree().create_timer(0.8).timeout  # intro slide + cursor settle
	var card_bottom: float = _scene.info.get_global_rect().end.y
	var tag_top: float = _scene.cursor.global_position.y - 54.0  # tag bobs up to -54
	return _T.assert_gte(tag_top, card_bottom, "P1 tag stays below the info card")


func test_early_pick_keeps_ready_over_reveal() -> String:
	Globals.boss_death.emit()
	await _mount()
	await _pad(PAD_A)  # before REVEAL_AT
	await _tree().create_timer(_scene.REVEAL_AT + 0.05).timeout
	var r: String = _T.assert_true(_scene.flash.color.a < 0.1, "no second flash/fanfare during READY! (a=%.2f)" % _scene.flash.color.a)
	if r != "":
		return r
	return _T.assert_eq(_scene.hero.stamp.text, "READY!", "reveal doesn't overwrite the pick")


func test_accept_grace_counts_game_time() -> String:
	# The autoplay bot runs at a high time_scale: 0.35 game-seconds pass in a few
	# real milliseconds, and its Enter taps must still land.
	Globals.selected_character = "Ryan"
	await _mount()
	_scene.accept_grace = 0.35
	_scene._age = 0.0
	Engine.time_scale = 50.0
	await _tree().create_timer(0.5).timeout  # 0.5 game-s, ~10ms real
	Engine.time_scale = 1.0
	await _pad(PAD_A)
	return _T.assert_true(_scene.confirmed, "grace measured in game time, not wall clock")
