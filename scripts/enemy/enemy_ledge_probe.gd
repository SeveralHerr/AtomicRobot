extends RefCounted
class_name EnemyLedgeProbe

## Ledge checks from an enemy's two down-rays. Pure and static so they can be
## unit-tested headless.
##
## The down-raycasts target Ground(2)/Platforms(32), but road-lane bodies
## deliberately disable both bits on themselves (set_ground_collision) since
## virtual lane floors have no real collision under them — so on any non-ground
## lane these rays never hit anything and would permanently read "near an edge",
## blocking chase movement outright. The virtual floors run gapless the length of
## the level (see docs/LANE_REFACTOR.md), so there's nothing to fall off there;
## only real ledges on the ground lane count.


## A ledge on EITHER side (patrol turn-around).
static func near_edge(lane: int, left_down: RayCast2D, right_down: RayCast2D) -> bool:
	if lane != Lanes.GROUND_LANE:
		return false
	return not left_down.is_colliding() or not right_down.is_colliding()


## Ledge check for the direction `body` is about to move in (+1 right, -1 left).
##
## Chase movement used to be gated on near_edge(), which reports an edge on
## EITHER side — so an enemy that walked up to a ledge could no longer move in
## the one direction that would take it away from that ledge, and froze on the
## spot permanently. Only the ray on the leading side can actually stop us.
static func near_edge_ahead(body: Node2D, lane: int, left_down: RayCast2D, right_down: RayCast2D, dir: int) -> bool:
	if lane != Lanes.GROUND_LANE or dir == 0:
		return false
	var left_offset := left_down.global_position.x - body.global_position.x
	var leading := left_down if leading_ray_is_left(left_offset, dir) else right_down
	return not leading.is_colliding()


## Which down-ray sits on the side we are moving toward.
##
## The rays are children of the body, whose transform mirrors on x when facing
## left (see FacingTransform), so the node *named* "left" is on the world right
## half the time — the choice has to be made from the ray's actual world offset,
## not its name.
static func leading_ray_is_left(left_ray_offset_x: float, dir: int) -> bool:
	return signf(left_ray_offset_x) == signf(float(dir))
