extends State
class_name AttackState

## One string of swings (see AttackChain for the timing rules). Works on the ground
## and in the air: in the air gravity and steering carry on (Player.apply_gravity
## leaves this state alone), and an airborne finish hands back to FallState.

var chain := AttackChain.new()
var _airborne := false


func enter_state(player: Player) -> void:
	player.default_sprite.frame_changed.connect(_on_frame_changed.bind(player))
	player.default_sprite.animation_finished.connect(_on_animation_finished.bind(player))
	_airborne = not player.is_grounded()
	if not _airborne:
		player.velocity.x = 0.0
	chain.reset()
	_swing(player)


func _swing(player: Player) -> void:
	player.default_sprite.play("Attack", AttackChain.ANIM_SPEED)
	player.default_sprite.set_frame_and_progress(0, 0.0)
	SfxPitch.play(player.attack_audio, chain.step)
	SfxPitch.play(player.attack_audio_player, chain.step)


func trigger_attack(player: Player)-> void:
	Globals.gust.emit(player.collision_shape_2d.global_position, 40.0)
	if Globals.selected_character == "Robot":
		_shoot(player, player.ROBOT_BULLET)
		return
	elif Globals.selected_character == "Cass":
		_shoot(player, player.FLIPFLOP_BULLET)
		return

	var bodies = player.area_2d.get_overlapping_bodies()
	for body in bodies:
		# Shake, sparks and hitstop come from player.land_hit (HitFeel).
		if body is Enemy and body.lane == player.current_lane:
			player.land_hit(body)

	for area in player.area_2d.get_overlapping_areas():
		var parent = area.get_parent()
		if parent is Crack:
			parent.take_blow(player)

	_reflect(player, bodies)


## Swat thrown things (enemy coins) back: anything in group "reflectable" with a
## reflect(by) method, on the player's lane when it has one. A coin is found through its
## ReflectArea child (layer 8, parent is the coin); a reflectable body works too.
## reflect() owns its juice (spark, ting, hitstop, score): nothing extra here.
func _reflect(player: Player, bodies: Array) -> void:
	var seen := {}
	var candidates: Array = bodies.duplicate()
	for area in player.area_2d.get_overlapping_areas():
		candidates.append(area)
		candidates.append(area.get_parent())
	for n in candidates:
		if n == null or seen.has(n) or not n.is_in_group("reflectable") or not n.has_method("reflect"):
			continue
		seen[n] = true
		if "lane" in n and n.lane != player.current_lane:
			continue
		n.reflect(player)


func _shoot(player: Player, scene: PackedScene) -> void:
	var instance = scene.instantiate()
	player.get_parent().add_child(instance)
	instance.global_position = player.robot_attack_position.global_position
	instance.dir = player.last_dir
	instance.player = player
	instance.lane = player.current_lane


func _hit_frame() -> int:
	return Globals.get_current_character_attack_frame()


func _on_frame_changed(player: Player) -> void:
	var sprite := player.default_sprite
	if sprite.animation != "Attack":
		return
	if not chain.hit_done and sprite.frame == _hit_frame():
		chain.hit_done = true
		trigger_attack(player)
	if chain.should_chain(sprite.frame, _hit_frame()):
		chain.advance()
		if not _airborne:
			player.velocity.x = player.last_dir * AttackChain.LUNGE
		_swing(player)


## The follow-through is cancellable (Player.try_change_lane asks before a lane step).
func cancellable(player: Player) -> bool:
	return chain.in_recovery(player.default_sprite.frame, _hit_frame())


func handle_input(player: Player, event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player.is_grounded():
		player.state_machine.change_state("JumpState")
	elif event.is_action_pressed("Attack"):
		chain.buffered = true
		_on_frame_changed(player)  # already in recovery: chain right now
	# ui_down (lane step) and Crouch are handled centrally by Player._process_lane_input


func update(player: Player, _delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0 and not _airborne and cancellable(player):
		player.state_machine.change_state("RunState" if Input.is_action_pressed("Run") else "WalkState")


func physics_update(player: Player, delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var grounded := player.is_grounded()
	if _airborne and grounded:
		FallState.land(player)
	_airborne = not grounded
	if _airborne:
		FallState.steer(player, direction, delta, false)
		return
	# Grounded: momentum bleeds off, input nudges a slow drift (facing stays put so
	# the swing still lands where it was aimed).
	var target := direction * player.get_speed() * AttackChain.DRIFT
	player.velocity.x = move_toward(player.velocity.x, target, player.FRICTION * delta)


func exit_state(player: Player) -> void:
	player.default_sprite.animation_finished.disconnect(_on_animation_finished.bind(player))
	player.default_sprite.frame_changed.disconnect(_on_frame_changed.bind(player))


func _on_animation_finished(player: Player) -> void:
	if chain.buffered:
		chain.reset()  # the finisher played out: a new string
		_swing(player)
		return
	player.state_machine.change_state("FallState" if _airborne else "IdleState")
