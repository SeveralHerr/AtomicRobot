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
## Hits one HUD orb absorbs before it pops. `health` below is raw hit points, NOT
## orbs — the HUD (scripts/health_container.gd) renders ceil(health / HITS_PER_ORB)
## orbs and swaps each orb through three damage-stage textures. Character configs
## still declare their starting health in ORBS; _init() converts.
const HITS_PER_ORB: int = 3
## Most orbs a pickup can stack to (replaces the old flat `min(health, 10)` cap).
const MAX_ORBS: int = 10
var health: int = HITS_PER_ORB
var damage: int = 1
## Debug-menu cheat: invincible + one-hit-kill. See scripts/autoload/debug_menu.gd.
var god_mode: bool = false

# --- POWER-UPS (timed buffs, see scripts/autoload/powerup_system.gd) ---
# Written ONLY by PowerupSystem; read through get_damage()/get_speed(). Kept as
# separate multipliers rather than by mutating `damage`/`SPEED` in place because
# those two hold character-config baselines that a buff expiring at an awkward
# moment (mid scene-change, mid death) must never be able to corrupt.
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var is_event_active: bool = false
var SPEED = 170.0
const JUMP_VELOCITY = -1250.0
var state_machine: StateMachine
const FRICTION := 800
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = 1200
const ACCELERATION = 1000.0  # Adjust as needed for smoother acceleration
## Air steering (px/s^2) for Jump, Fall and air swings: ~0.2s to reverse at full air
## speed (was 300-600, which took 0.6-1.2s and made boss dodges a guess).
const AIR_ACCELERATION := 1800.0
## Airborne horizontal target = ground speed x this. 1.0 made gaps hard to clear;
## 1.2 adds ~20% reach without touching jump height (test_jump_reach.gd).
const AIR_SPEED_MULT: float = 1.2
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
## World Y of the walkway FLOOR SURFACE (where soles rest) — not this node's Y.
## Shared by every entity, so it can be handed to enemies/props; INF until captured.
var lane_floor_y: float = INF
# Distance from this node's origin down to its soles. Measured lazily: the
# collision shape isn't reachable until the instanced scene has its children.
var _foot_offset: float = 0.0
var _foot_offset_measured: bool = false
var is_changing_lane: bool = false
var _lane_tween: Tween
## Lane the player is snapped into as soon as the walkway baseline is known. Only
## takes effect where lanes_active() is true (main.tscn) — boss_room ignores it.
@export var spawn_lane: int = 2
var _spawn_lane_applied: bool = false
# Previous-frame pressed states, so lane input works on polled edges (injected
# input and some devices don't deliver reliable just_released events).
var _up_prev: bool = false
var _down_prev: bool = false
func take_damage(amount: int) -> void:
	if god_mode:
		return
	health -= amount
	print(health)

	# Getting hit is what breaks a combo — this is the one funnel every damage
	# source already goes through, so nothing can damage the player without the
	# score system hearing about it.
	ScoreSystem.register_player_damaged()
	ComicPopup.spawn(self, global_position + Vector2(0.0, -40.0), &"hurt")

	player_health_updated.emit(health)

	if health <= 0:
		death()


## Damage this attack actually deals, after any active power-up. Always at least 1:
## a buff must never be able to round a hit down to a no-op.
func get_damage() -> int:
	return maxi(1, roundi(float(damage) * damage_multiplier))


## Single funnel for "the player connected with an enemy" — melee (AttackState) and
## both projectile characters route through here, so the combo meter cannot drift
## out of sync with the damage that was dealt. `finisher`: the last swing of a melee
## string (AttackChain), which gets the heavier comic word.
func land_hit(target: Node, finisher: bool = false) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.receive_hit(get_damage())
	ScoreSystem.register_hit()
	if not target is Node2D:
		return
	# Enemy.receive_hit flips is_dead on the hit frame, so this is the killing blow.
	var killed := bool(target.get("is_dead"))
	HitFeel.hit_landed(self, target, killed)
	HitWords.land(target, killed, finisher, global_position.x)

## Raw hit points at full health. Static so callers (debug menu, devtools) can ask
## without hardcoding the cap.
static func max_health() -> int:
	return MAX_ORBS * HITS_PER_ORB


## How many orbs `hp` raw hit points fill, rounding up — a partly-chewed orb still
## shows on the HUD. 0 hp is 0 orbs, which is death.
static func orbs_for(hp: int) -> int:
	return int(ceil(float(maxi(hp, 0)) / float(HITS_PER_ORB)))


## Hits left in orb `index` (0-based, left to right): HITS_PER_ORB for an untouched
## orb, 0 once it is spent. This is what picks the orb's damage-stage texture.
static func orb_hits_left(index: int, hp: int) -> int:
	return clampi(maxi(hp, 0) - index * HITS_PER_ORB, 0, HITS_PER_ORB)


## `amount` is in ORBS, not raw hits — an atomic heart restores a whole orb.
func add_heart(amount: int) -> void:
	health = mini(health + amount * HITS_PER_ORB, max_health())
	print("Healed! Current health: ", health, " (", orbs_for(health), " orbs)")
	pickup_audio.play()
	player_health_updated.emit(health)

func _input(event: InputEvent) -> void:
	state_machine.handle_input(event)
	
func is_near_ground() -> bool:
	return position.y >= -200

func _init() -> void:
	var current_character = Globals.get_current_character()
	# Configs are in orbs, health in hit points; the boss-room Player takes the street's.
	health = mini(Globals.take_carried_health(current_character.get_starting_health() * HITS_PER_ORB), max_health())
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
	# Draw inside the shared Y-sort container so the player interleaves correctly with
	# the enemies jittered around their lane line. No jitter of its own — the player's
	# depth is driven by input, not decoration. Deferred: reparenting inside _ready
	# trips "parent node is busy setting up children".
	Lanes.join_sort_layer.call_deferred(self)
	jumping_streak_sprite.hide()
	jump_fx_offset = jump_fx.position.y

	var current_character = Globals.get_current_character()
	default_sprite.sprite_frames = current_character.get_sprite_frames()
	attack_audio.stream = current_character.get_weapon_sound()
	jump_audio_player.stream = current_character.get_jump_sound()
	hurt_audio.stream = current_character.get_hit_sound()
	attack_audio_player.stream = current_character.get_attack_sound()
	land_audio.stream = current_character.get_land_sound()
	# Takes over DefaultSprite's material shader so power-ups have buff_* uniforms to
	# drive. Done from here rather than in the scene files because the player node is
	# inlined (with its own embedded copy of the shader) into player.tscn, main.tscn
	# AND boss_room.tscn — one runtime install covers all three and any future copy.
	PowerupSystem.attach(self)
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

	apply_gravity(delta)
	state_machine.physics_update(delta)
	move_and_slide()


## Gravity + fall multiplier (suspended while tweening between lanes), then the
## Jump->Fall hand-off once vy turns positive. Split out so tests can integrate a
## jump arc without a physics space (test_jump_reach.gd).
func apply_gravity(delta: float) -> void:
	if is_grounded() or is_changing_lane:
		return
	if velocity.y > 0:
		velocity.y += gravity * (fall_multiplier - 1.0) * delta
	velocity.y += gravity * delta
	if velocity.y > 0:
		var st = state_machine.current_state
		if not (st is FallState or st is DeadState or st is IdleState or st is AttackState):
			state_machine.change_state("FallState")


# --- Lane mechanics -------------------------------------------------------

func lanes_active() -> bool:
	return lane_floor_y != INF and Lanes.scene_has_lanes(get_tree().current_scene.scene_file_path if get_tree().current_scene else "")

## Distance from this node's origin down to its soles — see Lanes.measure_foot_offset.
func foot_offset() -> float:
	if not _foot_offset_measured:
		_foot_offset = Lanes.measure_foot_offset(self)
		_foot_offset_measured = true
	return _foot_offset

## World Y this node's origin sits at when standing on `lane`. Props authored
## against the player's standing line (cars, resting coins) read this rather than
## the raw floor line, so they keep the height they were tuned at.
func lane_stand_y(lane: int) -> float:
	return Lanes.stand_y(lane_floor_y, lane, foot_offset())

## Keep the draw z in step with where the player actually stands, so same-lane enemies
## jittered nearer the camera correctly draw over the player. See Lanes.depth_z for why
## this can't be left to Y-sorting.
func _refresh_depth_z() -> void:
	var z := Lanes.depth_z(current_lane, lane_stand_y(current_lane) + foot_offset(), lane_floor_y)
	if z != z_index:
		z_index = z

func _update_lane_floor() -> void:
	_refresh_depth_z()
	# The ground lane rides real collision; capture its walkway line as the baseline
	# the virtual road-lane floors are measured from. Stored as the FLOOR (soles),
	# not this node's Y, so enemies with different collision boxes can reuse it.
	if is_on_floor() and current_lane == Lanes.GROUND_LANE and not is_changing_lane:
		# Platforms and scaffolding are ground-lane floors too, so not every floor the
		# player stands on is the street — Lanes.accepts_baseline drops the raised ones
		# instead of letting the depth axis ride up onto them.
		var candidate := global_position.y + foot_offset()
		if Lanes.accepts_baseline(lane_floor_y, candidate):
			lane_floor_y = candidate
		_apply_spawn_lane()

	# Road lanes have no physical floor: snap onto the lane's virtual floor line.
	if lanes_active() and current_lane != Lanes.GROUND_LANE and not is_changing_lane:
		var fy := lane_stand_y(current_lane)
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
	global_position.y = lane_stand_y(target)
	current_lane = target
	_refresh_depth_z()

func _on_virtual_floor() -> bool:
	if not lanes_active() or current_lane == Lanes.GROUND_LANE or is_changing_lane:
		return false
	return velocity.y >= 0 and global_position.y >= lane_stand_y(current_lane) - 0.5

## The walkway tiles' collision boxes occupy the road strip below them, so bodies
## on road lanes must ignore Ground(2)/Meter(4)/Platforms(6); walls and cars stay on.
func _set_ground_collision(enabled: bool) -> void:
	set_collision_mask_value(2, enabled)
	set_collision_mask_value(4, enabled)
	set_collision_mask_value(6, enabled)

## Lane-aware replacement for is_on_floor(): true on real ground OR a virtual lane floor.
func is_grounded() -> bool:
	return is_on_floor() or _on_virtual_floor()

## Standing where play will start: grounded, not mid lane step, and on spawn_lane.
## A fresh player first lands on the walkway and only snaps to its road lane on the
## next physics frame, so grounded alone can still be one frame from a 48px drop.
func is_settled() -> bool:
	if not is_grounded() or is_changing_lane:
		return false
	# Not lanes_active(): that waits on the walkway baseline, which is captured the
	# same frame as the snap, so on the landing frame it still read "no lanes".
	var scene := get_tree().current_scene
	var has_lanes := Lanes.scene_has_lanes(scene.scene_file_path if scene else "")
	return _spawn_lane_applied or spawn_lane == Lanes.GROUND_LANE or not has_lanes

func _process_lane_input() -> void:
	if is_dead:
		return
	var up_now := Input.is_action_pressed("ui_up")
	var down_now := Input.is_action_pressed("ui_down")

	# W / up steps a lane deeper (up-screen).
	if up_now and not _up_prev:
		try_change_lane(-1)

	# S / down steps a lane toward the camera.
	if down_now and not _down_prev:
		try_change_lane(1)

	# Crouch is polled while held, so holding it through a landing crouches on touchdown.
	if Input.is_action_pressed("Crouch"):
		_try_crouch()

	_up_prev = up_now
	_down_prev = down_now

## Standing on the street, as opposed to raised ground-lane geometry (a platform, the
## scaffolding). Always true off the ground lane — road lanes ARE the street.
func is_on_street() -> bool:
	if current_lane != Lanes.GROUND_LANE:
		return true
	return Lanes.at_baseline(lane_floor_y, global_position.y + foot_offset())

func try_change_lane(dir: int) -> bool:
	if is_changing_lane or not lanes_active() or not is_grounded():
		return false
	# The lanes are street lanes. Stepping into one from a platform would tween the
	# player straight through the air down to the road, so hold them on the walkway
	# until they come back down to it.
	if not is_on_street():
		return false
	var st = state_machine.current_state
	var attack_cancel: bool = st is AttackState and st.cancellable(self)
	if not (st is IdleState or st is WalkState or st is RunState or attack_cancel):
		return false
	var target := current_lane + dir
	if not Lanes.is_valid_lane(target):
		return false
	if target == Lanes.GROUND_LANE and Lanes.walkway_blocked(self, collision_shape_2d_body, Vector2(global_position.x, lane_stand_y(target))):
		return false
	if attack_cancel:
		state_machine.change_state("IdleState")
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
	_lane_tween.tween_property(self, "global_position:y", lane_stand_y(target), Lanes.CHANGE_DURATION)
	_lane_tween.finished.connect(func() -> void:
		current_lane = target
		_refresh_depth_z()
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
	return (SPEED + boost_speed) * speed_multiplier

func get_air_speed() -> float:
	return get_speed() * AIR_SPEED_MULT
	
func _process(delta: float) -> void:
	state_machine.update(delta)
	_process_lane_input()

func receive_hit(source_position: Vector2, damage: int, knockback_strength: float = 300) -> void:
	if is_dead:
		return

	if god_mode:
		return

	# Don't allow multiple hits during knockback
	if state_machine.current_state is KnockbackState:
		return

	SfxPitch.play(hurt_audio)

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
	
	ScreenShake.apply_shake(6, 0.25)

	# Change to knockback state
	state_machine.change_state("KnockbackState")
	
	take_damage(damage)
	
func death() -> void:
	# Buffs do not survive the run that earned them.
	PowerupSystem.clear_all()
	state_machine.change_state("DeadState")


## Face the way `direction` points; no input keeps the current facing. Flipping
## scale.x mirrors the whole body (sprite, hitbox, shot spawn) in one go.
func _handle_direction(direction, _player = null) -> void:
	var d := int(signf(direction))
	if d != 0 and d != last_dir:
		scale.x *= -1
		last_dir = d
