extends EnemyState
class_name ChasePlayerState

const ACCELERATION = 5000.0 
var dir: Vector2
var stand_still: bool = false

func enter_state(new_enemy: Enemy) -> void:
	enemy = new_enemy
	enemy.velocity.x = 0
	stand_still = false
		
	if not enemy.timer.timeout.is_connected(_create_bullet):
		enemy.timer.timeout.connect(_create_bullet)
		
	if not enemy.range_timer.timeout.is_connected(_check_range):
		enemy.range_timer.timeout.connect(_check_range)
		
	ChatBubble.create(enemy, "I'LL GET YOU!")
		
	enemy.timer.start()

		
func exit_state(enemy: Enemy) -> void:
	if enemy.timer.timeout.is_connected(_create_bullet):
		enemy.timer.timeout.disconnect(_create_bullet)
		
	if enemy.range_timer.timeout.is_connected(_check_range):
		enemy.range_timer.timeout.disconnect(_check_range)
		
func _check_range() -> void:
	if Globals.player.is_dead:
		return
	
	print("check range")
	if not enemy.line_of_sight.is_player_line_of_sight():
		ChatBubble.create(enemy, "LOST HIM.")
		enemy.enemy_state_machine.change_state("PatrolState")


		
func physics_update(delta: float) -> void:
	if stand_still:
		enemy.velocity.x = 0
		return 
		
	dir = (Globals.player.position - enemy.position).normalized()
	var dist = enemy.position.distance_to(Globals.player.position)
	if dist > 8:
		_update_sprite_direction(enemy)
		enemy.velocity.x = move_toward(enemy.velocity.x, dir.x * 50, 2009 * delta)		
		
func _update_sprite_direction(enemy: Enemy) -> void:
	enemy.animated_sprite_2d.flip_h = sign(dir.x) == -1

func _create_bullet() -> void:
	if Globals.player.is_dead:
		return
	elif enemy.coins <= 0:
		enemy.enemy_state_machine.change_state("FindMeterState")
		return	
		
	
	stand_still = true
	enemy.animated_sprite_2d.animation_finished.connect(throw_coin)
	enemy.animated_sprite_2d.play("ThrowCoin")
	
func throw_coin() -> void:
	stand_still = false
	enemy.animated_sprite_2d.animation_finished.disconnect(throw_coin)
	
	var instance = enemy.COIN_BULLET.instantiate()
	enemy.coins -= 1
	enemy.node.call_deferred("add_child", instance)
	instance.position = enemy.position + enemy.coin_spawn_point.position
	enemy.animated_sprite_2d.play("Walk")
