extends EnemyCombatBehavior
class_name RangedCombatBehavior

func _perform_attack(target: Node2D) -> void:
	if not enemy.has_coins():
		return
		
	if not enemy.use_coin():
		return
		
	_spawn_coin_projectile(target)
	enemy.audio_manager.play_attack_sound()

func _spawn_coin_projectile(target: Node2D) -> void:
	# Use existing coin bullet scene
	var coin_scene = preload("res://scenes/coin_bullet.tscn")
	var coin = coin_scene.instantiate()
	
	# Set spawn position
	if enemy.coin_spawn_point:
		coin.global_position = enemy.coin_spawn_point.global_position
	else:
		coin.global_position = enemy.global_position
	
	# Add to scene
	enemy.get_parent().add_child(coin)
	
	# Set direction towards target
	var direction = (target.global_position - coin.global_position).normalized()
	if coin.has_method("set_direction"):
		coin.set_direction(direction)
