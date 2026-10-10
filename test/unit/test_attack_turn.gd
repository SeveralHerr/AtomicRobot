extends RefCounted

# Player feedback: "On the joystick, it's a bit tricky to turn around the player. It may
# be because they're spamming attack." A buffered press chained the next swing on the
# same frame the follow-through became cancellable, so a held stick never got its turn:
# mashing Attack locked the facing for the whole string. Each new swing (chained, or a
# fresh string after the finisher) now faces the held direction.
# Real Player scene on a real floor (player_combat_rig.gd), real physics frames.

var _T

const Rig := preload("res://test/unit/player_combat_rig.gd")
const GAP := 40.0

var _r: Rig


func setup() -> void:
	_r = Rig.new()


func teardown() -> void:
	_r.free_all()


## Taps Attack every other frame for `frames` frames; returns the frame the player
## first faced `dir`, or -1.
func _mash_until_facing(dir: int, frames: int) -> int:
	for i in frames:
		if i % 2 == 0:
			_r.tap("Attack")
		await _r.step(1)
		if _r.p.last_dir == dir:
			return i
	return -1


## Swinging right, the player pulls left and keeps mashing: they turn on the next
## swing of the string, not only once the whole string has played out.
func test_mashing_attack_turns_on_the_next_swing() -> String:
	await _r.spawn("Ryan")
	_r.tap("Attack")
	await _r.until(func(): return _r.p.state_machine.states["AttackState"].chain.hit_done, 60)
	Input.action_press("ui_left")
	var t := await _mash_until_facing(-1, 120)
	var r: String = _T.assert_gte(t, 0, "player turned left while mashing")
	if r != "":
		return r
	r = _T.assert_eq(_r.state_name(), "AttackState", "turned without dropping the string")
	if r != "":
		return r
	r = _T.assert_true(_r.p.velocity.x < 0.0, "the turned swing lunges the new way (vx %.1f)" % _r.p.velocity.x)
	if r != "":
		return r
	# One swing's follow-through, not the whole three-swing string.
	return _T.assert_true(t <= 12, "turned on the next swing (frame %d)" % t)


## The turned swing lands on the maid now in front, never on the side just left.
func test_turned_swing_hits_the_maid_behind() -> String:
	await _r.spawn("Ryan")
	var behind := _r.maid(-GAP)
	_r.tap("Attack")
	Input.action_press("ui_left")
	for i in 40:
		if i % 2 == 0:
			_r.tap("Attack")
		await _r.step(1)
	return _T.assert_true(behind.health < Rig.HP, "maid behind is hit after turning")


## No stick: the string keeps its facing (a chained swing never flips on its own).
func test_mashing_without_input_keeps_facing() -> String:
	await _r.spawn("Ryan")
	var dir: int = _r.p.last_dir
	for i in 60:
		if i % 2 == 0:
			_r.tap("Attack")
		await _r.step(1)
	return _T.assert_eq(_r.p.last_dir, dir, "facing unchanged")
