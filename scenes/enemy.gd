extends CharacterBody2D
class_name Enemy

var enemy_state_machine: EnemyStateMachine


const COIN_BULLET = preload("res://scenes/coin_bullet.tscn")

@onready var coin_spawn_point: Node2D = $CoinSpawnPoint

@onready var ray_cast_2d_left_down: RayCast2D = $RayCast2D_LeftDown
@onready var ray_cast_2d_left_wall: RayCast2D = $RayCast2D_LeftWall
@onready var ray_cast_2d_right_down: RayCast2D = $RayCast2D_RightDown
@onready var ray_cast_2d_right_wall: RayCast2D = $RayCast2D_RightWall
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
@onready var timer: Timer = $Timer
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var line_of_sight: LineOfSight = $LineOfSight
@onready var range_timer: Timer = $RangeTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var receive_hit_audio: AudioStreamPlayer = $ReceiveHitAudio

var health: int = 3
var direction: int = -1
var speed: int = 50
var move_speed: float = 100.0
var target: Node2D = null
var coins: int = 4
var node: Node
var last_dir: int = 0
var attack_range: int = 150

	
func _update_sprite_direction(direction: float) -> void:
	if direction:
		if direction < 0:
			animated_sprite_2d.flip_h = true
		elif direction > 0:
			animated_sprite_2d.flip_h = false
