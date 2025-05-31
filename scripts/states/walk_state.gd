extends State
class_name WalkState

const ACCELERATION = 5000.0  # Adjust as needed for smoother acceleration

func enter_state(player: Player) -> void:
	player.velocity.x = 0
	player.default_sprite.play("Walk")
	#player.walk_audio.play()
	
#func exit_state(player: Player) -> void:
	#player.walk_audio.stop()
func update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		return
	else:
		player.state_machine.change_state("IdleState")
		
var last_dir = 1
func physics_update(player: Player, delta: float) -> void:
	
	var direction := Input.get_axis("ui_left", "ui_right")

	#var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction * player.SPEED, ACCELERATION * delta)
		
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED * delta)

	if direction:
		if direction < 0:
			if last_dir != -1:
				if player.scale.x == -1:
					player.scale.x *= -1
					last_dir = -1
					return
				player.scale.x *= -1
				last_dir = -1

		elif direction > 0:
			if last_dir != 1 :
				player.scale.x *= -1
				last_dir = 1
		
func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.is_on_floor():
		player.state_machine.change_state("JumpState")
	elif event.is_action_pressed("Attack"):
		player.state_machine.change_state("AttackState")
	elif event.is_action("ui_down") and player.is_on_floor():
		player.state_machine.change_state("CrouchState")
		
