extends Area2D

var spawn_interval: float = 4.5
var event_length: float = 15.0
@onready var player: Player = $"../../../Player"

var spawn_timer: Timer
var wave_timer: Timer
var viewport_size: Vector2
var is_active: bool = false


func _ready():
	viewport_size = get_viewport_rect().size

	# Set up wave timer
	wave_timer = Timer.new()
	add_child(wave_timer)
	wave_timer.timeout.connect(_end_event)
	wave_timer.wait_time = event_length
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
		#player.state_machine.change_state("IdleState")
	
		_on_spawn_timer_timeout()
		Globals.event.emit(true)
		is_active = true
		print("event starting, spawning")
		wave_timer.start()
	
		



func _on_body_exited(body: Node2D):
	pass
	#if body is Player:
		#is_active = false
		#wave_timer.stop()
		#spawn_timer.stop()



func _end_event():
	if is_active:
		print("Event complete...")
		Globals.event.emit(false)
		queue_free()

func _on_spawn_timer_timeout():
	EnemySpawner.spawn_enemy(get_parent(), player, viewport_size, -122)
	spawn_timer.start()
