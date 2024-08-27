extends EnemyState
class_name EnemyAttackState

const ACCELERATION = 5000.0 
var dir: Vector2
var stand_still: bool = false

var see: bool = false
var r
func enter_state(new_enemy: Enemy) -> void:
	enemy = new_enemy
	enemy.velocity.x = 0
	stand_still = false
	#enemy.line_of_sight.set_collision_mask_value(11, true)
	#enemy.line_of_sight.set_collision_mask_value(1, false)
	enemy.timer.wait_time = 1
	enemy.animated_sprite_2d.play("Idle")
	if not enemy.timer.timeout.is_connected(throw_coin2):
		enemy.timer.timeout.connect(throw_coin2)
		
	enemy.timer.start()
	

func physics_update( delta: float) -> void:

	dir = (Globals.player.global_position - enemy.global_position).normalized()
	
	_update_sprite_direction(enemy)

	#see = enemy.line_of_sight.is_player_line_of_sight()



func _update_sprite_direction(enemy: Enemy) -> void:
	enemy.animated_sprite_2d.flip_h = sign(dir.x) == -1


func throw_coin() -> void:
	enemy.animated_sprite_2d.animation_finished.disconnect(throw_coin)
	
	var instance = enemy.COIN_BULLET.instantiate()
	Globals.player.get_parent().add_child(instance)

	var pos = enemy.coin_spawn_point.global_position
	instance.start(pos,  (Globals.player.position - pos).normalized())

func throw_coin2() -> void:

	if Globals.player.is_dead:
		return
	if not enemy.line_of_sight.is_player_line_of_sight():
		return
		
	enemy.animated_sprite_2d.play("ThrowCoin")		
	await enemy.get_tree().create_timer(0.3).timeout


	var instance = enemy.COIN_BULLET.instantiate()
	Globals.player.get_parent().add_child(instance)

	var start_pos = enemy.coin_spawn_point.global_position
	var target_pos = Globals.player.global_position

	# Calculate the distance and height difference
	var distance_x = target_pos.x - start_pos.x
	var distance_y = target_pos.y - start_pos.y

	# Determine the time it should take for the projectile to reach the player
	var time_to_target = 1  # Adjust this to control the arc height and duration

	# Calculate the horizontal velocity required to reach the player in the given time
	var velocity_x = distance_x / time_to_target

	# Calculate the vertical velocity required to reach the player's height considering gravity
	var gravity = 20.0  # Adjust this to change the arc's shape
	var velocity_y = (distance_y + 0.5 * gravity * pow(time_to_target, 2)) / time_to_target

	# Set the projectile's initial velocity
	instance.start(start_pos, Vector2(velocity_x, -velocity_y), true)
	enemy.animated_sprite_2d.play("Idle")
