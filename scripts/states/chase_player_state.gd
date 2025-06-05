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
	var dist = enemy.position.distance_to(Globals.player.position)
	
	# Check if close enough to attack
	if dist <= enemy.attack_range:
		enemy.enemy_state_machine.change_state("AttackPlayerState")
		return
	
	_handle_movement(dist, delta)
	_update_animation()
	enemy._update_sprite_direction(dir.x)

func _should_return_to_patrol() -> bool:
	var dist = enemy.position.distance_to(Globals.player.position)
	
	# Player not near ground and persist disabled
	if not Globals.player.is_near_ground() and not enemy.persist_enabled:
		return true
		
	# Too far when persist enabled
	if dist > 250 and enemy.persist_enabled:
		return true
		
	# Extremely far - cleanup enemy
	if dist > 3650 and not enemy.persist_enabled:
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
