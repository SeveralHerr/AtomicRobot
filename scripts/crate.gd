extends Node2D
class_name Crate

@onready var normal_crate_sprite: Sprite2D = $NormalCrateSprite
@onready var crack_1_sprite: Sprite2D = $Crack1Sprite
@onready var crack_2_sprite: Sprite2D = $Crack2Sprite
@onready var area_2d: Area2D = $Area2D

var hits: int = 0
var shaker: Shaker

func _ready() -> void:
	shaker = Shaker.new(self)

func _process(delta: float) -> void:
	shaker.process(delta)
		
		
func receive_hit() -> void:
	shaker.apply_shake(2)
	if hits == 0:
		crack_1_sprite.show()
	elif hits == 1:
		crack_2_sprite.show()
	elif hits == 2:
		queue_free()
	
	hits += 1
		
