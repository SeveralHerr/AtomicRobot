extends Node2D
class_name Cat

## Decorative rooftop cat released by the wall crack easter egg (crack.gd).
## Hops out of the crack onto the floor below it, then strolls the ledge, turning
## back where a down-ray ahead finds no floor and sitting down now and then.
## No body: it never collides with the player or anything else.

enum Mode { POP, WALK, SIT }

const FLOOR_MASK := 2 | 32 | 64  # Ground, Platforms, Wall (rooftops use the wall layer)
const PROBE_AHEAD := 14.0  # ~nose distance at 0.6 scale: turn before the head overhangs
const PROBE_UP := 6.0
const PROBE_DOWN := 8.0
const DROP_SEARCH := 160.0  # how far below the crack to look for a landing
const CLIMB_SEARCH := 140.0  # ...and how far above it (cats leap onto roofs)
const HOP_SIDE := 4.0
const HOP_CLEARANCE := 14.0
const HOP_GRAVITY := 900.0

@export var speed := 22.0
@export var min_walk_time := 2.5
@export var max_walk_time := 5.0
@export var min_sit_time := 1.5
@export var max_sit_time := 3.5
## When false the cat starts walking where it is (tests, hand-placed cats).
@export var pop_out := true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var mode := Mode.POP
var direction := 1
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if not pop_out:
		start_walking(direction)


func _physics_process(delta: float) -> void:
	match mode:
		Mode.POP:
			if pop_out:
				pop_out = false
				_hop_to(_find_floor_below())
		Mode.WALK:
			_walk(delta)
		Mode.SIT:
			_timer -= delta
			if _timer <= 0.0:
				start_walking(direction)


func start_walking(dir: int) -> void:
	mode = Mode.WALK
	direction = 1 if dir >= 0 else -1
	_timer = _rng.randf_range(min_walk_time, max_walk_time)
	sprite.play("walk")
	sprite.flip_h = direction < 0


func _walk(delta: float) -> void:
	if not has_floor_ahead(direction):
		start_walking(-direction)
		if not has_floor_ahead(direction):
			_sit()  # stranded on a sliver: just sit
			return
	position.x += direction * speed * delta
	_timer -= delta
	if _timer <= 0.0:
		_sit()


func _sit() -> void:
	mode = Mode.SIT
	_timer = _rng.randf_range(min_sit_time, max_sit_time)
	sprite.play("idle")


func has_floor_ahead(dir: int) -> bool:
	var x := global_position.x + dir * PROBE_AHEAD
	return _ray(Vector2(x, global_position.y - PROBE_UP), Vector2(x, global_position.y + PROBE_DOWN)).size() > 0


## First floor under a point a little above the crack: a crack set in a roof
## cornice hops UP onto the roof, one in a wall drops onto the ledge below.
func _find_floor_below() -> Vector2:
	var from := global_position - Vector2(0, CLIMB_SEARCH)
	var hit := _ray(from, global_position + Vector2(0, DROP_SEARCH))
	return hit.position if hit else global_position


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, FLOOR_MASK)
	return get_world_2d().direct_space_state.intersect_ray(q)


## Squash-and-stretch hop out of the wall, landing on `landing` (global).
func _hop_to(landing: Vector2) -> void:
	var base := scale
	var start := global_position
	var peak := Vector2(start.x + HOP_SIDE, minf(start.y, landing.y) - HOP_CLEARANCE)
	var land := landing + Vector2(HOP_SIDE * 2.0, 0)
	scale = base * 0.3
	sprite.play("walk")  # mid-stride frame reads as a leap
	sprite.pause()
	sprite.frame = 3
	var t := create_tween()
	t.tween_property(self, "scale", base * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "global_position", peak, _fall_time(start.y - peak.y)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "global_position", land, _fall_time(land.y - peak.y)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "scale", Vector2(base.x * 1.2, base.y * 0.8), 0.06)
	t.tween_property(self, "scale", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_sit_then_walk)


## Time to fall (or rise) `height` px under HOP_GRAVITY, so tall leaps take longer.
static func _fall_time(height: float) -> float:
	return sqrt(2.0 * maxf(height, 1.0) / HOP_GRAVITY)


func _sit_then_walk() -> void:
	_sit()
	_timer = 0.8
	direction = 1 if has_floor_ahead(1) else -1
