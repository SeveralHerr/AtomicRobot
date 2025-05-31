extends Area2D

var spawn_interval: float = 3.5
var event_length: float = 20.0
@onready var player: Player = $"../../../Player"

var spawn_timer: Timer
var wave_timer: Timer
var viewport_size: Vector2
var is_active: bool = false
var waves_done: bool = false
var spawned_enemies: Array[Node2D] = []

func _ready():
	viewport_size = get_viewport_rect().size
	
	# Set up wave timer
	wave_timer = Timer.new()
	add_child(wave_timer)
	wave_timer.timeout.connect(func(): waves_done = true)
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

func _process(_delta):
	if is_active and spawned_enemies.size() > 0:
		# Remove any dead enemies from the array

		spawned_enemies = spawned_enemies.filter(func(enemy): return is_instance_valid(enemy))
		# If all enemies are dead, end the event
		if spawned_enemies.size() == 0 and waves_done:
			_end_event()

func _on_body_entered(body: Node2D):
	if body is Player and not is_active:
		_on_spawn_timer_timeout()
		Globals.event.emit(true)
		is_active = true
		wave_timer.start()

func _on_body_exited(body: Node2D):
	pass

func _end_event():
	print("Event complete...")
	Globals.event.emit(false)
	queue_free()

func _on_spawn_timer_timeout():
	if not waves_done:
		var enemy = EnemySpawner.spawn_enemy(get_parent(), player, viewport_size, 0)
		spawned_enemies.append(enemy)
		spawn_timer.start()
