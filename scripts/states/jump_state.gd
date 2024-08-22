extends State
class_name JumpState

func enter_state(player: Player) -> void:
	player.velocity.y = -300.0
	player.default_sprite.play("Jump")

func update(player: Player, delta: float) -> void:
	if player.is_on_floor() and player.velocity.y >= -100:
		player.state_machine.change_state("IdleState")
