extends EnemyCombatBehavior
class_name StaticCombatBehavior

## Combat behavior for static enemies like window meter maids

func _perform_attack(target: Node2D) -> void:
	# Static enemies (window) just throw coins
	_spawn_coin_projectile(target)
	enemy.audio_manager.play_attack_sound()

func _spawn_coin_projectile(target: Node2D) -> void:
	# Same as ranged behavior
	var coin_scene = preload("res://scenes/coin_bullet.tscn")
	var coin = coin_scene.instantiate()
	
	if enemy.coin_spawn_point:
		coin.global_position = enemy.coin_spawn_point.global_position
	else:
		coin.global_position = enemy.global_position
	
	enemy.get_parent().add_child(coin)
	
	var direction = (target.global_position - coin.global_position).normalized()
	if coin.has_method("set_direction"):
		coin.set_direction(direction)
