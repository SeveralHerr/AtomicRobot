extends EnemyState
class_name ChasePlayerState

const ACCELERATION = 5000.0 
var dir: Vector2
var stand_still: bool = false

func enter_state(new_enemy: Enemy) -> void:
	enemy = new_enemy
	enemy.velocity.x = 0
	stand_still = false
	enemy.timer.one_shot = true
	
	if not enemy.timer.timeout.is_connected(_create_bullet):
		enemy.timer.timeout.connect(_create_bullet)
		
	if not enemy.range_timer.timeout.is_connected(_check_range):
		enemy.range_timer.timeout.connect(_check_range)
	#enemy.timer.start()
	#enemy.range_timer.start()
	#ChatBubble.create(enemy, "I'LL GET YOU!")
	enemy.animated_sprite_2d.play("idle")
	
func exit_state(enemy: Enemy) -> void:
	enemy.timer.stop()
	enemy.range_timer.stop()
	pass

func in_range() -> void:
	if not enemy.timer.timeout.is_connected(_create_bullet):
		enemy.timer.timeout.connect(_create_bullet)
		
	if not enemy.range_timer.timeout.is_connected(_check_range):
		enemy.range_timer.timeout.connect(_check_range)
		
func out_of_range(enemy: Enemy) -> void:
	if enemy.timer.timeout.is_connected(_create_bullet):
		enemy.timer.timeout.disconnect(_create_bullet)
		
	if enemy.range_timer.timeout.is_connected(_check_range):
		enemy.range_timer.timeout.disconnect(_check_range)
		

		
func _check_range() -> void:
	if Globals.player.is_dead:
		return
		
	dir = (Globals.player.position - enemy.position).normalized()
	var dist = enemy.position.distance_to(Globals.player.position)

	
	if dist > enemy.attack_range:
		out_of_range(enemy)
	#print("check range")
	#if not enemy.line_of_sight.is_player_line_of_sight():
		##ChatBubble.create(enemy, "LOST HIM.")
		#enemy.enemy_state_machine.change_state("PatrolState")


		
func physics_update(delta: float) -> void:
	enemy.line_of_sight.is_player_line_of_sight()
	if stand_still:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0, 2000 * delta)
		# Don't change animation when attacking - let the attack animation play
		return 
		
	if not Globals.player.is_near_ground() and not enemy.persist_enabled:
		enemy.enemy_state_machine.change_state("PatrolState")
		return
		

		
	dir = (Globals.player.position - enemy.position).normalized()
	var dist = enemy.position.distance_to(Globals.player.position)
	if dist > 3650 and not enemy.persist_enabled:
		print("way too far... removing enemy")
		queue_free()
	_update_sprite_direction(enemy)

	if dist > 250 and enemy.persist_enabled:
		enemy.enemy_state_machine.change_state("PatrolState")
		return	
	elif dist > enemy.attack_range and dist > 180:
		var player_direction = (Globals.player.global_position - enemy.global_position).normalized()
		var direction = sign(player_direction.x)
		var target_velocity = direction * enemy.move_speed * 1.2
		enemy.velocity.x = move_toward(enemy.velocity.x, target_velocity, 2000 * delta)
	elif dist > enemy.attack_range:
		var player_direction = (Globals.player.global_position - enemy.global_position).normalized()
		var direction = sign(player_direction.x)
		var target_velocity = direction * enemy.move_speed 
		enemy.velocity.x = move_toward(enemy.velocity.x, target_velocity, 2000 * delta)
	else:
		in_range()
		# Close to player - stop moving and attack if cooldown is finished
		enemy.velocity.x = move_toward(enemy.velocity.x, 0, 2000 * delta)	
		
		# Attack immediately if timer cooldown has finished
		if enemy.timer.is_stopped():
			_create_bullet()
	
	# Simple animation logic: if not moving, play idle. If moving, play walk.
	# But don't override attack animation if it's currently playing
	if enemy.animated_sprite_2d.animation != "attack":
		if abs(enemy.velocity.x) < 5.0:  # Not moving (small threshold for floating point precision)
			enemy.animated_sprite_2d.play("idle")
		else:  # Moving
			enemy.animated_sprite_2d.play("walk")

func _update_sprite_direction(enemy: Enemy) -> void:

	enemy._update_sprite_direction(dir.x)

func _create_bullet() -> void:
	if Globals.player.is_dead:
		return
		
	if enemy.timer.is_stopped():
		enemy.timer.start()
	
	#elif enemy.coins <= 0:
		##enemy.enemy_state_machine.change_state("FindMeterState")
		#return	
		
	
	stand_still = true
	enemy.animated_sprite_2d.play("attack")
	
	# Spawn coin halfway through attack animation instead of at the end
	_spawn_coin_delayed()
	
func _spawn_coin_delayed() -> void:
	# Wait for roughly half the attack animation duration
	await enemy.get_tree().create_timer(0.3).timeout
	throw_coin()
	
func throw_coin() -> void:
	if enemy == null:
		return
	stand_still = false
	
	var instance = enemy.COIN_BULLET.instantiate()
	enemy.coins -= 1
	enemy.node.add_child(instance)
	#instance.position = enemy.position + enemy.coin_spawn_point.positiona
	var pos = enemy.position + enemy.coin_spawn_point.position
	instance.start(pos,  (Globals.player.enemy_attack_position.global_position - pos).normalized())
	
	# Return to idle after throwing
	await enemy.animated_sprite_2d.animation_finished
	if enemy == null or enemy.health <= 0: 
		return
	enemy.animated_sprite_2d.play("idle")
	_check_range()
