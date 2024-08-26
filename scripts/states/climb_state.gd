extends State
class_name ClimbState

const ACCELERATION = 5000.0

func enter_state(player: Player) -> void:
	player.default_sprite.play("Climb")
	player.camera_2d.position_smoothing_enabled = false

func exit_state(player: Player) -> void:
	player.camera_2d.position_smoothing_enabled = true
	player.camera_2d.position_smoothing_speed = 5
	player.default_sprite.play("Walk")

func update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_up", "ui_down")
	if direction:
		player.velocity.y = move_toward(player.velocity.y, direction * player.SPEED / 2, ACCELERATION * delta)
		if not player.default_sprite.is_playing():
			player.default_sprite.play()
		
		if player.is_on_floor() and direction == 1:
			player.state_machine.change_state("IdleState")
			
	else:
		player.velocity.y = 0
		player.velocity.x = 0
		player.default_sprite.pause()
		

		
