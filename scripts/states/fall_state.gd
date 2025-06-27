extends State
class_name FallState

const ACCELERATION = 500.0

func enter_state(player: Player) -> void:
	player.default_sprite.play("Fall")
	player.jumping_streak_sprite.hide()

func exit_state(player: Player) -> void:
	player.jump_fx.emitting = true


	pass
	

func update(player: Player, delta: float) -> void:
	if not player.is_on_floor():
		return
	#player.land_audio.play()
	squash_and_stretch(player)
	if abs(player.velocity.x) <= 0:
		
		player.state_machine.change_state("IdleState")
		return

	player.state_machine.change_state("WalkState")

func squash_and_stretch(player: Player):
	player.default_sprite.scale = Vector2.ONE  # Reset scale before tweening

	var tween = player.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Shrink (squash)
	tween.tween_property(player.default_sprite, "scale", Vector2(1.2, 0.8), 0.08)

	# Stretch back
	tween.tween_property(player.default_sprite, "scale", Vector2.ONE, 0.1)
	
func physics_update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction * player.get_speed(), ACCELERATION * delta* player.AIR_CONTROL)
	player._handle_direction(direction, player)
	#else:
		#player.velocity.x = move_toward(player.velocity.x, 0, player.FRICTION * delta* player.AIR_CONTROL)
	# Gravity and fall multiplier are handled in Player.gd 
func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.can_jump():
		player.state_machine.change_state("JumpState")
	elif event.is_action_pressed("Attack"):
		player.state_machine.change_state("AttackState")
	elif event.is_action_pressed("ui_down") and player.is_on_floor():
		player.state_machine.change_state("CrouchState")
