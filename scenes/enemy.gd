extends Node2D

@onready var ray_cast_2d_left: RayCast2D = $RayCast2D_Left
@onready var ray_cast_2d_right: RayCast2D = $RayCast2D_Right

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
var direction: int = -1
var speed = 50





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if direction == -1:
		animated_sprite_2d.flip_h = true
	elif direction == 1:
		animated_sprite_2d.flip_h = false

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x += direction * speed * delta

	if not ray_cast_2d_left.is_colliding():
		direction = 1
		animated_sprite_2d.flip_h = false
		ray_cast_2d_left.enabled = false
		await get_tree().create_timer(0.3).timeout
		ray_cast_2d_left.enabled = true
		
	elif not ray_cast_2d_right.is_colliding():
		direction = -1
		animated_sprite_2d.flip_h = true
		ray_cast_2d_right.enabled = false
		await get_tree().create_timer(0.3).timeout
		ray_cast_2d_right.enabled = true


	pass
	
