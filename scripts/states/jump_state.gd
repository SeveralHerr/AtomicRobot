extends State
class_name JumpState

const ACCELERATION = 500.0  # Adjust as needed for smoother acceleration

func enter_state(player: Player) -> void:
	player.velocity.y = -350.0
	player.default_sprite.play("Jump")
	player.jump_audio_player.play()
	player.jumping_streak_sprite.show()
	player.jumping_streak_sprite.play("default")
	
func exit_state(player: Player) -> void:
	player.jumping_streak_sprite.hide()

func update(player: Player, delta: float) -> void:
	if player.is_on_floor() and player.velocity.y >= -100:
		player.state_machine.change_state("IdleState")
		
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction * player.SPEED, ACCELERATION * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
		
	if player.velocity.y > 0 and player.jumping_streak_sprite.visible:
		player.jumping_streak_sprite.hide()
