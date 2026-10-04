extends CharacterBody2D
class_name Enemy

## Base enemy class with common functionality and state management

# State management
var enemy_state_machine: EnemyStateMachine
## Lane movement collaborator (virtual depth) — see EnemyLaneMover.
var _lanes: EnemyLaneMover

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
##   * the state check misses enemies whose die() is driven directly, and
##   * an instance-validity check counts the corpse as a live enemy for the whole
##     death animation — which is what used to make wave events hang after the last
##     kill and made the living queue up around a body instead of walking over it.
var is_dead: bool = false

# Stats (on the DamageRules scale; fighters hit for 3-6)
var health: int = DamageRules.MAID_HEALTH
## Full health, for the hit pips' fraction. Subclasses that change `health` set both.
var max_health: int = DamageRules.MAID_HEALTH
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
## Slight depth offset within the current lane (px, down-screen positive) so a lane
## doesn't read as sprites on one ruled line. Re-rolled on every lane change and
## always 0.0 on the ground lane — see Lanes.random_in_lane_offset.
var lane_depth_offset: float = 0.0
var is_changing_lane: bool = false
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
	_lanes = EnemyLaneMover.new(self)

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
	EnemySeparation.apply(self, delta)

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


func move_towards_target(target_pos: Vector2, delta: float):
	var direction = (target_pos - global_position).normalized()
	var target_velocity = direction * move_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, 2000 * delta)


## Ledge on either side — see EnemyLedgeProbe for why road lanes never have one.
func is_near_edge() -> bool:
	return EnemyLedgeProbe.near_edge(lane, ray_cast_2d_left_down, ray_cast_2d_right_down)


## Ledge on the side we are about to move toward (+1 right, -1 left).
func is_near_edge_ahead(dir: int) -> bool:
	return EnemyLedgeProbe.near_edge_ahead(self, lane, ray_cast_2d_left_down, ray_cast_2d_right_down, dir)


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


## Absolute facing setter — +1 looks right, -1 looks left. Writes the basis, not
## scale.x: see FacingTransform for why.
func set_facing(dir: int) -> void:
	if dir == 0:
		return
	facing = signi(dir)
	transform = FacingTransform.mirrored(transform, _base_scale, facing)


func _apply_gravity(delta: float) -> void:
	if is_changing_lane or _lanes.rest_on_virtual_floor():
		return
	if not is_on_floor():
		velocity.y += 300 * delta


# --- Lane movement: thin delegators to EnemyLaneMover (callers across the game use these).
func foot_offset() -> float:
	return _lanes.foot_offset()


func lane_stand_y(for_lane: int) -> float:
	return _lanes.stand_y(for_lane)


func _refresh_depth_z() -> void:
	_lanes.refresh_depth_z()


func _update_lane_floor() -> void:
	_lanes.update_floor()


func _set_ground_collision(enabled: bool) -> void:
	_lanes.set_ground_collision(enabled)


func _lane_chase() -> void:
	_lanes.chase()


## `duration` defaults to the snappy in-combat speed; callers that want a slower,
## more deliberate step (e.g. walking out of a spawn point) can override it.
func _start_lane_change(target: int, duration: float = LANE_CHANGE_DURATION) -> void:
	_lanes.start_change(target, duration)


func is_same_lane_as_player() -> bool:
	return player != null and player.current_lane == lane


func die() -> void:
	# Re-entrant kills (two blows on the same frame, or a hazard finishing off an
	# already-dying maid) would otherwise double-count
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

	# Deferred: die() can run inside a physics callback (a car's body_entered kills
	# via receive_hit), where Area2D refuses a direct monitorable change.
	player_detection.set_deferred("monitorable", false)
	player_detection.set_deferred("monitoring", false)
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
	if flinches():
		_flinch()

	# Same frame as the blow: the Hit flash, the "oof" and the death all land with the
	# hitstop. (A random 0-0.2s delay here used to read as input lag.)
	if health <= 0 and has_state("DeadEnemyState"):
		enemy_state_machine.change_state("DeadEnemyState")


func _play_hit_effects() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	animation_player.play("Hit")
	# Apply the first key now: a hitstop freezes time this very frame, and the
	# white flash has to be on screen for the freeze, not after it.
	animation_player.advance(0.0)
	receive_hit_audio.play()

func _apply_damage(damage: int) -> void:
	health -= damage
	if shows_hp_pips():
		EnemyHpPips.show_on(self)


## Seconds a blow holds off this enemy's next swing. With kills taking 3-4 blows
## (DamageRules), a maid that kept swinging through them traded hit for hit.
const FLINCH_TIME := 0.8


## A blow staggers her: a swing still winding up starts over, and no new one can
## begin for FLINCH_TIME. A swing already released (coin in the air) is not undone.
func _flinch() -> void:
	if attack_timer.time_left < FLINCH_TIME:
		var cooldown := attack_timer.wait_time
		attack_timer.start(FLINCH_TIME)
		attack_timer.wait_time = cooldown
	var st = enemy_state_machine.current_state
	if st is AttackPlayerState and not st.get("_released") 			and animated_sprite_2d.animation == st.clip:
		animated_sprite_2d.set_frame_and_progress(0, 0.0)


## Whether blows stagger this enemy. The boss is planted and has his own rhythm.
func flinches() -> bool:
	return true


## The little health bar a blow pops over the head. The boss has his own HUD bar.
func shows_hp_pips() -> bool:
	return true


func _apply_knockback(knockback_strength: float = 200.0) -> void:
	# Hazards (cars, hitboxes) can damage an enemy with no player resolved — the
	# knockback then falls back to its own facing rather than crashing.
	var from: Variant = player.global_position if _resolve_player() != null else null
	EnemyKnockback.apply(self, knockback_strength, from)


func _apply_knockback_decay(delta: float) -> void:
	EnemyKnockback.decay(self, delta)


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
