extends CharacterBody2D
class_name Enemy

## Base enemy class with common functionality and state management

# State management
var enemy_state_machine: EnemyStateMachine

# Resources - moved to Utils for shared access

# Node references - cached for performance
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

# Configuration
@export var persist_enabled: bool = false
@export var refills_enabled: bool = false

# Stats
var health: int = 3
var move_speed: float = 100.0
var coins: int = 1
var attack_range: int = 120

# Deprecated - clean up unused variables
# var direction: int = -1  # Use velocity direction instead
# var speed: int = 50      # Use move_speed instead
# var target: Node2D = null  # Use Globals.player instead
# var last_dir: int = 0    # Not needed with proper state management

# Runtime data
var node: Node  # Parent node reference

## Efficiently update sprite direction with early return
func _update_sprite_direction(direction: float) -> void:
	if not animated_sprite_2d or direction == 0.0:
		return
		
	animated_sprite_2d.flip_h = direction < 0.0
