extends Enemy
class_name MeterMaidMelee

const METERMAID_MELEE_SPRITE_FRAMES = preload("res://sprites/metermaid_melee_sprite_frames.tres")
@onready var attack_area: Area2D = $AttackArea
@onready var attack_player: AudioStreamPlayer = $AttackPlayer

func _ready() -> void:
	animated_sprite_2d.sprite_frames = METERMAID_MELEE_SPRITE_FRAMES
	attack_cooldown = 1
	move_speed = 150
	super._ready()
	#enemy_state_machine.add_state("PatrolState", PatrolState.new(self))
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new(self))
	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerMeleeState.new(self))
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new(self))
	
	enemy_state_machine.change_state("ChasePlayerState")
	
