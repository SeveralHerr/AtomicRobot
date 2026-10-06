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
##   peak pressure, and the barriers leave nowhere to go), a street side job (its
##   squad walks the road lane the parked cars push traffic into), or before the
##   lanes exist.
## The boss room and menus never have one: this node only lives in main.tscn.

const CAR := preload("res://scenes/car.tscn")

## Seconds of open play between cars.
const INTERVAL_MIN := 15.0
const INTERVAL_MAX := 30.0
## Seconds between the warning going up and the car's nose reaching the screen.
const LEAD_S := 1.5
## Free a car this far past the exit edge...
const EXIT_MARGIN := 160.0
## ...or this far off either edge (the player outran it). Must exceed the farthest
## spawn (SPEED_MAX * LEAD_S + Car.HALF_LEN) or a car is freed as it spawns.
const FAR_MARGIN := 960.0

## Street span a car may drive in: the inner faces of the LeftBoundary /
## RightBoundary end buildings (their wall shapes). Past them a car drew over
## the building facade.
@export var street_min_x := -1440.0
@export var street_max_x := 9170.0
## Found from the "player" group when left empty.
@export var player: Player

## >= 0 pins the traffic RNG (autoplay sets its scenario seed). Traffic never draws
## from the global stream: one extra draw there reshuffles every later enemy roll,
## which alone flipped a seeded mortal run from a win to a street death.
static var fixed_seed := -1

## Seconds of open play left before the next car.
var countdown := INTERVAL_MAX
## The edge sign (CarWarning.Sign) of the car on the way.
var warning: CarWarning.Sign
var _signs: CarWarning
var _car: Car
var _rng := RandomNumberGenerator.new()


static func next_interval(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(INTERVAL_MIN, INTERVAL_MAX)


static func may_spawn(cutscene: bool, fight: bool, player_ready: bool, road_busy: bool) -> bool:
	return player_ready and not cutscene and not fight and not road_busy


## A door fight or a street side job is on (the clock holds for both).
static func scripted_fight(tree: SceneTree) -> bool:
	return Globals.event_active() or StreetObjective.any_running(tree)


## World x a car driving `dir` starts at: off the entry edge by LEAD_S of travel.
static func spawn_x(view_x: float, half_view: float, dir: int, speed: int) -> float:
	return view_x - dir * (half_view + speed * LEAD_S + Car.HALF_LEN)


## `preferred`, or the other way if that pass would start or end off the street;
## 0 if neither fits (an end building is on screen: no car drives into it).
static func pick_direction(preferred: int, view_x: float, half_view: float, speed: int,
		min_x: float, max_x: float) -> int:
	for d: int in [preferred, -preferred]:
		var start := spawn_x(view_x, half_view, d, speed)
		var exit := view_x + d * (half_view + EXIT_MARGIN)
		if minf(start, exit) >= min_x and maxf(start, exit) <= max_x:
			return d
	return 0


static func should_despawn(car_x: float, dir: int, view_x: float, half_view: float) -> bool:
	var ahead := (car_x - view_x) * dir
	return ahead > half_view + EXIT_MARGIN or absf(car_x - view_x) > half_view + FAR_MARGIN


func _ready() -> void:
	if fixed_seed >= 0:
		_rng.seed = fixed_seed
	else:
		_rng.randomize()
	countdown = next_interval(_rng)
	_signs = CarWarning.new()
	add_child(_signs)
	warning = _signs.sign


func _physics_process(delta: float) -> void:
	var p := _player()
	if may_spawn(MicroCutscene.playing, scripted_fight(get_tree()),
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
	var lane := road_lane(_rng.randi_range(Lanes.GROUND_LANE + 1, Lanes.FRONT_LANE),
		_parked_near(view_x, half))
	_car = CAR.instantiate()
	_car.rng = _rng
	# The engine is the audio half of the telegraph: heard (panned to its side) from
	# off screen, not only once the car shows. Freed before _ready, so the enabler
	# never gets to switch the player off.
	_car.get_node("VisibleOnScreenEnabler2D").free()
	add_child(_car)
	_car.launch(lane, Vector2(spawn_x(view_x, half, dir, speed), Car.road_y(p, lane)), dir, speed)


## `rolled`, unless cars are parked at the curb nearby (a MeterDefense job): then
## never the curb lane, or the car would drive straight through them. Same RNG draws
## either way, so seeded runs keep their later rolls.
static func road_lane(rolled: int, curb_parked: bool) -> int:
	if curb_parked and rolled == ParkedCar.LANE:
		return ParkedCar.LANE + 1
	return rolled


func _parked_near(view_x: float, half: float) -> bool:
	for c in get_tree().get_nodes_in_group(ParkedCar.GROUP):
		if absf((c as Node2D).global_position.x - view_x) < half + FAR_MARGIN:
			return true
	return false


## Free the car once it has left, and keep its warning on the entry edge.
func _track_car() -> void:
	var view_x := _view_x(_player())
	var half := _half_view()
	if is_instance_valid(_car) and not _car.is_queued_for_deletion() 			and should_despawn(_car.global_position.x, _car.direction, view_x, half):
		_car.queue_free()
	_signs.track(_car, view_x, half)


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
	return CarWarning.view_x(get_viewport(), p)


func _half_view() -> float:
	return CarWarning.half_view(get_viewport())
