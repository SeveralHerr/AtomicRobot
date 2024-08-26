extends State
class_name CrouchState

var shape: RectangleShape2D
var original_shape_size: Vector2
var original_position: Vector2

func enter_state(player: Player) -> void:
	player.velocity.x = 0
	player.default_sprite.play("Crouch")
	shape = player.collision_shape_2d_body.shape
	original_shape_size = shape.size
	original_position = player.collision_shape_2d_body.position
	shape.size = Vector2(14, 16)
	player.collision_shape_2d_body.position = Vector2(0,8)

func exit_state(player: Player) -> void:
	shape.size = original_shape_size
	player.collision_shape_2d_body.position = original_position

func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_released("ui_down"):
		player.state_machine.change_state("IdleState")
