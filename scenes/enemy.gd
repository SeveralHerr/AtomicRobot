extends Node2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
var direction: int = -1
var speed = 50


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.body_entered.connect(_on_enter)
	if direction == -1:
		animated_sprite_2d.flip_h = true
	elif direction == 1:
		animated_sprite_2d.flip_h = false

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x += direction * speed * delta

	pass
	
func _on_enter(body: Node2D) -> void:
	if body is Player: 
		direction *= -1
		
		if direction == -1:
			animated_sprite_2d.flip_h = true
		elif direction == 1:
			animated_sprite_2d.flip_h = false
