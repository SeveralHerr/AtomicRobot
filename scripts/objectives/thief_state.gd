extends EnemyState
class_name ThiefState

## SnatchChase's thief: a maid who darts in, grabs the keys and runs for it.
##
## APPROACH sprints along the walkway to the keys; FLEE runs `flee_dir` slower than the
## player walks, so a chase can always be won, and dodges between the road lanes:
## catching her means matching her lane as well as her speed, through whatever traffic
## is on the road. When the player closes in on her lane she jukes to another one (at
## most once per JUKE_COOLDOWN); far off she drifts lanes now and then. Every juke
## winds her (TIRE off her speed, down to MIN_SPEED), so a dogged chase pays off — a
## fixed hop timer let her dodge a swing forever. She never attacks while she is the
## thief; SnatchChase hands her to ChasePlayerState once she has been caught.

enum Step { APPROACH, FLEE }

const APPROACH_SPEED := 300.0
## Below the player's 170 px/s, so steady pursuit always closes (and a running jump,
## x1.2 air speed, closes faster). Each juke takes TIRE off, down to MIN_SPEED.
const FLEE_SPEED := 120.0
const MIN_SPEED := 90.0
const TIRE := 10.0
## A juke: the player on her lane within JUKE_RANGE px; then none for JUKE_COOLDOWN s.
const JUKE_RANGE := 110.0
const JUKE_COOLDOWN := 0.9
## Seconds between idle lane drifts while nobody is close; a hop's own length.
const DRIFT_MIN := 1.4
const DRIFT_MAX := 2.4
const WEAVE_STEP_S := 0.22
## The getaway: right after the grab she sprints this fast for GETAWAY_S, so there is
## a gap to close (~300 px at the grab: ~6 s of steady walking to close, inside the
## 12 s clock; 1.0 s at 200 left ~11 s and a bot that never caught her). Without it the player was standing next to her as she scooped the
## keys and the "chase" was one swing long.
const GETAWAY_SPEED := 190.0
const GETAWAY_S := 0.6
## A warm gold throb on her sprite: the street has other maids in it, and in a scrap
## the thief read as just one more of them (the keys over her head are small).
const GLINT := Color(1.35, 1.15, 0.7)
const GLINT_HZ := 1.6
## Close enough to the keys to scoop them up (world px).
const GRAB_REACH := 10.0

var step: Step = Step.APPROACH
var grab_x: float = 0.0
var flee_dir: int = -1
var rng := RandomNumberGenerator.new()
## Called once, the frame she scoops the keys up.
var on_grab: Callable
var jukes: int = 0
var _drift: float = 0.0
var _juke_cd: float = 0.0
var _sprint: float = 0.0
var _t: float = 0.0


## Flee speed after `juke_count` jukes.
static func flee_speed(juke_count: int) -> float:
	return maxf(MIN_SPEED, FLEE_SPEED - juke_count * TIRE)


## Is the player close behind her on her own lane (time to juke)?
static func threatened(dx: float, same_lane: bool) -> bool:
	return same_lane and absf(dx) <= JUKE_RANGE


## The next lane to hop to: one of the ROAD lanes other than `current` — the walkway
## has props on it, and a hop onto it can be refused (Lanes.walkway_blocked).
static func next_weave_lane(current: int, roll: int) -> int:
	var options: Array[int] = []
	for l in range(Lanes.GROUND_LANE + 1, Lanes.FRONT_LANE + 1):
		if l != current:
			options.append(l)
	return options[absi(roll) % options.size()]


func enter_state() -> void:
	enemy.animated_sprite_2d.play("walk", 1.8)


func exit_state() -> void:
	enemy.animated_sprite_2d.self_modulate = Color.WHITE


func update(delta: float) -> void:
	_t += delta
	var k := 0.5 + 0.5 * sin(_t * TAU * GLINT_HZ)
	enemy.animated_sprite_2d.self_modulate = Color.WHITE.lerp(GLINT, k * 0.6)
	# Don't fight a knockback (a car clipped her): let it decay first.
	if absf(enemy.knockback_velocity.x) >= 10.0:
		return
	if step == Step.APPROACH:
		_approach()
	else:
		_flee(delta)


func _approach() -> void:
	var dx := grab_x - enemy.global_position.x
	if absf(dx) <= GRAB_REACH:
		step = Step.FLEE
		_sprint = GETAWAY_S
		_drift = rng.randf_range(0.2, 0.4)
		enemy.velocity.x = 0.0
		if on_grab.is_valid():
			on_grab.call()
		return
	enemy.velocity.x = signf(dx) * minf(APPROACH_SPEED, absf(dx) * 60.0)
	enemy.face_towards(grab_x)


func _flee(delta: float) -> void:
	_sprint -= delta
	enemy.velocity.x = flee_dir * (GETAWAY_SPEED if _sprint > 0.0 else flee_speed(jukes))
	enemy.face_towards(enemy.global_position.x + flee_dir * 100.0)
	_drift -= delta
	_juke_cd -= delta
	if enemy.is_changing_lane or enemy.lane_floor_y == INF:
		return
	var p := enemy.player
	var dx := enemy.global_position.x - p.global_position.x if p != null else INF
	if _juke_cd <= 0.0 and threatened(dx, p != null and p.current_lane == enemy.lane):
		jukes += 1
		_juke_cd = JUKE_COOLDOWN
		_hop()
	elif _drift <= 0.0:
		_hop()


func _hop() -> void:
	enemy._start_lane_change(next_weave_lane(enemy.lane, rng.randi()), WEAVE_STEP_S)
	_drift = rng.randf_range(DRIFT_MIN, DRIFT_MAX)
