extends State
class_name IdleState

func enter_state(player: Player) -> void:
	player.velocity.x = 0
	player.default_sprite.play("idle")

func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.is_on_floor():
		player.state_machine.change_state("JumpState")
	elif event.is_action_pressed("Attack"):
		player.state_machine.change_state("AttackState")
		
func update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		player.state_machine.change_state("WalkState")
