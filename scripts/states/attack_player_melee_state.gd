extends AttackPlayerState
class_name AttackPlayerMeleeState
#
func enter_state() -> void:
	# Claim this enemy's turn-taking attack slot (see Globals.request_attack_slot).
	# Overrides AttackPlayerState.enter_state() entirely (different animation), so
	# the claim has to be repeated here rather than inherited via super().
	Globals.request_attack_slot(enemy)
	enemy.animated_sprite_2d.frame_changed.connect(_on_frame_changed.bind(enemy))
	enemy.velocity.x = 0
	enemy._face_player()
	attack_finished = false


	enemy.animated_sprite_2d.play("melee")
func exit_state() -> void:
	# Free the slot for a queued enemy the moment this one stops actively attacking.
	Globals.release_attack_slot(enemy)
	enemy.animated_sprite_2d.frame_changed.disconnect(_on_frame_changed.bind(enemy))
			
func _on_frame_changed(enemy: Enemy):
	if enemy.animated_sprite_2d.animation == "melee" and enemy.animated_sprite_2d.frame == 6:

		attack()
	elif enemy.animated_sprite_2d.animation == "melee" and enemy.animated_sprite_2d.frame == 3:
		Utils.shake_node2d(enemy, 2, 0.2)
		await enemy.get_tree().create_timer(0.2).timeout
		enemy.attack_player.play()
	elif enemy.animated_sprite_2d.animation == "melee" and enemy.animated_sprite_2d.frame == 7:
		if not enemy.enemy_state_machine.current_state is DeadEnemyState:
			enemy.animated_sprite_2d.play("idle")
			attack_finished = true
			enemy.attack_timer.start()

func attack() -> void:
	if not enemy.is_same_lane_as_player():
		return
	for body in enemy.attack_area.get_overlapping_bodies():
		if body is Player:
			enemy.player.receive_hit(enemy.global_position, 1)
