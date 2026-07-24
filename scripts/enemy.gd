extends CharacterBody2D
class_name Enemy

## Base enemy class with common functionality and state management

# State management
var enemy_state_machine: EnemyStateMachine

# Resources - moved to Utils for shared access

# Node references - cached for performance
@onready var coin_spawn_point: Node2D = $CoinSpawnPoint
@onready var ray_cast_2d_left_down: RayCast2D = $RayCast2D_LeftDown
@onready var ray_cast_2d_left_wall: RayCast2D = $RayCast2D_LeftWall
@onready var ray_cast_2d_right_down: RayCast2D = $RayCast2D_RightDown
@onready var ray_cast_2d_right_wall: RayCast2D = $RayCast2D_RightWall
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_detection: Area2D = $Area2D
@onready var attack_timer: Timer = $Timer
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer
@onready var range_timer: Timer = $RangeTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var receive_hit_audio: AudioStreamPlayer = $ReceiveHitAudio
@onready var line_of_sight: LineOfSight = $LineOfSight
@onready var meter_line_of_sight: LineOfSight = $MeterLineOfSight

@export var persist: bool = false

var is_player_in_attack_range: bool = false

# Stats
var health: int = 2
var move_speed: float = 100.0
var coins: int = 1
var attack_range: int = 120
var attack_cooldown: float = 4
var detection_range: float = 600.0
var last_dir: int = -1

# --- ENGAGEMENT (turn-taking combat, see docs/LANE_REFACTOR.md + attack-slot manager) ---
## Which attack-slot pool this enemy competes for (see Globals.request_attack_slot).
@export var attack_category: String = "ranged"
## Desired distance from the player's center while actively attacking / about to.
@export var attack_standoff: float = 120.0
## Desired distance from the player's center while queued, waiting for a free slot.
@export var wait_standoff: float = 150.0
## True once _chase_toward_player has closed to within ~4px of its target standoff
## (attack or wait). Drives the walk/idle animation choice in ChasePlayerState —
## deliberately independent of the Area2D-based is_player_in_attack_range flag,
## since wait_standoff can sit outside that circle for tightly-ranged enemies.
var is_holding_position: bool = false
# Knockback variables
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 8.0  # How fast knockback decays
var turn_cooldown: float = 0.0
var turn_cooldown_duration: float = 0.5

# Same-lane enemies never physically collide with each other (collision_mask
# excludes the enemy layer, to avoid move_and_slide push jitter), so without an
# explicit separation nudge they can walk to/spawn at the same X and sit stacked
# on top of each other indefinitely. See docs/LANE_REFACTOR.md.
const ENEMY_SEPARATION_DISTANCE := 40.0
const ENEMY_SEPARATION_STRENGTH := 160.0

# --- LANE SYSTEM (virtual depth, see docs/LANE_REFACTOR.md) ---
## Lane this enemy starts on (editor-visible; hand-placed enemies default to the walkway).
@export var starting_lane: int = Lanes.GROUND_LANE
## Lane-locked enemies (platform/window maids) never lane-chase, and their coins
## hit every lane (they arc down from above).
@export var lane_locked: bool = false
var lane: int = Lanes.GROUND_LANE
var lane_baseline_y: float = INF
var is_changing_lane: bool = false
var _lane_tween: Tween
var lane_change_cooldown: float = 0.0
const LANE_CHANGE_COOLDOWN := 0.7
const LANE_CHANGE_DURATION := 0.2

# Runtime data
var player: Player

func _init() -> void:
	enemy_state_machine = EnemyStateMachine.new(self)
	
	add_child(enemy_state_machine)

func _ready() -> void:
	lane = Lanes.clamp_lane(starting_lane)
	z_index = Lanes.z_for(lane)
	_set_ground_collision(lane == Lanes.GROUND_LANE)
	if lane != Lanes.GROUND_LANE:
		# Hand-placed enemies that start on a road lane never touch the real floor,
		# so _update_lane_floor() would never capture a baseline for them and
		# _lane_chase() would stay permanently blocked (lane_baseline_y == INF).
		# Back-derive the walkway baseline from the current (already-offset) Y.
		lane_baseline_y = global_position.y - Lanes.y_offset(lane)
	attack_timer.wait_time = attack_cooldown
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	if player and player.is_dead:
		print("Dead player detected")
		queue_free()
	
	player_detection.body_entered.connect(func(body: Node2D): is_player_in_attack_range = true)
	player_detection.body_exited.connect(func(body: Node2D): is_player_in_attack_range = false)
	
	Globals.player_death.connect(func(): 
		if not enemy_state_machine.current_state is DeadEnemyState:
			animated_sprite_2d.play("idle")
		set_physics_process(false)
		set_process(false))
	
func _process(delta: float) -> void:
	if is_too_far() and not persist:
		print("enemy too far, purgiing....")
		Globals.release_attack_slot(self)
		queue_free()
	
func _physics_process(delta: float) -> void:
	_update_lane_floor()
	_apply_gravity(delta)
	_apply_knockback_decay(delta)
	enemy_state_machine.update(delta)
	turn_cooldown -= delta
	lane_change_cooldown -= delta
	_apply_enemy_separation(delta)

	move_and_slide()


func is_player_in_line_of_sight() -> bool:
	return line_of_sight.is_player_line_of_sight()

func is_meter_in_line_of_sight() -> bool:
	return meter_line_of_sight.is_meter_line_of_sight(Globals.nearest_meter(global_position).global_position)


# Virtual methods to be overridden
func attack():
	pass




func move_towards_target(target_pos: Vector2, delta: float):
	#var direction = sign(dir.x)
	var direction = (target_pos - global_position).normalized()
	var target_velocity = direction * move_speed
	#_update_sprite_direction(direction.x)
	velocity.x = move_toward(velocity.x, target_velocity.x, 2000 * delta)
	pass


## Same-lane approach toward the player that holds a standoff distance instead of
## closing to the player's exact center (that was bug: enemies ending up on top of
## the player). Holds `attack_standoff` when a turn-taking attack slot is available
## to this enemy (about to fight), otherwise `wait_standoff` (queued, giving the
## active attacker(s) room). Approaches from whichever side it's already on so it
## doesn't cross through the player to switch sides.
func _chase_toward_player(delta: float) -> void:
	var slot_ready := Globals.has_attack_slot_available(attack_category, self)
	var target_standoff := attack_standoff if slot_ready else wait_standoff
	var dx := global_position.x - player.global_position.x
	var side := signf(dx) if absf(dx) > 0.5 else (1.0 if get_instance_id() > player.get_instance_id() else -1.0)
	var target_x := player.global_position.x + side * target_standoff
	var to_target := target_x - global_position.x
	if absf(to_target) < 4.0:
		is_holding_position = true
		velocity.x = move_toward(velocity.x, 0.0, 2000 * delta)
		return
	is_holding_position = false
	var target_velocity := signf(to_target) * move_speed
	velocity.x = move_toward(velocity.x, target_velocity, 2000 * delta)


func is_near_edge() -> bool:
	# The down-raycasts target Ground(2)/Platforms(32), but road-lane bodies
	# deliberately disable both bits on themselves (_set_ground_collision) since
	# virtual lane floors have no real collision under them — so on any non-ground
	# lane these rays never hit anything and this would permanently read "near an
	# edge", blocking chase movement outright. The virtual floors run gapless the
	# length of the level (see docs/LANE_REFACTOR.md), so there's nothing to fall
	# off there; only check for real ledges on the ground lane.
	if lane != Lanes.GROUND_LANE:
		return false
	return not ray_cast_2d_left_down.is_colliding() or not ray_cast_2d_right_down.is_colliding()


func is_near_wall() -> bool:
	# Check for wall collisions
	return ray_cast_2d_left_wall.is_colliding() or ray_cast_2d_right_wall.is_colliding()

	
func _face_player() -> void:
	var direction = (global_position - player.global_position ).normalized()
	_handle_direction( direction.x  )
	
func _handle_direction(direction) -> void:
	if direction:
		if direction < 0:
			if last_dir != -1:
				if scale.x == -1:
					scale.x *= -1
					last_dir = -1
					return
				scale.x *= -1
				last_dir = -1

		elif direction > 0:
			if last_dir != 1 :
				scale.x *= -1
				last_dir = 1
	
	
func _apply_gravity(delta: float) -> void:
	if is_changing_lane:
		return
	# Road lanes stand on a virtual floor below the walkway line.
	if lane != Lanes.GROUND_LANE and lane_baseline_y != INF:
		var fy := Lanes.floor_y(lane_baseline_y, lane)
		if velocity.y >= 0 and global_position.y >= fy:
			global_position.y = fy
			velocity.y = 0.0
			return
	if not is_on_floor():
		velocity.y += 300 * delta


func _update_lane_floor() -> void:
	# Capture the walkway ground line whenever physically standing on it.
	if is_on_floor() and lane == Lanes.GROUND_LANE and not is_changing_lane:
		lane_baseline_y = global_position.y


## The walkway tiles' collision occupies the road strip; road-lane bodies ignore
## Ground(2)/Platforms(6) and stand on virtual floors instead.
func _set_ground_collision(enabled: bool) -> void:
	set_collision_mask_value(2, enabled)
	set_collision_mask_value(6, enabled)


## Minimum enemy-center-to-player-center gap on the same lane, enforced as a hard
## floor (not a spring like the enemy-enemy push below) so nothing — chase drift,
## knockback, or an enemy-enemy shove — can land an enemy on top of the player.
const MIN_PLAYER_GAP := 26.0

## Nudges apart from other same-lane enemies within ENEMY_SEPARATION_DISTANCE so
## they don't sit stacked on top of each other (no physical collision resolves this
## since enemies deliberately don't collide with their own layer), and enforces
## MIN_PLAYER_GAP from the player (no physical collision resolves that either —
## enemy/player collision masks deliberately exclude each other, see collision
## layer comment above).
func _apply_enemy_separation(delta: float) -> void:
	if is_changing_lane or enemy_state_machine.current_state is DeadEnemyState:
		return
	var push := 0.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node) or not node is Enemy:
			continue
		var other: Enemy = node
		if other.lane != lane or other.is_changing_lane:
			continue
		if other.enemy_state_machine.current_state is DeadEnemyState:
			continue
		var dx: float = global_position.x - other.global_position.x
		var dist := absf(dx)
		if dist >= ENEMY_SEPARATION_DISTANCE:
			continue
		# Perfectly overlapping (dx == 0) has no direction to push in — break the
		# tie deterministically so both instances agree on opposite directions.
		var dir := signf(dx) if dist > 0.5 else (1.0 if get_instance_id() > other.get_instance_id() else -1.0)
		push += dir * (ENEMY_SEPARATION_DISTANCE - dist) / ENEMY_SEPARATION_DISTANCE
	if push != 0.0:
		# A direct position nudge rather than a velocity add — idle/attacking enemies
		# have their velocity.x actively damped to 0 by knockback friction every frame
		# (see _apply_knockback_decay), which would eat a velocity-based push before
		# move_and_slide ever applied it.
		global_position.x += push * ENEMY_SEPARATION_STRENGTH * delta
	_apply_player_separation()


func _apply_player_separation() -> void:
	if player == null or player.current_lane != lane:
		return
	var pdx := global_position.x - player.global_position.x
	var pdist := absf(pdx)
	if pdist >= MIN_PLAYER_GAP:
		return
	var pdir := signf(pdx) if pdist > 0.5 else (1.0 if get_instance_id() > player.get_instance_id() else -1.0)
	global_position.x = player.global_position.x + pdir * MIN_PLAYER_GAP


func is_same_lane_as_player() -> bool:
	return player != null and player.current_lane == lane


## Step one lane toward the player's lane (used while chasing). Combat is
## same-lane-only, so every non-locked enemy converges onto the player's exact
## lane — turn-taking attack slots (Globals.request_attack_slot) plus standoff
## distance (_chase_toward_player) are what keep a crowd from stacking up, not
## lane diversion (a previous version parked extra attackers on adjacent lanes,
## which left them permanently unable to attack — same-lane-gated combat check
## always failed for them; see docs/LANE_REFACTOR.md).
func _lane_chase() -> void:
	if lane_locked or is_changing_lane or lane_change_cooldown > 0.0 or lane_baseline_y == INF:
		return
	if player == null or player.is_changing_lane:
		return
	if lane == player.current_lane:
		return
	_start_lane_change(lane + signi(player.current_lane - lane))


## `duration` defaults to the snappy in-combat speed; callers that want a slower,
## more deliberate step (e.g. walking out of a spawn point) can override it.
func _start_lane_change(target: int, duration: float = LANE_CHANGE_DURATION) -> void:
	target = Lanes.clamp_lane(target)
	if target == lane or lane_baseline_y == INF:
		return
	is_changing_lane = true
	lane_change_cooldown = LANE_CHANGE_COOLDOWN
	velocity.y = 0.0
	if target != Lanes.GROUND_LANE:
		_set_ground_collision(false)
	# Snap draw order to the arriving lane immediately, not on tween completion —
	# the sprite is visually moving toward that depth for the whole tween, so
	# holding the departing lane's z_index for the tween's duration renders it
	# in front of/behind the wrong props and entities until it lands.
	z_index = Lanes.z_for(target)
	if _lane_tween:
		_lane_tween.kill()
	_lane_tween = create_tween()
	_lane_tween.tween_property(self, "global_position:y", Lanes.floor_y(lane_baseline_y, target), duration)
	_lane_tween.finished.connect(func() -> void:
		lane = target
		if target == Lanes.GROUND_LANE:
			_set_ground_collision(true)
		is_changing_lane = false)

func die() -> void:
	Globals.release_attack_slot(self)
	set_collision_mask_value(3, false )
	set_collision_mask_value(10, false )
	attack_timer.stop()
	range_timer.stop()
	velocity = Vector2.ZERO
	Globals.meter_maids_killed += 1
	Globals.meter_maid_death.emit()
	animated_sprite_2d.play("death")
	print("dead af")

	player_detection.monitorable = false
	player_detection.monitoring = false
	set_collision_layer_value(3, false)
	set_collision_layer_value(10, false)
	set_collision_mask_value(1, false)
	await get_tree().create_timer(1.5).timeout
	
	# Create blinking effect
	var tween = create_tween()
	#tween.set_loops(6) # 3 full blinks (fade out + fade in = 2 tweens per blink)

	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.chain().tween_property(self, "modulate:a", 1.0, 0.1).set_delay(0.2)

	tween.chain().tween_property(self, "modulate:a", 0.0, 0.1).set_delay(0.5)
	tween.chain().tween_property(self, "modulate:a", 1.0, 0.1).set_delay(0.2)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.1).set_delay(0.5)
	tween.chain().tween_property(self, "modulate:a", 1.0, 0.1).set_delay(0.2)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.1).set_delay(0.4)
	tween.chain().tween_property(self, "modulate:a", 1.0, 0.1).set_delay(0.2)
	# Wait for blinking to finish, then free the self
	await tween.finished
	queue_free()	

func should_turn() -> bool: 
	# Only check for turning if cooldown has expired
	if turn_cooldown <= 0.0 and (is_near_wall() or is_near_edge()):
		_handle_direction(last_dir * -1)
		turn_cooldown = turn_cooldown_duration  # Reset cooldown
		return true
	return false


func receive_hit(damage: int, knockback_strength: float = 200.0) -> void:
	_play_hit_effects()
	_apply_damage(damage)
	_apply_knockback(knockback_strength)

	if health <= 0 and has_state("DeadEnemyState"):
		var random_delay = randf_range(0, 0.2)
		await get_tree().create_timer(random_delay).timeout
		enemy_state_machine.change_state("DeadEnemyState")
		

func _play_hit_effects() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	var random_delay = randf_range(0, 0.2)
	await get_tree().create_timer(random_delay).timeout
	animation_player.play("Hit")
	receive_hit_audio.play()

func _apply_damage(damage: int) -> void:
	health -= damage
	print(health)


func _apply_knockback(knockback_strength: float = 200.0) -> void:
	var knockback_direction = (global_position - player.global_position).normalized()
	knockback_velocity = knockback_direction * knockback_strength
	velocity.y = -50.0

func _apply_knockback_decay(delta: float) -> void:
	# Apply knockback to velocity
	velocity.x += knockback_velocity.x * delta
	
	# Decay knockback over time
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta * 100)
	
	# Apply friction to horizontal movement when not being controlled by states
	if abs(knockback_velocity.x) < 10.0:  # Only apply friction when knockback is minimal
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	
func get_distance_to_player() -> float:
	return global_position.distance_to(player.global_position)

func can_see_player() -> bool:
	return  get_distance_to_player() <= detection_range

func is_too_far() -> bool:
	return  get_distance_to_player() >= 1500

func can_see_player_threshold(threshold_multiplier: float) -> bool:
	return get_distance_to_player() <= detection_range * threshold_multiplier
	
func is_the_player_in_attack_range() -> bool:
	return is_player_in_attack_range
	
func has_state(state: String) -> bool:
	return enemy_state_machine.states.has(state)


## Pure query — does NOT claim a slot. Claiming happens in AttackPlayerState.enter_state()
## (and its melee subclass) so a slot is only ever held while actually in that state;
## see Globals.request_attack_slot / release_attack_slot for the turn-taking pool.
func can_attack() -> bool:
	return (attack_timer.is_stopped() and is_player_in_attack_range
		and is_same_lane_as_player()
		and Globals.has_attack_slot_available(attack_category, self))
	
