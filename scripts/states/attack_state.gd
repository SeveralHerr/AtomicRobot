extends State
class_name AttackState

const PLAYER_DAMAGE = 2

func enter_state(player: Player) -> void:
	player.default_sprite.frame_changed.connect(_on_frame_changed.bind(player))
	player.default_sprite.play("Attack")
	player.attack_audio.play()
	player.attack_audio_player.play()
	player.velocity = Vector2.ZERO

	player.default_sprite.animation_finished.connect(_on_animation_finished)
	

func trigger_attack(player: Player)-> void:
	Globals.gust.emit(player.collision_shape_2d.global_position, 40.0)
	var bodies = player.area_2d.get_overlapping_bodies()
	for body in bodies:
		if body is Enemy:
			ScreenShake.apply_shake(5)
			var dir = (player.global_position - body.global_position).normalized()
			body.receive_hit(PLAYER_DAMAGE)
			
			
	var areas = player.area_2d.get_overlapping_areas()
	for area in areas:
		ScreenShake.apply_shake(5)
		var parent = area.get_parent()
		print(parent.name)
		if area is Enemy:
			parent.receive_hit(PLAYER_DAMAGE)
		elif parent is Crack: 
			parent.receive_hit()
			
			
func _on_frame_changed(player: Player):
	if player.default_sprite.animation == "Attack" and player.default_sprite.frame == Globals.get_current_character_attack_frame():
		trigger_attack(player)
			
func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.is_on_floor():
		player.state_machine.change_state("JumpState")
	elif event.is_action("ui_down") and player.is_on_floor():
		player.state_machine.change_state("CrouchState")

func exit_state(player: Player) -> void:
	player.default_sprite.animation_finished.disconnect(_on_animation_finished.bind(player))
	player.default_sprite.frame_changed.disconnect(_on_frame_changed.bind(player))

func _on_animation_finished(player: Player) -> void:
	player.state_machine.change_state("IdleState")

		
