extends EnemyCombatBehavior
class_name MeleeCombatBehavior

func _perform_attack(target: Node2D) -> void:
	# Play melee attack animation
	if enemy.animation_player:
		enemy.animation_player.play("melee_attack")
	
	enemy.audio_manager.play_attack_sound()
	
	# Deal damage if player is in range
	var distance = enemy.global_position.distance_to(target.global_position)
	if distance <= config.attack_range:
		_deal_melee_damage(target)

func _deal_melee_damage(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(config.damage)

func on_player_collision(player: Node2D) -> void:
	# Melee enemies can damage on collision
	if can_attack(player):
		_deal_melee_damage(player)
