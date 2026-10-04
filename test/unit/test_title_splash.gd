extends RefCounted

## Jamcraft logo splash over the title screen (scripts/startscreen.gd + scripts/ui/jamcraft_splash.gd):
## plays once per boot, any button skips it, the skipping press never starts the game.

var _T

const START := preload("res://scenes/startscreen.tscn")
const StartScript := preload("res://scripts/startscreen.gd")
const PAD_A := 0


class StubStart:
	extends "res://scripts/startscreen.gd"
	var advanced := 0
	func _advance() -> void:
		advanced += 1


var _scene: Node


func setup() -> void:
	StartScript.splash_played = false


func teardown() -> void:
	# Other suites mount the title too: they must not get a splash eating their presses.
	StartScript.splash_played = true
	if is_instance_valid(_scene):
		_scene.free()
	_scene = null


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
	return _scene


func _splash(s: Node) -> JamcraftSplash:
	for c in s.get_children():
		if c is JamcraftSplash:
			return c
	return null


func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await _frames()


func _pad(button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	await _send(e)
	var up := e.duplicate() as InputEventJoypadButton
	up.pressed = false
	await _send(up)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	await _send(e)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	await _send(up)


## Real seconds until `cond` holds (tweens run on the wall clock), or -1 on timeout.
func _wait_for(cond: Callable, limit: float) -> float:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < limit:
		if cond.call():
			return (Time.get_ticks_msec() - start) / 1000.0
		await _tree().process_frame
	return -1.0


func test_splash_plays_over_title_on_first_boot() -> String:
	var s := await _mount()
	var sp := _splash(s)
	var r: String = _T.assert_true(sp != null, "first title of the boot shows the logo")
	if r != "":
		return r
	r = _T.assert_true(sp.logo != null, "logo texture found at res://images/jamcraft_logo.png")
	if r != "":
		return r
	return _T.assert_true(StartScript.splash_played, "remembered for the rest of the boot")


func test_splash_only_once_per_boot() -> String:
	StartScript.splash_played = true
	var s := await _mount()
	return _T.assert_true(_splash(s) == null, "back to the title (game over, quit) = no logo again")


func test_splash_sits_under_crt_overlay() -> String:
	var s := await _mount()
	return _T.assert_true(_splash(s).layer < CRTOverlay.OVERLAY_LAYER, "scanlines draw over the logo like every screen")


func test_splash_holds_title_input() -> String:
	var s := await _mount()
	await _frames(4)
	var r: String = _T.assert_false(s.delay, "title not accepting presses under the logo")
	if r != "":
		return r
	return _T.assert_true(s.get_node("Timer").is_stopped(), "anti-skip timer waits for the reveal")


func test_pad_press_skips_splash_without_starting_game() -> String:
	var s := await _mount()
	s.delay = true  # even if the title were ready, the skipping press is swallowed
	await _pad(PAD_A)
	var r: String = _T.assert_eq(s.advanced, 0, "the press that skips the logo does not start the game")
	if r != "":
		return r
	var sp := _splash(s)
	var t := await _wait_for(func() -> bool: return not is_instance_valid(sp) or sp._done, 0.8)
	return _T.assert_gte(t, 0.0, "pad A skips to the fade-out (< 0.8s)")


func test_key_skips_splash() -> String:
	var s := await _mount()
	var sp := _splash(s)
	await _key(KEY_ENTER)
	return _T.assert_true(sp._leaving, "Enter skips the logo")


func test_click_skips_splash() -> String:
	var s := await _mount()
	var sp := _splash(s)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(640, 400)
	await _send(e)
	return _T.assert_true(sp._leaving, "a click skips the logo")


func test_touch_skips_splash() -> String:
	var s := await _mount()
	var sp := _splash(s)
	# Without the emulated mouse click, so the touch itself is what skips.
	var emulate := Input.is_emulating_mouse_from_touch()
	Input.set_emulate_mouse_from_touch(false)
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = Vector2(640, 400)
	await _send(e)
	Input.set_emulate_mouse_from_touch(emulate)
	return _T.assert_true(sp._leaving, "a tap skips the logo (web/mobile)")


func test_stick_drift_does_not_skip_splash() -> String:
	var s := await _mount()
	var sp := _splash(s)
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = 1.0
	await _send(e)
	e = e.duplicate()
	e.axis_value = 0.0
	await _send(e)
	return _T.assert_false(sp._leaving, "stick motion is not a button press (AnyButton rule)")


func test_splash_ends_on_its_own_and_title_takes_over() -> String:
	var s := await _mount()
	var sp := _splash(s)
	s._attract = -100.0
	var t := await _wait_for(func() -> bool: return sp._done, 3.0)
	var r: String = _T.assert_gte(t, 1.0, "logo holds long enough to read")
	if r != "":
		return r
	r = _T.assert_true(s._attract >= 0.0 and s._attract < 1.0, "attract loop counts from the reveal, not from boot")
	if r != "":
		return r
	r = _T.assert_false(s.get_node("Timer").is_stopped(), "title's anti-skip delay restarts at the reveal")
	if r != "":
		return r
	var gone := await _wait_for(func() -> bool: return not is_instance_valid(sp), 1.0)
	r = _T.assert_gte(gone, 0.0, "splash frees itself after the reveal")
	if r != "":
		return r
	s.delay = true
	await _pad(PAD_A)
	return _T.assert_eq(s.advanced, 1, "title then takes a press as usual")


## Bot scenarios change scene on the title's first frame: the splash leaves the tree
## while its _ready still waits out the load hitch, and must not touch get_tree() after.
func test_splash_removed_before_intro_is_quiet() -> String:
	var splash := JamcraftSplash.new()
	_tree().root.add_child(splash)
	_tree().root.remove_child(splash)
	await _frames(3)
	var r: String = _T.assert_true(splash.get_child_count() > 0, "splash built before leaving")
	splash.free()
	return r
