extends RefCounted

# Air attack + air control. Player feedback: "Hitting attack in midair plays the
# sound, but not the animation. It also briefly stops your fall and plays the landing
# FX", and "very little control over movement in mid-air". Real Player scene on a
# real floor (player_combat_rig.gd), real physics frames.

var _T

const Rig := preload("res://test/unit/player_combat_rig.gd")
const FRAME := 1.0 / 60.0

var _r: Rig


func setup() -> void:
	_r = Rig.new()


func teardown() -> void:
	_r.free_all()


# --- characterization: grounded behaviour that must not change -----------------

func test_landing_from_a_fall_plays_the_landing_fx() -> String:
	await _r.spawn("Ryan", 60.0)
	_r.p.jump_fx.emitting = false
	var t := await _r.until(func(): return _r.p.is_grounded(), 120)
	await _r.step(2)
	var r: String = _T.assert_gte(t, 0, "player lands")
	if r != "":
		return r
	return _T.assert_true(_r.p.jump_fx.emitting, "landing puffs the jump fx")


func test_jump_from_a_grounded_swing_still_jumps() -> String:
	await _r.spawn("Ryan")
	_r.tap("Attack")
	await _r.step(2)
	_r.event("ui_accept", true)
	await _r.step(1)
	_r.event("ui_accept", false)
	return _T.assert_eq(_r.state_name(), "JumpState", "jump cancels a grounded swing")


# --- the bug: attack in the air -------------------------------------------------

func test_air_attack_plays_the_attack_animation() -> String:
	await _r.spawn("Ryan", 120.0)
	_r.tap("Attack")
	await _r.step(6)
	var r: String = _T.assert_eq(_r.state_name(), "AttackState", "still swinging 6 frames later")
	if r != "":
		return r
	return _T.assert_eq(String(_r.p.default_sprite.animation), "Attack", "Attack anim on screen")


func test_air_attack_keeps_falling() -> String:
	await _r.spawn("Ryan", 160.0)
	await _r.step(4)
	var vy0 := _r.p.velocity.y
	var y0 := _r.p.global_position.y
	_r.tap("Attack")
	await _r.step(1)
	var r: String = _T.assert_gte(_r.p.velocity.y, vy0, "no hover: the press keeps the fall speed")
	if r != "":
		return r
	await _r.step(5)
	r = _T.assert_gt(_r.p.velocity.y, vy0, "gravity keeps pulling during the swing")
	if r != "":
		return r
	return _T.assert_gt(_r.p.global_position.y, y0 + 5.0, "still moving down")


func test_air_attack_keeps_horizontal_momentum() -> String:
	await _r.spawn("Ryan", 160.0)
	_r.p.velocity.x = 150.0
	_r.tap("Attack")
	await _r.step(2)
	return _T.assert_gt(_r.p.velocity.x, 100.0, "the swing does not zero air momentum")


func test_air_attack_does_not_puff_landing_fx_mid_air() -> String:
	await _r.spawn("Ryan", 160.0)
	_r.p.jump_fx.emitting = false
	_r.tap("Attack")
	await _r.step(3)
	return _T.assert_false(_r.p.jump_fx.emitting, "no landing fx while still in the air")


func test_air_attack_that_lands_puffs_landing_fx_once_grounded() -> String:
	await _r.spawn("Ryan", 30.0)
	_r.p.jump_fx.emitting = false
	_r.tap("Attack")
	var t := await _r.until(func(): return _r.p.is_grounded(), 60)
	await _r.step(1)
	var r: String = _T.assert_gte(t, 0, "lands mid swing")
	if r != "":
		return r
	return _T.assert_true(_r.p.jump_fx.emitting, "touchdown during a swing still puffs")


func test_air_attack_from_a_jump_rise_swings_too() -> String:
	await _r.spawn("Ryan")
	_r.event("ui_accept", true)
	await _r.step(3)
	_r.tap("Attack")
	await _r.step(3)
	_r.event("ui_accept", false)
	var r: String = _T.assert_eq(_r.state_name(), "AttackState", "attack works on the way up")
	if r != "":
		return r
	return _T.assert_gt(_r.ground_y - 10.0, _r.p.global_position.y, "still airborne")


func test_air_attack_ends_back_in_fall_when_still_airborne() -> String:
	await _r.spawn("Ryan", 400.0)
	_r.tap("Attack")
	var t := await _r.until(func(): return _r.state_name() != "AttackState", 90)
	var r: String = _T.assert_gte(t, 0, "swing ends")
	if r != "":
		return r
	return _T.assert_eq(_r.state_name(), "FallState", "airborne finish hands back to Fall")


func test_air_melee_hits_an_enemy_in_lane() -> String:
	await _r.spawn("Ryan", 30.0)
	var e := _r.maid(40.0)
	_r.tap("Attack")
	await _r.until(func(): return e.health < Rig.HP, 60)
	return _T.assert_gt(Rig.HP, e.health, "a falling swing connects")


func test_air_melee_misses_an_enemy_on_another_lane() -> String:
	await _r.spawn("Ryan", 30.0)
	var e := _r.maid(40.0)
	e.lane = _r.p.current_lane + 1
	_r.tap("Attack")
	await _r.step(40)
	return _T.assert_eq(e.health, Rig.HP, "other lane is untouched")


# --- air control ---------------------------------------------------------------

## Hand-integrated (no physics space): air control is what the Jump/Fall states do
## to velocity.x while a direction is held.
func _reverse_frames(state_name: String) -> int:
	await _r.spawn("Ryan", 400.0)
	_r.p.set_physics_process(false)
	_r.p.state_machine.change_state(state_name)
	var air := _r.p.get_air_speed()
	_r.p.velocity.x = air
	Input.action_press("ui_left")
	for i in 120:
		_r.p.state_machine.physics_update(FRAME)
		if _r.p.velocity.x <= -0.8 * air:
			return i + 1
	return 999


func test_fall_air_control_reverses_within_a_quarter_second() -> String:
	var n := await _reverse_frames("FallState")
	return _T.assert_true(n <= 15, "full right to 80%% left while falling took %d frames (max 15)" % n)


func test_jump_air_control_reverses_within_a_quarter_second() -> String:
	var n := await _reverse_frames("JumpState")
	return _T.assert_true(n <= 15, "full right to 80%% left while rising took %d frames (max 15)" % n)
