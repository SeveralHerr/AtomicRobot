extends EnemyState
class_name FindMeterState

const ACCELERATION = 5000.0 
var dir: Vector2
var meter: Meter
var stand_still: bool = false

func _check(body: Node2D) -> void:
	if body is Player:
		enemy.enemy_state_machine.change_state("PatrolState")

func enter_state(enemy: Enemy) -> void:
	super.enter_state(enemy)
	meter = Globals.nearest_meter(enemy.position)
	stand_still = false
	enemy.animated_sprite_2d.play("walk")
	ChatBubble.create(enemy, "Out of ammo!")
	
func exit_state(enemy: Enemy) -> void:
	stand_still = false
	enemy.coin_audio_player.stop()



func physics_update(delta: float) -> void:
	if stand_still:
		enemy.velocity.x = 0
		enemy.animated_sprite_2d.pause()
		return
		
	if enemy.enemy_state_machine.current_state is not FindMeterState:
		return
	
	var dist = enemy.global_position.distance_to(meter.global_position)
	dir = (meter.position - enemy.position).normalized()
	
	if dist < 20 and enemy.coins <= 0:
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
	var target_velocity = dir.x * enemy.move_speed
	enemy.velocity.x = move_toward(enemy.velocity.x, target_velocity, 2000 * delta)
	
# Unused navigation methods - can be removed if not needed
func move_along_path(delta: float) -> void:
	var target_position = enemy.navigation_agent_2d.get_next_path_position()
	var path_dir = (target_position - enemy.position).normalized()
	enemy.velocity.x = move_toward(enemy.velocity.x, path_dir.x * 50, 2000 * delta)

func _delayed_handle_state() -> void:
	await enemy.node.get_tree().create_timer(1).timeout
	_handle_state()

func _handle_state() -> void:
	if enemy.line_of_sight.is_player_line_of_sight():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return
	enemy.enemy_state_machine.change_state("PatrolState")
