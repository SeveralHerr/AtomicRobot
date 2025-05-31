extends EnemyState
class_name PatrolState

@onready var ray_cast_2d_left_down: RayCast2D = $RayCast2D_LeftDown
@onready var ray_cast_2d_left_wall: RayCast2D = $RayCast2D_LeftWall
@onready var ray_cast_2d_right_down: RayCast2D = $RayCast2D_RightDown
@onready var ray_cast_2d_right_wall: RayCast2D = $RayCast2D_RightWall

var direction: int = -1
var move_speed: float = 100.0
var patrol_start_x: float
var patrol_end_x: float

func enter() -> void:
	# Set up patrol boundaries when entering the state
	patrol_start_x = enemy.global_position.x
	patrol_end_x = patrol_start_x + 500.0

func physics_update(delta: float) -> void:
	enemy.animated_sprite_2d.play("walk")
	
	# Check if player is in line of sight to chase
	#var dist = enemy.position.distance_to(Globals.player.position)
	#if dist < 50:
		#enemy.enemy_state_machine.change_state("ChasePlayerState")
		#return
		
	if Globals.player.is_near_ground():
		enemy.enemy_state_machine.change_state("ChasePlayerState")
		return
	
	# Check for walls and ledges
	var should_turn = false
	
	if direction < 0: # Moving left
		if ray_cast_2d_left_wall.is_colliding() or not ray_cast_2d_left_down.is_colliding():
			should_turn = true
	elif direction > 0: # Moving right
		if ray_cast_2d_right_wall.is_colliding() or not ray_cast_2d_right_down.is_colliding():
			should_turn = true
	
	# Check if we've reached patrol boundaries
	if enemy.global_position.x <= patrol_start_x or enemy.global_position.x >= patrol_end_x:
		should_turn = true
	
	# Turn around if needed
	if should_turn:
		direction *= -1
	
	# Update sprite direction
	enemy._update_sprite_direction(direction)
	
	# Move with smooth acceleration
	var target_velocity = direction * move_speed
	enemy.velocity.x = move_toward(enemy.velocity.x, target_velocity, 2000 * delta)
