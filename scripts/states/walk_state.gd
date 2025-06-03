extends State
class_name WalkState

func enter_state(player: Player) -> void:
	#player.velocity.x = 0
	player.default_sprite.play("Walk")
	if Input.is_action_pressed("Run"):
		player.state_machine.change_state("RunState")

func exit_state(player: Player) -> void:
	player.walk_audio.stop()

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
		var target = direction * player.get_speed()
		player.velocity.x = move_toward(player.velocity.x, target, player.ACCELERATION * delta)
		
	player._handle_direction(direction, player)
		

func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("Run"):
		player.state_machine.change_state("RunState")
	elif event.is_action_pressed("ui_accept") and player.can_jump():
		player.state_machine.change_state("JumpState")
	elif event.is_action_pressed("Attack"):
		player.state_machine.change_state("AttackState")
	elif event.is_action("ui_down") and player.is_on_floor():
		player.state_machine.change_state("CrouchState")
		
