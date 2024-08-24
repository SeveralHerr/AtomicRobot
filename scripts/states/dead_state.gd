extends State
class_name DeadState

func enter_state(player: Player) -> void:
	#if Globals.player.state_machine.current_state is DeadState:
	#	return
	
	Globals.player.is_dead = true
	Globals.player_death.emit()
	player.default_sprite.play("Dead")
	player.default_sprite.offset.y += 8
	player.velocity.x = 0
