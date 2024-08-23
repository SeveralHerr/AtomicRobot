extends EnemyState
class_name FindMeterState

const ACCELERATION = 5000.0 
var dir: Vector2
var meter: Meter
var stand_still: bool = false

func _check(body: Node2D) -> void:
	if body is Player:
		enemy.enemy_state_machine.change_state("PatrolState")

func enter_state(new_enemy: Enemy) -> void:
	enemy = new_enemy
	meter = Config.nearest_meter(enemy.position)
	stand_still = false
	
	
func exit_state(enemy: Enemy) -> void:
	enemy.velocity.x = 0
	#enemy.animated_sprite_2d.play("Idle")

	await enemy.node.get_tree().create_timer(1).timeout
	stand_still= false
	enemy.animated_sprite_2d.play()
	enemy.coin_audio_player.stop()	

func update(enemy: Enemy, delta: float) -> void:
	if stand_still:
		enemy.velocity.x = 0
		enemy.animated_sprite_2d.pause()
		return 
	if enemy.enemy_state_machine.current_state is not FindMeterState:
		return  
	if meter == null:
		_handle_state()
	
	var dist = enemy.position.distance_to(meter.position)
	if dist < 5:
		stand_still = true
		enemy.coins += 4
		meter.play_animation()
		
		enemy.coin_audio_player.play()
		_handle_state()

		return

		
	dir = (meter.position - enemy.position).normalized()

	_update_sprite_direction(enemy)
	enemy.velocity.x = move_toward(enemy.velocity.x, dir.x * 50, 2009 * delta)
	
func _update_sprite_direction(enemy: Enemy) -> void:
	enemy.animated_sprite_2d.flip_h = sign(dir.x) == -1
	
func _handle_state() -> void:
	var bodies = enemy.range_area_2d.get_overlapping_bodies()
	for body in bodies: 
		if body is Player:
			enemy.enemy_state_machine.change_state("ChasePlayerState")
			return
			
	enemy.enemy_state_machine.change_state("PatrolState")
