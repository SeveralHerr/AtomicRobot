extends CharacterBody2D
class_name Enemy

var enemy_state_machine: EnemyStateMachine


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
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var health: int = 3
var direction: int = -1
var speed: int = 50
var target: Node2D = null
var coins: int = 4
var node: Node
var last_dir: int = 0


	
func _update_sprite_direction(direction: float) -> void:
	if direction:
		if direction < 0:
			if last_dir != -1:
				scale.x *= -1
				last_dir = -1
		elif direction > 0:
			if last_dir != 1:
				scale.x *= -1
				last_dir = 1
