extends CharacterBody2D
class_name Player

signal player_health_updated(current_value: int) 

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

var is_dead: bool = false
var health: int = 3

const SPEED = 100.0
const JUMP_VELOCITY = -650.0
var state_machine: StateMachine

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

func take_damage(amount: int) -> void:
	health -= amount
	print(health)
	
	player_health_updated.emit(health) 
	
	if health <= 0:
		death()

func _input(event: InputEvent) -> void:
	state_machine.handle_input(event)
	


func _ready() -> void:
	Globals.player = self
	state_machine = StateMachine.new(self)
	state_machine.add_state("IdleState", IdleState.new())
	state_machine.add_state("JumpState", JumpState.new())
	state_machine.add_state("AttackState", AttackState.new())
	state_machine.add_state("WalkState", WalkState.new())
	state_machine.add_state("DeadState", DeadState.new())
	state_machine.add_state("ClimbState", ClimbState.new())
	state_machine.add_state("CrouchState", CrouchState.new())
	
	state_machine.change_state("IdleState")
	jumping_streak_sprite.hide()
	print(Globals.selected_character)
	if Globals.selected_character == "Robot":
		default_sprite.sprite_frames = Globals.ROBOT_FRAMES
	elif Globals.selected_character == "Cody":
		default_sprite.sprite_frames = Globals.DEFAULT_FRAMES
	
	
func move_player() -> void:
	camera_2d.position_smoothing_enabled = false

	position = Globals.player_last_position

	await get_tree().create_timer(0.5).timeout
	camera_2d.position_smoothing_enabled = true
	camera_2d.position_smoothing_speed = 5
	Globals.player_last_position = null
		
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		
	state_machine.physics_update(delta)
	move_and_slide()
	
func _process(delta: float) -> void:
	state_machine.update(delta)

func receive_hit(source_position: Vector2, damage: int) -> void:
	if is_dead:
		return
	hurt_audio_player.play()

	if animation_player.is_playing():
		animation_player.stop()
	
	animation_player.play("Hit")
	
	var knockback_direction = (global_position - source_position).normalized()
	var knockback_strength = 50.0  
	if state_machine.current_state is WalkState:
		knockback_strength *= 2
	velocity += knockback_direction * knockback_strength

	# Optionally, you could also reset velocity.y to create a more distinct knockback effect
	velocity.y += -10.0 
	#state_machine.change_state("DeadState")
	
	take_damage(damage)
	
func death() -> void:
	state_machine.change_state("DeadState")
