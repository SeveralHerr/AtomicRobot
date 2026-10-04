extends Enemy
class_name PlatformMeterMaid

func _ready() -> void:
	#animated_sprite_2d.sprite_frames = METERMAID_MELEE_SPRITE_FRAMES
	attack_cooldown = EnemyTuning.PLATFORM_ATTACK_COOLDOWN
	move_speed = EnemyTuning.PLATFORM_MOVE_SPEED
	lane_locked = true  # patrols a platform above the street; lobs onto your lane
	super._ready()
	#enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new(self))
	enemy_state_machine.add_state("PlatformPatrolState", PlatformPatrolState.new(self))
	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new(self))
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new(self))
	enemy_state_machine.change_state("PlatformPatrolState")
	
