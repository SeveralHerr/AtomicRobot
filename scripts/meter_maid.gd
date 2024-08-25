extends CharacterBody2D
class_name Enemy

const COIN_BULLET = preload("res://scenes/coin_bullet.tscn")

@onready var coin_spawn_point: Node2D = $CoinSpawnPoint

@onready var ray_cast_2d_left: RayCast2D = $RayCast2D_Left
@onready var ray_cast_2d_right: RayCast2D = $RayCast2D_Right
@onready var ray_cast_2d_left2: RayCast2D = $RayCast2D_Left2
@onready var ray_cast_2d_right2: RayCast2D = $RayCast2D_Right2
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
@onready var timer: Timer = $Timer
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var line_of_sight: LineOfSight = $LineOfSight
@onready var range_timer: Timer = $RangeTimer


var direction: int = -1
var speed: int = 50
var target: Node2D = null
var coins: int = 4
var node: Node

var enemy_state_machine: EnemyStateMachine


func _ready() -> void:
	node = Globals.player.get_parent()
	enemy_state_machine = EnemyStateMachine.new(self)
	enemy_state_machine.add_state("PatrolState", PatrolState.new())
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new())
	enemy_state_machine.add_state("FindMeterState", FindMeterState.new())
	
	enemy_state_machine.change_state("PatrolState")

func _process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 300 * delta

	enemy_state_machine.update(delta)
	move_and_slide()
	
func _physics_process(delta: float) -> void:
	enemy_state_machine.physics_update(delta)
