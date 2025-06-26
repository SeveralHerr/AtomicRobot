extends State
class_name IdleState

func enter_state(player: Player) -> void:
	player.default_sprite.play("idle")
	player.velocity.x = 0

func update(player: Player, delta: float) -> void:
	player.default_sprite.play("idle")
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		if Input.is_action_pressed("Run"):
			player.state_machine.change_state("RunState")		
		else:
			player.state_machine.change_state("WalkState")

func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.is_on_floor():
		player.state_machine.change_state("JumpState")
	elif event.is_action_pressed("Attack"):
		player.state_machine.change_state("AttackState")
	elif event.is_action_pressed("ui_down") and player.is_on_floor():
		player.state_machine.change_state("CrouchState")
