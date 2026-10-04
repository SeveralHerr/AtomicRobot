extends Node2D
class_name AmbientTraffic

## Rare background traffic for the whole street: every INTERVAL_MIN..MAX seconds of
## open play, one car drives the length of the screen down a random road lane, from
## either side. The intersections' streetlights still run their own cars.
##
## Fair by construction:
## - telegraphed: the car starts LEAD_S of travel off screen, and a warning sign
##   sits at that screen edge on the car's lane until the car itself shows;
## - never two at once (any driving car, streetlight ones included, holds the next);
## - the clock only runs in open play — not during a cut scene (the player is
##   frozen), a scripted fight (door encounter arena lock, event volume: already
##   peak pressure, and the barriers leave nowhere to go), or before the lanes exist.
## The boss room and menus never have one: this node only lives in main.tscn.

const CAR := preload("res://scenes/car.tscn")

## Seconds of open play between cars.
const INTERVAL_MIN := 15.0
const INTERVAL_MAX := 30.0
## Seconds between the warning going up and the car's nose reaching the screen.
const LEAD_S := 1.5
## Half the car art's length (opaque 107px of Car_*.png).
const CAR_HALF_LEN := 56.0
## Free a car this far past the exit edge...
const EXIT_MARGIN := 160.0
## ...or this far off either edge (the player outran it). Must exceed the farthest
## spawn (SPEED_MAX * LEAD_S + CAR_HALF_LEN) or a car is freed as it spawns.
const FAR_MARGIN := 960.0
## Half the visible world width when there is no camera (1280 px at zoom 2.5).
const HALF_VIEW_FALLBACK := 256.0
## Warning sign inset from the screen edge (world px). The CRT overlay eats ~40
## screen px (16 world px at zoom 2.5) of every edge.
const EDGE_INSET := 30.0

## Street span a car may start in: the LeftBoundary/RightBoundary walls.
@export var street_min_x := -1680.0
@export var street_max_x := 9400.0
## Found from the "player" group when left empty.
@export var player: Player

## >= 0 pins the traffic RNG (autoplay sets its scenario seed). Traffic never draws
## from the global stream: one extra draw there reshuffles every later enemy roll,
## which alone flipped a seeded mortal run from a win to a street death.
static var fixed_seed := -1

## Seconds of open play left before the next car.
var countdown := INTERVAL_MAX
var warning: TrafficWarning
var _car: Car
var _rng := RandomNumberGenerator.new()


static func next_interval(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(INTERVAL_MIN, INTERVAL_MAX)


static func may_spawn(cutscene: bool, fight: bool, player_ready: bool, road_busy: bool) -> bool:
	return player_ready and not cutscene and not fight and not road_busy


## World x a car driving `dir` starts at: off the entry edge by LEAD_S of travel.
static func spawn_x(view_x: float, half_view: float, dir: int, speed: int) -> float:
	return view_x - dir * (half_view + speed * LEAD_S + CAR_HALF_LEN)


## `preferred`, or the other way if that start point is off the street; 0 if neither fits.
static func pick_direction(preferred: int, view_x: float, half_view: float, speed: int,
		min_x: float, max_x: float) -> int:
	for d: int in [preferred, -preferred]:
		var x := spawn_x(view_x, half_view, d, speed)
		if x >= min_x and x <= max_x:
			return d
	return 0


static func should_despawn(car_x: float, dir: int, view_x: float, half_view: float) -> bool:
	var ahead := (car_x - view_x) * dir
	return ahead > half_view + EXIT_MARGIN or absf(car_x - view_x) > half_view + FAR_MARGIN


## Up while the car's nose is still off screen on its way in.
static func warning_visible(car_x: float, dir: int, view_x: float, half_view: float) -> bool:
	return (car_x + dir * CAR_HALF_LEN - view_x) * dir < -half_view


func _ready() -> void:
	if fixed_seed >= 0:
		_rng.seed = fixed_seed
	else:
		_rng.randomize()
	countdown = next_interval(_rng)
	warning = TrafficWarning.new()
	warning.visible = false
	add_child(warning)


func _physics_process(delta: float) -> void:
	var p := _player()
	if may_spawn(MicroCutscene.playing, Globals.event_active(),
			p != null and not p.is_dead and p.lane_floor_y != INF, _road_busy()):
		countdown -= delta
		if countdown <= 0.0:
			countdown = next_interval(_rng)
			_spawn(p)
	_track_car()


func _spawn(p: Player) -> void:
	var view_x := _view_x(p)
	var half := _half_view()
	var speed := _rng.randi_range(Car.SPEED_MIN, Car.SPEED_MAX)
	var dir := pick_direction(-1 if _rng.randf() < 0.5 else 1, view_x, half, speed, street_min_x, street_max_x)
	if dir == 0:
		return
	var lane := _rng.randi_range(Lanes.GROUND_LANE + 1, Lanes.FRONT_LANE)
	_car = CAR.instantiate()
	_car.rng = _rng
	add_child(_car)
	_car.launch(lane, Vector2(spawn_x(view_x, half, dir, speed), Car.road_y(p, lane)), dir, speed)


## Free the car once it has left, and keep its warning on the entry edge.
func _track_car() -> void:
	if not is_instance_valid(_car) or _car.is_queued_for_deletion():
		warning.visible = false
		return
	var view_x := _view_x(_player())
	var half := _half_view()
	var x := _car.global_position.x
	if should_despawn(x, _car.direction, view_x, half):
		_car.queue_free()
		warning.visible = false
		return
	warning.visible = warning_visible(x, _car.direction, view_x, half)
	if warning.visible:
		warning.direction = _car.direction
		warning.z_as_relative = false
		warning.z_index = _car.z_index + 1
		warning.global_position = Vector2(view_x - _car.direction * (half - EDGE_INSET), _car.global_position.y)


func _road_busy() -> bool:
	for c in get_tree().get_nodes_in_group(Car.GROUP):
		if c is Car and c.start:
			return true
	return false


func _player() -> Player:
	if is_instance_valid(player):
		return player
	return get_tree().get_first_node_in_group("player") as Player


func _view_x(p: Player) -> float:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.get_screen_center_position().x
	return p.global_position.x if p else 0.0


func _half_view() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.zoom.x > 0.0:
		return get_viewport_rect().size.x / (2.0 * cam.zoom.x)
	return HALF_VIEW_FALLBACK


## Road-sign "!" at the screen edge with a chevron for the way the car is heading.
class TrafficWarning extends Node2D:
	const FILL := Color("ffd23f")
	const INK := Color("1a1a1a")
	var direction := -1:
		set(d):
			direction = d
			queue_redraw()
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		# Blink hard enough to read at the corner of the eye, never fully gone.
		modulate.a = 0.55 + 0.45 * absf(sin(_t * TAU * 2.5))

	func _draw() -> void:
		var tri := PackedVector2Array([Vector2(0, -15), Vector2(13, 8), Vector2(-13, 8)])
		draw_colored_polygon(tri, FILL)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), INK, 2.0, true)
		draw_rect(Rect2(-1.5, -8, 3, 9), INK)
		draw_rect(Rect2(-1.5, 3, 3, 3), INK)
		# Chevron under the sign, pointing the way the car will cross the screen.
		var d := float(direction)
		var tip := Vector2(6 * d, 16)
		draw_polyline(PackedVector2Array([tip + Vector2(-6 * d, -5), tip, tip + Vector2(-6 * d, 5)]), FILL, 3.0, true)
