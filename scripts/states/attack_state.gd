extends State
class_name AttackState

func enter_state(player: Player) -> void:
	player.default_sprite.play("Attack")
	_handle_offset(player, 1)
	player.default_sprite.animation_finished.connect(_on_animation_finished)

func exit_state(player: Player) -> void:
	_handle_offset(player, -1)
	player.default_sprite.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished() -> void:
	Config.player.state_machine.change_state("IdleState")
	
func _handle_offset(player: Player, value: int) -> void:
	if player.default_sprite.flip_h:
		player.default_sprite.offset.x -= 8 * value
	else:
		player.default_sprite.offset.x += 8 * value
