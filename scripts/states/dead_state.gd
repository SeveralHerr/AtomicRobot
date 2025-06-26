extends State
class_name DeadState

func enter_state(player: Player) -> void:
	if player.is_dead:
		return
	player.velocity = Vector2.ZERO
	player.is_dead = true
	Globals.player_death.emit()
	player.default_sprite.play("Dead")
	await player.get_tree().create_timer(2).timeout
	#player.game_over_container.show()
	#player.default_sprite.offset.y += 8
	#player.velocity.x = 0
