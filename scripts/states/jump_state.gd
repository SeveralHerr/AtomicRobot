extends State
class_name JumpState

const ACCELERATION = 500.0 # Adjust as needed for smoother acceleration
const JUMP_VELOCITY = -420.0 # Slightly lower jump height

func enter_state(player: Player) -> void:
	# Only allow jump if on floor or within coyote time
	if player.is_on_floor() or player.time_since_grounded <= player.coyote_time:
		player.velocity.y = JUMP_VELOCITY
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0:
				player.velocity.x += direction * 40
		player.default_sprite.play("Jump")
		player.jump_audio_player.play()
		player.jumping_streak_sprite.show()
		player.jumping_streak_sprite.play("default")
	else:
		# If not allowed, return to idle
		player.state_machine.change_state("IdleState")

func exit_state(player: Player) -> void:
	player.jumping_streak_sprite.hide()

func update(player: Player, delta: float) -> void:
	if player.is_on_floor() and player.velocity.y >= -100:
		if player.velocity.x <= 0:
			player.state_machine.change_state("IdleState")
		else:
			player.state_machine.change_state("WalkState")
	
	if player.velocity.y > 0 and player.jumping_streak_sprite.visible:
		player.jumping_streak_sprite.hide()
	
func physics_update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction * player.SPEED, ACCELERATION * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
	# Gravity and fall multiplier are now handled in Player.gd
