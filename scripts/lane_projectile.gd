extends Node2D
class_name LaneProjectile

## A player shot that flies straight along X on one lane (Robot's bullet, Cass's
## flip-flop).
##
## Hits are a LANE + X test, not a physics overlap at the shooter's height: lanes are
## a depth axis, so a maid on the shot's lane is in its path whatever her y. An
## Area2D overlap used to miss any maid standing at the wrong height for her lane and
## left ranged characters unable to clear a door arena. Lane-locked maids (window and
## platform) are the exception — they are up on the building, so they still need
## real vertical overlap.

## World px the shot may travel before it despawns. The camera (zoom 2.5 on a
## 1280-wide viewport) shows 512 px of world, so the screen edge sits ~256 px from
## the player — anything beyond this would land hits on enemies that are off-frame.
const MAX_TRAVEL: float = 220.0
## 600 px/s == the old 10 px per 60 Hz physics frame, but delta-driven so it is
## frame-rate independent and respects Engine.time_scale.
const SPEED: float = 600.0
## Half the shot's own length along X, added to each body's half-width for contact.
const HALF_LENGTH: float = 11.0
## Vertical reach toward a lane-locked maid, beyond her own half-height.
const HALF_HEIGHT: float = 7.0

var dir = 0
var player: Player
## Set by the spawner right after instantiation. Road lanes fly over the road tiles,
## so the projectile must take the lane's z or the TileMapLayer (z=1) hides it.
var lane: int = Lanes.GROUND_LANE:
	set(value):
		lane = value
		z_index = Lanes.z_for(value)

var _travelled: float = 0.0


func _physics_process(delta: float) -> void:
	if dir == 0:
		return
	_spin(delta)
	var step: float = SPEED * delta
	var from_x := global_position.x
	position.x += dir * step
	_travelled += step
	var target := find_target(get_tree().get_nodes_in_group("enemies"), lane,
		global_position.y, from_x, global_position.x, dir)
	if target != null:
		_hit(target)
	elif _travelled >= MAX_TRAVEL:
		queue_free()


## Visual-only hook for subclasses.
func _spin(_delta: float) -> void:
	pass


func _hit(enemy: Enemy) -> void:
	ScreenShake.apply_shake(7)
	if player != null:
		player.land_hit(enemy)
	queue_free()


## The first living enemy on `lane` this frame's sweep from `from_x` to `to_x`
## touches, nearest along `dir`; null if none.
static func find_target(enemies: Array, on_lane: int, shot_y: float, from_x: float,
		to_x: float, dir: int) -> Enemy:
	var lo := minf(from_x, to_x) - HALF_LENGTH
	var hi := maxf(from_x, to_x) + HALF_LENGTH
	var best: Enemy = null
	var best_d := INF
	for node in enemies:
		if not (node is Enemy) or not is_instance_valid(node):
			continue
		var e: Enemy = node
		if e.is_dead or e.lane != on_lane:
			continue
		var half := Lanes.measure_half_extents(e)
		var x := e.global_position.x
		if x + half.x < lo or x - half.x > hi:
			continue
		if e.lane_locked and absf(e.global_position.y - shot_y) > half.y + HALF_HEIGHT:
			continue
		var d := (x - from_x) * signf(dir)
		if d < best_d:
			best_d = d
			best = e
	return best
