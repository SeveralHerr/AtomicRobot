extends State
class_name WalkState

const ACCELERATION = 5000.0  # Adjust as needed for smoother acceleration

func enter_state(player: Player) -> void:
	player.velocity.x = 0
	player.default_sprite.play("Walk")

func update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		if direction <= -1:
			player.default_sprite.flip_h = true
		elif direction >= 1:
			player.default_sprite.flip_h = false
	else:
		player.state_machine.change_state("IdleState")
		

func physics_update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction * player.SPEED, ACCELERATION * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)

		
func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.is_on_floor():
		player.state_machine.change_state("JumpState")
	elif event.is_action_pressed("Attack"):
		player.state_machine.change_state("AttackState")
	elif event.is_action("ui_down") and player.is_on_floor():
		player.state_machine.change_state("CrouchState")
		
