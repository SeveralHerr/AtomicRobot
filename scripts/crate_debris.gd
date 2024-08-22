extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await Config.player.get_tree().create_timer(1).timeout
	$Chunk1.freeze = true
	$Chunk2.freeze = true
	$Chunk3.freeze = true
	await Config.player.get_tree().create_timer(5).timeout
	
	queue_free()
	pass # Replace with function body.
