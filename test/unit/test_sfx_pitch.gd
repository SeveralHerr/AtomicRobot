extends RefCounted

# SfxPitch: combo steps rise, jitter stays small and can never reorder two steps.

var _T


func test_neutral_roll_is_base_pitch_plus_step_rise() -> String:
	var r: String = _T.assert_float_eq(SfxPitch.for_step(0, 0.5), 1.0, 0.0001, "step 0, mid roll")
	if r != "":
		return r
	return _T.assert_float_eq(SfxPitch.for_step(2, 0.5), 1.0 + 2.0 * SfxPitch.STEP_RISE, 0.0001, "step 2")


func test_jitter_spans_plus_minus_jitter() -> String:
	var lo := SfxPitch.for_step(0, 0.0)
	var hi := SfxPitch.for_step(0, 1.0)
	var r: String = _T.assert_float_eq(lo, 1.0 - SfxPitch.JITTER, 0.0001, "lowest roll")
	if r != "":
		return r
	return _T.assert_float_eq(hi, 1.0 + SfxPitch.JITTER, 0.0001, "highest roll")


func test_jitter_is_subtle() -> String:
	return _T.assert_true(SfxPitch.JITTER <= 0.05, "jitter under 5%% (was %s)" % SfxPitch.JITTER)


func test_worst_rolls_never_reorder_combo_steps() -> String:
	for s in AttackChain.MAX_STEPS - 1:
		var next_low := SfxPitch.for_step(s + 1, 0.0)
		var this_high := SfxPitch.for_step(s, 0.999999)
		var r: String = _T.assert_gt(next_low, this_high, "step %d low over step %d high" % [s + 1, s])
		if r != "":
			return r
	return ""


func test_play_sets_a_pitch_and_plays() -> String:
	var a := AudioStreamPlayer.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(a)
	a.stream = AudioStreamWAV.new()
	SfxPitch.play(a, 1)
	var p := a.pitch_scale
	a.free()
	var lo := 1.0 + SfxPitch.STEP_RISE - SfxPitch.JITTER
	var hi := 1.0 + SfxPitch.STEP_RISE + SfxPitch.JITTER
	return _T.assert_true(p >= lo - 0.0001 and p <= hi + 0.0001, "pitch %s in [%s, %s]" % [p, lo, hi])


## "Enemy 'oof' sounds at different pitches for variety": Enemy._play_hit_effects
## routes ReceiveHitAudio through SfxPitch.
func test_enemy_oof_pitch_varies_within_the_jitter_band() -> String:
	var e: Enemy = (load("res://scenes/meter_maid.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(e)
	e.set_physics_process(false)
	e.set_process(false)
	var seen := {}
	var ok := true
	for i in 12:
		e._play_hit_effects()
		var p: float = e.receive_hit_audio.pitch_scale
		seen[snappedf(p, 0.0001)] = true
		ok = ok and p >= 1.0 - SfxPitch.JITTER - 0.0001 and p <= 1.0 + SfxPitch.JITTER + 0.0001
	e.free()
	var r: String = _T.assert_true(ok, "every oof within +-JITTER of 1.0")
	if r != "":
		return r
	return _T.assert_gt(seen.size(), 1, "12 oofs are not all the same pitch")
