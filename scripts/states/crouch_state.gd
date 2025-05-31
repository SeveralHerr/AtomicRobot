extends State
class_name CrouchState

var shape: RectangleShape2D
var normal_pos: Vector2 = Vector2(0, -6)
var crouch_pos: Vector2 = Vector2(0, 5.5)

func enter_state(player: Player) -> void:
	player.velocity.x = 0
	player.default_sprite.play("Crouch")
	#shape = player.collision_shape_2d_body.shape
	#original_shape_size = shape.size
	#original_position = player.collision_shape_2d_body.position
	#shape.size = Vector2(14, 16)
	player.collision_shape_2d_body.position = crouch_pos
	player.collision_shape_2d_body.shape = player.PLAYER_CROUCH_COLLISION_SHAPE


func exit_state(player: Player) -> void:
	#shape.size = original_shape_size
	player.collision_shape_2d_body.position = normal_pos
	player.collision_shape_2d_body.shape = player.PLAYER_NORMAL_COLLISION_SHAPE

func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_released("ui_down"):
		player.state_machine.change_state("IdleState")
