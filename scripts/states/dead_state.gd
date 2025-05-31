extends State
class_name DeadState

func enter_state(player: Player) -> void:
	if player.is_dead:
		return
	player.velocity = Vector2.ZERO
	Globals.player.is_dead = true
	Globals.player_death.emit()
	player.default_sprite.play("Dead")
	#player.default_sprite.offset.y += 8
	#player.velocity.x = 0
