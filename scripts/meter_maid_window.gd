extends Enemy
class_name MeterMaidWindow

## Stationary window meter maid that attacks from buildings

@onready var cpu_particles_2d: CPUParticles2D = $BrokenWindow/CPUParticles2D
@export var is_event: bool = false

var is_attacking: bool = false
var attack_cooldown: float = 2.0
var is_activated: bool = false

func _ready() -> void:
	health = 3
	attack_range = 200

	call_deferred("_setup_initial_state")

func _setup_initial_state() -> void:
	node = Globals.player.get_parent()
	_setup_sprite_direction()
	hide() # Start hidden

func _setup_sprite_direction() -> void:
	if not Globals.player:
		return
	var direction_to_player = (Globals.player.global_position - global_position).normalized().x
	_update_sprite_direction(direction_to_player)

func trigger() -> void:
	"""Manually trigger the window meter maid to appear"""
	_activate()

func _physics_process(delta: float) -> void:
	_check_activation()
	if not is_activated:
		return
	
	_update_facing_direction()
	_check_attack()

func _check_activation() -> void:
	if is_activated: 
		return
		
	if is_event:
		return
	
	var dist = global_position.distance_to(Globals.player.global_position)
	if (dist < attack_range):
		_activate()

func _activate() -> void:
	is_activated = true
	show()
	_setup_sprite_direction()
	animated_sprite_2d.play("idle")
	_play_break_effect()

func _play_break_effect() -> void:
	cpu_particles_2d.emitting = true
	await get_tree().create_timer(0.5).timeout
	cpu_particles_2d.emitting = false
	await get_tree().create_timer(1.0).timeout

func _check_attack() -> void:
	if is_attacking or not _player_in_range() or timer.time_left > 0:
		return
	_start_attack()

func _player_in_range() -> bool:
	if not Globals.player or Globals.player.is_dead:
		return false
	var dist = global_position.distance_to(Globals.player.global_position)
	return dist <= attack_range

func _start_attack() -> void:
	is_attacking = true
	animated_sprite_2d.play("attack")
	timer.wait_time = attack_cooldown
	timer.start()
	Utils.throw_coin_delayed(self, 0.3)
	await animated_sprite_2d.animation_finished
	if health <= 0:
		return
	is_attacking = false
	animated_sprite_2d.play("idle")

func _update_facing_direction() -> void:
	if not Globals.player:
		return
	var direction_to_player = (Globals.player.global_position - global_position).normalized().x
	_update_sprite_direction(direction_to_player)

func die() -> void:
	queue_free()

func receive_hit(damage: int) -> void:
	_play_hit_effects()
	_apply_damage(damage)
	# No knockback for window enemies

func _play_hit_effects() -> void:
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	if animation_player:
		animation_player.play("Hit")
	if receive_hit_audio:
		receive_hit_audio.play()

func _apply_damage(damage: int) -> void:
	health -= damage
	if health <= 0:
		call_deferred("die")
