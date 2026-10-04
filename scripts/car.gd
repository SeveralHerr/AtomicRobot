extends Node2D
class_name Car

const CAR_BLUE = preload("res://images/new/Car_Blue.png")
const CAR_RED = preload("res://images/new/Car_Red.png")
## Every live car joins this group, so a spawner can tell when the road is busy.
const GROUP := "cars"
const SPEED_MIN := 150
const SPEED_MAX := 450

## Times any car has struck a player this process (autoplay reports car hits).
static var player_hits := 0

@onready var area_2d: Area2D = $Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D

## Road lane this car drives in. Assigned per-car by the spawning streetlight, so
## which lane is dangerous varies from car to car.
var lane: int = Lanes.FRONT_LANE
var start: bool = false
## Player-side (raw hits). Enemies take DamageRules.CAR_ENEMY_DAMAGE instead.
var car_damage = 1
## A car impact should knock harder than a regular hit (baselines: player 300, enemy 200).
var player_knockback_strength = 360
var enemy_knockback_strength = 240
var speed: int = 0
var current_speed
## -1 drives left (the art's facing), +1 drives right (mirrored).
var direction: int = -1
## Bodies already knocked back this pass — the car drives through without
## stopping, so each body should only be hit once until it leaves the area.
var hit_bodies: Array = []
## Rolls colour and speed when set before add_child; the global stream otherwise.
var rng: RandomNumberGenerator

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(GROUP)
	sprite_2d.texture = CAR_BLUE if _roll(0, 1) == 1 else CAR_RED
	area_2d.body_entered.connect(_hit)
	speed = _roll(SPEED_MIN, SPEED_MAX)
	hide()


func _roll(lo: int, hi: int) -> int:
	return rng.randi_range(lo, hi) if rng else randi_range(lo, hi)


## Put the car on `lane` at `pos` and set it driving `dir` (-1 left, +1 right).
## `with_speed` 0 rolls a random speed on the first frame. Call after add_child.
## Draws mid-band in its lane, so bodies nearer the camera in that lane draw over it.
func launch(car_lane: int, pos: Vector2, dir: int = -1, with_speed: int = 0) -> void:
	lane = car_lane
	z_as_relative = false
	z_index = Lanes.z_for(car_lane) + Lanes.DEPTH_Z_BIAS
	global_position = pos
	direction = 1 if dir > 0 else -1
	sprite_2d.flip_h = direction > 0
	# The audio enabler's rect trails BEHIND the car (engine heard before it shows).
	var enabler := get_node_or_null("VisibleOnScreenEnabler2D") as Node2D
	if enabler:
		enabler.position.x = absf(enabler.position.x) * -direction
	speed = with_speed
	start = true


## Absolute world Y a car drives at on `lane`: the PLAYER's standing line, not the
## walkway floor line — car.tscn has no footprint shape of its own (its only
## CollisionShape2D is an Area2D hitbox), so its art is positioned against the
## player's origin. Using y_offset() as an absolute Y put cars ~21px off their lane.
static func road_y(player: Player, car_lane: int) -> float:
	if player == null:
		return 0.0
	if player.lane_floor_y == INF:
		return player.global_position.y + Lanes.y_offset(car_lane)
	return player.lane_stand_y(car_lane)


func _physics_process(delta: float) -> void:
	if start:

		show()
		if speed == 0:
			# No randomize(): Godot seeds at startup, and reseeding from the clock here
			# made seeded autoplay runs unrepeatable.
			speed = _roll(SPEED_MIN, SPEED_MAX)
		current_speed = delta * speed
		position.x += current_speed * direction

func _hit(body: Node2D) -> void:
	if body in hit_bodies:
		return
	if body is Player:
		# A car only hits players standing in the lane it is driving down.
		if body.current_lane != lane:
			return
		hit_bodies.append(body)
		player_hits += 1
		# The player's own hurt shake (6) stacks on top; strongest wins.
		ScreenShake.apply_shake(8, 0.35)
		body.receive_hit(global_position, car_damage, player_knockback_strength)
	elif body is Enemy:
		if body.lane != lane:
			return
		hit_bodies.append(body)
		ScreenShake.apply_shake(5, 0.25)
		body.receive_hit(DamageRules.CAR_ENEMY_DAMAGE, enemy_knockback_strength)
	elif body is DroppedLeaf:
		body.do_gust(8, Vector2(global_position.x + 450 * direction, 0))
