extends Node
class_name EnemyCombatBehavior

## Base class for enemy combat behaviors

var enemy  # EnemyController - avoid circular dependency
var config  # EnemyConfig - avoid circular dependency  
var last_attack_time: float = 0.0

func setup(enemy_controller, enemy_config) -> void:
	enemy = enemy_controller
	config = enemy_config

func can_attack(target: Node2D) -> bool:
	if not target or not config.can_attack:
		return false
		
	# Check cooldown
	if Time.get_time() - last_attack_time < config.attack_cooldown:
		return false
		
	# Check range
	var distance = enemy.global_position.distance_to(target.global_position)
	return distance <= config.attack_range

func attack(target: Node2D) -> void:
	if not can_attack(target):
		return
		
	last_attack_time = Time.get_time()
	_perform_attack(target)

func _perform_attack(target: Node2D) -> void:
	# Override in subclasses
	pass

func on_player_collision(player: Node2D) -> void:
	# Override in subclasses if needed
	pass
