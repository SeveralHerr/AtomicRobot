extends CharacterBody2D
class_name Player

@onready var default_sprite: AnimatedSprite2D = $DefaultSprite

const SPEED = 100.0
const JUMP_VELOCITY = -300.0
var state_machine: StateMachine

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

func _input(event: InputEvent) -> void:
	state_machine.handle_input(event)

func _ready() -> void:
	Config.player = self
	state_machine = StateMachine.new(self)
	state_machine.add_state("IdleState", IdleState.new())
	state_machine.add_state("JumpState", JumpState.new())
	state_machine.add_state("AttackState", AttackState.new())
	state_machine.add_state("WalkState", WalkState.new())

	state_machine.change_state("IdleState")
		
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	state_machine.update(delta)
	move_and_slide()
