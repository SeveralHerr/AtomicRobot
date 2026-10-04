extends RefCounted

## Party Code secret (scripts/party_code.gd + scripts/party_fx.gd): typing
## up up down down left right left right B A on the title turns on Globals.party_mode
## for the boot; every meter maid then bursts into confetti when defeated. Not a
## secret on the end card: no secret_found, no tally change, no score change.

var _T

const START := preload("res://scenes/startscreen.tscn")
const StartScript := preload("res://scripts/startscreen.gd")
const MAIDS := [
	preload("res://scenes/meter_maid.tscn"),
	preload("res://scenes/meter_maid_melee.tscn"),
	preload("res://scenes/meter_maid_window.tscn"),
	preload("res://scenes/meter_maid_platform.tscn"),
]
const CONFETTI_GROUP := &"party_confetti"
const ARROWS: Array[Key] = [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]


class StubStart:
	extends "res://scripts/startscreen.gd"
	var advanced := 0
	func _advance() -> void:
		advanced += 1


var _scene: Node
var _world: Node2D


func setup() -> void:
	StartScript.splash_played = true
	Globals.set("party_mode", false)


func teardown() -> void:
	Globals.set("party_mode", false)
	if is_instance_valid(_scene):
		_scene.free()
	_scene = null
	if is_instance_valid(_world):
		_world.free()
	_world = null


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n := 2) -> void:
	for i in n:
		await _tree().process_frame


func _mount() -> Node:
	_scene = START.instantiate()
	_scene.set_script(StubStart)
	_tree().root.add_child(_scene)
	await _frames()
	_scene.delay = true  # past the anti-skip delay: any advancing press would advance
	return _scene


func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await _frames(1)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	await _send(e)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	await _send(up)


func _pad(button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	await _send(e)
	var up := e.duplicate() as InputEventJoypadButton
	up.pressed = false
	await _send(up)


func _keys(codes: Array) -> void:
	for c in codes:
		await _key(c)


func _party() -> bool:
	return Globals.get("party_mode") == true


# --- title input -------------------------------------------------------------------

func test_party_arrow_code_turns_party_mode_on() -> String:
	var s := await _mount()
	await _keys(ARROWS)
	var r: String = _T.assert_true(_party(), "full arrow code sets Globals.party_mode")
	if r != "":
		return r
	return _T.assert_eq(s.advanced, 0, "typing the code never starts the game")


func test_party_wasd_code_turns_party_mode_on() -> String:
	await _mount()
	await _keys([KEY_W, KEY_W, KEY_S, KEY_S, KEY_A, KEY_D, KEY_A, KEY_D, KEY_B, KEY_A])
	return _T.assert_true(_party(), "WASD is the same directions (A doubles as left and the final A)")


func test_party_pad_code_turns_party_mode_on() -> String:
	var s := await _mount()
	for b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN,
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
			JOY_BUTTON_B, JOY_BUTTON_A]:
		await _pad(b)
	var r: String = _T.assert_true(_party(), "d-pad + pad B, A enters the code on the cabinet")
	if r != "":
		return r
	return _T.assert_eq(s.advanced, 0, "the closing pad A is the code's, not a start press")


func test_party_wrong_sequence_leaves_party_off() -> String:
	await _mount()
	await _keys([KEY_UP, KEY_DOWN, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A])
	return _T.assert_false(_party(), "a wrong order does nothing")


func test_party_code_missing_last_step_leaves_party_off() -> String:
	await _mount()
	await _keys(ARROWS.slice(0, ARROWS.size() - 1))
	return _T.assert_false(_party(), "B without the closing A is not the code")


func test_party_mistake_restarts_the_code() -> String:
	await _mount()
	await _keys([KEY_UP, KEY_UP, KEY_DOWN, KEY_LEFT])  # slip
	await _keys(ARROWS.slice(2))  # finishing from where it went wrong is not enough
	return _T.assert_false(_party(), "a slip resets the progress")


func test_party_extra_up_keeps_the_start() -> String:
	await _mount()
	await _key(KEY_UP)
	await _keys(ARROWS)
	return _T.assert_true(_party(), "up up up down down ... still counts (mashing the first key)")


func test_party_arrows_do_not_advance_title() -> String:
	var s := await _mount()
	await _keys([KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W])
	return _T.assert_eq(s.advanced, 0, "directions are code input, never a start press")


func test_party_dpad_does_not_advance_title() -> String:
	var s := await _mount()
	await _pad(JOY_BUTTON_DPAD_UP)
	return _T.assert_eq(s.advanced, 0, "d-pad is code input, never a start press")


func test_party_enter_still_advances_title() -> String:
	var s := await _mount()
	await _key(KEY_ENTER)
	return _T.assert_eq(s.advanced, 1, "Enter starts the game as before")


func test_party_pad_a_still_advances_title() -> String:
	var s := await _mount()
	await _pad(JOY_BUTTON_A)
	return _T.assert_eq(s.advanced, 1, "pad A starts the game when it is not closing the code")


func test_party_pad_b_still_advances_title() -> String:
	var s := await _mount()
	await _pad(JOY_BUTTON_B)
	return _T.assert_eq(s.advanced, 1, "pad B (not mid-code) starts the game as before")


func test_party_b_mid_code_does_not_advance() -> String:
	var s := await _mount()
	await _keys(ARROWS.slice(0, 9))
	return _T.assert_eq(s.advanced, 0, "the code's B is swallowed")


func test_party_title_acknowledges_party_mode() -> String:
	var s := await _mount()
	var label: Label = s.get_node("MarginContainer/VBoxContainer/Label")
	var before := label.text
	await _keys(ARROWS)
	var r: String = _T.assert_eq(label.text, "PARTY MODE!", "the title's own prompt line says so")
	if r != "":
		return r
	r = _T.assert_gt(_tree().get_nodes_in_group(CONFETTI_GROUP).size(), 0, "confetti burst on the title")
	if r != "":
		return r
	var back := await _wait_for(func() -> bool: return label.text == before, 4.0)
	return _T.assert_gte(back, 0.5, "prompt line comes back after a beat")


func test_party_advance_after_code_still_works() -> String:
	var s := await _mount()
	await _keys(ARROWS)
	await _key(KEY_ENTER)
	return _T.assert_eq(s.advanced, 1, "normal flow continues after the code")


func _wait_for(cond: Callable, limit: float) -> float:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < limit:
		if cond.call():
			return (Time.get_ticks_msec() - start) / 1000.0
		await _tree().process_frame
	return -1.0


# --- maid death --------------------------------------------------------------------

func _spawn(scene: PackedScene) -> Enemy:
	if not is_instance_valid(_world):
		_world = Node2D.new()
		_tree().root.add_child(_world)
	var e: Enemy = scene.instantiate()
	_world.add_child(e)
	e.set_physics_process(false)
	await _tree().process_frame
	e.show()
	return e


func _confetti_in_world() -> int:
	var n := 0
	for c in _tree().get_nodes_in_group(CONFETTI_GROUP):
		if _world.is_ancestor_of(c):
			n += 1
	return n


func test_party_maid_death_no_confetti_without_party() -> String:
	for scene in MAIDS:
		var e := await _spawn(scene)
		e.die()
	await _frames()
	return _T.assert_eq(_confetti_in_world(), 0, "normal deaths stay normal")


func test_party_every_maid_variant_bursts_in_party_mode() -> String:
	Globals.set("party_mode", true)
	for scene in MAIDS:
		var e := await _spawn(scene)
		var before := _confetti_in_world()
		e.die()
		await _frames()
		var r: String = _T.assert_eq(_confetti_in_world(), before + 1, "%s bursts into confetti" % scene.resource_path.get_file())
		if r != "":
			return r
		r = _T.assert_false(e._death_blink_target().visible, "%s pops (body gone)" % scene.resource_path.get_file())
		if r != "":
			return r
	return ""


func test_party_confetti_outlives_the_corpse_node() -> String:
	Globals.set("party_mode", true)
	var e := await _spawn(MAIDS[0])
	e.die()
	await _frames()
	for c in _tree().get_nodes_in_group(CONFETTI_GROUP):
		if _world.is_ancestor_of(c):
			var r: String = _T.assert_false(e.is_ancestor_of(c), "burst is a sibling, so hiding the maid can't hide it")
			if r != "":
				return r
			return _T.assert_gt((c as CanvasItem).z_index, e.z_index, "drawn over her lane, not behind it")
	return "no confetti"


func test_party_boss_never_bursts() -> String:
	var fx = load("res://scripts/party_fx.gd")
	if fx == null:
		return "scripts/party_fx.gd missing"
	Globals.set("party_mode", true)
	var boss: Node = preload("res://scenes/final_boss.tscn").instantiate()
	var maid: Node = MAIDS[0].instantiate()
	var r: String = _T.assert_false(fx.pops(boss), "City Council is unaffected")
	if r == "":
		r = _T.assert_true(fx.pops(maid), "a maid pops in party mode")
	boss.free()
	maid.free()
	return r


func test_party_kill_is_not_a_secret_and_scores_the_same() -> String:
	var found := [0]
	var count := func(_k: String, _id: String) -> void: found[0] += 1
	Globals.secret_found.connect(count)
	var tally_before: int = ScoreSystem.secrets.found_total()
	var was_running := ScoreSystem.running
	var score_before := ScoreSystem.score
	ScoreSystem.running = true
	var deltas: Array[int] = []
	for party in [false, true]:
		Globals.set("party_mode", party)
		ScoreSystem.combo = 0
		var s0 := ScoreSystem.score
		var e := await _spawn(MAIDS[0])
		e.die()
		await _frames()
		deltas.append(ScoreSystem.score - s0)
	ScoreSystem.running = was_running
	ScoreSystem.score = score_before
	ScoreSystem.combo = 0
	Globals.secret_found.disconnect(count)
	var r: String = _T.assert_eq(found[0], 0, "no secret_found from a party kill")
	if r != "":
		return r
	r = _T.assert_eq(ScoreSystem.secrets.found_total(), tally_before, "end-card secrets a/b unchanged")
	if r != "":
		return r
	r = _T.assert_true(_party(), "precondition: last kill was in party mode")
	if r != "":
		return r
	return _T.assert_eq(deltas[1], deltas[0], "a party kill scores exactly like a normal one")


# --- mutation survivors ------------------------------------------------------------

func test_party_held_key_echo_is_not_a_second_press() -> String:
	await _mount()
	var e := InputEventKey.new()
	e.keycode = KEY_UP
	e.physical_keycode = KEY_UP
	e.pressed = true
	await _send(e)
	var echo := e.duplicate() as InputEventKey
	echo.echo = true
	await _send(echo)  # holding up must not count as "up up"
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	await _send(up)
	await _keys(ARROWS.slice(2))  # one real up + an echo, then down down ...
	return _T.assert_false(_party(), "key repeat is not input")


func test_party_kill_squeaks_the_oof_up() -> String:
	Globals.set("party_mode", true)
	var e := await _spawn(MAIDS[0])
	e.die()
	return _T.assert_float_eq(e.receive_hit_audio.pitch_scale, PartyFx.HORN_PITCH, 0.001, "party-horn pitch on the killing oof")


func test_party_second_code_keeps_its_full_ack() -> String:
	var s := await _mount()
	var label: Label = s.get_node("MarginContainer/VBoxContainer/Label")
	await _keys(ARROWS)
	await _wait_for(func() -> bool: return false, 1.2)
	await _keys(ARROWS)  # typed again mid-ack
	await _wait_for(func() -> bool: return false, 1.2)  # first ack's timer has run out
	return _T.assert_eq(label.text, "PARTY MODE!", "the first ack's timer can't cut the second one short")
