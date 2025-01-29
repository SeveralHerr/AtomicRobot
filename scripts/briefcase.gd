extends Sprite2D



# Speed of the thrown sprite
var throw_speed = 300.0
var target_position = Vector2.ZERO
var direction = Vector2.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target_position = Globals.player.position
	# Calculate the direction to the target
	direction = (target_position - position).normalized()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Move the sprite in the direction of the player
	position += direction * throw_speed * delta
		
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		var player: Player = body
		player.receive_hit(position, 1)
		queue_free()
		
	pass # Replace with function body.
