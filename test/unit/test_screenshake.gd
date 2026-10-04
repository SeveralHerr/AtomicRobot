extends RefCounted

# ScreenShake used to shake only while `elapsed < duration - 0.8`, so every shake of
# 0.8s or less (most call sites) never moved the camera, and a second request while
# one ran just restarted the timer. A fresh instance is stepped by hand here with an
# injected camera, so nothing depends on the player scene or the frame clock.

var _T

const SHAKE := preload("res://scripts/autoload/screenshake.gd")
const STEP := 1.0 / 60.0

var _s: Node
var _cam: Camera2D


func setup() -> void:
	_s = SHAKE.new()
	_cam = Camera2D.new()
	_cam.offset = Vector2(5, 7)
	_s.camera = _cam


func teardown() -> void:
	_s.free()
	if is_instance_valid(_cam):
		_cam.free()


func _step(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		_s.step(STEP)
		t += STEP


func test_short_shake_moves_the_camera() -> String:
	_s.apply_shake(15.0, 0.3)
	var moved := false
	for i in 6:
		_s.step(STEP)
		moved = moved or _cam.offset != Vector2(5, 7)
	return _T.assert_true(moved, "a 0.3s shake displaces the camera in its first frames")


func test_default_duration_shake_moves_the_camera() -> String:
	_s.apply_shake(9.0)
	_s.step(STEP)
	return _T.assert_gt(_s.current_strength(), 0.0, "apply_shake(9) is live after one frame")


func test_offset_restored_and_shake_ends() -> String:
	_s.apply_shake(10.0, 0.25)
	_step(0.3)
	var r: String = _T.assert_eq(_cam.offset, Vector2(5, 7), "camera offset back at rest")
	if r != "":
		return r
	return _T.assert_false(_s.is_shaking(), "shake over after its duration")


func test_amplitude_decays_to_zero() -> String:
	var prev := INF
	for i in 11:
		var a: float = SHAKE.amplitude(10.0, i * 0.1, 1.0)
		if a > prev:
			return "amplitude rose at t=%.1f" % (i * 0.1)
		prev = a
	var r: String = _T.assert_float_eq(SHAKE.amplitude(10.0, 0.0, 1.0), 10.0, 0.001, "peak at t=0")
	if r != "":
		return r
	r = _T.assert_float_eq(SHAKE.amplitude(10.0, 0.5, 1.0), 2.5, 0.001, "quadratic falloff")
	if r != "":
		return r
	return _T.assert_float_eq(prev, 0.0, 0.0001, "zero at the end")


func test_weaker_request_does_not_cut_a_strong_shake() -> String:
	_s.apply_shake(12.0, 1.0)
	_step(0.1)
	var before: float = _s.current_strength()
	_s.apply_shake(2.0, 0.1)
	var r: String = _T.assert_gte(_s.current_strength(), before - 0.001, "strength kept")
	if r != "":
		return r
	return _T.assert_gte(_s.remaining(), 0.85, "remaining time kept")


func test_stronger_request_raises_strength_keeps_longer_time() -> String:
	_s.apply_shake(3.0, 1.0)
	_step(0.1)
	_s.apply_shake(10.0, 0.2)
	var r: String = _T.assert_float_eq(_s.current_strength(), 10.0, 0.001, "stronger wins")
	if r != "":
		return r
	return _T.assert_gte(_s.remaining(), 0.85, "longer remaining time wins")


func test_strength_is_capped() -> String:
	_s.apply_shake(100.0, 0.5)
	return _T.assert_float_eq(_s.current_strength(), SHAKE.MAX_STRENGTH, 0.001, "capped")


func test_offset_never_exceeds_strength() -> String:
	_s.apply_shake(8.0, 0.5)
	for i in 30:
		_s.step(STEP)
		var d: Vector2 = _cam.offset - Vector2(5, 7)
		if absf(d.x) > 8.0 + 0.001 or absf(d.y) > 8.0 + 0.001:
			return "offset %s exceeds strength" % d
	return ""


func test_freed_camera_is_safe() -> String:
	_s.apply_shake(8.0, 0.5)
	_s.step(STEP)
	_cam.free()
	_s.step(STEP)
	return _T.assert_false(_s.is_shaking(), "shake drops a freed camera")


func test_zero_strength_is_ignored() -> String:
	_s.apply_shake(0.0, 0.5)
	return _T.assert_false(_s.is_shaking(), "no-op shake")


func test_runs_on_real_time_under_slow_mo() -> String:
	_s.apply_shake(8.0, 1.0)
	Engine.time_scale = 0.5
	_s._process(0.1)  # 0.1 scaled seconds == 0.2 real seconds
	Engine.time_scale = 1.0
	return _T.assert_float_eq(_s.remaining(), 0.8, 0.001, "slow-mo doesn't stretch a shake")


func test_hitstop_holds_the_shake() -> String:
	_s.apply_shake(8.0, 1.0)
	Engine.time_scale = 0.0
	_s._process(0.0)
	Engine.time_scale = 1.0
	return _T.assert_float_eq(_s.remaining(), 1.0, 0.001, "time_scale 0 holds the shake")
