extends Node2D

@onready var boss_sprite: AnimatedSprite2D = $BossSprite
@onready var attack_timer: Timer = $AttackTimer
@onready var briefcase_spawn_point: Node2D = $BulletSpawnPoint

const BRIEFCASE_BULLET = preload("res://scenes/briefcase_bullet.tscn")

var player: Player
var is_attacking: bool = false
var attack_cooldown: float = 2.0
var briefcases_per_attack: int = 3
var time_between_briefcases: float = 0.3

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

func _on_attack_timer_timeout() -> void:
	if player and not player.is_dead and not is_attacking:
		_perform_briefcase_attack()

func _perform_briefcase_attack() -> void:
	if is_attacking:
		return
		
	is_attacking = true
	boss_sprite.play("Attack")  # Assumes attack animation exists
	
	# Spawn multiple briefcases like Hammer Bros
	for i in briefcases_per_attack:
		await get_tree().create_timer(time_between_briefcases).timeout
		_spawn_briefcase()
	
	# Reset attack state and restart timer
	await get_tree().create_timer(0.5).timeout  # Brief pause after last briefcase
	is_attacking = false
	boss_sprite.play("Idle")  # Return to idle animation
	attack_timer.start()

func _spawn_briefcase() -> void:
	if not player or player.is_dead:
		return
		
	var briefcase = BRIEFCASE_BULLET.instantiate()
	get_tree().root.add_child(briefcase)
	
	# Position briefcase at spawn point
	var spawn_position = briefcase_spawn_point.global_position if briefcase_spawn_point else global_position
	briefcase.global_position = spawn_position
	
	# Calculate direction to player with some lead prediction
	var target_position = player.global_position
	# Add some vertical offset for arc trajectory
	var direction = (target_position - spawn_position).normalized()
	
	# Start the briefcase movement
	briefcase.start_movement(direction, target_position)
