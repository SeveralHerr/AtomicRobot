extends Sprite2D

var rotation_speed: float = 30.0 



func _process(delta: float) -> void:
	if visible:
		rotation_degrees += rotation_speed * delta
	
