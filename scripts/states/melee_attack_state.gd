extends EnemyState
class_name MeleeAttackState

## Focused state for melee attacks

var is_attacking: bool = false
var attack_damage: int = 1
var attack_range: float = 60.0

func enter_state(enemy: Enemy) -> void:
	super.enter_state(enemy)
	enemy.velocity.x = 0
	is_attacking = false
	_start_attack()

func exit_state(enemy: Enemy) -> void:
	_cleanup_timers()

func physics_update(delta: float) -> void:
	# Stop movement while attacking
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, 2000 * delta)
	
	# Check if should return to chase
	if not is_attacking:
		var dist = enemy.position.distance_to(Globals.player.position)
		if dist > attack_range:
			enemy.enemy_state_machine.change_state("ChasePlayerState")
			return

func _start_attack() -> void:
	if Globals.player.is_dead:
		return
		
	is_attacking = true
	enemy.animated_sprite_2d.play("attack")
	
	# Setup timer for next attack
	if not enemy.timer.timeout.is_connected(_on_attack_cooldown):
		enemy.timer.timeout.connect(_on_attack_cooldown)
	enemy.timer.start()
	
	_perform_melee_attack()

func _perform_melee_attack() -> void:
	# Wait for attack animation to reach hit frame
	await enemy.get_tree().create_timer(0.3).timeout
	
	if enemy == null or Globals.player.is_dead:
		return
		
	# Check if player is still in range
	var dist = enemy.position.distance_to(Globals.player.position)
	if dist <= attack_range:
		_damage_player()
	
	await enemy.animated_sprite_2d.animation_finished
	if enemy == null or enemy.health <= 0:
		return
		
	is_attacking = false
	enemy.animated_sprite_2d.play("idle")

func _damage_player() -> void:
	# Apply damage to player if they have a receive_hit method
	if Globals.player.has_method("receive_hit"):
		Globals.player.receive_hit(attack_damage)
	
	# Play hit effect
	if enemy.has_node("HitEffect"):
		enemy.get_node("HitEffect").play()

func _on_attack_cooldown() -> void:
	var dist = enemy.position.distance_to(Globals.player.position)
	if dist <= attack_range and not is_attacking:
		_start_attack()
	else:
		enemy.enemy_state_machine.change_state("ChasePlayerState")

func _cleanup_timers() -> void:
	if enemy.timer.timeout.is_connected(_on_attack_cooldown):
		enemy.timer.timeout.disconnect(_on_attack_cooldown)
	enemy.timer.stop()