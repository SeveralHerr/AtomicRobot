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
	if turn_cooldown <= 0.0 and (enemy.should_turn() or enemy.is_near_edge()):
		direction *= -1
		turn_cooldown = turn_cooldown_duration  # Reset cooldown

	enemy.animated_sprite_2d.play("walk")
	enemy.move_towards_target(enemy.global_position + Vector2(direction, 0), delta)
