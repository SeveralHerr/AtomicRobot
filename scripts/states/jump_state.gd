extends State
class_name JumpState


const JUMP_VELOCITY = -450.0 # Slightly lower jump height
const RUN_JUMP_X_BOOST = 60.0 # Tweak this value for how much extra x velocity to add
const WALK_THRESHOLD = 10.0 # Minimum x velocity to count as running

func enter_state(player: Player) -> void:
	player.jump_start_position = Vector2(player.global_position.x, player.global_position.y + player.jump_fx_offset)
	# Only allow jump if on floor or within coyote time

	player.velocity.y = JUMP_VELOCITY
	player.coyote_timer = 0
		
		# running jump boost
		#if player.state_machine.previous_state is RunState:
			#player.velocity.y -= RUN_JUMP_X_BOOST


		## Add x boost if player was moving horizontally (run-and-jump)
		#var direction := Input.get_axis("ui_left", "ui_right")
		#var can_boost := true
		#if player.is_on_wall():
			## If pressing into the wall, don't boost
			#if (direction < 0 and player.get_wall_normal().x > 0) or (direction > 0 and player.get_wall_normal().x < 0):
				#can_boost = false
#
		#if player.state_machine.
		## Only apply boost if running for at least 0.5s
		#if can_boost and (abs(player.velocity.x) > WALK_THRESHOLD or direction != 0) and player.running_time >= player.run_boost_runtime:
			#var boost_dir = direction if direction != 0 else sign(player.velocity.x)
			#if boost_dir == 0:
				#boost_dir = 1 # Default to right if completely stopped (optional)
#
			#if boost_dir == -1:
				#player.velocity.y += boost_dir * RUN_JUMP_X_BOOST
			#else:
				#player.velocity.y -= boost_dir * RUN_JUMP_X_BOOST
	player.jump_fx.global_position = 	player.jump_start_position
	player.jump_fx.emitting=true
	player.default_sprite.play("Jump")
	LeafSystem.trigger_area_gust(player.global_position, 40, 10)
	player.jump_audio_player.play()
	player.jumping_streak_sprite.show()
	player.jumping_streak_sprite.play("default")
	#else:
		## If not allowed, return to idle
		#player.state_machine.change_state("IdleState")  

func exit_state(player: Player) -> void:
	player.jumping_streak_sprite.hide()
	player.jump_fx.global_position = Vector2(player.global_position.x, player.global_position.y + player.jump_fx_offset)

func update(player: Player, delta: float) -> void:
	player.jump_fx.global_position = 	player.jump_start_position
	if player.is_on_floor() and player.velocity.y >= -100:
		if player.velocity.x <= 0:
			player.state_machine.change_state("IdleState")
		else:
			player.state_machine.change_state("WalkState")
			
	if Input.is_action_just_released("ui_accept") and player.velocity.y < 0:
		player.velocity.y *= 0.5  # variable jump
	
	if player.velocity.y > 0 and player.jumping_streak_sprite.visible:
		player.jumping_streak_sprite.hide()
	
func physics_update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction * player.get_speed(), player.ACCELERATION * delta* player.AIR_CONTROL)
	#else:
		#player.velocity.x = move_toward(player.velocity.x, 0, player.FRICTION * delta)
	# Gravity and fall multiplier are now handled in Player.gd
