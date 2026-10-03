extends RefCounted

# Jump reach: the real Player scene integrates a held-right jump arc frame by frame
# (Player.apply_gravity + the Jump/Fall states' air control) with a flat floor at
# y = 0. No physics space needed — position is advanced by hand.
#
# Pre-tune baseline (air target == ground speed 170): reach 116.2px, apex 80.7px.

var _T

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const FRAME := 1.0 / 60.0
const BASELINE_REACH := 116.2
const BASELINE_APEX := 80.7


class ArcPlayer:
	extends Player

	func is_grounded() -> bool:
		return position.y > 0.0


var _p: ArcPlayer


func setup() -> void:
	var node := PLAYER_SCENE.instantiate()
	node.set_script(ArcPlayer)
	_p = node
	(Engine.get_main_loop() as SceneTree).root.add_child(_p)
	_p.set_process(false)
	_p.set_physics_process(false)


func teardown() -> void:
	Input.action_release("ui_right")
	_p.free()
	_p = null


## Running start, right held, full (unreleased) jump. Returns [reach, apex].
func _arc() -> Array:
	_p.position = Vector2.ZERO
	_p.velocity = Vector2(_p.get_speed(), 0)
	Input.action_press("ui_right")
	_p.state_machine.change_state("JumpState")
	var apex := 0.0
	for i in 600:
		_p.apply_gravity(FRAME)
		_p.state_machine.physics_update(FRAME)
		_p.position += _p.velocity * FRAME
		apex = maxf(apex, -_p.position.y)
		if _p.is_grounded():
			break
	return [_p.position.x, apex]


func test_running_jump_reaches_15_to_30_percent_further() -> String:
	var reach: float = _arc()[0]
	var r: String = _T.assert_true(reach >= BASELINE_REACH * 1.15,
		"reach %.1f >= 115%% of baseline %.1f" % [reach, BASELINE_REACH])
	if r != "":
		return r
	return _T.assert_true(reach <= BASELINE_REACH * 1.30,
		"reach %.1f <= 130%% of baseline (no absurd jumps)" % reach)


## Reach comes from air speed, not height: walls/ledges sized for the old jump
## must still block.
func test_jump_height_is_unchanged() -> String:
	var apex: float = _arc()[1]
	return _T.assert_true(absf(apex - BASELINE_APEX) <= 3.0,
		"apex %.1f ~= baseline %.1f" % [apex, BASELINE_APEX])


func test_jump_landing_hands_back_to_ground_speed() -> String:
	_arc()
	_p.state_machine.change_state("WalkState")
	for i in 30:
		_p.state_machine.physics_update(FRAME)
	return _T.assert_true(absf(_p.velocity.x - _p.get_speed()) < 0.5,
		"walk settles to ground speed after landing, vx=%.1f" % _p.velocity.x)
