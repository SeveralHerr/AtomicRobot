extends State
class_name JumpState

const ACCELERATION = 500.0 # Adjust as needed for smoother acceleration
const JUMP_VELOCITY = -380.0 # Slightly lower jump height
const RUN_JUMP_X_BOOST = 60.0 # Tweak this value for how much extra x velocity to add
const WALK_THRESHOLD = 10.0 # Minimum x velocity to count as running

func enter_state(player: Player) -> void:
	# Only allow jump if on floor or within coyote time
	if player.is_on_floor() or player.time_since_grounded <= player.coyote_time:
		player.velocity.y = JUMP_VELOCITY
		# Add x boost if player was moving horizontally (run-and-jump)
		var direction := Input.get_axis("ui_left", "ui_right")
		var can_boost := true
		if player.is_on_wall():
			# If pressing into the wall, don't boost
			if (direction < 0 and player.get_wall_normal().x > 0) or (direction > 0 and player.get_wall_normal().x < 0):
				can_boost = false

		if can_boost and (abs(player.velocity.x) > WALK_THRESHOLD or direction != 0):
			var boost_dir = direction if direction != 0 else sign(player.velocity.x)
			if boost_dir == 0:
				boost_dir = 1 # Default to right if completely stopped (optional)
				
			player.velocity.x += boost_dir * RUN_JUMP_X_BOOST
			if boost_dir == -1: 
				player.velocity.y += boost_dir * RUN_JUMP_X_BOOST 				
			else:
				player.velocity.y -= boost_dir * RUN_JUMP_X_BOOST 

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
