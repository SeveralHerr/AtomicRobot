extends EnemyState
class_name ChasePlayerState

## Focused state that only handles chasing the player (movement logic)

func enter_state(enemy: Enemy) -> void:
	super.enter_state(enemy)
	enemy.velocity.x = 0
	enemy.animated_sprite_2d.play("walk")

func exit_state(enemy: Enemy) -> void:
	pass

func physics_update(delta: float) -> void:
	if _should_return_to_patrol():
		enemy.enemy_state_machine.change_state("PatrolState")
		return
		
	var dir = (Globals.player.position - enemy.position).normalized()
	var dist_squared = enemy.position.distance_squared_to(Globals.player.position)
	var attack_range_squared = enemy.attack_range * enemy.attack_range
	
	# Check if close enough to attack
	if dist_squared <= attack_range_squared:
		enemy.enemy_state_machine.change_state("AttackPlayerState")
		return
	
	# For movement calculation, we need actual distance
	var dist = sqrt(dist_squared)
	_handle_movement(dist, delta)
	_update_animation()
	enemy._update_sprite_direction(dir.x)

func _should_return_to_patrol() -> bool:
	# Use squared distance for better performance
	var dist_squared = enemy.position.distance_squared_to(Globals.player.position)
	
	# Player not near ground and persist disabled
	if not Globals.player.is_near_ground() and not enemy.persist_enabled:
		return true
		
	# Too far when persist enabled (250^2 = 62500)
	if dist_squared > 62500 and enemy.persist_enabled:
		return true
		
	# Extremely far - cleanup enemy (3650^2 = 13322500)
	if dist_squared > 13322500 and not enemy.persist_enabled:
		enemy.queue_free()
		return true
		
	return false

func _handle_movement(dist: float, delta: float) -> void:
	var dir = (Globals.player.position - enemy.position).normalized()
	var direction = sign(dir.x)
	var speed_multiplier = 1.2 if dist > 180 else 1.0
	var target_velocity = direction * enemy.move_speed * speed_multiplier
	enemy.velocity.x = move_toward(enemy.velocity.x, target_velocity, 2000 * delta)

func _update_animation() -> void:
	if abs(enemy.velocity.x) < 5.0:
		enemy.animated_sprite_2d.play("idle")
	else:
		enemy.animated_sprite_2d.play("walk")
