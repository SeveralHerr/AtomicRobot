extends State
class_name JumpState


const JUMP_VELOCITY = -450.0 # Slightly lower jump height
const RUN_JUMP_X_BOOST = 60.0 # Tweak this value for how much extra x velocity to add
const WALK_THRESHOLD = 10.0 # Minimum x velocity to count as running

func enter_state(player: Player) -> void:
	player.jump_start_position = Vector2(player.global_position.x, player.global_position.y + player.jump_fx_offset)
	# Only allow jump if on floor or within coyote time

	player.velocity.y = JUMP_VELOCITY
	player.coyote_timer = 0

	player.jump_fx.global_position = 	player.jump_start_position
	player.jump_fx.emitting=true
	player.default_sprite.play("Jump")
	LeafSystem.trigger_area_gust(player.global_position, 40, 10)
	SfxPitch.play(player.jump_audio_player)

func exit_state(player: Player) -> void:
	player.jump_fx.global_position = Vector2(player.global_position.x, player.global_position.y + player.jump_fx_offset)

func update(player: Player, delta: float) -> void:
	player.jump_fx.global_position = 	player.jump_start_position
	if player.is_grounded() and player.velocity.y >= -100:
		if player.velocity.x <= 0:
			player.state_machine.change_state("IdleState")
		else:
			player.state_machine.change_state("WalkState")

	if Input.is_action_just_released("ui_accept") and player.velocity.y < 0:
		player.velocity.y *= 0.5  # variable jump


func physics_update(player: Player, delta: float) -> void:
	# Gravity and fall multiplier are handled in Player.gd
	FallState.steer(player, Input.get_axis("ui_left", "ui_right"), delta)


func handle_input(player: Player, event: InputEvent) -> void:
	# Air attack on the way up too, not only once falling.
	if event.is_action_pressed("Attack"):
		player.state_machine.change_state("AttackState")
