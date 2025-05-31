extends Node2D
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
	spawn_timer.wait_time = randf_range(13.0, 15.0)
	spawn_timer.start()

func _on_spawn_timer_timeout():
	EnemySpawner.spawn_enemy(self, player, viewport_size)
	# Reset timer with new random interval
	spawn_timer.wait_time = randf_range(13.0, 15.0)
	spawn_timer.start()
