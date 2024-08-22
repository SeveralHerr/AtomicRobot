extends CharacterBody2D
class_name Player


const SPEED = 100.0
const JUMP_VELOCITY = -300.0
var current_state: STATE = STATE.Idle

enum STATE {
	Idle,
	Jumping,
	Attacking
}

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Attack") and current_state != STATE.Attacking and current_state != STATE.Jumping:
		$DefaultSprite.play("Attack")
		if $DefaultSprite.flip_h:
			$DefaultSprite.offset.x -= 8
		else:
			$DefaultSprite.offset.x += 8
		current_state = STATE.Attacking
		$DefaultSprite.animation_finished.connect(_idle)
		
func _idle():
	if $DefaultSprite.animation_finished.is_connected(_idle):
		if current_state == STATE.Attacking:
			if $DefaultSprite.flip_h:
				$DefaultSprite.offset.x += 8
			else:
				$DefaultSprite.offset.x -= 8
		current_state = STATE.Idle
		$DefaultSprite.animation_finished.disconnect(_idle)
	
	$DefaultSprite.play("idle")

func _ready() -> void:
	Config.player = self
	if Config.cody_selected: 
		$CodySprite.show()
		$DefaultSprite.hide()
	else:
		$CodySprite.hide()
		$DefaultSprite.show()
		
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
	elif  current_state != STATE.Attacking and  current_state == STATE.Jumping:
		if is_on_floor() :
			current_state = STATE.Idle
		

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and current_state != STATE.Attacking:
		velocity.y = JUMP_VELOCITY
		$DefaultSprite.play("Jump")
		current_state = STATE.Jumping


	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction and current_state != STATE.Attacking:
		velocity.x = direction * SPEED
		current_state = STATE.Idle
		$DefaultSprite.play("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if current_state == STATE.Idle:
			$DefaultSprite.play("idle")
		
	if direction <= -1:
		$DefaultSprite.flip_h = true
	elif direction >= 1:
		$DefaultSprite.flip_h = false
		

	move_and_slide()
