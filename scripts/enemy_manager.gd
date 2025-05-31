extends Node2D
const METER_MAID = preload("res://scenes/meter_maid.tscn")
@onready var player: Player = $"../Player"

var spawn_timer: Timer
var viewport_size: Vector2

func _ready():
	# Get the viewport size
	viewport_size = get_viewport_rect().size
	
	# Set up spawn timer
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.wait_time = randf_range(1.0, 10.0)
	spawn_timer.start()

func _on_spawn_timer_timeout():
	spawn_enemy()
	# Reset timer with new random interval
	spawn_timer.wait_time = randf_range(1.0, 10.0)
	spawn_timer.start()

func spawn_enemy():
	var enemy = METER_MAID.instantiate()
	add_child(enemy)
	
	# Randomly choose left or right side
	var spawn_side = randi() % 2 # 0 for left, 1 for right
	var spawn_x = 0.0
	
	if spawn_side == 0: # Left side
		spawn_x = player.position.x - viewport_size.x / 2 - 100 # 100 pixels off-screen
	else: # Right side
		spawn_x = player.position.x + viewport_size.x / 2 + 100 # 100 pixels off-screen
	
	# Set enemy position
	enemy.position = Vector2(spawn_x, player.position.y)
