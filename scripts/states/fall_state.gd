extends State
class_name FallState

func enter_state(player: Player) -> void:
	player.default_sprite.play("Fall")
	player.jumping_streak_sprite.hide()


func update(player: Player, delta: float) -> void:
	if not player.is_grounded():
		return
	land(player)
	if abs(player.velocity.x) <= 0:
		player.state_machine.change_state("IdleState")
		return

	player.state_machine.change_state("WalkState")


## Touchdown feedback: the dust puff at the feet plus a squash. Only on an actual
## landing — leaving Fall mid-air (into an air attack, a coyote jump, knockback)
## must not puff. Shared with AttackState, whose air swings can land too.
static func land(player: Player) -> void:
	player.jump_fx.global_position = Vector2(player.global_position.x, player.global_position.y + player.jump_fx_offset)
	player.jump_fx.emitting = true
	squash_and_stretch(player)


static func squash_and_stretch(player: Player):
	player.default_sprite.scale = Vector2.ONE  # Reset scale before tweening

	var tween = player.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Shrink (squash)
	tween.tween_property(player.default_sprite, "scale", Vector2(1.2, 0.8), 0.08)

	# Stretch back
	tween.tween_property(player.default_sprite, "scale", Vector2.ONE, 0.1)


## Air control, shared by Jump, Fall and air swings. Momentum carries when no
## direction is held (platforming arcs depend on it); a held direction steers hard.
## `turn` false keeps facing (an air swing stays aimed).
static func steer(player: Player, direction: float, delta: float, turn: bool = true) -> void:
	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction * player.get_air_speed(), player.AIR_ACCELERATION * delta)
	if turn:
		player._handle_direction(direction)


func physics_update(player: Player, delta: float) -> void:
	# Gravity and fall multiplier are handled in Player.gd
	steer(player, Input.get_axis("ui_left", "ui_right"), delta)


func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.can_jump():
		player.state_machine.change_state("JumpState")
	elif event.is_action_pressed("Attack"):
		player.state_machine.change_state("AttackState")
	# ui_down (lane step) and Crouch are handled centrally by Player._process_lane_input
