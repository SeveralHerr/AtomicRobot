extends EnemyState
class_name FindMeterState

const ACCELERATION = 5000.0 
var dir: Vector2
var meter: Meter
var stand_still: bool = false

func enter_state() -> void:
	meter = Globals.nearest_meter(enemy.position)
	stand_still = false
	var dist = enemy.global_position.distance_to(meter.global_position)
	if dist >= 300 or not enemy.is_meter_in_line_of_sight():
		print("Meter too far away, replenish coins ")
		enemy.coins += 1
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return

	enemy.animated_sprite_2d.play("walk")
	ChatBubble.create(enemy, "Out of ammo!")


	
func exit_state() -> void:
	stand_still = false
	enemy.coin_audio_player.stop()



func update(delta: float) -> void:
	if stand_still:
		enemy.velocity.x = 0
		enemy.animated_sprite_2d.pause()
		return
		
	if enemy.enemy_state_machine.current_state is not FindMeterState:
		return
	
	var dist = enemy.global_position.distance_to(meter.global_position)
	dir = (meter.global_position - enemy.global_position).normalized()
	

	if dist < 30 and enemy.coins <= 0:
		_refill_at_meter()
	else:
		_move_to_meter(delta)
	
	enemy._update_sprite_direction(dir.x)

func _refill_at_meter() -> void:
	stand_still = true
	enemy.coins += 4
	meter.play_animation()
	enemy.velocity.x = 0
	enemy.coin_audio_player.play()
	enemy.animated_sprite_2d.play("refill", 2)
	Utils.shake_two_node2d(enemy.animated_sprite_2d, meter, 3)
	await enemy.get_tree().create_timer(2).timeout
	
	enemy.enemy_state_machine.change_state("ChasePlayerState")
	

func _move_to_meter(delta: float) -> void:
	enemy.move_towards_target(meter.global_position, delta)
	#enemy.velocity.x = move_toward(enemy.velocity.x, target_velocity, 2000 * delta)
	
# Unused navigation methods - can be removed if not needed
func move_along_path(delta: float) -> void:
	enemy.move_towards_target(dir * 50, delta)
