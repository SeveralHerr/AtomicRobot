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
## Trim on every enemy's hurt "oof" (ReceiveHitAudio), on top of each scene's authored
## volume_db: -6 dB halves amplitude. One knob for all maids; player/other sfx untouched.
const HIT_SOUND_TRIM_DB: float = -6.0
@onready var line_of_sight: LineOfSight = $LineOfSight
@onready var meter_line_of_sight: LineOfSight = $MeterLineOfSight

@export var persist: bool = false

var is_player_in_attack_range: bool = false

## True from the first frame of die() — i.e. the moment the kill lands, not when the
## corpse finally frees itself ~3.5s later after the death clip and the blink-out.
##
## Everything that asks "is this enemy still in the fight?" must read this rather than
## `current_state is DeadEnemyState` or `is_instance_valid()`:
##   * the state check misses enemies whose die() is driven directly (and the ~0.2s
##     randomised gap in receive_hit before the state actually flips), and
##   * an instance-validity check counts the corpse as a live enemy for the whole
##     death animation — which is what used to make wave events hang after the last
##     kill and made the living queue up around a body instead of walking over it.
var is_dead: bool = false

# Stats
var health: int = 2
var move_speed: float = 100.0
var coins: int = 1
var attack_range: int = 120
var attack_cooldown: float = 4
var detection_range: float = 600.0
## Which attack-slot pool this enemy competes in ("melee" / "ranged"). Base Enemy
## throws coins (AttackPlayerState._do_hit), so ranged is the default; melee
## subclasses override it. See Globals' attack-slot manager.
@export var attack_category: String = "ranged"
## Direction the sprite is LOOKING: +1 = right, -1 = left. All meter-maid art is
## authored facing right, so +1 is the unmirrored transform. Read this rather than
## `scale.x` — see set_facing() for why scale.x lies about a horizontal flip.
var facing: int = 1
## Authored (unmirrored) scale, captured before anything flips us — set_facing()
## rebuilds the transform from this so instance scaling in the editor survives.
var _base_scale: Vector2 = Vector2.ONE
## Below this world-space X gap, a face target counts as "on top of us" and the
## current facing is kept — stops jitter when a target is nearly vertically aligned.
const FACE_DEADZONE := 2.0
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
## World Y of the walkway FLOOR SURFACE (where soles rest) — not this node's Y.
## Body-independent, so the spawner can seed it from the player; INF until known.
var lane_floor_y: float = INF
# Distance from this node's origin down to its soles. Measured lazily: the
# collision shape isn't reachable until the instanced scene has its children.
var _foot_offset: float = 0.0
var _foot_offset_measured: bool = false
## Slight depth offset within the current lane (px, down-screen positive) so a lane
## doesn't read as sprites on one ruled line. Re-rolled on every lane change and
## always 0.0 on the ground lane — see Lanes.random_in_lane_offset.
var lane_depth_offset: float = 0.0
var is_changing_lane: bool = false
var _lane_tween: Tween
var lane_change_cooldown: float = 0.0
const LANE_CHANGE_COOLDOWN := 0.7
const LANE_CHANGE_DURATION := 0.2
## Seconds left before this enemy may attack at all. Set by spawners that pour a
## squad onto the street (BuildingDoorEncounter) so the squad files out into its
## lanes before anyone swings — otherwise the player is swarmed at the doorway.
## Only attacking is gated: the enemy still moves, chases and can be hit.
var spawn_grace: float = 0.0

# Runtime data
var player: Player

func _init() -> void:
	enemy_state_machine = EnemyStateMachine.new(self)
	
	add_child(enemy_state_machine)

func _ready() -> void:
	_base_scale = Vector2(absf(scale.x), scale.y)
	receive_hit_audio.volume_db += HIT_SOUND_TRIM_DB
	lane = Lanes.clamp_lane(starting_lane)
	z_index = Lanes.z_for(lane)
	_refresh_depth_z()
	# Ground collision stays ON while the walkway line is still unknown, even on a
	# road lane: a hand-placed enemy authored straight onto lane 1-3 has no baseline
	# and nothing virtual to stand on, so dropping the mask here left it falling
	# forever. _update_lane_floor() takes it off the moment it has a floor line.
	_set_ground_collision(lane == Lanes.GROUND_LANE or lane_floor_y == INF)
	lane_depth_offset = Lanes.random_in_lane_offset(lane)
	# Deferred: reparenting inside _ready trips "parent node is busy setting up children".
	Lanes.join_sort_layer.call_deferred(self)
	attack_timer.wait_time = attack_cooldown
	add_to_group("enemies")
	# The sight ray must reach as far as this enemy claims to detect, or chase
	# logic gated on line-of-sight can never fire at the edge of detection range.
	line_of_sight.max_range = maxf(line_of_sight.max_range, detection_range)
	_resolve_player()
	if player and player.is_dead:
		print("Dead player detected")
		queue_free()

	Globals.player_death.connect(func():
		if not is_dead:
			animated_sprite_2d.play("idle")
		set_physics_process(false)
		set_process(false))
	
func _process(delta: float) -> void:
	if is_too_far() and not persist:
		print("enemy too far, purgiing....")
		queue_free()

func _physics_process(delta: float) -> void:
	_resolve_player()
	_refresh_player_in_attack_range()
	_update_lane_floor()
	_apply_gravity(delta)
	_apply_knockback_decay(delta)
	enemy_state_machine.update(delta)
	turn_cooldown -= delta
	lane_change_cooldown -= delta
	spawn_grace = maxf(spawn_grace - delta, 0.0)
	_apply_enemy_separation(delta)

	move_and_slide()


## Resolve (and re-resolve) the player. Node `_ready` order decides whether the
## player is already in its group when a hand-placed enemy readies, and the
## instance is replaced outright on a scene reload — so a cache-once lookup
## leaves enemies permanently inert (or null-crashing) rather than just late.
func _resolve_player() -> Player:
	if player != null and is_instance_valid(player):
		return player
	player = get_tree().get_first_node_in_group("player") as Player
	return player


## Recomputed from the live overlap set every physics tick instead of latched by
## body_entered/body_exited. The latch had two failure modes that both read in
## game as "the enemy randomly stopped attacking": the callbacks accepted ANY
## body, so one non-player body leaving cleared a flag the player was still
## setting (the window maid's detector masks Ground as well as Player); and a
## teleport, a lane snap or a deferred add could drop an edge outright and strand
## the flag on the wrong value with nothing to correct it.
func _refresh_player_in_attack_range() -> void:
	if not player_detection.monitoring:
		is_player_in_attack_range = false
		return
	for body in player_detection.get_overlapping_bodies():
		if body is Player:
			is_player_in_attack_range = true
			return
	is_player_in_attack_range = false


func is_player_in_line_of_sight() -> bool:
	return line_of_sight.is_player_line_of_sight()

func is_meter_in_line_of_sight() -> bool:
	var nearest := Globals.nearest_meter(global_position)
	if nearest == null:
		return false
	return meter_line_of_sight.is_meter_line_of_sight(nearest.global_position)


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


## Ledge check for the direction we are about to move in (+1 right, -1 left).
##
## Chase movement used to be gated on is_near_edge(), which reports an edge on
## EITHER side — so an enemy that walked up to a ledge could no longer move in
## the one direction that would take it away from that ledge, and froze on the
## spot permanently. Only the ray on the leading side can actually stop us.
func is_near_edge_ahead(dir: int) -> bool:
	if lane != Lanes.GROUND_LANE or dir == 0:
		return false
	var left_offset := ray_cast_2d_left_down.global_position.x - global_position.x
	var leading := ray_cast_2d_left_down if leading_ray_is_left(left_offset, dir) else ray_cast_2d_right_down
	return not leading.is_colliding()


## Which down-ray sits on the side we are moving toward.
##
## The rays are children of this body, whose transform mirrors on x when facing
## left (see set_facing), so the node *named* "left" is on the world right half
## the time — the choice has to be made from the ray's actual world offset, not
## its name. Pure and static so it can be unit-tested headless.
static func leading_ray_is_left(left_ray_offset_x: float, dir: int) -> bool:
	return signf(left_ray_offset_x) == signf(float(dir))


func is_near_wall() -> bool:
	# Check for wall collisions
	return ray_cast_2d_left_wall.is_colliding() or ray_cast_2d_right_wall.is_colliding()

	
func _face_player() -> void:
	if player == null:
		return
	face_towards(player.global_position.x)


## Turn to look at a world-space X coordinate (a meter, the player, a waypoint).
func face_towards(world_x: float) -> void:
	var dx := world_x - global_position.x
	if absf(dx) < FACE_DEADZONE:
		return
	set_facing(signi(dx))


## Absolute facing setter — +1 looks right, -1 looks left.
##
## Two things here are deliberate and both were bugs in the old `scale.x *= -1`
## toggle (`_handle_direction`):
##
## 1. It is *absolute*, not a toggle. The old version only flipped when its argument
##    disagreed with the previously *requested* direction, so which way the sprite
##    actually pointed was bookkeeping that any other writer to scale.x/flip_h
##    silently desynced. It also flipped on the *opposite* of the movement direction
##    (callers passed the away-from-target vector), so every new caller had a 50/50
##    chance of coming out mirrored — FindMeterState drew that short straw and
##    walked backwards to every meter.
##
## 2. It writes the transform's basis columns instead of assigning `scale`/`scale.x`.
##    Transform2D has no way to store a negative x-scale, so Godot re-decomposes
##    `scale = (-1, 1)` into `rotation = PI, scale = (1, -1)` — a visually identical
##    mirror, but one that `scale.x` reads back from as *+1*. Worse, Node2D.set_scale
##    only rescales the existing columns and preserves their direction, so once the
##    mirror has migrated into `rotation` no assignment to `scale.x` can undo it and
##    the enemy is stuck facing the wrong way. Setting the columns is idempotent and
##    survives move_and_slide (which only translates the origin).
func set_facing(dir: int) -> void:
	if dir == 0:
		return
	facing = signi(dir)
	var t := transform
	t.x = Vector2(_base_scale.x * facing, 0.0)
	t.y = Vector2(0.0, _base_scale.y)
	transform = t


func _apply_gravity(delta: float) -> void:
	if is_changing_lane:
		return
	# Road lanes stand on a virtual floor below the walkway line.
	if lane != Lanes.GROUND_LANE and lane_floor_y != INF:
		var fy := lane_stand_y(lane)
		if velocity.y >= 0 and global_position.y >= fy:
			global_position.y = fy
			velocity.y = 0.0
			return
	if not is_on_floor():
		velocity.y += 300 * delta


## Distance from this node's origin down to its soles — see Lanes.measure_foot_offset.
func foot_offset() -> float:
	if not _foot_offset_measured:
		_foot_offset = Lanes.measure_foot_offset(self)
		_foot_offset_measured = true
	return _foot_offset


## World Y this node's origin sits at when standing on `for_lane`, including its
## in-lane depth offset. The ground lane ignores the offset outright — real floor
## collision there would fight it, and a contaminated capture in _update_lane_floor()
## would bake the jitter into the shared baseline every other body reads.
func lane_stand_y(for_lane: int) -> float:
	var offset := 0.0 if for_lane == Lanes.GROUND_LANE else lane_depth_offset
	return Lanes.stand_y(lane_floor_y, for_lane, foot_offset()) + offset


## Keep the draw z in step with where this body actually stands. Cheap enough to poll:
## it only writes when the value changes, and it self-heals the frame a baseline is
## first captured (before that, depth_z has no floor line to measure against).
func _refresh_depth_z() -> void:
	var z := Lanes.depth_z(lane, lane_stand_y(lane) + foot_offset(), lane_floor_y)
	if z != z_index:
		z_index = z


func _update_lane_floor() -> void:
	_refresh_depth_z()
	if is_changing_lane:
		return
	# Capture the walkway ground line whenever physically standing on it. Stored as
	# the FLOOR (soles), not this node's Y — a maid's origin sits 27px above its
	# feet and the player's 19.75px, so an origin-based baseline could not be shared
	# between them without one of the two standing at the wrong height.
	if is_on_floor() and lane == Lanes.GROUND_LANE:
		# Platform maids and anyone knocked onto raised geometry are still on the
		# ground lane; Lanes.accepts_baseline keeps their street line from climbing up
		# to whatever they happen to be standing on (it feeds coin and power-up drop
		# heights as well as this body's own virtual floors).
		var candidate := global_position.y + foot_offset()
		var real_lane := Lanes.lane_for_floor(lane_floor_y, candidate)
		if real_lane != Lanes.GROUND_LANE and not lane_locked:
			_settle_onto_lane(real_lane)
			return
		if Lanes.accepts_baseline(lane_floor_y, candidate):
			lane_floor_y = candidate
		return
	# Authored straight onto a road lane (starting_lane 1-3): _ready kept real ground
	# collision so we'd land on something. First contact defines the walkway line;
	# from here on the lane's virtual floor takes over.
	if is_on_floor() and lane_floor_y == INF:
		lane_floor_y = global_position.y + foot_offset()
		_set_ground_collision(false)
		global_position.y = lane_stand_y(lane)


## Adopt `road_lane` in place: off real collision, onto that lane's virtual floor.
## For a ground-lane body that ended up standing in the road strip (see
## Lanes.lane_for_floor) — the street baseline stays where it is.
func _settle_onto_lane(road_lane: int) -> void:
	lane = road_lane
	lane_depth_offset = Lanes.random_in_lane_offset(lane)
	_set_ground_collision(false)
	global_position.y = lane_stand_y(lane)
	velocity.y = 0.0
	_refresh_depth_z()


## The walkway tiles' collision occupies the road strip; road-lane bodies ignore
## Ground(2)/Platforms(6) and stand on virtual floors instead.
func _set_ground_collision(enabled: bool) -> void:
	set_collision_mask_value(2, enabled)
	set_collision_mask_value(6, enabled)


## Nudges apart from other same-lane enemies within ENEMY_SEPARATION_DISTANCE so
## they don't sit stacked on top of each other (no physical collision resolves this
## since enemies deliberately don't collide with their own layer).
func _apply_enemy_separation(delta: float) -> void:
	if is_changing_lane or is_dead:
		return
	var push := 0.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node) or not node is Enemy:
			continue
		var other: Enemy = node
		if other.lane != lane or other.is_changing_lane:
			continue
		# Corpses take up no space: a dying maid is on the floor for several seconds
		# and the living should be able to close over her, not shuffle around her.
		if other.is_dead:
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


func is_same_lane_as_player() -> bool:
	return player != null and player.current_lane == lane


## Step one lane toward the player's lane (used while chasing). Always targets the
## player's own lane.
##
## This used to route chasers into a *free adjacent* lane whenever another attacker
## was already camped near the player on the wanted lane, one enemy per lane. That
## lane exclusivity was the cause of the one-attacker bug: can_attack() requires lane
## parity (Lanes.can_engage), so every enemy parked in a neighbouring lane was
## permanently unable to attack and the wave collapsed into a 1v1. Lanes are purely
## about depth/dodging again; attack pacing now lives in Globals' attack-slot pool,
## and horizontal crowding is handled by _apply_enemy_separation, which fans the
## squad out along X within the player's lane.
func _lane_chase() -> void:
	if lane_locked or is_changing_lane or lane_change_cooldown > 0.0 or lane_floor_y == INF:
		return
	if player == null or player.is_changing_lane:
		return
	if player.current_lane == lane:
		return
	var target := lane + signi(player.current_lane - lane)
	if target == Lanes.GROUND_LANE and Lanes.walkway_blocked(self, get_node_or_null("CollisionShape2D"), Vector2(global_position.x, lane_stand_y(target))):
		return
	_start_lane_change(target)


## `duration` defaults to the snappy in-combat speed; callers that want a slower,
## more deliberate step (e.g. walking out of a spawn point) can override it.
func _start_lane_change(target: int, duration: float = LANE_CHANGE_DURATION) -> void:
	target = Lanes.clamp_lane(target)
	if target == lane or lane_floor_y == INF:
		return
	is_changing_lane = true
	lane_change_cooldown = LANE_CHANGE_COOLDOWN
	velocity.y = 0.0
	# Fresh jitter for the lane being entered, picked before the tween reads its
	# destination so the step lands on the offset rather than sliding onto it after.
	lane_depth_offset = Lanes.random_in_lane_offset(target)
	if target != Lanes.GROUND_LANE:
		_set_ground_collision(false)
	if _lane_tween:
		_lane_tween.kill()
	_lane_tween = create_tween()
	_lane_tween.tween_property(self, "global_position:y", lane_stand_y(target), duration)
	_lane_tween.finished.connect(func() -> void:
		lane = target
		_refresh_depth_z()
		if target == Lanes.GROUND_LANE:
			_set_ground_collision(true)
		is_changing_lane = false)

func die() -> void:
	# Re-entrant kills (a second hit landing inside receive_hit's randomised delay,
	# or a hazard finishing off an already-dying maid) would otherwise double-count
	# the kill, re-roll the drop table and restart the fade.
	if is_dead:
		return
	is_dead = true
	set_collision_mask_value(3, false )
	set_collision_mask_value(10, false )
	attack_timer.stop()
	# A corpse is a valid instance for seconds (1.5s death fade + the blink-out), and
	# _prune_attack_slots only drops instances that have actually been freed — so
	# without an explicit release here a dying maid holds her slot the whole time and
	# the rest of the wave stands around waiting for a turn that never comes.
	Globals.release_attack_slot(self)
	range_timer.stop()
	velocity = Vector2.ZERO
	Globals.meter_maids_killed += 1
	Globals.meter_maid_death.emit()
	_maybe_drop_powerup()
	animated_sprite_2d.play("death")
	print("dead af")

	player_detection.monitorable = false
	player_detection.monitoring = false
	set_collision_layer_value(3, false)
	set_collision_layer_value(10, false)
	set_collision_mask_value(1, false)
	await get_tree().create_timer(1.5).timeout
	await _play_death_blink()
	_on_death_blink_finished()

## Blinks the corpse out: 4 fade-out/fade-in pulses on _death_blink_target().
func _play_death_blink() -> void:
	var target := _death_blink_target()
	var tween := create_tween()
	for delays in [[0.0, 0.2], [0.5, 0.2], [0.5, 0.2], [0.4, 0.2]]:
		tween.tween_property(target, "modulate:a", 0.0, 0.1).set_delay(delays[0])
		tween.tween_property(target, "modulate:a", 1.0, 0.1).set_delay(delays[1])
	await tween.finished

## What blinks on death. The whole enemy by default; subclasses whose scene carries
## scenery (a window frame) narrow it to just the maid's sprite.
func _death_blink_target() -> CanvasItem:
	return self

## Called once the blink-out is done. The default removes the corpse.
func _on_death_blink_finished() -> void:
	queue_free()

## Roll the drop table for this kill. Rolled from die() rather than after the 1.5s
## death fade so the pickup lands while the fight it was earned in is still going.
##
## PowerupSystem owns the roll (and the pity counter that guarantees a drop after a
## drought), so this must run exactly once per death — die() is the only caller.
func _maybe_drop_powerup() -> void:
	var id := PowerupSystem.roll_drop()
	if id != "":
		Utils.drop_powerup(self, id)


func should_turn() -> bool:
	# Only check for turning if cooldown has expired
	if turn_cooldown <= 0.0 and (is_near_wall() or is_near_edge()):
		set_facing(-facing)
		turn_cooldown = turn_cooldown_duration  # Reset cooldown
		return true
	return false


func receive_hit(damage: int, knockback_strength: float = 200.0) -> void:
	# A corpse doesn't flinch, bleed health or get knocked around.
	if is_dead:
		return
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
	# Hazards (cars, hitboxes) can damage an enemy with no player resolved — fall
	# back to knocking it backwards off its own facing rather than crashing.
	var knockback_direction := Vector2(-facing, 0.0)
	if _resolve_player() != null:
		knockback_direction = (global_position - player.global_position).normalized()
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
	
## INF when there is no player, so every "within range" test below reads false.
func get_distance_to_player() -> float:
	if _resolve_player() == null:
		return INF
	return global_position.distance_to(player.global_position)

func can_see_player() -> bool:
	return  get_distance_to_player() <= detection_range

func is_too_far() -> bool:
	# No player is not "too far" — purging on it would delete every enemy in a
	# test scene (and every enemy spawned a frame before the player registers).
	if _resolve_player() == null:
		return false
	return  get_distance_to_player() >= 1500

func can_see_player_threshold(threshold_multiplier: float) -> bool:
	return get_distance_to_player() <= detection_range * threshold_multiplier

func is_the_player_in_attack_range() -> bool:
	return is_player_in_attack_range

func has_state(state: String) -> bool:
	return enemy_state_machine.states.has(state)


## Whether this enemy competes in Globals' turn-taking attack-slot pool.
##
## The pool exists to pace a CROWD, so only crowd members belong in it. Two kinds of
## enemy sit outside it and must never hold a slot: lane-locked maids (window and
## platform) are stationary hazards raining coins onto the street from their own
## axis, and two of them would silence every maid actually walking it. FinalBoss
## overrides this for a sharper reason — it enters BossAttackPlayerState in _ready()
## and has no state to exit into, so it would claim a ranged slot on spawn and hold
## it until death, leaving one slot for the entire boss room.
func competes_for_attack_slots() -> bool:
	return not lane_locked


func can_attack() -> bool:
	if spawn_grace > 0.0:
		return false
	if not attack_timer.is_stopped() or not is_player_in_attack_range:
		return false
	if player == null:
		return false
	if not Lanes.can_engage(lane, player.current_lane, lane_locked):
		return false
	if not competes_for_attack_slots():
		return true
	# Pure query, never a claim — this is polled every frame from ChasePlayerState.update.
	# The claim/release pair lives in AttackPlayerState; passing `self` means the enemy
	# currently holding the slot keeps reading as available.
	return Globals.has_attack_slot_available(attack_category, self)
