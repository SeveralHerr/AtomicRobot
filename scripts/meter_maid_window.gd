extends Enemy
class_name MeterMaidWindow

## A maid who smashes a window open and throws coins down at the street. Never
## moves, never chases: she holds position and fires whenever she has a shot.


@onready var cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@export var is_event: bool = false

var is_attacking: bool = false

var is_activated: bool = false

func _ready() -> void:
	health = 3
	detection_range = 450
	attack_range = 250
	attack_cooldown = 2
	lane_locked = true  # attacks from a window; coins hit any lane
	super._ready()

	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new(self))
	enemy_state_machine.add_state("HoldPositionState", HoldPositionState.new(self))
	# Enemy.receive_hit() only enters the dead state if it is registered, so
	# without this the window maid absorbed unlimited damage and could never die.
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new(self))
	enemy_state_machine.change_state("HoldPositionState")

	call_deferred("_setup_initial_state")

func _setup_initial_state() -> void:
	hide() # Start hidden

func trigger() -> void:
	"""Manually trigger the window meter maid to appear"""
	_activate()

## Deliberately does NOT call super(): this maid is mounted in a wall, so she has
## no gravity, no lane floor, no separation and no move_and_slide. She does still
## need her state machine stepped — the base _physics_process was the only thing
## doing that, and overriding it wholesale is why the attack state's update()
## never ran and every transition out of a swing was dead code.
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_resolve_player()
	_refresh_player_in_attack_range()
	_check_activation()
	if not is_activated:
		return
	enemy_state_machine.update(delta)

## The window frame is part of this scene: only the maid blinks out on death, and
## the node stays so the smashed window remains in the wall.
func _death_blink_target() -> CanvasItem:
	return animated_sprite_2d

func _on_death_blink_finished() -> void:
	animated_sprite_2d.hide()

func _check_activation() -> void:
	if visible and not is_player_in_line_of_sight() and not can_see_player():
		queue_free()

	if is_activated:
		return

	if is_event:
		return

	if is_player_in_line_of_sight():
		_activate()


func _activate() -> void:
	is_activated = true
	show()
	animated_sprite_2d.play("idle")
	_play_break_effect()

func _play_break_effect() -> void:
	$GlassBreakAudio.play()
	cpu_particles_2d.emitting = true
	await get_tree().create_timer(0.5).timeout
	cpu_particles_2d.emitting = false
