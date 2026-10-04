extends CanvasLayer
class_name CarWarning

## The road-sign "!" at the screen edge a car is about to come in from, on the car's
## lane, until the car itself shows. Shared by AmbientTraffic and the intersection
## Streetlights: every car on the street is telegraphed the same way.
##
## Owners call track(car) each tick; the sign is placed in world units on a canvas
## layer that follows the camera.

## Above the HUD and the touch buttons (UI, layer 2) — on a phone the buttons covered
## a world-space sign — below the pause menu (99) and the CRT overlay (100).
const LAYER := 3
## Sign inset from the screen edge (world px). The CRT overlay eats ~40 screen px
## (16 world px at zoom 2.5) of every edge; at 30 the sign's outer half was lost.
const EDGE_INSET := 44.0
## Half the view when there is no camera (tests, a frame before the camera exists).
const HALF_VIEW_FALLBACK := 256.0

var sign: Sign


func _init() -> void:
	layer = LAYER
	follow_viewport_enabled = true
	sign = Sign.new()
	sign.visible = false
	add_child(sign)


## Up until the car's nose reaches the sign (EDGE_INSET in from the edge): the car
## takes over from the sign instead of leaving a beat where only a sliver shows.
static func visible_for(car_x: float, dir: int, view_x: float, half_view: float) -> bool:
	return (car_x + dir * Car.HALF_LEN - view_x) * dir < -(half_view - EDGE_INSET)


static func view_x(vp: Viewport, p: Node2D) -> float:
	var cam := vp.get_camera_2d()
	if cam:
		return cam.get_screen_center_position().x
	return p.global_position.x if p else 0.0


static func half_view(vp: Viewport) -> float:
	var cam := vp.get_camera_2d()
	if cam and cam.zoom.x > 0.0:
		return vp.get_visible_rect().size.x / (2.0 * cam.zoom.x)
	return HALF_VIEW_FALLBACK


## Show the sign for `car` (null, freed or parked: hide it). Untyped on purpose: a
## freed car can't convert to Car, so a typed parameter errored before the check ran.
func track(car, center_x: float, half: float) -> void:
	if not is_instance_valid(car) or car.is_queued_for_deletion() or not car.start:
		sign.visible = false
		return
	sign.visible = visible_for(car.global_position.x, car.direction, center_x, half)
	if sign.visible:
		sign.direction = car.direction
		sign.global_position = Vector2(center_x - car.direction * (half - EDGE_INSET), car.global_position.y)


## Road-sign "!" with a chevron for the way the car is heading.
class Sign extends Node2D:
	const FILL := Color("ffd23f")
	const INK := Color("1a1a1a")
	var direction := -1:
		set(d):
			direction = d
			queue_redraw()
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		# Pulse (size + brightness) to catch the corner of the eye; never faded out,
		# so every frame of it reads.
		var k := absf(sin(_t * TAU * 2.5))
		scale = Vector2.ONE * (1.0 + 0.15 * k)
		modulate.a = 0.8 + 0.2 * k

	func _draw() -> void:
		var tri := PackedVector2Array([Vector2(0, -15), Vector2(13, 8), Vector2(-13, 8)])
		# Drop shadow + heavy ink so it separates from yellow street furniture.
		var shadow := PackedVector2Array()
		for v in tri:
			shadow.append(v + Vector2(2, 2))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
		draw_colored_polygon(tri, FILL)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), INK, 3.0, true)
		draw_rect(Rect2(-1.5, -8, 3, 9), INK)
		draw_rect(Rect2(-1.5, 3, 3, 3), INK)
		# Chevron under the sign, pointing the way the car will cross the screen.
		var d := float(direction)
		var tip := Vector2(6 * d, 16)
		draw_polyline(PackedVector2Array([tip + Vector2(-6 * d, -5), tip, tip + Vector2(-6 * d, 5)]), FILL, 3.0, true)
