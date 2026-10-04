extends RefCounted
class_name EnemyLaneMover

## Lane (virtual depth) movement for one Enemy — see docs/LANE_REFACTOR.md.
##
## Owns the HOW of moving between lanes: measuring the body's feet, standing on a
## road lane's virtual floor, capturing the walkway baseline, stepping between lanes
## and chasing the player's lane. The lane STATE (lane, lane_floor_y,
## lane_depth_offset, is_changing_lane, lane_change_cooldown) stays on the Enemy,
## because states, spawners, projectiles and other enemies read it there.

var _e: Enemy
# Distance from the enemy's origin down to its soles. Measured lazily: the
# collision shape isn't reachable until the instanced scene has its children.
var _foot_offset: float = 0.0
var _foot_offset_measured: bool = false
var _tween: Tween
## Standing on raised ground (ledge, scaffold): draws behind the sidewalk trees.
var _raised: bool = false


func _init(enemy: Enemy) -> void:
	_e = enemy


## Distance from the origin down to the soles — see Lanes.measure_foot_offset.
func foot_offset() -> float:
	if not _foot_offset_measured:
		_foot_offset = Lanes.measure_foot_offset(_e)
		_foot_offset_measured = true
	return _foot_offset


## World Y the origin sits at when standing on `for_lane`, including the in-lane
## depth offset. The ground lane ignores the offset outright — real floor collision
## there would fight it, and a contaminated capture in update_floor() would bake the
## jitter into the shared baseline every other body reads.
func stand_y(for_lane: int) -> float:
	var offset := 0.0 if for_lane == Lanes.GROUND_LANE else _e.lane_depth_offset
	return Lanes.stand_y(_e.lane_floor_y, for_lane, foot_offset()) + offset


## Keep the draw z in step with where the body actually stands. Cheap enough to poll:
## it only writes when the value changes, and it self-heals the frame a baseline is
## first captured (before that, depth_z has no floor line to measure against).
func refresh_depth_z() -> void:
	_raised = Lanes.on_raised_floor(_raised, _e.is_on_floor(), _e.lane_floor_y, _e.global_position.y + foot_offset())
	var z := Lanes.depth_z(_e.lane, stand_y(_e.lane) + foot_offset(), _e.lane_floor_y, _raised)
	if z != _e.z_index:
		_e.z_index = z


## The walkway tiles' collision occupies the road strip; road-lane bodies ignore
## Ground(2)/Platforms(6) and stand on virtual floors instead.
func set_ground_collision(enabled: bool) -> void:
	_e.set_collision_mask_value(2, enabled)
	_e.set_collision_mask_value(6, enabled)


## Road lanes stand on a virtual floor below the walkway line. Returns true when the
## body is resting on it this frame (gravity must not apply).
func rest_on_virtual_floor() -> bool:
	if _e.lane == Lanes.GROUND_LANE or _e.lane_floor_y == INF:
		return false
	var fy := stand_y(_e.lane)
	if _e.velocity.y >= 0 and _e.global_position.y >= fy:
		_e.global_position.y = fy
		_e.velocity.y = 0.0
		return true
	return false


func update_floor() -> void:
	refresh_depth_z()
	if _e.is_changing_lane:
		return
	# Capture the walkway ground line whenever physically standing on it. Stored as
	# the FLOOR (soles), not the node's Y — a maid's origin sits 27px above its
	# feet and the player's 19.75px, so an origin-based baseline could not be shared
	# between them without one of the two standing at the wrong height.
	if _e.is_on_floor() and _e.lane == Lanes.GROUND_LANE:
		# Platform maids and anyone knocked onto raised geometry are still on the
		# ground lane; Lanes.accepts_baseline keeps their street line from climbing up
		# to whatever they happen to be standing on (it feeds coin and power-up drop
		# heights as well as this body's own virtual floors).
		var candidate := _e.global_position.y + foot_offset()
		var real_lane := Lanes.lane_for_floor(_e.lane_floor_y, candidate)
		if real_lane != Lanes.GROUND_LANE and not _e.lane_locked:
			_settle_onto(real_lane)
			return
		if Lanes.accepts_baseline(_e.lane_floor_y, candidate):
			_e.lane_floor_y = candidate
		return
	# Authored straight onto a road lane (starting_lane 1-3): _ready kept real ground
	# collision so we'd land on something. First contact defines the walkway line;
	# from here on the lane's virtual floor takes over.
	if _e.is_on_floor() and _e.lane_floor_y == INF:
		_e.lane_floor_y = _e.global_position.y + foot_offset()
		set_ground_collision(false)
		_e.global_position.y = stand_y(_e.lane)


## Adopt `road_lane` in place: off real collision, onto that lane's virtual floor.
## For a ground-lane body that ended up standing in the road strip (see
## Lanes.lane_for_floor) — the street baseline stays where it is.
func _settle_onto(road_lane: int) -> void:
	_e.lane = road_lane
	_e.lane_depth_offset = Lanes.random_in_lane_offset(road_lane)
	set_ground_collision(false)
	_e.global_position.y = stand_y(road_lane)
	_e.velocity.y = 0.0
	refresh_depth_z()


## Step one lane toward the player's lane (used while chasing). Always targets the
## player's own lane.
##
## This used to route chasers into a *free adjacent* lane whenever another attacker
## was already camped near the player on the wanted lane, one enemy per lane. That
## lane exclusivity was the cause of the one-attacker bug: can_attack() requires lane
## parity (Lanes.can_engage), so every enemy parked in a neighbouring lane was
## permanently unable to attack and the wave collapsed into a 1v1. Lanes are purely
## about depth/dodging again; attack pacing now lives in Globals' attack-slot pool,
## and horizontal crowding is handled by EnemySeparation, which fans the squad out
## along X within the player's lane.
func chase() -> void:
	if _e.lane_locked or _e.is_changing_lane or _e.lane_change_cooldown > 0.0 or _e.lane_floor_y == INF:
		return
	var player := _e.player
	if player == null or player.is_changing_lane:
		return
	if player.current_lane == _e.lane:
		return
	var target := _e.lane + signi(player.current_lane - _e.lane)
	if target == Lanes.GROUND_LANE and Lanes.walkway_blocked(_e, _e.get_node_or_null("CollisionShape2D"), Vector2(_e.global_position.x, stand_y(target))):
		return
	start_change(target, Enemy.LANE_CHANGE_DURATION)


## Tween onto `target`'s floor over `duration`; the lane commits when the step lands.
func start_change(target: int, duration: float) -> void:
	target = Lanes.clamp_lane(target)
	if target == _e.lane or _e.lane_floor_y == INF:
		return
	_e.is_changing_lane = true
	_e.lane_change_cooldown = Enemy.LANE_CHANGE_COOLDOWN
	_e.velocity.y = 0.0
	# Fresh jitter for the lane being entered, picked before the tween reads its
	# destination so the step lands on the offset rather than sliding onto it after.
	_e.lane_depth_offset = Lanes.random_in_lane_offset(target)
	if target != Lanes.GROUND_LANE:
		set_ground_collision(false)
	if _tween:
		_tween.kill()
	_tween = _e.create_tween()
	_tween.tween_property(_e, "global_position:y", stand_y(target), duration)
	_tween.finished.connect(func() -> void:
		_e.lane = target
		refresh_depth_z()
		if target == Lanes.GROUND_LANE:
			set_ground_collision(true)
		_e.is_changing_lane = false)
