extends Node

const COIN_BULLET = preload("res://scenes/coin_bullet.tscn")
const HIT_FX = preload("res://scenes/hit_fx.tscn")
const BRIEFCASE_BULLET = preload("res://scenes/briefcase_bullet2.tscn")
const POWERUP_PICKUP = preload("res://scenes/powerup_pickup.tscn")


## Drop a power-up pickup where `enemy` fell. Returns the pickup, or null if the id
## is unknown or the enemy is already out of the tree.
static func drop_powerup(enemy: Node2D, id: String) -> Node2D:
	if enemy == null or not enemy.is_inside_tree() or not PowerupRules.has_id(id):
		return null
	var parent := enemy.get_tree().current_scene
	if parent == null:
		return null
	var pickup := POWERUP_PICKUP.instantiate()
	# Set before add_child so the pickup's _ready() already has its final identity.
	pickup.powerup_id = id
	pickup.lane = enemy.lane
	parent.add_child(pickup)
	# Hover above the LANE'S FLOOR LINE, not above the enemy's origin. Origins sit
	# different distances above their soles (a maid's is 27px up, the player's
	# 19.75px), so an origin-relative drop would float at a visibly different height
	# for every enemy type. See Lanes.measure_foot_offset.
	var floor_line: float = enemy.global_position.y + enemy.foot_offset()
	if is_finite(enemy.lane_floor_y):
		floor_line = Lanes.floor_y(enemy.lane_floor_y, enemy.lane)
	pickup.global_position = Vector2(enemy.global_position.x, floor_line - PowerupPickup.HOVER_HEIGHT)
	return pickup
static func shake_node2d(node: Node2D, strength: float = 10.0, duration: float = 0.3, frequency: float = 0.02) -> void:
	var original_pos = node.position
	var tween = node.get_tree().create_tween()
	var steps = int(duration / frequency)
	for i in range(steps):
		var random_offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		tween.tween_property(node, "position", original_pos + random_offset, frequency)
	# Ensure the last tween resets to the original position
	tween.tween_property(node, "position", original_pos, frequency)
	
	
## Hitstop: freeze the game (Engine.time_scale = 0) for `duration` REAL seconds.
## - A request during a running pause extends it; it never shortens it.
## - Skipped if time_scale is already not 1.0 — someone else (BossJuice slow-mo, the
##   death beat) owns time, and we must not clobber it.
## - On release, time is only restored if it is still ours (still 0).
## - Off in headless runs (unit tests, the autoplay bot): a wall-clock freeze would
##   make --fixed-fps runs non-deterministic. Tests lift that via allow_headless_hit_pause.
## - A fixed clock (Movie Maker's --write-movie, and --fixed-fps: every windowed
##   autoplay run) gets a near-freeze. There time_scale 0 makes the frame delta NaN:
##   Movie Maker's release timer never fired, and any awake RigidBody2D (leaves a gust
##   just kicked, coins in flight) integrated NaN for good, logging a "Vector2 cannot
##   be normalized" warning per body per frame (171k in one windowed run).
const HIT_PAUSE_SCALE := 0.0
const MOVIE_HIT_PAUSE_SCALE := 0.01
static var allow_headless_hit_pause := false
## Last requested duration, recorded even when skipped (lets tests see the ask).
static var last_hit_pause_request := 0.0
static var _hit_pause_until_usec := 0
static var _hit_pause_running := false


## Set by launchers that pass --fixed-fps (the autoplay runner): Godot strips engine
## flags from OS.get_cmdline_args(), so the game cannot see that one for itself.
static var fixed_clock := false


static func hit_pause_scale(on_fixed_clock: bool = OS.has_feature("movie") or fixed_clock) -> float:
	return MOVIE_HIT_PAUSE_SCALE if on_fixed_clock else HIT_PAUSE_SCALE


static func apply_hit_pause(node: Node, duration := 0.05) -> void:
	last_hit_pause_request = duration
	if node == null or not node.is_inside_tree() or duration <= 0.0:
		return
	if DisplayServer.get_name() == "headless" and not allow_headless_hit_pause:
		return
	var until := Time.get_ticks_usec() + int(duration * 1000000.0)
	if _hit_pause_running:
		_hit_pause_until_usec = maxi(_hit_pause_until_usec, until)
		return
	if Engine.time_scale != 1.0:
		return
	_hit_pause_running = true
	_hit_pause_until_usec = until
	var scale := hit_pause_scale()
	Engine.time_scale = scale
	var tree := node.get_tree()
	var left := duration
	while left > 0.0:
		# process_always, ignore_time_scale: the timer must run while time is frozen.
		await tree.create_timer(left, true, false, true).timeout
		left = float(_hit_pause_until_usec - Time.get_ticks_usec()) / 1000000.0
	if Engine.time_scale == scale:
		Engine.time_scale = 1.0
	_hit_pause_running = false


## Hit sparks at `hit_position`. A sibling drawn just above `target`, not its child:
## the burst stays where the blow landed while the target is knocked back or
## mirrored, and it isn't swallowed by the target's own white hit flash.
static func hit_effect(target: Node2D, hit_position: Vector2) -> Node2D:
	var instance: Node2D = HIT_FX.instantiate()
	var parent := target.get_parent()
	if parent == null:
		parent = target
	parent.add_child(instance)
	instance.z_index = target.z_index + 1
	instance.global_position = hit_position
	instance.start()
	return instance

static func shake_two_node2d(node1: Node2D, node2: Node2D, strength1: float = 10.0, duration1: float = 0.3, strength2: float = 10.0, duration2: float = 0.3, frequency: float = 0.02) -> void:
	var original_pos1 = node1.position
	var original_pos2 = node2.position
	var tween1 = node1.get_tree().create_tween()
	var tween2 = node2.get_tree().create_tween()
	var steps = int(min(duration1, duration2) / frequency)
	for i in range(steps):
		var base_offset = Vector2(
			randf_range(-1, 1),
			randf_range(-1, 1)
		)
		var offset1 = base_offset * strength1
		var offset2 = base_offset * strength2
		tween1.tween_property(node1, "position", original_pos1 + offset1, frequency)
		tween2.tween_property(node2, "position", original_pos2 + offset2, frequency)
	# Ensure the last tween resets to the original position
	tween1.tween_property(node1, "position", original_pos1, frequency)
	tween2.tween_property(node2, "position", original_pos2, frequency)

## Coin throwing factory methods
static func throw_coin(spawn_position: Vector2, target_position: Vector2, parent_node: Node, use_arc: bool = false, lane: int = Lanes.GROUND_LANE) -> Bullet:
	var instance = COIN_BULLET.instantiate()
	parent_node.add_child(instance)
	instance.lane = lane
	# Road lanes have no real floor — hand the coin its lane's virtual floor, and
	# tell it where it was thrown from so a throw can't snap up-screen. The shadow
	# sits on that lane's floor so the coin's lane reads.
	var player = parent_node.get_tree().get_first_node_in_group("player")
	if player and player.lanes_active():
		# Rest ON the lane floor, beside its shadow. Coins used to settle on the
		# player's standing line (their origin, ~20px up) and hung in mid-air.
		var floor_y: float = Lanes.floor_y(player.lane_floor_y, lane)
		instance.set_lane_floor(lane, floor_y - Bullet.REST_LIFT, spawn_position.y)
		instance.show_shadow(floor_y)
	var direction = (target_position - spawn_position).normalized()
	instance.start(spawn_position, direction, use_arc)
	return instance

## Small per-shot spread so simultaneous throws from stacked/close enemies don't
## fly the exact same path and visually overlap.
const PROJECTILE_TARGET_JITTER: float = 10.0

static func throw_coin_from_enemy(enemy: Node, use_arc: bool = false, offset: int = 0) -> void:
	var player = enemy.get_tree().get_first_node_in_group("player")
	if not enemy or not player:
		return
	# global_position, not global + LOCAL offset: set_facing() mirrors the enemy's
	# transform on x, so a raw local offset put the projectile on the maid's back
	# whenever she faced left.
	var spawn_pos = enemy.coin_spawn_point.global_position
	var lane: int = coin_lane_for(enemy, player)
	var target_pos: Vector2 = player.enemy_attack_position.global_position
	# Fly at the player's chest height ON THE COIN'S LANE, not at wherever the
	# player is now: this used to re-aim at the player's lane on the release frame,
	# so stepping a lane during the wind-up was tracked and the coin hit anyway.
	if player.lanes_active():
		target_pos.y = player.lane_stand_y(lane) + player.enemy_attack_position.position.y
	target_pos.y += offset
	target_pos.x += randf_range(-PROJECTILE_TARGET_JITTER, PROJECTILE_TARGET_JITTER)
	throw_coin(spawn_pos, target_pos, enemy.player.get_parent(), use_arc, lane)

## The lane a thrown coin belongs to. A street maid throws down HER lane (she only
## swings once lined up with you). Lane-locked maids are up on the building and
## lob onto the lane you stood in at the release frame — a step after it dodges.
static func coin_lane_for(enemy: Node, player: Node) -> int:
	if enemy is Enemy and not enemy.lane_locked:
		return enemy.lane
	return player.current_lane

## Briefcases: the boss's throws and the ceiling drops. `speed` is the launch speed in
## px/s — slower than a coin so a briefcase reads as lobbed and can be dodged.
static func throw_briefcase(spawn_position: Vector2, target_position: Vector2, parent_node: Node, use_arc: bool = false, gravity: float = 0.55, is_falling: bool = false, speed: float = 600.0) -> Bullet:
	var instance = BRIEFCASE_BULLET.instantiate()
	parent_node.add_child(instance)
	var direction = (target_position - spawn_position).normalized()
	instance.initial_speed = speed
	if is_falling:
		instance.enable_passthrough()
	instance.start(spawn_position, direction, use_arc, gravity)
	return instance

static func throw_coin_delayed(enemy: Node, delay: float = 0.3, use_arc: bool = false) -> void:
	if not enemy:
		return
	await enemy.get_tree().create_timer(delay).timeout
	throw_coin_from_enemy(enemy, use_arc)
