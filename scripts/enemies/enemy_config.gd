extends Resource
class_name EnemyConfig

## Data-driven configuration for different enemy types
## Use this to define enemy stats and behavior without code changes

@export_group("Basic Stats")
@export var enemy_type: String = ""
@export var health: int = 3
@export var move_speed: float = 100.0
@export var attack_range: float = 120.0

@export_group("Combat")
@export var damage: int = 1
@export var coins: int = 1
@export var can_attack: bool = true
@export var attack_type: AttackType = AttackType.RANGED
@export var attack_cooldown: float = 2.0

@export_group("Behavior")
@export var chase_range: float = 250.0
@export var patrol_range: float = 500.0
@export var refills_enabled: bool = true
@export var can_patrol: bool = true
@export var is_invulnerable: bool = false

@export_group("AI")
@export var aggression_level: float = 1.0  # 0.5 = passive, 1.0 = normal, 2.0 = aggressive
@export var detection_range: float = 50.0
@export var lose_target_distance: float = 400.0

enum AttackType {
	RANGED,
	MELEE,
	STATIC  # For window enemies
}

## Factory method to create predefined enemy configs
static func create_config(type: String) -> EnemyConfig:
	var config = EnemyConfig.new()
	
	match type:
		"patrol_meter_maid":
			config.enemy_type = "patrol_meter_maid"
			config.health = 3
			config.move_speed = 100.0
			config.attack_range = 120.0
			config.attack_type = AttackType.RANGED
			config.can_patrol = true
			config.refills_enabled = true
			
		"ranged_meter_maid":
			config.enemy_type = "ranged_meter_maid"
			config.health = 3
			config.move_speed = 120.0
			config.attack_range = 120.0
			config.attack_type = AttackType.RANGED
			config.can_patrol = false  # Always chases
			config.aggression_level = 1.5
			config.refills_enabled = true
			
		"melee_meter_maid":
			config.enemy_type = "melee_meter_maid"
			config.health = 3
			config.move_speed = 100.0
			config.attack_range = 60.0
			config.attack_type = AttackType.MELEE
			config.can_patrol = false  # Always chases
			config.refills_enabled = false
			config.coins = 0
			
		"window_meter_maid":
			config.enemy_type = "window_meter_maid"
			config.health = 999  # Effectively invulnerable
			config.move_speed = 0.0
			config.attack_range = 150.0
			config.attack_type = AttackType.STATIC
			config.can_patrol = false
			config.refills_enabled = false
			config.is_invulnerable = true
			
	return config
