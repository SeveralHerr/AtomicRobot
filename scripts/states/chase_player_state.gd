extends EnemyState
class_name ChasePlayerState

const ACCELERATION = 5000.0
var dir: Vector2
var is_attacking: bool = false

func enter_state(enemy: Enemy) -> void:
	super.enter_state(enemy)
	enemy.velocity.x = 0
	is_attacking = false
	_setup_timers()
	enemy.animated_sprite_2d.play("idle")

func _setup_timers() -> void:
	enemy.timer.one_shot = true
	
	if not enemy.timer.timeout.is_connected(_on_attack_ready):
		enemy.timer.timeout.connect(_on_attack_ready)
		
	if not enemy.range_timer.timeout.is_connected(_on_range_check):
		enemy.range_timer.timeout.connect(_on_range_check)
	
func exit_state(enemy: Enemy) -> void:
	_cleanup_timers()

func _cleanup_timers() -> void:
	enemy.timer.stop()
	enemy.range_timer.stop()
	
	if enemy.timer.timeout.is_connected(_on_attack_ready):
		enemy.timer.timeout.disconnect(_on_attack_ready)
		
	if enemy.range_timer.timeout.is_connected(_on_range_check):
		enemy.range_timer.timeout.disconnect(_on_range_check)

func _on_range_check() -> void:
	if Globals.player.is_dead:
		return
		
	dir = (Globals.player.position - enemy.position).normalized()
	var dist = enemy.position.distance_to(Globals.player.position)
	
	if dist > enemy.attack_range:
		pass # Handle out of range if needed


		
func physics_update(delta: float) -> void:
	if is_attacking:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0, 2000 * delta)
		return
		
	if _should_return_to_patrol():
		enemy.enemy_state_machine.change_state("PatrolState")
		return
		
	dir = (Globals.player.position - enemy.position).normalized()
	var dist = enemy.position.distance_to(Globals.player.position)
	
	_handle_movement(dist, delta)
	_handle_attack(dist)
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
	if dist > enemy.attack_range:
		var direction = sign(dir.x)
		var speed_multiplier = 1.2 if dist > 180 else 1.0
		var target_velocity = direction * enemy.move_speed * speed_multiplier
		enemy.velocity.x = move_toward(enemy.velocity.x, target_velocity, 2000 * delta)
	else:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0, 2000 * delta)

func _handle_attack(dist: float) -> void:
	if dist <= enemy.attack_range and enemy.timer.is_stopped():
		_start_attack()

func _update_animation() -> void:
	if enemy.animated_sprite_2d.animation != "attack":
		if abs(enemy.velocity.x) < 5.0:
			enemy.animated_sprite_2d.play("idle")
		else:
			enemy.animated_sprite_2d.play("walk")

func _start_attack() -> void:
	if Globals.player.is_dead:
		return
		
	if enemy.coins <= 0 and enemy.refills_enabled:
		enemy.enemy_state_machine.change_state("FindMeterState")
		return
		
	enemy.timer.start()
	is_attacking = true
	enemy.animated_sprite_2d.play("attack")
	_spawn_coin_delayed()

func _on_attack_ready() -> void:
	pass # Attack cooldown finished

func _spawn_coin_delayed() -> void:
	await enemy.get_tree().create_timer(0.3).timeout
	_throw_coin()
	
func _throw_coin() -> void:
	if enemy == null:
		return
		
	var instance = enemy.COIN_BULLET.instantiate()
	enemy.coins -= 1
	enemy.node.add_child(instance)
	
	var spawn_pos = enemy.position + enemy.coin_spawn_point.position
	var target_pos = Globals.player.enemy_attack_position.global_position
	instance.start(spawn_pos, (target_pos - spawn_pos).normalized())
	
	await enemy.animated_sprite_2d.animation_finished
	if enemy == null or enemy.health <= 0: 
		return
		
	is_attacking = false
	enemy.animated_sprite_2d.play("idle")
