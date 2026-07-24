extends Node2D

const CAR_BLUE = preload("res://images/new/Car_Blue.png")
const CAR_RED = preload("res://images/new/Car_Red.png")

@onready var area_2d: Area2D = $Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D

## Road lane this car drives in. Assigned per-car by the spawning streetlight, so
## which lane is dangerous varies from car to car.
var lane: int = Lanes.FRONT_LANE
var start: bool = false
var car_damage = 1
## A car impact should knock harder than a regular hit (baselines: player 300, enemy 200).
var player_knockback_strength = 360
var enemy_knockback_strength = 240
var speed: int = 0
var current_speed
## Bodies already knocked back this pass — the car drives through without
## stopping, so each body should only be hit once until it leaves the area.
var hit_bodies: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var rand = randi_range(0, 1)
	if rand == 1:
		sprite_2d.texture = CAR_BLUE
	else:
		sprite_2d.texture = CAR_RED

	area_2d.body_entered.connect(_hit)
	area_2d.body_exited.connect(_on_body_exited)
	speed = randi_range(150,450)
	hide()

	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	if start:

		show()
		if speed == 0:
			randomize()
			speed = randi_range(150,450)
			print("new speed ", speed)
		current_speed = delta * speed
		position.x -= current_speed
	
func _hit(body: Node2D) -> void:
	if body in hit_bodies:
		return
	if body is Player:
		# A car only hits players standing in the lane it is driving down.
		if body.current_lane != lane:
			return
		hit_bodies.append(body)
		ScreenShake.apply_shake(2, 0.2)
		body.receive_hit(global_position, car_damage, player_knockback_strength)
	elif body is Enemy:
		if body.lane != lane:
			return
		hit_bodies.append(body)
		ScreenShake.apply_shake(2, 0.2)
		body.receive_hit(car_damage, enemy_knockback_strength)
	elif body is DroppedLeaf:
		body.do_gust(8, Vector2(global_position.x - 450, 0))

func _on_body_exited(body: Node2D) -> void:
	hit_bodies.erase(body)
