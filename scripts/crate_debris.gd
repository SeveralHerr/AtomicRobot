extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#position = Vector2( randf_range(-15, 1), randf_range(-51, 1))
	await Config.player.get_tree().create_timer(10).timeout
	
	queue_free()
	pass # Replace with function body.
