extends RefCounted

# Attack speed, recovery cancel and combo chaining. Player feedback: "Attacks are very
# slow, and the player is unable to move while waiting for their animation", "start a
# new attack without waiting for full follow-through, or combo into a second attack",
# and "move more quickly after an attack so dodging feels responsive".
# Real Player scene on a real floor (player_combat_rig.gd), real physics frames.
# The chain is read duck-typed (`chain` on AttackState) so this file still loads on a
# build without it — that is how the bug tests were shown to fail first.

var _T

const Rig := preload("res://test/unit/player_combat_rig.gd")
const GAP := 40.0

var _r: Rig


class LanePlayer:
	extends Player
	var lanes_on := false

	func lanes_active() -> bool:
		return lanes_on

	func is_on_street() -> bool:
		return true


func setup() -> void:
	_r = Rig.new()


func teardown() -> void:
	_r.free_all()


func _attack() -> State:
	return _r.p.state_machine.states["AttackState"]


func _hits(e: Enemy) -> int:
	return int((Rig.HP - e.health) / _r.p.get_damage())


func _hit_frame() -> int:
	return Globals.get_current_character_attack_frame()


# --- characterization ----------------------------------------------------------

func test_single_tap_hits_once_and_returns_to_idle() -> String:
	await _r.spawn("Ryan")
	var e := _r.maid(GAP)
	_r.tap("Attack")
	var t := await _r.until(func(): return _r.state_name() != "AttackState" and _r.trail.size() > 3, 120)
	var r: String = _T.assert_gte(t, 0, "swing ends")
	if r != "":
		return r
	r = _T.assert_eq(_hits(e), 1, "one tap, one hit")
	if r != "":
		return r
	return _T.assert_eq(_r.state_name(), "IdleState", "back to idle")


func test_no_input_plays_the_follow_through() -> String:
	await _r.spawn("Ryan")
	var e := _r.maid(GAP)
	_r.tap("Attack")
	await _r.until(func(): return _hits(e) == 1, 60)
	await _r.step(4)
	return _T.assert_eq(_r.state_name(), "AttackState", "without input the swing finishes")


# --- faster swing ----------------------------------------------------------------

func test_attack_animation_plays_faster_than_authored() -> String:
	await _r.spawn("Ryan")
	_r.tap("Attack")
	await _r.step(2)
	var r: String = _T.assert_eq(String(_r.p.default_sprite.animation), "Attack", "swinging")
	if r != "":
		return r
	return _T.assert_gte(_r.p.default_sprite.get_playing_speed(), 1.3, "attack anim speed")


# --- chaining ------------------------------------------------------------------

func test_tap_during_swing_chains_a_second_hit_without_idling() -> String:
	await _r.spawn("Ryan")
	var e := _r.maid(GAP)
	_r.tap("Attack")
	await _r.step(2)
	_r.tap("Attack")  # before the hit frame: buffered
	var t := await _r.until(func(): return _r.state_name() != "AttackState", 150)
	var r: String = _T.assert_gte(t, 0, "string ends")
	if r != "":
		return r
	r = _T.assert_eq(_hits(e), 2, "two taps, two hits")
	if r != "":
		return r
	var first_exit := _r.trail.find("IdleState")
	return _T.assert_eq(_r.trail.slice(0, first_exit).count("AttackState"), first_exit,
			"no idle between the two swings")


func test_tap_after_the_hit_also_chains() -> String:
	await _r.spawn("Ryan")
	var e := _r.maid(GAP)
	_r.tap("Attack")
	await _r.until(func(): return _hits(e) == 1, 60)
	_r.tap("Attack")
	await _r.until(func(): return _hits(e) == 2, 60)
	return _T.assert_eq(_hits(e), 2, "a tap in the follow-through chains")


## Mash: steps go 0,1,2 then the finisher (2) plays to its last frame before a new
## string starts at 0. Records (step, sprite frame) every physics frame.
func test_finisher_plays_out_before_a_new_string() -> String:
	await _r.spawn("Ryan")
	_r.maid(GAP)
	var log: Array = []
	for i in 150:
		if i % 3 == 0:
			_r.tap("Attack")
		await _r.step(1)
		var ch = _attack().get("chain")
		if ch == null:
			return "AttackState has no chain"
		log.append([int(ch.step), _r.p.default_sprite.frame])
	var steps: Array = []
	for s in log:
		if steps.is_empty() or steps[-1] != s[0]:
			steps.append(s[0])
	var r: String = _T.assert_eq(steps.slice(0, 4), [0, 1, 2, 0], "step order while mashing")
	if r != "":
		return r
	var last := _r.p.default_sprite.sprite_frames.get_frame_count("Attack") - 1
	for i in range(1, log.size()):
		if log[i - 1][0] == 2 and log[i][0] == 0:
			return _T.assert_eq(log[i - 1][1], last, "finisher reached its last frame first")
	return "never wrapped from the finisher"


func test_ranged_tap_tap_fires_two_shots_in_one_string() -> String:
	await _r.spawn("Cass")
	# Counted as they spawn: a flip-flop can free itself before the string ends.
	var shots := [0]
	_r.world.child_entered_tree.connect(func(n: Node) -> void:
		if "dir" in n and "player" in n:
			shots[0] += 1)
	_r.tap("Attack")
	await _r.step(2)
	_r.tap("Attack")
	await _r.until(func(): return _r.state_name() != "AttackState", 150)
	return _T.assert_eq(shots[0], 2, "Cass refires off the buffered tap")


# --- recovery cancel -------------------------------------------------------------

func test_moving_after_the_hit_cancels_the_follow_through() -> String:
	await _r.spawn("Ryan")
	var e := _r.maid(GAP)
	_r.tap("Attack")
	Input.action_press("ui_right")  # held from the start: must not skip the hit
	var t := await _r.until(func(): return _hits(e) == 1, 60)
	var r: String = _T.assert_gte(t, 0, "the hit still lands with right held")
	if r != "":
		return r
	var c := await _r.until(func(): return _r.state_name() == "WalkState", 60)
	r = _T.assert_gte(c, 0, "walks out of the swing")
	if r != "":
		return r
	# Recovery is RECOVERY_FRAMES anim frames (~6 physics frames); the old full
	# follow-through took ~20.
	return _T.assert_true(c <= 10, "cancelled %d frames after the hit (max 10)" % c)


func test_moving_before_the_hit_does_not_cancel() -> String:
	await _r.spawn("Sara")  # late hit frame: plenty of pre-hit frames to test
	var e := _r.maid(GAP)
	_r.tap("Attack")
	Input.action_press("ui_left")  # away from the maid
	await _r.until(func(): return _r.state_name() != "AttackState", 60)
	return _T.assert_eq(_hits(e), 1, "the swing is committed until its hit frame")


func test_lane_step_cancels_the_follow_through_only_after_the_hit() -> String:
	Globals.selected_character = "Ryan"
	var node := Rig.PLAYER_SCENE.instantiate()
	node.set_script(LanePlayer)
	# Reuse the rig floor/settle by spawning, then swapping in the lane-aware player.
	await _r.spawn("Ryan")
	var pos := _r.p.global_position
	_r.p.free()
	_r.p = _r.add(node)
	_r.p.global_position = pos
	await _r.step(20)
	var e := _r.maid(GAP)
	var lp := _r.p as LanePlayer
	_r.tap("Attack")
	await _r.step(1)
	lp.lanes_on = true
	var early := lp.try_change_lane(1)
	lp.lanes_on = false
	var r: String = _T.assert_false(early, "no lane step before the hit")
	if r != "":
		return r
	await _r.until(func(): return _hits(e) == 1, 60)
	await _r.until(func(): return _r.p.default_sprite.frame >= _hit_frame() + 2, 30)
	lp.lanes_on = true
	var late := lp.try_change_lane(1)
	lp.lanes_on = false
	r = _T.assert_true(late, "lane step allowed in the follow-through")
	if r != "":
		return r
	return _T.assert_false(_r.state_name() == "AttackState", "the step left the swing")


# --- audio variation -----------------------------------------------------------

func test_chained_swings_rise_in_pitch() -> String:
	await _r.spawn("Ryan")
	var e := _r.maid(GAP)
	var pitches: Array[float] = []
	for k in 3:
		_r.tap("Attack")
		await _r.until(func(): return _hits(e) == k + 1, 60)
		pitches.append(_r.p.attack_audio.pitch_scale)
	var r: String = _T.assert_gt(pitches[1], pitches[0], "step 2 above step 1: %s" % [pitches])
	if r != "":
		return r
	return _T.assert_gt(pitches[2], pitches[1], "finisher highest: %s" % [pitches])
