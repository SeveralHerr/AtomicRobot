extends CharacterBody2D
class_name EnemyController

## Modern component-based enemy controller
## Replaces the old Enemy + MeterMaid inheritance chain

signal died
signal health_changed(new_health: int)

# Configuration
@export var config: Resource  # EnemyConfig
@export var enemy_type: String = "patrol_meter_maid"

# Node references - cached for performance  
@onready var coin_spawn_point: Node2D = $CoinSpawnPoint
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_detector: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_manager = $EnemyAudioManager  # EnemyAudioManager

# Behavior components
var movement_behavior  # EnemyMovementBehavior
var combat_behavior  # EnemyCombatBehavior
var ai_behavior  # EnemyAIBehavior

# State
var current_health: int
var current_coins: int
var is_dead: bool = false
var target_player: Node2D

# Movement state
var facing_direction: float = -1.0
var is_on_ground: bool = false

func _ready() -> void:
	_initialize_config()
	_initialize_components()
	_connect_signals()
	target_player = Globals.player

func _initialize_config() -> void:
	if not config:
		config = EnemyConfig.create_config(enemy_type)
	
	current_health = config.health
	current_coins = config.coins

func _initialize_components() -> void:
	# Create behavior components based on config
	movement_behavior = EnemyMovementBehavior.new()
	movement_behavior.setup(self, config)
	
	combat_behavior = _create_combat_behavior()
	combat_behavior.setup(self, config)
	
	ai_behavior = _create_ai_behavior()
	ai_behavior.setup(self, config)
	
	add_child(movement_behavior)
	add_child(combat_behavior)
	add_child(ai_behavior)

func _create_combat_behavior():
	match config.attack_type:
		EnemyConfig.AttackType.RANGED:
			return RangedCombatBehavior.new()
		EnemyConfig.AttackType.MELEE:
			return MeleeCombatBehavior.new()
		EnemyConfig.AttackType.STATIC:
			return StaticCombatBehavior.new()
		_:
			return RangedCombatBehavior.new()

func _create_ai_behavior():
	if config.can_patrol:
		return PatrolAIBehavior.new()
	else:
		return ChaseAIBehavior.new()

func _connect_signals() -> void:
	Globals.player_death.connect(_on_player_death)
	area_detector.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	_apply_gravity(delta)
	_update_ground_detection()
	
	# Let AI behavior decide what to do
	ai_behavior.update(delta)
	
	# Apply movement
	move_and_slide()
	
	# Update sprite direction
	_update_sprite_direction()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980 * delta

func _update_ground_detection() -> void:
	is_on_ground = is_on_floor()

func _update_sprite_direction() -> void:
	if animated_sprite and velocity.x != 0:
		facing_direction = sign(velocity.x)
		animated_sprite.flip_h = facing_direction < 0

## Public API for behaviors to use

func move_towards_target(target_pos: Vector2, speed_multiplier: float = 1.0) -> void:
	movement_behavior.move_towards(target_pos, speed_multiplier)

func patrol() -> void:
	movement_behavior.patrol()

func stop_movement() -> void:
	movement_behavior.stop()

func attack_target() -> void:
	combat_behavior.attack(target_player)

func can_attack_target() -> bool:
	return combat_behavior.can_attack(target_player)

func is_target_in_range(target_pos: Vector2, range_override: float = -1) -> bool:
	var check_range = range_override if range_override > 0 else config.attack_range
	return global_position.distance_to(target_pos) <= check_range

func get_distance_to_target() -> float:
	if not target_player:
		return INF
	return global_position.distance_to(target_player.global_position)

func should_despawn() -> bool:
	# Don't despawn window enemies or if no target
	if config.attack_type == EnemyConfig.AttackType.STATIC or not target_player:
		return false
		
	var distance = get_distance_to_target()
	return distance > 2000.0  # Despawn if very far from player

## Damage and health system

func take_damage(damage: int) -> void:
	if config.is_invulnerable or is_dead:
		return
		
	current_health -= damage
	health_changed.emit(current_health)
	
	_play_hit_effects()
	_apply_knockback()
	
	if current_health <= 0:
		die()

func _play_hit_effects() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	animation_player.play("Hit")
	audio_manager.play_hit_sound()

func _apply_knockback() -> void:
	if not target_player:
		return
		
	var knockback_direction = (global_position - target_player.global_position).normalized()
	var knockback_strength = 300.0
	velocity += knockback_direction * knockback_strength
	velocity.y = -50.0

func die() -> void:
	if is_dead:
		return
		
	is_dead = true
	died.emit()
	
	# Play death effects
	audio_manager.play_death_sound()
	
	# Signal global systems
	Globals.meter_maid_death.emit()
	
	# Clean up
	queue_free()

## Coin/ammo system

func use_coin() -> bool:
	if current_coins <= 0:
		return false
	current_coins -= 1
	return true

func refill_coins() -> void:
	current_coins = config.coins

func has_coins() -> bool:
	return current_coins > 0

func needs_refill() -> bool:
	return config.refills_enabled and current_coins <= 0

## Signal handlers

func _on_player_death() -> void:
	# Stop all behaviors when player dies
	ai_behavior.stop()

func _on_body_entered(body: Node2D) -> void:
	# Handle player collision damage
	if body == target_player and can_attack_target():
		# Let combat behavior handle the attack
		combat_behavior.on_player_collision(body)
