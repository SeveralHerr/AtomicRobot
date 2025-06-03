extends CharacterBody2D
class_name Player

signal player_health_updated(current_value: int)

const PLAYER_CROUCH_COLLISION_SHAPE = preload("res://sprites/player_crouch_collision_shape.tres")
const PLAYER_NORMAL_COLLISION_SHAPE = preload("res://sprites/player_normal_collision_shape.tres")

# Import the KnockbackState
const KnockbackState = preload("res://scripts/states/knockback_state.gd")
const FallState = preload("res://scripts/states/fall_state.gd")

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

var jump_fx_offset: float = 0
var is_dead: bool = false
var health: int = 4
var is_event_active: bool = false
var SPEED = 170.0
const JUMP_VELOCITY = -1250.0
var state_machine: StateMachine
const FRICTION := 800
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- JUMP PHYSICS TUNING ---
var coyote_time: float = 0.1
var time_since_grounded: float = 0.0
var fall_multiplier: float = 1.5 # Stronger gravity when falling
var running_time: float = 0.0
var run_boost_runtime: float = 0.3
var boost_speed: float = 0
var jump_start_position: Vector2

func take_damage(amount: int) -> void:
	health -= amount
	print(health)
	
	player_health_updated.emit(health)
	
	if health <= 0:
		death()

func _input(event: InputEvent) -> void:
	state_machine.handle_input(event)
	
func is_near_ground() -> bool:
	if position.y >= -200:
		return true
	return false
var h
func _ready() -> void:
	print("grav, ", gravity)
	Globals.player = self
	state_machine = StateMachine.new(self)
	state_machine.add_state("IdleState", IdleState.new())
	state_machine.add_state("JumpState", JumpState.new())
	state_machine.add_state("AttackState", AttackState.new())
	state_machine.add_state("WalkState", WalkState.new())
	state_machine.add_state("DeadState", DeadState.new())
	state_machine.add_state("ClimbState", ClimbState.new())
	state_machine.add_state("CrouchState", CrouchState.new())
	state_machine.add_state("KnockbackState", KnockbackState.new())
	state_machine.add_state("FallState", FallState.new())
	
	state_machine.change_state("IdleState")
	jumping_streak_sprite.hide()
	jump_fx_offset = jump_fx.position.y
	#var tex = default_sprite.sprite_frames.get_frame_texture(default_sprite.animation, default_sprite.frame)
#
	#if tex is AtlasTexture:
		#var atlas := tex as AtlasTexture
		#var hframes = atlas.get_size().x / atlas.atlas.get_width()
		#h = hframes
		#var vframes = atlas.get_size().y / atlas.atlas.get_height()
		## Or send manually known values if ratio isn't perfect
		#var m: ShaderMaterial = default_sprite.material 
		#m.set_shader_parameter("nb_frames", Vector2(hframes, vframes))
		

	#default_sprite.material.set_shader_param("nb_frames",Vector2(default_sprite.sprite_frames.hframes, default_sprite.sprite_frames.vframes))
	default_sprite.sprite_frames = Globals.character_dict[Globals.selected_character].sprite_frames

	Globals.event.connect(_event_started)

func _event_started(status: bool) -> void:
	if status:
		print("event active... lowering player speed")
		SPEED /= 3
	else:
		SPEED *= 3
	
func move_player() -> void:
	camera_2d.position_smoothing_enabled = false

	position = Globals.player_last_position

	await get_tree().create_timer(0.5).timeout
	camera_2d.position_smoothing_enabled = true
	camera_2d.position_smoothing_speed = 5
	Globals.player_last_position = null
		
func _physics_process(delta: float) -> void:
	# Track coyote time
	if is_on_floor():
		time_since_grounded = 0.0
	else:
		time_since_grounded += delta

	# Track running time
	var direction := Input.get_axis("ui_left", "ui_right")	
	if abs(velocity.x) > 10 and direction != 0 and is_on_floor():
		running_time += delta
	else:
		running_time = 0.0
		
	# faster animation when jump boost is ready
	if running_time >= run_boost_runtime:
		default_sprite.speed_scale = 1.5
		boost_speed = 30
		run_particles.start()
	else: 
		default_sprite.speed_scale = 1
		boost_speed = 0
		run_particles.stop()

	# Apply gravity and fall multiplier
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * (fall_multiplier - 1.0) * delta
		velocity.y += gravity * delta

	# Switch to FallState if falling and not already in it or dead
	if not is_on_floor() and velocity.y > 0:
		if not (state_machine.current_state is FallState or state_machine.current_state is DeadState or state_machine.current_state is IdleState):
			state_machine.change_state("FallState")

	state_machine.physics_update(delta)
	move_and_slide()

func get_speed() -> float:
	return SPEED + boost_speed
	
func _process(delta: float) -> void:
	state_machine.update(delta)
	#var frame = default_sprite.frame
	#var x = frame / h
	#var y = frame / h
	#var frame_coords = Vector2(x, y)
	#default_sprite.material.set_shader_parameter("frame_coords",frame_coords)
	#default_sprite.material.set_shader_parameter("velocity",velocity)

func receive_hit(source_position: Vector2, damage: int) -> void:
	if is_dead:
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
	var base_knockback_strength = 300
	
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
	if is_on_floor():
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
