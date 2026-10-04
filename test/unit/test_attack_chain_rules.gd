extends RefCounted

# AttackChain timing rules on their own (no scene): commit until the hit frame,
# cancel/chain RECOVERY_FRAMES after it, the finisher never chains early.

var _T

const HIT := 3

var _c: AttackChain


func setup() -> void:
	_c = AttackChain.new()
	_c.reset()


func test_no_recovery_before_the_hit_fires() -> String:
	return _T.assert_false(_c.in_recovery(HIT + 5, HIT), "hit not done: committed")


func test_recovery_opens_exactly_recovery_frames_after_the_hit() -> String:
	_c.hit_done = true
	var r: String = _T.assert_false(_c.in_recovery(HIT + AttackChain.RECOVERY_FRAMES - 1, HIT), "one frame early")
	if r != "":
		return r
	return _T.assert_true(_c.in_recovery(HIT + AttackChain.RECOVERY_FRAMES, HIT), "on the frame")


func test_chain_needs_a_buffered_press() -> String:
	_c.hit_done = true
	var f := HIT + AttackChain.RECOVERY_FRAMES
	var r: String = _T.assert_false(_c.should_chain(f, HIT), "no press, no chain")
	if r != "":
		return r
	_c.buffered = true
	return _T.assert_true(_c.should_chain(f, HIT), "buffered press chains in recovery")


func test_buffered_press_waits_for_recovery() -> String:
	_c.buffered = true
	_c.hit_done = true
	return _T.assert_false(_c.should_chain(HIT, HIT), "on the hit frame itself: not yet")


func test_finisher_never_chains_early() -> String:
	for i in AttackChain.MAX_STEPS - 1:
		_c.advance()
	var r: String = _T.assert_true(_c.is_finisher(), "last step is the finisher")
	if r != "":
		return r
	_c.hit_done = true
	_c.buffered = true
	return _T.assert_false(_c.should_chain(HIT + 9, HIT), "finisher plays out")


func test_step_before_last_is_not_the_finisher() -> String:
	for i in AttackChain.MAX_STEPS - 2:
		_c.advance()
	return _T.assert_false(_c.is_finisher(), "step %d of %d" % [_c.step, AttackChain.MAX_STEPS])


func test_advance_starts_a_clean_swing() -> String:
	_c.hit_done = true
	_c.buffered = true
	_c.advance()
	var r: String = _T.assert_eq(_c.step, 1, "next step")
	if r != "":
		return r
	return _T.assert_false(_c.hit_done or _c.buffered, "hit and buffer cleared")


func test_reset_returns_to_step_zero_clean() -> String:
	_c.advance()
	_c.hit_done = true
	_c.buffered = true
	_c.reset()
	var r: String = _T.assert_eq(_c.step, 0, "step 0")
	if r != "":
		return r
	return _T.assert_false(_c.hit_done or _c.buffered, "hit and buffer cleared")


func test_tuning_stays_in_arcade_range() -> String:
	var r: String = _T.assert_true(AttackChain.ANIM_SPEED > 1.0 and AttackChain.ANIM_SPEED <= 2.0, "anim speed")
	if r != "":
		return r
	return _T.assert_true(AttackChain.MAX_STEPS >= 2 and AttackChain.MAX_STEPS <= 4, "string length")
