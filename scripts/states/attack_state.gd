extends State
class_name AttackState

const PLAYER_DAMAGE = 2

func enter_state(player: Player) -> void:
	player.default_sprite.frame_changed.connect(_on_frame_changed.bind(player))
	player.default_sprite.play("Attack")
	player.attack_audio.play()
	player.attack_audio_player.play()
	player.velocity = Vector2.ZERO
	#_handle_offset(player, 1)
	
	#player.area_2d.monitoring = true
	player.default_sprite.animation_finished.connect(_on_animation_finished)
	

func trigger_attack(player: Player)-> void:
	Globals.gust.emit(player.collision_shape_2d.global_position, 40.0)
	var bodies = player.area_2d.get_overlapping_bodies()
	for body in bodies:
		if body is Enemy:
			ScreenShake.apply_shake(5)
			var dir = (player.global_position - body.global_position).normalized()
			#Utils.hit_effect(body, Vector2(body.position.x + (dir.x * 10) , body.position.y) )
#			Utils.apply_hit_pause(player)
			body.receive_hit(PLAYER_DAMAGE)
			
			
	var areas = player.area_2d.get_overlapping_areas()
	for area in areas:
		ScreenShake.apply_shake(5)
		var parent = area.get_parent()
		print(parent.name)
		if parent is Crate:
			parent.receive_hit()
		elif area is Enemy:
			parent.receive_hit(PLAYER_DAMAGE)
		elif parent is Boss:
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
	#_handle_offset(player, -1)
	#player.collision_shape_2d.position.x = 0
	#player.area_2d.monitoring = false
	player.default_sprite.animation_finished.disconnect(_on_animation_finished)
	player.default_sprite.frame_changed.disconnect(_on_frame_changed.bind(player))

func _on_animation_finished() -> void:
	Globals.player.state_machine.change_state("IdleState")
	
#func _handle_offset(player: Player, value: int) -> void:
	#if player.default_sprite.flip_h:
		#player.default_sprite.offset.x -= 8 * value
		##player.collision_shape_2d.position.x = -6
	#else:
		#player.default_sprite.offset.x += 8 * value
		##player.collision_shape_2d.position.x = 6
		
		
