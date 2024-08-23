extends EnemyState
class_name FindMeterState

const ACCELERATION = 5000.0 
var dir: Vector2
var meter: Meter


func _check(body: Node2D) -> void:
	if body is Player:
		enemy.enemy_state_machine.change_state("PatrolState")

func enter_state(new_enemy: Enemy) -> void:
	enemy = new_enemy
	meter = Config.nearest_meter(enemy.position)
	
func exit_state(enemy: Enemy) -> void:
	await enemy.node.get_tree().create_timer(1).timeout
	enemy.coin_audio_player.stop()	

func update(enemy: Enemy, delta: float) -> void:
	if enemy.enemy_state_machine.current_state is not FindMeterState:
		return  
	
	dir = (meter.position - enemy.position).normalized()

	_update_sprite_direction(enemy)
	enemy.velocity.x = move_toward(enemy.velocity.x, dir.x * 50, 2009 * delta)
	
	var dist = enemy.position.distance_to(meter.position)
	if dist < 5:
		enemy.coins += 4
		meter.play_animation()
		
		enemy.coin_audio_player.play()

		var bodies = enemy.range_area_2d.get_overlapping_bodies()
		for body in bodies: 
			if body is Player:
				enemy.enemy_state_machine.change_state("ChasePlayerState")
				return
				
		enemy.enemy_state_machine.change_state("PatrolState")
		
func _update_sprite_direction(enemy: Enemy) -> void:
	enemy.animated_sprite_2d.flip_h = sign(dir.x) == -1
