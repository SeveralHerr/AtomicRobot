extends AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func start() -> void:
	animation_finished.connect(_end)
	play("default")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _end() -> void:
	queue_free()
