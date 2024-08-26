extends RigidBody2D
class_name Crate

const CRATE_DEBRIS = preload("res://scenes/crate_debris.tscn")
@onready var normal_crate_sprite: Sprite2D = $NormalCrateSprite
@onready var crack_1_sprite: Sprite2D = $Crack1Sprite
@onready var crack_2_sprite: Sprite2D = $Crack2Sprite
@onready var area_2d: Area2D = $Area2D

var objects: Node2D



var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

var hits: int = 0
var shaker: Shaker

func _ready() -> void:
	if Globals.is_node_destroyed(name):
		queue_free()
	
	shaker = Shaker.new(self)
	objects = get_tree().get_nodes_in_group("Debris")[0]

func _process(delta: float) -> void:
	shaker.process(delta)

		
func receive_hit() -> void:
	shaker.apply_shake(2)
	if hits == 0:
		crack_1_sprite.show()
	elif hits == 1:
		crack_2_sprite.show()
	elif hits == 2:
		_create_debris()		
		Globals.mark_node_destroyed(name)
		queue_free()
	
	hits += 1
		
		
func _create_debris() -> void:
	var instance = CRATE_DEBRIS.instantiate()

	objects.add_child(instance)
	instance.position = position
	

	
	
