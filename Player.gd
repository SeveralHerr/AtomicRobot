extends CharacterBody2D
class_name Player

@onready var default_sprite: AnimatedSprite2D = $DefaultSprite
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
@onready var jump_audio_player: AudioStreamPlayer2D = $JumpAudioPlayer
@onready var hurt_audio_player: AudioStreamPlayer2D = $HurtAudioPlayer
@onready var attack_audio_player: AudioStreamPlayer2D = $AttackAudioPlayer
@onready var camera_2d: Camera2D = $Camera2D
@onready var jumping_streak_sprite: AnimatedSprite2D = $JumpingStreakSprite

var is_dead: bool = false


const SPEED = 100.0
const JUMP_VELOCITY = -650.0
var state_machine: StateMachine

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

func _input(event: InputEvent) -> void:
	state_machine.handle_input(event)
	
	if event.is_action("Interact"):
		default_sprite.play("Crouch")

func _ready() -> void:
	Globals.player = self
	state_machine = StateMachine.new(self)
	state_machine.add_state("IdleState", IdleState.new())
	state_machine.add_state("JumpState", JumpState.new())
	state_machine.add_state("AttackState", AttackState.new())
	state_machine.add_state("WalkState", WalkState.new())
	state_machine.add_state("DeadState", DeadState.new())
	state_machine.add_state("ClimbState", ClimbState.new())
	
	state_machine.change_state("IdleState")
	jumping_streak_sprite.hide()
	
	
func move_player() -> void:
	camera_2d.position_smoothing_enabled = false

	position = Globals.player_last_position

	await get_tree().create_timer(0.5).timeout
	camera_2d.position_smoothing_enabled = true
	camera_2d.position_smoothing_speed = 5
	Globals.player_last_position = null
		
func _process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	state_machine.update(delta)
	move_and_slide()

		
	
func receive_hit() -> void:
	if is_dead:
		return
	hurt_audio_player.play()
	state_machine.change_state("DeadState")
