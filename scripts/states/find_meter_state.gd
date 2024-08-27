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
	meter = Globals.nearest_meter(enemy.position)
	stand_still = false
	
	enemy.navigation_agent_2d.set_target_position(meter.position)
	
	ChatBubble.create(enemy, "OH NO! I NEED MORE QUARTERS.")
	
func exit_state(enemy: Enemy) -> void:

	#enemy.animated_sprite_2d.play("Idle")

	stand_still= false
	enemy.animated_sprite_2d.play("Walk")
	enemy.coin_audio_player.stop()	


func update(enemy: Enemy, delta: float) -> void:
	if meter == null:
		_handle_state()

func physics_update(delta: float) -> void:
	if stand_still:
			enemy.velocity.x = 0
			enemy.animated_sprite_2d.pause()
			return 
	if enemy.enemy_state_machine.current_state is not FindMeterState:
		return  

		

	
	var dist = enemy.position.distance_to(meter.position)
	if dist < 5 and enemy.coins <= 0:
		stand_still = true
		enemy.coins += 4
		meter.play_animation()
		enemy.navigation_agent_2d.set_target_position(enemy.global_position)
		
		enemy.coin_audio_player.play()
		enemy.animated_sprite_2d.play("ShakeMeter")
		
		enemy.velocity.x = 0
		call_deferred("_delayed_handle_state")

		return
		
	if not enemy.navigation_agent_2d.is_navigation_finished():
		move_along_path(delta)
		return
		
	dir = (meter.position - enemy.position).normalized()

	_update_sprite_direction(enemy)
	enemy.velocity.x = move_toward(enemy.velocity.x, dir.x * 50, 2009 * delta)
	
func move_along_path(delta: float) -> void:
	var target_position = enemy.navigation_agent_2d.get_next_path_position()
	var dir = (target_position - enemy.position).normalized()
	
	_update_sprite_direction(enemy)
	enemy.velocity.x = move_toward(enemy.velocity.x, dir.x * 50, 2009 * delta)
	
	
func _update_sprite_direction(enemy: Enemy) -> void:
	enemy.animated_sprite_2d.flip_h = sign(dir.x) == -1
	
func _delayed_handle_state() -> void:
	await enemy.node.get_tree().create_timer(1).timeout
	_handle_state()

func _handle_state() -> void:
	if enemy.line_of_sight.is_player_line_of_sight():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return
			
	enemy.enemy_state_machine.change_state("PatrolState")
