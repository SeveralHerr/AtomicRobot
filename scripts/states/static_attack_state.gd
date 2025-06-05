extends EnemyState
class_name StaticAttackState

## Attack state for stationary enemies (like window meter maids)
## Does not move or return to chase states

var is_attacking: bool = false
var attack_cooldown: float = 2.0

func enter_state(enemy: Enemy) -> void:
	super.enter_state(enemy)
	enemy.velocity.x = 0
	is_attacking = false
	_setup_timers()
	_update_facing_direction()
	_start_attack()

func exit_state(enemy: Enemy) -> void:
	_cleanup_timers()

func physics_update(delta: float) -> void:
	# Ensure enemy stays still
	enemy.velocity.x = 0
	
	# Update facing direction continuously
	_update_facing_direction()
	
	# Continue attacking if player is in range
	if not is_attacking and _player_in_range():
		#_start_attack()
		
		# attack cooldown timer
		if enemy.timer.is_stopped():
			enemy.timer.start()
func _player_in_range() -> bool:
	if not enemy or Globals.player.is_dead:
		return false
	var dist = enemy.global_position.distance_to(Globals.player.global_position)
	return dist <= enemy.attack_range

func _setup_timers() -> void:
	enemy.timer.wait_time = attack_cooldown
	enemy.timer.one_shot = true
	
	if not enemy.timer.timeout.is_connected(_on_attack_ready):
		enemy.timer.timeout.connect(_on_attack_ready)

func _cleanup_timers() -> void:
	enemy.timer.stop()
	if enemy.timer.timeout.is_connected(_on_attack_ready):
		enemy.timer.timeout.disconnect(_on_attack_ready)

func _start_attack() -> void:
	if not _player_in_range():
		return
		
	is_attacking = true
	enemy.animated_sprite_2d.play("attack")
	enemy.timer.start()
	_spawn_coin_delayed()

func _spawn_coin_delayed() -> void:
	# Allow the coin to happen  at the right frame, roughly 0.3seconds into the animation
	if enemy == null or not _player_in_range():
		return
	Utils.throw_coin_delayed(enemy, 0.3)
	
	await enemy.animated_sprite_2d.animation_finished
	if enemy == null or enemy.health <= 0:
		return
		
	is_attacking = false
	enemy.animated_sprite_2d.play("idle")

func _update_facing_direction() -> void:
	if not enemy or not Globals.player:
		return
	var direction_to_player = (Globals.player.global_position - enemy.global_position).normalized().x
	enemy._update_sprite_direction(direction_to_player)

func _on_attack_ready() -> void:
	# Attack cooldown finished, can attack again if player still in range
	if _player_in_range() and not is_attacking:
		_start_attack()
