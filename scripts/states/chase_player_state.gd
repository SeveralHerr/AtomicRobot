extends EnemyState
class_name ChasePlayerState

const ACCELERATION = 5000.0 
var dir: Vector2


func _check(body: Node2D) -> void:
	if body is Player:
		enemy.enemy_state_machine.change_state("PatrolState")

func enter_state(new_enemy: Enemy) -> void:
	enemy = new_enemy
	enemy.velocity.x = 0
	if not enemy.range_area_2d.body_exited.is_connected(_check):
		enemy.range_area_2d.body_exited.connect(_check)
		
	if not enemy.timer.timeout.is_connected(_create_bullet):
		enemy.timer.timeout.connect(_create_bullet)
		
	enemy.timer.start()
		
func exit_state(enemy: Enemy) -> void:
	if enemy.range_area_2d.body_exited.is_connected(_check):
		enemy.range_area_2d.body_exited.disconnect(_check)
		
	if enemy.timer.timeout.is_connected(_create_bullet):
		enemy.timer.timeout.disconnect(_create_bullet)

func update(enemy: Enemy, delta: float) -> void:
	dir = (Config.player.position - enemy.position).normalized()

	_update_sprite_direction(enemy)
	enemy.velocity.x = move_toward(enemy.velocity.x, dir.x * 50, 2009 * delta)
		
		
func _update_sprite_direction(enemy: Enemy) -> void:
	enemy.animated_sprite_2d.flip_h = sign(dir.x) == -1

func _create_bullet() -> void:
	if enemy.coins <= 0:
		enemy.enemy_state_machine.change_state("FindMeterState")
		return	
	elif Config.player.state_machine.current_state is DeadState: 
		return
	
	var instance = enemy.COIN_BULLET.instantiate()

	enemy.coins -= 1
	enemy.node.call_deferred("add_child", instance)
	instance.position = enemy.position
