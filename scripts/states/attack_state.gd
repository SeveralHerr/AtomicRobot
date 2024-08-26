extends State
class_name AttackState

func enter_state(player: Player) -> void:
	player.default_sprite.play("Attack")
	_handle_offset(player, 1)
	
	player.area_2d.monitoring = true
	player.default_sprite.animation_finished.connect(_on_animation_finished)

	
	player.attack_audio_player.play()
	
	await player.get_tree().create_timer(0.1).timeout
	var areas = Globals.player.area_2d.get_overlapping_areas()
	for area in areas:
		var parent = area.get_parent()
		print(parent.name)
		if parent is Crate:
			parent.receive_hit()
		elif parent is Enemy:
			parent.receive_hit(1)
		elif parent is Boss:
			parent.receive_hit(1)

func exit_state(player: Player) -> void:
	_handle_offset(player, -1)
	player.collision_shape_2d.position.x = 0
	player.area_2d.monitoring = false
	player.default_sprite.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished() -> void:
	Globals.player.state_machine.change_state("IdleState")
	
func _handle_offset(player: Player, value: int) -> void:
	if player.default_sprite.flip_h:
		player.default_sprite.offset.x -= 8 * value
		player.collision_shape_2d.position.x = -6
	else:
		player.default_sprite.offset.x += 8 * value
		player.collision_shape_2d.position.x = 6
		
		
