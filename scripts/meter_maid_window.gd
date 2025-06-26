extends Enemy
class_name MeterMaidWindow

## Stationary window meter maid that attacks from buildings

@onready var cpu_particles_2d: CPUParticles2D = $BrokenWindow/CPUParticles2D
@export var is_event: bool = false

var is_attacking: bool = false

var is_activated: bool = false

func _ready() -> void:
	health = 3
	detection_range = 450
	attack_range = 250
	attack_cooldown = 2
	super._ready()

	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new(self))
	call_deferred("_setup_initial_state")

func _setup_initial_state() -> void:
	_setup_sprite_direction()
	hide() # Start hidden

func _setup_sprite_direction() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var direction_to_player = (player.global_position - global_position).normalized().x
	_update_sprite_direction(direction_to_player)

func trigger() -> void:
	"""Manually trigger the window meter maid to appear"""
	_activate()

func _physics_process(delta: float) -> void:
	_check_activation()
	if not is_activated:
		return
	_face_player()
	#_update_facing_direction()
	_check_attack()

func _check_activation() -> void:
	if visible and not is_player_in_line_of_sight() and not can_see_player(): 
		queue_free()
	
	if is_activated: 
		return
		
	if is_event:
		return
	

	if (is_player_in_line_of_sight()):
		_activate()


func _activate() -> void:
	is_activated = true
	show()
	_setup_sprite_direction()
	animated_sprite_2d.play("idle")
	_play_break_effect()

func _play_break_effect() -> void:
	$GlassBreakAudio.play()
	cpu_particles_2d.emitting = true
	await get_tree().create_timer(0.5).timeout
	cpu_particles_2d.emitting = false
	await get_tree().create_timer(1.0).timeout

func _check_attack() -> void:
	#if is_attacking or not _player_in_range() or attack_timer.time_left > 0:
		#return
	#_start_attack()
	if can_attack():
		enemy_state_machine.change_state("AttackPlayerState")
