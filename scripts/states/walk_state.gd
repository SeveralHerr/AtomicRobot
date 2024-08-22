extends State
class_name WalkState

func enter_state(player: Player) -> void:
	player.velocity.x = 0
	player.default_sprite.play("Walk")

func update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		player.velocity.x = direction * player.SPEED
		if direction <= -1:
			player.default_sprite.flip_h = true
		elif direction >= 1:
			player.default_sprite.flip_h = false
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
		player.state_machine.change_state("IdleState")
		
func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.is_on_floor():
		player.state_machine.change_state("JumpState")
	elif event.is_action_pressed("Attack"):
		player.state_machine.change_state("AttackState")
		
