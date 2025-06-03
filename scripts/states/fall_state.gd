extends State
class_name FallState

const ACCELERATION = 500.0

func enter_state(player: Player) -> void:
	player.default_sprite.play("Fall")
	player.jumping_streak_sprite.hide()

func exit_state(player: Player) -> void:
	pass

func update(player: Player, delta: float) -> void:
	if player.is_on_floor():
		if abs(player.velocity.x) > 0:
			player.state_machine.change_state("WalkState")
		else:
			player.state_machine.change_state("IdleState")

func physics_update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction * player.SPEED, ACCELERATION * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
	# Gravity and fall multiplier are handled in Player.gd 