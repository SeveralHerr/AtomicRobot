extends AttackPlayerState
class_name AttackPlayerMeleeState
#
func enter_state() -> void:
	enemy.animated_sprite_2d.frame_changed.connect(_on_frame_changed.bind(enemy))
	enemy.velocity.x = 0
	enemy._face_player()
	attack_finished = false
	

	enemy.animated_sprite_2d.play("melee")
func exit_state() -> void:
	enemy.animated_sprite_2d.frame_changed.disconnect(_on_frame_changed.bind(enemy))
			
func _on_frame_changed(enemy: Enemy):
	if enemy.animated_sprite_2d.animation == "melee" and enemy.animated_sprite_2d.frame == 6:

		attack()
	elif enemy.animated_sprite_2d.animation == "melee" and enemy.animated_sprite_2d.frame == 3:
		Utils.shake_node2d(enemy, 2, 0.2)
		await enemy.get_tree().create_timer(0.2).timeout
	elif enemy.animated_sprite_2d.animation == "melee" and enemy.animated_sprite_2d.frame == 7:
		if not enemy.enemy_state_machine.current_state is DeadEnemyState:
			enemy.animated_sprite_2d.play("idle")
			attack_finished = true
			enemy.attack_timer.start()

func attack() -> void:
	for body in enemy.attack_area.get_overlapping_bodies():
		if body is Player:
			enemy.player.receive_hit(enemy.global_position, 1)
