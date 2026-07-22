class_name Lanes
extends RefCounted

## Virtual-depth lane system (TMNT-arcade style).
##
## Lanes are a gameplay/render dimension layered on top of the existing physics:
## lane GROUND (0, the back lane) is the original walkway line and uses real floor
## collision; road lanes (1, 2) extend DOWN-SCREEN toward the camera LANE_SPACING
## apart on "virtual floors" — entities there snap to floor_y() and disable their
## Ground/Platforms collision bits (the walkway tiles' collision boxes occupy the
## road strip). Combat only connects between entities on the same lane.
## See docs/LANE_REFACTOR.md.

const LANE_COUNT := 3
const BACK_LANE := 0
const FRONT_LANE := 2
## The lane that owns the REAL floor collision (the sidewalk/walkway line).
const GROUND_LANE := BACK_LANE

## World pixels between adjacent lane floors (down-screen is nearer the camera).
const LANE_SPACING := 24.0
## Seconds for a lane-step tween (player).
const CHANGE_DURATION := 0.12
## Holding ui_down at least this long crouches; a shorter tap steps a lane forward.
const CROUCH_HOLD_TIME := 0.25

## Lane play only happens in the street level for now (boss room stays single-plane).
const LANE_SCENES: Array[String] = ["res://scenes/main.tscn"]


static func clamp_lane(lane: int) -> int:
	return clampi(lane, BACK_LANE, FRONT_LANE)


static func is_valid_lane(lane: int) -> bool:
	return lane >= BACK_LANE and lane <= FRONT_LANE


## Y offset of a lane's floor relative to the ground-lane baseline (0 for GROUND,
## positive = down-screen toward the camera for the road lanes).
static func y_offset(lane: int) -> float:
	return float(clamp_lane(lane) - GROUND_LANE) * LANE_SPACING


## Absolute floor Y for a lane, given the entity's Y when grounded on the walkway.
static func floor_y(baseline_ground_y: float, lane: int) -> float:
	return baseline_ground_y + y_offset(lane)


## Draw order: nearer lanes render on top (back=1 matches prop z, front=3 above accents).
static func z_for(lane: int) -> int:
	return 1 + clamp_lane(lane)


static func same_lane(a: int, b: int) -> bool:
	return a == b


static func scene_has_lanes(scene_path: String) -> bool:
	return scene_path in LANE_SCENES
