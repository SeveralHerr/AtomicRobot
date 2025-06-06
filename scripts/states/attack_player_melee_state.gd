extends AttackPlayerState
class_name AttackPlayerMeleeState
#
#func enter_state() -> void:
	##enemy.player_detection.body_entered.connect(_attack_player)
	#super.enter_state()
#
	##
##func exit_state() -> void:
	###enemy.player_detection.body_entered.disconnect(_attack_player)
	##
	#
	#
#func update(delta: float) -> void:
	#super.update(delta)

	

func attack() -> void:
	enemy.velocity.x = 0
	enemy._face_player()
	enemy.animated_sprite_2d.play("melee")
	enemy.attack_timer.start()
	#if enemy.is_player_in_attack_range:
	await enemy.get_tree().create_timer(0.2).timeout
	enemy.player.receive_hit(enemy.global_position, 1)
	await enemy.animated_sprite_2d.animation_finished
	enemy.animated_sprite_2d.play("idle")
	attack_finished = true
