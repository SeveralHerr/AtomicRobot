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
## Holding ui_down at least this long crouches; a shorter tap steps a lane forward.
const CROUCH_HOLD_TIME := 0.25

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
	if body == null:
		return 0.0
	for child in body.get_children():
		if not (child is CollisionShape2D):
			continue
		var cs := child as CollisionShape2D
		if cs.disabled or cs.shape == null:
			continue
		var half := _shape_half_height(cs.shape)
		if half < 0.0:
			continue
		var scale_y := 1.0
		if body is Node2D:
			scale_y = absf((body as Node2D).scale.y)
		return (cs.position.y + half) * scale_y
	return 0.0


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


static func same_lane(a: int, b: int) -> bool:
	return a == b


# --- Level baseline registry -------------------------------------------------
#
# The walkway floor line is a property of the LEVEL, not of whatever a body happens
# to be standing on. main.tscn stacks several colliding TileMapLayers — the walkway
# at Y=-1, raised building ledges at Y=-33 and Y=-65 — and every one of them satisfies
# is_on_floor(). Bodies used to re-capture the baseline from their own contact every
# frame, so walking onto a ledge at X~2600 lifted the whole lane stack 62.5px (2.6
# lane widths) up-screen, and any enemy spawned during that window kept the lifted
# value forever (only the ground lane ever re-captured). One value per scene fixes
# both: authored if the level says so, otherwise seeded once by the first body that
# stands on real ground and never rewritten.

## Optional authored Marker2D, a direct child of the scene root, whose global Y is
## the walkway floor line. Authoritative wherever it exists.
const BASELINE_MARKER_NAME := "LaneBaseline"
## Scene-root metadata key the resolved baseline is cached under. Lives on the scene
## instance, so a reload starts clean without any explicit reset.
const BASELINE_META := "lane_baseline_floor_y"


## The scene instance `node` belongs to, or null outside the tree.
static func _scene_root(node: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return null
	var tree := node.get_tree()
	if tree == null:
		return null
	return tree.current_scene


## The walkway floor line recorded on `root`, or INF when nothing has established one.
##
## Resolution order: the cached value, then an authored BASELINE_MARKER_NAME child. A
## level that authors the marker therefore has a correct baseline from frame zero,
## before anything has touched the ground.
##
## Takes the scene root directly rather than reaching for it, so the registry can be
## exercised without a running tree — see test/unit/test_lane_baseline.gd.
static func baseline_on_root(root: Node) -> float:
	if root == null:
		return INF
	if root.has_meta(BASELINE_META):
		return float(root.get_meta(BASELINE_META))
	var marker := root.get_node_or_null(NodePath(BASELINE_MARKER_NAME))
	if marker is Node2D:
		var y: float = (marker as Node2D).global_position.y
		root.set_meta(BASELINE_META, y)
		return y
	return INF


## Record `candidate` on `root` if no baseline exists yet, and return whatever the
## level's baseline now is.
##
## FIRST WRITER WINS — this is the whole fix. A later contact on higher or lower
## geometry reads the established value back instead of overwriting it, so the lane
## floors stay put no matter what the body is standing on.
static func seed_on_root(root: Node, candidate: float) -> float:
	var existing := baseline_on_root(root)
	if is_finite(existing):
		return existing
	if root == null or not is_finite(candidate):
		return INF
	root.set_meta(BASELINE_META, candidate)
	return candidate


## The level's walkway floor line for a body in the tree, or INF when unknown.
static func baseline_floor_y(node: Node) -> float:
	return baseline_on_root(_scene_root(node))


## Offer `candidate` as the level baseline on behalf of `node`. See seed_on_root.
static func seed_baseline(node: Node, candidate: float) -> float:
	return seed_on_root(_scene_root(node), candidate)


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
