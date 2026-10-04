class_name CameraLimitBlend
extends Node

## Eases a Camera2D's horizontal limits to new values instead of snapping them.
##
## A snapped limit moves the view in one frame: when a door fight locks the arena
## the camera jumps to the arena edge, and when STREET CLEAR! releases it the camera
## jumps back onto the player — up to 640 screen px, which reads as the player
## having teleported. The camera's own `limit_smoothed` only works with position
## smoothing on, which would make the whole game's camera lag.
##
## Each frame the blend works out where the view's left edge WOULD sit under the old
## limits and under the new ones, given where the player is right now, mixes the two
## and pins the camera there (limits exactly one view wide). At w = 0 that is the
## current view, at w = 1 exactly what the new limits show, so neither end jumps, and
## a player walking during the blend is tracked through both terms.
## (Easing each limit on its own does not work: while the right limit pushes the view
## left, an unmoved left limit drags it back and Godot centres the view between them.)
##
## Lives under the camera (named NODE_NAME), so it dies with the player on a scene
## change; a new blend replaces one in flight, starting from wherever that one got to.

const NODE_NAME := "LimitBlend"
## Long enough that a full-screen recentre (256 world px) reads as a pan, short
## enough to be over before the next fight starts.
const DEFAULT_SECONDS := 0.55
## Longest step one frame may take. A hitch frame (a squad spawning, a scene load)
## can carry a quarter second of delta and would otherwise cover half the pan in
## one frame — the very jump this exists to remove.
const MAX_STEP := 1.0 / 30.0

var camera: Camera2D
var from_left: int
var from_right: int
var to_left: int
var to_right: int
var seconds: float = DEFAULT_SECONDS
var _t: float = 0.0


## Ease `cam`'s limits to [to_left, to_right] over `secs`. Returns the blend node.
static func blend(cam: Camera2D, left: int, right: int, secs: float = DEFAULT_SECONDS) -> CameraLimitBlend:
	var old := cam.get_node_or_null(NODE_NAME)
	if old != null:
		cam.remove_child(old)
		old.queue_free()
	var b := CameraLimitBlend.new()
	b.name = NODE_NAME
	b.camera = cam
	b.from_left = cam.limit_left
	b.from_right = cam.limit_right
	b.to_left = left
	b.to_right = right
	b.seconds = maxf(secs, 0.0)
	cam.add_child(b)
	if b.seconds <= 0.0:
		b._finish()
	return b


## The limits `cam` is heading for: a blend's target while one runs, else its own.
## Save THESE before a lock, not the live limits, or a lock that starts while the
## last release is still easing would restore a half-blended view.
static func target_limits(cam: Camera2D) -> Vector2i:
	var b := cam.get_node_or_null(NODE_NAME) as CameraLimitBlend
	if b != null:
		return Vector2i(b.to_left, b.to_right)
	return Vector2i(cam.limit_left, cam.limit_right)


## Smoothstep weight at `progress` (0..1, clamped).
static func weight(progress: float) -> float:
	return smoothstep(0.0, 1.0, progress)


## Where a view `width` wide whose unlimited left edge is `free_left` sits under the
## limits [left, right] (right wins first, then left: the camera's own order).
static func view_left(free_left: float, left: float, right: float, width: float) -> float:
	var v := free_left
	if v + width > right:
		v = right - width
	if v < left:
		v = left
	return v


func _process(delta: float) -> void:
	step(delta)


## Advance the blend by `delta` seconds and write the camera's limits.
func step(delta: float) -> void:
	if not is_instance_valid(camera):
		queue_free()
		return
	_t += minf(delta, MAX_STEP)
	if _t >= seconds:
		_finish()
		return
	var w := weight(_t / seconds)
	var width := camera.get_viewport_rect().size.x / camera.zoom.x
	# The node's own position, not get_screen_center_position(): that one is
	# already clamped by the limits we are writing. (No drag on this camera.)
	var free_left := camera.global_position.x - width * 0.5
	var v := lerpf(view_left(free_left, from_left, from_right, width),
		view_left(free_left, to_left, to_right, width), w)
	camera.limit_left = floori(v)
	camera.limit_right = floori(v) + ceili(width)


func _finish() -> void:
	if is_instance_valid(camera):
		camera.limit_left = to_left
		camera.limit_right = to_right
	queue_free()
