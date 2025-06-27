extends Node2D

const CAR_BLUE = preload("res://images/new/Car_Blue.png")
const CAR_RED = preload("res://images/new/Car_Red.png")

@onready var area_2d: Area2D = $Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D

var shaker: Shaker
var start: bool = false
var car_damage = 1
var speed: int = 0
var current_speed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var rand = randi_range(0, 1)
	if rand == 1:
		sprite_2d.texture = CAR_BLUE
	else:
		sprite_2d.texture = CAR_RED
		
	area_2d.body_entered.connect(_hit)
	shaker = Shaker.new(self)
	speed = randi_range(150,450)
	hide()

	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	if start:

		show()
		if speed == 0:
			_enable_player_layer(true)
			randomize()
			speed = randi_range(150,450)
			print("new speed ", speed)
		current_speed = delta * speed
		position.x -= current_speed
	
func _process(delta: float) -> void:

		
	shaker.process(delta)

func _hit(body: Node2D) -> void:
	if body is Player:
		
		shaker.apply_shake(2)
		_enable_player_layer(false)
		print("Car hit")
		body.receive_hit(global_position, car_damage)

		speed = 0
		#await get_tree().create_timer(3).timeout
		#start=false
	if body is DroppedLeaf:
		body.do_gust(8, Vector2(global_position.x - 450, 0))
		
func _enable_player_layer(can_hit: bool) -> void:
	area_2d.set_collision_mask_value(1, can_hit)
	area_2d.set_collision_mask_value(5, can_hit)
