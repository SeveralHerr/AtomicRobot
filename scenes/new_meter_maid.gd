extends Node2D

class_name MeterMaidEnemy

enum EnemyState {
	IDLE,
	WALKING,
	ATTACKING,
	COOLDOWN
}

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
const COIN_BULLET = preload("res://scenes/coin_bullet.tscn")
@onready var player: Player = $"../Player"

@export var attack_range: float = 500.0
@export var move_speed: float = 100.0
@export var attack_cooldown: float = 2.0

var current_state: EnemyState = EnemyState.IDLE
var attack_timer: Timer

func _ready() -> void:
	attack_timer = Timer.new()
	attack_timer.one_shot = true
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)

func _process(delta: float) -> void:
	if not player:
		return
		
	match current_state:
		EnemyState.IDLE:
			process_idle_state()
		EnemyState.WALKING:
			process_walking_state(delta)
		EnemyState.ATTACKING:
			process_attacking_state()
		EnemyState.COOLDOWN:
			process_cooldown_state()

func process_idle_state() -> void:
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= attack_range:
		change_state(EnemyState.ATTACKING)
	else:
		change_state(EnemyState.WALKING)

func process_walking_state(delta: float) -> void:
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= attack_range:
		change_state(EnemyState.ATTACKING)
		return
		
	if animated_sprite_2d.animation != "walk":
		animated_sprite_2d.play("walk")
	
	var direction = (player.global_position - global_position).normalized()
	var vel = direction * move_speed * delta
	global_position.x += vel.x
	
	# Update sprite direction
	animated_sprite_2d.flip_h = direction.x < 0

func process_attacking_state() -> void:
	if animated_sprite_2d.animation != "attack":
		animated_sprite_2d.play("attack")
		animated_sprite_2d.animation_finished.connect(_on_animation_finished)

func process_cooldown_state() -> void:
	# Just wait for the timer
	pass

func change_state(new_state: EnemyState) -> void:
	if current_state == new_state:
		return
		
	match current_state:
		EnemyState.ATTACKING:
			animated_sprite_2d.animation_finished.disconnect(_on_animation_finished)
	
	current_state = new_state
	
	match new_state:
		EnemyState.IDLE:
			animated_sprite_2d.play("idle")
		EnemyState.WALKING:
			animated_sprite_2d.play("walk")
		EnemyState.ATTACKING:
			animated_sprite_2d.play("attack")
		EnemyState.COOLDOWN:
			attack_timer.start()

func _on_animation_finished() -> void:
	if current_state == EnemyState.ATTACKING:
		spawn_coin()
		change_state(EnemyState.COOLDOWN)

func _on_attack_timer_timeout() -> void:
	change_state(EnemyState.IDLE)

func spawn_coin() -> void:
	var coin = COIN_BULLET.instantiate()
	coin.global_position = global_position
	get_tree().current_scene.add_child(coin)
	
	# Set coin direction towards player
	var direction = (player.global_position - global_position).normalized()
	coin.direction = direction
