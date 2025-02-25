extends Area2D


const HIT_FX = preload("res://scenes/hit_fx.tscn")

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.receive_hit(global_position, 1)
		var instance = HIT_FX.instantiate()
		body.get_tree().root.add_child(instance)
		instance.global_position = global_position
		instance.start()
		
