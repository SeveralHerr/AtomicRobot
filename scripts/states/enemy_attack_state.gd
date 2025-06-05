extends EnemyState
class_name EnemyAttackState

var is_attacking: bool = false

func enter_state(enemy: Enemy) -> void:
	super.enter_state(enemy)
	enemy.attack_range = 250
	is_attacking = false
	_setup_timers()
	enemy.animated_sprite_2d.play("idle")

func exit_state(enemy: Enemy) -> void:
	_cleanup_timers()

func _setup_timers() -> void:
	enemy.timer.one_shot = true
	
	if not enemy.timer.timeout.is_connected(_on_attack_ready):
		enemy.timer.timeout.connect(_on_attack_ready)
		
	if not enemy.range_timer.timeout.is_connected(_on_range_check):
		enemy.range_timer.timeout.connect(_on_range_check)

func _cleanup_timers() -> void:
	enemy.timer.stop()
	enemy.range_timer.stop()
	
	if enemy.timer.timeout.is_connected(_on_attack_ready):
		enemy.timer.timeout.disconnect(_on_attack_ready)
		
	if enemy.range_timer.timeout.is_connected(_on_range_check):
		enemy.range_timer.timeout.disconnect(_on_range_check)

func physics_update(delta: float) -> void:
	var dir = (Globals.player.position - enemy.global_position).normalized()
	var dist = enemy.global_position.distance_to(Globals.player.position)
	
	enemy._update_sprite_direction(dir.x)
	
	if dist > enemy.attack_range:
		return
		
	if enemy.timer.is_stopped() and not is_attacking:
		_start_attack()

func _on_range_check() -> void:
	if Globals.player.is_dead:
		return
		
	var dist = enemy.global_position.distance_to(Globals.player.position)
	if dist > enemy.attack_range:
		pass # Handle out of range if needed

func _on_attack_ready() -> void:
	pass # Attack cooldown finished

func _start_attack() -> void:
	if Globals.player.is_dead:
		return
		
	enemy.timer.start()
	is_attacking = true
	enemy.animated_sprite_2d.play("attack")
	_spawn_coin_delayed()

func _spawn_coin_delayed() -> void:
	await enemy.get_tree().create_timer(0.3).timeout
	_throw_coin()
	
func _throw_coin() -> void:
	if enemy == null:
		return
		
	var instance = enemy.COIN_BULLET.instantiate()
	enemy.coins -= 1
	enemy.node.add_child(instance)
	
	var spawn_pos = enemy.global_position + enemy.coin_spawn_point.position
	var target_pos = Globals.player.enemy_attack_position.global_position
	instance.start(spawn_pos, (target_pos - spawn_pos).normalized())
	
	await enemy.animated_sprite_2d.animation_finished
	if enemy == null or enemy.health <= 0:
		return
		
	is_attacking = false
	enemy.animated_sprite_2d.play("idle")
