extends Area2D
const EnemySpawner = preload("res://scripts/enemy_spawner.gd")

@export var wave_count: int = 3
@export var spawn_interval: float = 0.5
@export var wave_delay: float = 2.0
@onready var player: Player = $"../../../Player"

var spawn_timer: Timer
var wave_timer: Timer
var viewport_size: Vector2
var current_wave: int = 0
var is_active: bool = false

func _ready():
	viewport_size = get_viewport_rect().size

	# Set up wave timer
	wave_timer = Timer.new()
	add_child(wave_timer)
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	wave_timer.wait_time = wave_delay
	wave_timer.one_shot = true
	
	# Set up spawn timer
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = true
	
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body is Player and not is_active:
		player.state_machine.change_state("IdleState")
		is_active = true
		start_wave()

func _on_body_exited(body: Node2D):
	if body is Player:
		is_active = false
		wave_timer.stop()
		spawn_timer.stop()

func start_wave():
	if is_active:
		current_wave = 0
		spawn_timer.start()

func _on_wave_timer_timeout():
	if is_active:
		start_wave()

func _on_spawn_timer_timeout():
	if current_wave < wave_count and is_active:
		EnemySpawner.spawn_enemy(get_parent(), player, viewport_size)
		current_wave += 1
		spawn_timer.start()
	elif is_active:
		wave_timer.start()
