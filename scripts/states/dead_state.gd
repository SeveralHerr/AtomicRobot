extends State
class_name DeadState

func enter_state(player: Player) -> void:
	player.default_sprite.play("Dead")
	player.default_sprite.offset.y += 8
	player.velocity.x = 0
