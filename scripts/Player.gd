extends CharacterBody2D
class_name Player

signal player_health_updated(current_value: int)

const PLAYER_CROUCH_COLLISION_SHAPE = preload("res://sprites/player_crouch_collision_shape.tres")
const PLAYER_NORMAL_COLLISION_SHAPE = preload("res://sprites/player_normal_collision_shape.tres")

const ROBOT_BULLET = preload("uid://dt4euylnjmkp7")
const FLIPFLOP_BULLET = preload("uid://b2gx172dqadbi")


# Import the states
const KnockbackState = preload("res://scripts/states/knockback_state.gd")
const FallState = preload("res://scripts/states/fall_state.gd")
const RunState = preload("res://scripts/states/run_state.gd")
@onready var robot_attack_position: Node2D = $RobotAttackPosition
@onready var default_sprite: AnimatedSprite2D = $DefaultSprite
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
@onready var jump_audio_player: AudioStreamPlayer2D = $JumpAudioPlayer
@onready var hurt_audio_player: AudioStreamPlayer2D = $HurtAudioPlayer
@onready var attack_audio_player: AudioStreamPlayer2D = $AttackAudioPlayer
@onready var camera_2d: Camera2D = $Camera2D
@onready var jumping_streak_sprite: AnimatedSprite2D = $JumpingStreakSprite
@onready var collision_shape_2d_body: CollisionShape2D = $CollisionShape2D
@onready var boss_spawn_position: Node2D = $BossSpawnPosition
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var enemy_attack_position: Node2D = $EnemyAttackPosition
@onready var attack_audio: AudioStreamPlayer = $AttackAudio
@onready var walk_audio: AudioStreamPlayer = $WalkAudio
@onready var hurt_audio: AudioStreamPlayer = $HurtAudio
@onready var jump_fx: CPUParticles2D = $JumpFx
@onready var run_particles: CPUParticles2D = $RunParticles
@onready var pickup_audio: AudioStreamPlayer = $PickupAudio
@onready var land_audio: AudioStreamPlayer = $LandAudio

var jump_fx_offset: float = 0
var is_dead: bool = false
var health: int = 3
var damage: int = 1
## Debug-menu cheat: invincible + one-hit-kill. See scripts/autoload/debug_menu.gd.
var god_mode: bool = false
var is_event_active: bool = false
var SPEED = 170.0
const JUMP_VELOCITY = -1250.0
var state_machine: StateMachine
const FRICTION := 800
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = 1200
const ACCELERATION = 1000.0  # Adjust as needed for smoother acceleration
const AIR_CONTROL: float = 0.6
# --- JUMP PHYSICS TUNING ---
const COYOTE_TIME: float = 0.1
var coyote_timer: float = 0
var time_since_grounded: float = 0.0
var fall_multiplier: float = 1.5 # Stronger gravity when falling
var boost_speed: float = 0
var jump_start_position: Vector2
var last_dir = 1

# --- LANE SYSTEM (virtual depth, see docs/LANE_REFACTOR.md) ---
var current_lane: int = Lanes.GROUND_LANE
# Node Y when physically grounded on the walkway (ground lane); INF until captured.
var lane_baseline_y: float = INF
var is_changing_lane: bool = false
var _lane_tween: Tween
## Lane the player is snapped into as soon as the walkway baseline is known. Only
## takes effect where lanes_active() is true (main.tscn) — boss_room ignores it.
@export var spawn_lane: int = 2
var _spawn_lane_applied: bool = false
# Seconds ui_down has been held this press; negative = not tracking a press.
var _down_held: float = -1.0
# Previous-frame pressed states, so lane input works on polled edges (injected
# input and some devices don't deliver reliable just_released events).
var _up_prev: bool = false
var _down_prev: bool = false
func take_damage(amount: int) -> void:
	if god_mode:
		return
	health -= amount
	print(health)
	
	player_health_updated.emit(health)
	
	if health <= 0:
		death()

func add_heart(amount: int) -> void:
	health += amount
	health = min(health, 10)  # Cap at 10 hearts for now
	print("Healed! Current health: ", health)
	pickup_audio.play()
	player_health_updated.emit(health)

func _input(event: InputEvent) -> void:
	state_machine.handle_input(event)
	
func is_near_ground() -> bool:
	if position.y >= -200:
		return true
	return false
var h

func _init() -> void:
	var current_character = Globals.get_current_character()
	health = current_character.get_starting_health()
	damage = current_character.get_starting_damage()

func _ready() -> void:
	state_machine = StateMachine.new(self)
	state_machine.add_state("IdleState", IdleState.new())
	state_machine.add_state("JumpState", JumpState.new())
	state_machine.add_state("AttackState", AttackState.new())
	state_machine.add_state("WalkState", WalkState.new())
	state_machine.add_state("RunState", RunState.new())
	state_machine.add_state("DeadState", DeadState.new())
	state_machine.add_state("ClimbState", ClimbState.new())
	state_machine.add_state("CrouchState", CrouchState.new())
	state_machine.add_state("KnockbackState", KnockbackState.new())
	state_machine.add_state("FallState", FallState.new())
	
	state_machine.change_state("IdleState")
	z_index = Lanes.z_for(current_lane)
	jumping_streak_sprite.hide()
	jump_fx_offset = jump_fx.position.y

	var current_character = Globals.get_current_character()
	default_sprite.sprite_frames = current_character.get_sprite_frames()
	attack_audio.stream = current_character.get_weapon_sound()
	jump_audio_player.stream = current_character.get_jump_sound()
	hurt_audio.stream = current_character.get_hit_sound()
	attack_audio_player.stream = current_character.get_attack_sound()
	land_audio.stream = current_character.get_land_sound()
	Globals.event.connect(_event_started)
	

	if LeafSystem.leaf_manager == null: 
		LeafSystem.leaf_manager =  get_tree().get_first_node_in_group("leaf_manager")

func _event_started(status: bool) -> void:
	if status:
		SPEED /= 3
		await get_tree().create_timer(1.5).timeout
		SPEED *= 3

	
func move_player() -> void:
	camera_2d.position_smoothing_enabled = false

	await get_tree().create_timer(0.5).timeout
	camera_2d.position_smoothing_enabled = true
	camera_2d.position_smoothing_speed = 5

		
func _physics_process(delta: float) -> void:
	_update_lane_floor()

	# Track coyote time
	if is_grounded():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	# Apply gravity and fall multiplier (suspended while tweening between lanes)
	if not is_grounded() and not is_changing_lane:
		if velocity.y > 0:
			velocity.y += gravity * (fall_multiplier - 1.0) * delta
		velocity.y += gravity * delta

	# Switch to FallState if falling and not already in it or dead
	if not is_grounded() and not is_changing_lane and velocity.y > 0:
		if not (state_machine.current_state is FallState or state_machine.current_state is DeadState or state_machine.current_state is IdleState):
			state_machine.change_state("FallState")

	state_machine.physics_update(delta)
	move_and_slide()


# --- Lane mechanics -------------------------------------------------------

func lanes_active() -> bool:
	return lane_baseline_y != INF and Lanes.scene_has_lanes(get_tree().current_scene.scene_file_path if get_tree().current_scene else "")

func _update_lane_floor() -> void:
	# The ground lane rides real collision; capture its walkway line as the baseline
	# the virtual road-lane floors are measured from.
	if is_on_floor() and current_lane == Lanes.GROUND_LANE and not is_changing_lane:
		lane_baseline_y = global_position.y
		_apply_spawn_lane()

	# Road lanes have no physical floor: snap onto the lane's virtual floor line.
	if lanes_active() and current_lane != Lanes.GROUND_LANE and not is_changing_lane:
		var fy := Lanes.floor_y(lane_baseline_y, current_lane)
		if velocity.y >= 0 and global_position.y >= fy:
			global_position.y = fy
			velocity.y = 0.0

## Snaps the player onto `spawn_lane` the instant the walkway baseline is known.
## Instant, not tweened — this is the starting position, not a played lane change.
func _apply_spawn_lane() -> void:
	if _spawn_lane_applied or spawn_lane == Lanes.GROUND_LANE or not lanes_active():
		return
	_spawn_lane_applied = true
	var target := Lanes.clamp_lane(spawn_lane)
	_set_ground_collision(false)
	global_position.y = Lanes.floor_y(lane_baseline_y, target)
	current_lane = target
	z_index = Lanes.z_for(target)

func _on_virtual_floor() -> bool:
	if not lanes_active() or current_lane == Lanes.GROUND_LANE or is_changing_lane:
		return false
	return velocity.y >= 0 and global_position.y >= Lanes.floor_y(lane_baseline_y, current_lane) - 0.5

## The walkway tiles' collision boxes occupy the road strip below them, so bodies
## on road lanes must ignore Ground(2)/Meter(4)/Platforms(6); walls and cars stay on.
func _set_ground_collision(enabled: bool) -> void:
	set_collision_mask_value(2, enabled)
	set_collision_mask_value(4, enabled)
	set_collision_mask_value(6, enabled)

## Lane-aware replacement for is_on_floor(): true on real ground OR a virtual lane floor.
func is_grounded() -> bool:
	return is_on_floor() or _on_virtual_floor()

func _process_lane_input(delta: float) -> void:
	if is_dead:
		return
	var up_now := Input.is_action_pressed("ui_up")
	var down_now := Input.is_action_pressed("ui_down")

	# W / up steps a lane deeper (up-screen).
	if up_now and not _up_prev:
		try_change_lane(-1)

	# S / down: tap steps a lane toward the camera, hold crouches.
	if down_now and not _down_prev:
		_down_held = 0.0
	elif down_now and _down_held >= 0.0:
		_down_held += delta
		if _down_held >= Lanes.CROUCH_HOLD_TIME:
			_down_held = -1.0
			_try_crouch()
	elif _down_prev and not down_now:
		if _down_held >= 0.0 and _down_held < Lanes.CROUCH_HOLD_TIME:
			try_change_lane(1)
		_down_held = -1.0

	_up_prev = up_now
	_down_prev = down_now

func try_change_lane(dir: int) -> bool:
	if is_changing_lane or not lanes_active() or not is_grounded():
		return false
	var st = state_machine.current_state
	if not (st is IdleState or st is WalkState or st is RunState):
		return false
	var target := current_lane + dir
	if not Lanes.is_valid_lane(target):
		return false
	_start_lane_change(target)
	return true

func _start_lane_change(target: int) -> void:
	is_changing_lane = true
	velocity.y = 0.0
	# Leaving the walkway: drop ground collision BEFORE the body sinks into the
	# walkway tiles' boxes. Returning to it: re-enable only on arrival (on top).
	if target != Lanes.GROUND_LANE:
		_set_ground_collision(false)
	# Snap draw order to the arriving lane immediately, not on tween completion —
	# the sprite is visually moving toward that depth for the whole tween, so
	# holding the departing lane's z_index for its ~0.12s duration renders it
	# in front of/behind the wrong props and entities until it lands.
	z_index = Lanes.z_for(target)
	if _lane_tween:
		_lane_tween.kill()
	_lane_tween = create_tween()
	_lane_tween.tween_property(self, "global_position:y", Lanes.floor_y(lane_baseline_y, target), Lanes.CHANGE_DURATION)
	_lane_tween.finished.connect(func() -> void:
		current_lane = target
		if target == Lanes.GROUND_LANE:
			_set_ground_collision(true)
		is_changing_lane = false)

func _try_crouch() -> void:
	if is_changing_lane or not is_grounded():
		return
	var st = state_machine.current_state
	if st is IdleState or st is WalkState or st is RunState:
		state_machine.change_state("CrouchState")

# --------------------------------------------------------------------------

func can_jump() -> bool:
	return coyote_timer > 0 or is_grounded()

func get_speed() -> float:
	return SPEED + boost_speed
	
func _process(delta: float) -> void:
	state_machine.update(delta)
	_process_lane_input(delta)
	#var frame = default_sprite.frame
	#var x = frame / h
	#var y = frame / h
	#var frame_coords = Vector2(x, y)
	#default_sprite.material.set_shader_parameter("frame_coords",frame_coords)
	#default_sprite.material.set_shader_parameter("velocity",velocity)

func receive_hit(source_position: Vector2, damage: int, knockback_strength: float = 300) -> void:
	if is_dead:
		return

	if god_mode:
		return

	# Don't allow multiple hits during knockback
	if state_machine.current_state is KnockbackState:
		return

	hurt_audio.play()

	if animation_player.is_playing():
		animation_player.stop()

	animation_player.play("Hit")

	# Calculate knockback direction and strength
	var knockback_direction = (global_position - source_position).normalized()
	var base_knockback_strength = knockback_strength
	
	# Adjust knockback based on current state
	var knockback_multiplier = 1.0
	if state_machine.current_state is WalkState:
		knockback_multiplier = 1.5
	elif state_machine.current_state is CrouchState:
		knockback_multiplier = 0.5
	elif state_machine.current_state is JumpState:
		knockback_multiplier = 0.8
	
	var final_knockback_strength = base_knockback_strength * knockback_multiplier
	
	# Apply knockback (replace velocity instead of adding to it for more consistent effect)
	velocity.x = knockback_direction.x * final_knockback_strength
	
	# Add slight upward velocity for more dramatic effect if on ground
	if is_grounded():
		velocity.y = -100
	else:
		velocity.y = knockback_direction.y * final_knockback_strength * 0.5
	
	# Add screen shake effect (if you have a camera shake system)
	if camera_2d.has_method("add_trauma"):
		camera_2d.add_trauma(0.3)
	
	# Use the existing screenshake system
	var screenshake_node = get_tree().get_first_node_in_group("screenshake")
	if screenshake_node:
		screenshake_node.apply_shake(15.0, 0.3)
	
	# Change to knockback state
	state_machine.change_state("KnockbackState")
	
	take_damage(damage)
	
func death() -> void:
	state_machine.change_state("DeadState")


func _on_attack_timer_timeout() -> void:
	pass # Replace with function body.

# Update player's facing direction based on movement input
func update_facing_direction() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction < 0:
		scale.x = -1 # Face left
	elif direction > 0:
		scale.x = 1 # Face right
func _handle_direction(direction, player) -> void:
	if direction:
		if direction < 0:
			if last_dir != -1:
				if scale.x == -1:
					scale.x *= -1
					last_dir = -1
					return
				scale.x *= -1
				last_dir = -1

		elif direction > 0:
			if last_dir != 1 :
				scale.x *= -1
				last_dir = 1
