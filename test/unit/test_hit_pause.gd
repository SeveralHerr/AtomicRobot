extends RefCounted

# Utils.apply_hit_pause freezes Engine.time_scale for a beat when a blow lands. It
# must run on real time, extend (never shorten) a running pause, leave another
# system's slow-mo alone, and stay off in headless runs (tests, the autoplay bot).
# The headless gate is lifted per test through Utils' allow_headless_hit_pause.

var _T

const U := preload("res://scripts/autoload/utils.gd")

var _host: Node


func setup() -> void:
	Engine.time_scale = 1.0
	U.allow_headless_hit_pause = true
	_host = Node.new()
	_tree().root.add_child(_host)


func teardown() -> void:
	# Let any pause still running finish before the next test reads time_scale.
	await _wait(0.25)
	U.allow_headless_hit_pause = false
	Engine.time_scale = 1.0
	_host.free()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Poll the wall clock frame by frame: a SceneTree timer created from inside another
## timer's timeout can fire on the same frame, which made these waits unreliable.
func _wait(real_seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(real_seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await _tree().process_frame


func test_skipped_in_headless_by_default() -> String:
	U.allow_headless_hit_pause = false
	U.apply_hit_pause(_host, 0.1)
	return _T.assert_eq(Engine.time_scale, 1.0, "headless runs never freeze")


func test_freezes_then_restores() -> String:
	U.apply_hit_pause(_host, 0.05)
	var r: String = _T.assert_eq(Engine.time_scale, 0.0, "frozen during the pause")
	if r != "":
		return r
	await _wait(0.15)
	return _T.assert_eq(Engine.time_scale, 1.0, "restored after the pause")


func test_short_request_does_not_shorten_a_long_pause() -> String:
	U.apply_hit_pause(_host, 0.2)
	U.apply_hit_pause(_host, 0.02)
	await _wait(0.08)
	return _T.assert_eq(Engine.time_scale, 0.0, "still frozen: the long pause wins")


func test_long_request_extends_a_short_pause() -> String:
	U.apply_hit_pause(_host, 0.03)
	U.apply_hit_pause(_host, 0.2)
	await _wait(0.1)
	return _T.assert_eq(Engine.time_scale, 0.0, "extended by the longer request")


func test_skipped_during_someone_elses_slow_mo() -> String:
	Engine.time_scale = 0.3
	U.apply_hit_pause(_host, 0.05)
	var r: String = _T.assert_float_eq(Engine.time_scale, 0.3, 0.0001, "slow-mo untouched at start")
	if r != "":
		return r
	await _wait(0.1)
	return _T.assert_float_eq(Engine.time_scale, 0.3, 0.0001, "slow-mo untouched after")


func test_does_not_clobber_slow_mo_started_mid_pause() -> String:
	U.apply_hit_pause(_host, 0.05)
	Engine.time_scale = 0.3
	await _wait(0.12)
	return _T.assert_float_eq(Engine.time_scale, 0.3, 0.0001, "later slow-mo survives the pause end")


func test_records_requested_duration() -> String:
	U.allow_headless_hit_pause = false
	U.apply_hit_pause(_host, 0.12)
	return _T.assert_float_eq(U.last_hit_pause_request, 0.12, 0.0001, "request recorded even when skipped")


## Movie Maker (--write-movie) runs a fixed clock on which time_scale 0 turns the
## unscaled delta to NaN: the release timer never fires and the recording freezes.
## Players keep a true freeze; only recordings get a near-freeze.
func test_players_get_a_true_freeze() -> String:
	return _T.assert_eq(U.hit_pause_scale(false), 0.0, "live play freezes fully")


func test_movie_maker_gets_a_near_freeze() -> String:
	var s: float = U.hit_pause_scale(true)
	var r: String = _T.assert_true(s > 0.0, "never 0 while recording")
	if r != "":
		return r
	return _T.assert_true(s <= 0.02, "still reads as a freeze on video")
