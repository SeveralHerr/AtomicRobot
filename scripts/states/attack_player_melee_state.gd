extends AttackPlayerState
class_name AttackPlayerMeleeState
#
func enter_state() -> void:
	enemy.animated_sprite_2d.frame_changed.connect(_on_frame_changed.bind(enemy))
	enemy.velocity.x = 0
	enemy._face_player()
	enemy.animated_sprite_2d.play("melee")
	enemy.attack_timer.start()
func exit_state() -> void:
	enemy.animated_sprite_2d.frame_changed.disconnect(_on_frame_changed.bind(enemy))
			
func _on_frame_changed(enemy: Enemy):
	if enemy.animated_sprite_2d.animation == "attack" and enemy.animated_sprite_2d.frame == 8:
		attack()
	

func attack() -> void:
	enemy.player.receive_hit(enemy.global_position, 1)
	await enemy.animated_sprite_2d.animation_finished
	enemy.animated_sprite_2d.play("idle")
	attack_finished = true
