extends EnemyState
class_name PatrolState

var direction: int = -1
var turn_cooldown: float = 0.0
var turn_cooldown_duration: float = 0.5

func enter_state() -> void:
	enemy.animated_sprite_2d.play("walk")
	enemy.line_of_sight.enabled = true
	
func exit_state() -> void:
	enemy.line_of_sight.enabled = false
	
func update(delta: float) -> void:
	if enemy.has_state("ChasePlayerState") and (enemy.can_see_player_threshold(0.8) and enemy.is_player_in_line_of_sight()):
		enemy.enemy_state_machine.change_state("ChasePlayerState")

	enemy._face_player()
	
	# Update turn cooldown
	turn_cooldown -= delta
	
	# Only check for turning if cooldown has expired
	if turn_cooldown <= 0.0 and _should_turn():
		direction *= -1
		turn_cooldown = turn_cooldown_duration  # Reset cooldown

	enemy.animated_sprite_2d.play("walk")
	enemy.move_towards_target(enemy.global_position + Vector2(direction, 0), delta)


func _should_turn() -> bool:
	# Check for wall collisions
	return enemy.ray_cast_2d_left_wall.is_colliding() or enemy.ray_cast_2d_right_wall.is_colliding() or randi_range(0, 130) == 2
