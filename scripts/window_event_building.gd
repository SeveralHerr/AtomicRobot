extends Node2D

@onready var meter_maid_window: MeterMaidWindow = $MeterMaidWindow
@onready var meter_maid_window_3: MeterMaidWindow = $MeterMaidWindow3
@onready var area_2d: Area2D = $Area2D

var spawn_timer: Timer
var spawn_count: int = 0
const MAX_SPAWNS: int = 3
var player: Player

func _ready() -> void:
	area_2d.body_entered.connect(_on_area_2d_body_entered)
	player = get_tree().get_first_node_in_group("player")
	# Initialize spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 7.0
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		area_2d.body_entered.disconnect(_on_area_2d_body_entered)
		area_2d.queue_free()	
		# Start spawning meter maids
		spawn_count = 0
		spawn_timer.start()
		_spawn_enemy(true)
		
		# Show the meter maid windows
		#meter_maid_window.trigger()
		await get_tree().create_timer(2).timeout
		#meter_maid_window_2.trigger()
		await get_tree().create_timer(4).timeout
		#meter_maid_window_3.trigger()



func _on_spawn_timer_timeout() -> void:
	if spawn_count >= MAX_SPAWNS:
		spawn_timer.stop()
		spawn_timer.queue_free()
		return
		
	_spawn_enemy()

func _spawn_enemy(force_right_spawn: bool = false) -> void:
	var viewport_size = get_viewport_rect().size
	if player:
		EnemySpawner.spawn_enemy(self, player, viewport_size, 0, force_right_spawn)
		spawn_count += 1
		
