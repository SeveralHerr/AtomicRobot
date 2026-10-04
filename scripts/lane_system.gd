class_name Lanes
extends RefCounted

## Virtual-depth lane system (TMNT-arcade style).
##
## Lanes are a gameplay/render dimension layered on top of the existing physics:
## lane GROUND (0, the back lane) is the original walkway line and uses real floor
## collision; road lanes (1, 2, 3) extend DOWN-SCREEN toward the camera LANE_SPACING
## apart on "virtual floors" — entities there snap to stand_y() and disable their
## Ground/Platforms collision bits (the walkway tiles' collision boxes occupy the
## road strip). Combat only connects between entities on the same lane.
##
## Baselines are FLOOR LINES (where soles rest), shared by every entity; each body
## converts one into its own position with stand_y() + measure_foot_offset().
## See docs/LANE_REFACTOR.md.

const LANE_COUNT := 4
const BACK_LANE := 0
const FRONT_LANE := 3
## The lane that owns the REAL floor collision (the sidewalk/walkway line).
const GROUND_LANE := BACK_LANE

## World pixels between adjacent lane floors (down-screen is nearer the camera).
const LANE_SPACING := 24.0
## Seconds for a lane-step tween (player).
const CHANGE_DURATION := 0.12

## Lane play only happens in the street level for now (boss room stays single-plane).
const LANE_SCENES: Array[String] = ["res://scenes/main.tscn"]
## Everything under here is an enemy-behaviour sandbox (test/scenes/*.tscn). They
## exist to exercise lane combat, so they opt in as a directory rather than each
## one having to be listed above.
const LANE_SCENE_PREFIX := "res://test/scenes/"


static func clamp_lane(lane: int) -> int:
	return clampi(lane, BACK_LANE, FRONT_LANE)


static func is_valid_lane(lane: int) -> bool:
	return lane >= BACK_LANE and lane <= FRONT_LANE


## Y offset of a lane's floor relative to the ground-lane baseline (0 for GROUND,
## positive = down-screen toward the camera for the road lanes).
static func y_offset(lane: int) -> float:
	return float(clamp_lane(lane) - GROUND_LANE) * LANE_SPACING


## Absolute world Y of a lane's FLOOR SURFACE, given the walkway's floor line.
##
## `baseline_floor_y` is where soles rest, not where any particular body's origin
## sits — it is the same number for every entity in the scene. Use stand_y() to
## turn it into a body's own position.
static func floor_y(baseline_floor_y: float, lane: int) -> float:
	return baseline_floor_y + y_offset(lane)


## World Y a body's ORIGIN sits at when standing on `lane`.
##
## Splitting the shared floor line from each body's `foot_offset` is what makes a
## baseline transferable between entities — see measure_foot_offset() for the bug
## that came from conflating them.
static func stand_y(baseline_floor_y: float, lane: int, foot_offset: float) -> float:
	return floor_y(baseline_floor_y, lane) - foot_offset


## Distance from `body`'s origin DOWN to the sole of its own collision shape.
##
## Bodies do NOT all sit the same distance above their feet: the player's box is
## 28 x 51.5 at y=-6 (origin 19.75px up), a meter maid's is 24 x 48 at y=+3 (origin
## 27px up). Lane baselines used to be stored as the body ORIGIN, so when the
## spawner copied the player's baseline onto a maid (EnemySpawner.spawn_enemy_at)
## that maid stood 7.25px lower than a maid that had captured its own — visible as
## enemies on "the same lane" sitting at different heights, and permanent, since
## only the ground lane ever recaptures a baseline.
##
## Only DIRECT CollisionShape2D children count — an Area2D's shape is a hitbox, not
## a footprint. Returns 0.0 when there is no measurable shape (props like Car), so
## callers that care must supply their own offset.
static func measure_foot_offset(body: Node) -> float:
	var cs := _footprint(body)
	if cs == null:
		return 0.0
	return (cs.position.y + _shape_half_height(cs.shape)) * absf((body as Node2D).scale.y if body is Node2D else 1.0)


## Half width/height of `body`'s footprint shape (see measure_foot_offset), scaled.
## Vector2.ZERO when there is none.
static func measure_half_extents(body: Node) -> Vector2:
	var cs := _footprint(body)
	if cs == null:
		return Vector2.ZERO
	var half := Vector2(_shape_half_width(cs.shape), _shape_half_height(cs.shape))
	if body is Node2D:
		half *= (body as Node2D).scale.abs()
	return half


## The first enabled, measurable DIRECT CollisionShape2D child of `body`.
static func _footprint(body: Node) -> CollisionShape2D:
	if body == null:
		return null
	for child in body.get_children():
		if not (child is CollisionShape2D):
			continue
		var cs := child as CollisionShape2D
		if cs.disabled or cs.shape == null or _shape_half_height(cs.shape) < 0.0:
			continue
		return cs
	return null


static func _shape_half_width(shape: Shape2D) -> float:
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size.x * 0.5
	if shape is CapsuleShape2D:
		return (shape as CapsuleShape2D).radius
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	return -1.0


## Half-height of the shape kinds this project actually stands bodies on. Returns
## -1.0 for anything else, so an unmeasurable shape is skipped rather than being
## mistaken for a zero-height one.
static func _shape_half_height(shape: Shape2D) -> float:
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size.y * 0.5
	if shape is CapsuleShape2D:
		return (shape as CapsuleShape2D).height * 0.5
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	return -1.0


## First z of a lane's draw band. Nearer lanes render on top.
##
## GROUND_LANE deliberately stays at a bare z=1: it shares the walkway with authored
## props (parked-car decals and interact labels sit at z=2 and must keep drawing over
## bodies standing there), so its band is one value wide and its layering is exactly
## what it always was. Road lanes are out in the street with nothing authored to
## interleave with, so they get wide bands — the room depth_z() needs to sub-order
## bodies within a lane.
static func z_for(lane: int) -> int:
	var l := clamp_lane(lane)
	if l == GROUND_LANE:
		return 1
	return ROAD_Z_BASE + (l - 1) * ROAD_Z_STRIDE


## First z of the nearest road lane's band, clear of every authored prop z (-4..2).
const ROAD_Z_BASE := 10
## Width of each road lane's band. Must exceed the full jitter span (2 * IN_LANE_JITTER)
## with room to spare, or a body at one lane's near edge could out-sort the next lane.
const ROAD_Z_STRIDE := 20
## Added to a body's in-lane depth so the sub-index stays positive within its band.
const DEPTH_Z_BIAS := 8


## Draw z for a body whose soles are at `foot_y`, standing on `lane`.
##
## Y-sorting cannot do this job: Godot keys it on the node ORIGIN, and origins sit at
## different heights above their soles (player 19.75px, maid 27px), so a same-lane
## player always out-sorted every maid by a constant 7.25px no matter who actually
## stood nearer the camera. Sorting on the foot line is the whole point, so the depth
## goes into z explicitly. GROUND_LANE has no sub-ordering — it keeps its bare z.
static func depth_z(lane: int, foot_y: float, baseline_floor_y: float) -> int:
	var l := clamp_lane(lane)
	if l == GROUND_LANE or not is_finite(baseline_floor_y):
		return z_for(l)
	var depth := clampf(foot_y - floor_y(baseline_floor_y, l), -IN_LANE_JITTER, IN_LANE_JITTER)
	return z_for(l) + DEPTH_Z_BIAS + roundi(depth)


## Draw z for a vehicle on `lane`: just above the deepest in-lane body, still inside
## the lane's band. A car fills the lane's depth, so a same-lane body must never draw
## over it; mid-band tied with a body standing on the lane line and lost to tree order.
static func vehicle_z(lane: int) -> int:
	return z_for(lane) + DEPTH_Z_BIAS + int(IN_LANE_JITTER) + 1


static func same_lane(a: int, b: int) -> bool:
	return a == b


# --- Baseline anchoring -------------------------------------------------------

## How far off the street line a floor may be and still count as the street (px).
## Covers tile-seam and float drift, not authored elevation: the smallest thing the
## lanes must refuse to follow is a one-lane step (LANE_SPACING = 24px).
const BASELINE_TOLERANCE := 6.0


## Should a freshly measured floor line replace the street baseline?
##
## The ground lane rides real collision, so a body standing on it re-measures the
## floor under its own feet — and platforms, scaffolding and raised ledges are ALSO
## ground-lane floors. Taking every measurement dragged the whole depth axis up with
## the player: step onto a platform and lanes 1-3, the enemies standing on them, the
## cars and the resting coins all lifted off the street to hang in mid-air under it.
##
## The street is the LOWEST floor in the level (the road strip below it has no
## collision at all), so "never move the baseline up-screen" anchors it while still
## self-healing downward if the first capture ever lands somewhere raised.
static func accepts_baseline(current: float, candidate: float) -> bool:
	if not is_finite(current):
		return true
	return candidate >= current - BASELINE_TOLERANCE


## Which lane soles at `foot_y` are standing on, given the street line.
##
## The walkway tiles' collision fills the road strip, so a ground-lane body knocked or
## walked down into it lands on REAL floor at road height while still reporting lane 0
## — out of reach of every lane-0 projectile flying at street height. Re-deriving the
## lane from the feet puts it back on the depth axis. Anything above the street
## (platforms, ledges) is still GROUND_LANE, and so is anything deeper than the road
## strip — that is a raised baseline capture to correct (accepts_baseline), not a lane.
## Nothing is derivable before the street has been measured.
static func lane_for_floor(baseline_floor_y: float, foot_y: float) -> int:
	if not is_finite(baseline_floor_y):
		return GROUND_LANE
	var depth := foot_y - baseline_floor_y
	if depth > y_offset(FRONT_LANE) + LANE_SPACING * 0.5:
		return GROUND_LANE
	return clamp_lane(GROUND_LANE + roundi(depth / LANE_SPACING))


## Are soles at `foot_y` resting on the street itself, rather than on raised
## ground-lane geometry? False while the baseline is still unknown — nothing can be
## called street-level before the street has been measured.
static func at_baseline(baseline_floor_y: float, foot_y: float) -> bool:
	if not is_finite(baseline_floor_y):
		return false
	return absf(foot_y - baseline_floor_y) <= BASELINE_TOLERANCE


# --- In-lane depth jitter + draw sorting -------------------------------------

## Max in-lane depth offset (px) for a road-lane enemy, so a lane doesn't read as a
## rank of sprites pinned to one ruled line. GROUND_LANE is deliberately exempt: it
## stands on real collision geometry, so an offset there would float or sink bodies
## off the walkway instead of just shifting a virtual floor.
const IN_LANE_JITTER := 5.0

## Name of the runtime-created Y-sorted container that lane bodies draw inside.
const SORT_LAYER_NAME := "LaneSortLayer"


## A random in-lane depth offset for `lane` — always 0.0 on the ground lane.
static func random_in_lane_offset(lane: int) -> float:
	if clamp_lane(lane) == GROUND_LANE:
		return 0.0
	return randf_range(-IN_LANE_JITTER, IN_LANE_JITTER)


## The scene's Y-sorted draw container, created on first use.
##
## ONE container is enough for the whole depth axis: Godot only Y-sorts siblings that
## share a z_index, so z_for(lane) still bands the lanes exactly as before, and within
## a band the in-lane offsets sort themselves nearest-last. That keeps every authored
## prop z (-4, -1, 1, 2) layering untouched, which widening the z bands would not.
static func sort_layer(scene_root: Node) -> Node2D:
	if scene_root == null:
		return null
	var existing := scene_root.get_node_or_null(NodePath(SORT_LAYER_NAME))
	if existing is Node2D:
		return existing as Node2D
	var layer := Node2D.new()
	layer.name = SORT_LAYER_NAME
	layer.y_sort_enabled = true
	scene_root.add_child(layer)
	return layer


## Reparent `body` into the sort container, keeping its world position.
##
## Clears top_level on the way in: a top_level CanvasItem is parented straight to the
## canvas root by the renderer, so it would ignore the container and never sort. The
## bodies only set it to escape transformed level parents, and the container sits at
## the scene root with an identity transform, so dropping it costs nothing.
static func join_sort_layer(body: Node2D) -> void:
	if body == null or not body.is_inside_tree():
		return
	var tree := body.get_tree()
	if tree == null or tree.current_scene == null:
		return
	if not scene_has_lanes(tree.current_scene.scene_file_path):
		return
	var layer := sort_layer(tree.current_scene)
	if layer == null or body.get_parent() == layer:
		return
	var world := body.global_position
	body.set_as_top_level(false)
	body.reparent(layer, false)
	body.global_position = world


## Can an attacker on `attacker_lane` reach a target on `target_lane`?
##
## Combat normally only connects within a lane — that is the whole point of the
## depth axis. The exception is lane-locked attackers (window and platform maids):
## they fire down from above onto the street and their coins are deliberately
## lane-agnostic (see Utils.throw_coin), so holding them to lane parity silenced
## them the moment the player stepped off the walkway.
static func can_engage(attacker_lane: int, target_lane: int, attacker_lane_locked: bool) -> bool:
	return attacker_lane_locked or same_lane(attacker_lane, target_lane)


static func scene_has_lanes(scene_path: String) -> bool:
	return scene_path in LANE_SCENES or scene_path.begins_with(LANE_SCENE_PREFIX)


## Walkway (GROUND_LANE) solids a body can be embedded in: Ground(2). Platforms(6) are
## one-way (the awnings overhead), so standing under or inside one is never stuck.
const WALKWAY_SOLID_MASK := 1 << 1
## Lift the probe off the walkway so resting on its tiles doesn't read as an overlap.
const WALKWAY_PROBE_LIFT := 2.0

## Would `body` (via its footprint `shape`) be embedded in walkway solids standing at
## `stand_pos`? Road-lane bodies ignore Ground/Platforms, so they can walk in front
## of a walkway prop (the crate stack); stepping back onto the walkway there would
## re-enable that collision with the body already inside it.
static func walkway_blocked(body: CollisionObject2D, shape: CollisionShape2D, stand_pos: Vector2) -> bool:
	if body == null or shape == null or shape.shape == null or not body.is_inside_tree():
		return false
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape.shape
	q.transform = Transform2D(shape.global_rotation, stand_pos + shape.position + Vector2(0, -WALKWAY_PROBE_LIFT))
	q.collision_mask = WALKWAY_SOLID_MASK
	return not body.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()
