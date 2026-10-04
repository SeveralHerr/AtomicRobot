extends State
class_name AttackState


func enter_state(player: Player) -> void:
	player.default_sprite.frame_changed.connect(_on_frame_changed.bind(player))
	player.default_sprite.play("Attack")
	player.attack_audio.play()
	player.attack_audio_player.play()
	player.velocity = Vector2.ZERO

	player.default_sprite.animation_finished.connect(_on_animation_finished.bind(player))
	

func trigger_attack(player: Player)-> void:
	Globals.gust.emit(player.collision_shape_2d.global_position, 40.0)	
	if Globals.selected_character == "Robot":
		var instance = player.ROBOT_BULLET.instantiate()
		player.get_parent().add_child(instance)
		instance.global_position = player.robot_attack_position.global_position

		var dir = player.last_dir
		instance.dir = dir
		instance.player = player
		instance.lane = player.current_lane
		return
	elif Globals.selected_character == "Cass":
		var instance = player.FLIPFLOP_BULLET.instantiate()
		player.get_parent().add_child(instance)
		instance.global_position = player.robot_attack_position.global_position

		var dir = player.last_dir
		instance.dir = dir
		instance.player = player
		instance.lane = player.current_lane
		return

	var bodies = player.area_2d.get_overlapping_bodies()
	for body in bodies:
		# Shake, sparks and hitstop come from player.land_hit (HitFeel).
		if body is Enemy and body.lane == player.current_lane:
			player.land_hit(body)

	for area in player.area_2d.get_overlapping_areas():
		var parent = area.get_parent()
		if parent is Crack:
			parent.take_blow(player)


func _on_frame_changed(player: Player):
	if player.default_sprite.animation == "Attack" and player.default_sprite.frame == Globals.get_current_character_attack_frame():
		trigger_attack(player)
			
func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.is_grounded():
		player.state_machine.change_state("JumpState")
	# ui_down (lane step) and Crouch are handled centrally by Player._process_lane_input

func exit_state(player: Player) -> void:
	player.default_sprite.animation_finished.disconnect(_on_animation_finished.bind(player))
	player.default_sprite.frame_changed.disconnect(_on_frame_changed.bind(player))

func _on_animation_finished(player: Player) -> void:
	player.state_machine.change_state("IdleState")

		
