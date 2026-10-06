extends Node2D
class_name ParkedCar

## A customer's car parked at the curb for a MeterDefense: the traffic cars' art, no
## hitbox (it is scenery the maids are after, not a hazard), on the nearest road lane.
##
## Shows the job's state on the car itself: while a maid writes, a ticket slip fills
## above the roof; once she is done, the slip sits under the wiper, the car flashes and
## TICKET! pops. When the job ends it pulls out and drives off the screen.

const GROUP := &"parked_cars"
const CAR_BLUE := preload("res://images/new/Car_Blue.png")
const CAR_RED := preload("res://images/new/Car_Red.png")
const TICKET_SFX := preload("res://sounds/tap.wav")
## Lane the cars park on: the road lane next to the curb.
const LANE := 1
## The sprite's offset inside the node, as car.tscn (tyres land on road_y()).
const SPRITE_AT := Vector2(-3.67, -4)
## Where the slip sits on the windshield (node px, art faces left), and the progress
## slip's spot: above the writing maid's head (she stands right behind the roof — at
## -46 the slip sat on her face and hid who was writing).
const SLIP_AT := Vector2(-24, -17)
const SLIP_SIZE := Vector2(18, 12)
const METER_AT := Vector2(0, -66)
const METER_SIZE := Vector2(30, 18)
## How far a maid stands from the car's centre on the walkway behind it.
const CURB_SLOT := 6.0
## Seconds to pull out and leave; distance driven.
const LEAVE_S := 1.8
const LEAVE_PX := 760.0
const SHINE_HOP_PX := 6.0
## Brightening, not a gold multiply: gold times the blue paint read as murky green.
const SHINE_TINT := Color(1.8, 1.7, 1.3)
## Scraps of a torn-up ticket (a blow knocked the maid off it).
## Sized for play zoom: 2-3.5 px scraps were lost under the hit flash.
const TEAR_BITS := 18
## Half the view at zoom 2.5 plus a car length: a car this far from the player is gone.
const OFFSCREEN_PX := 256.0 + 2.0 * Car.HALF_LEN

var ticketed: bool = false
## 0..1 while a maid writes this car's ticket; 0 when nobody is.
var progress: float = 0.0
## The maid writing on this car (claims keep two maids off one car).
var claimed_by: Node = null
var sprite: Sprite2D
var _flash: float = 0.0
## Gold glint (1 -> 0): "these are the cars" when the job opens, "this one's free"
## as a clean car pulls out — otherwise saved and ticketed cars left alike.
var _shine: float = 0.0
var _slip_pop: float = 0.0
var _t: float = 0.0


func _init(red: bool = false, facing_right: bool = false) -> void:
	sprite = Sprite2D.new()
	sprite.texture = CAR_RED if red else CAR_BLUE
	sprite.position = SPRITE_AT
	sprite.flip_h = facing_right
	add_child(sprite)


func _ready() -> void:
	add_to_group(GROUP)
	z_as_relative = false
	z_index = Lanes.vehicle_z(LANE)


## Park on `lane`'s floor at world x `x` (tyres on the floor line).
func park(x: float, lane_floor_y: float) -> void:
	global_position = Vector2(x, Lanes.floor_y(lane_floor_y, LANE) - Car.WHEEL_DROP)


## World x a maid writes this car's ticket from.
func curb_x() -> float:
	return global_position.x + CURB_SLOT


func ticket() -> void:
	if ticketed:
		return
	ticketed = true
	progress = 0.0
	_flash = 1.0
	_slip_pop = 1.0
	ComicPopup.spawn(self, global_position + Vector2(0, -26), &"ticket")
	var s := AudioStreamPlayer2D.new()
	s.stream = TICKET_SFX
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


## Pure: which way a car at `x` leaves with the player at `px` — away from them, so it
## never drives through the fight (or the crates behind it), and LEAVE_PX then always
## ends out of view: a fixed westward drive vanished mid-screen beside the player.
static func leave_dir(x: float, px: float) -> int:
	return 1 if x >= px else -1


## The ticket being written is torn up: paper scraps burst off the slip. A blow that
## knocks the writer off a car otherwise only made the slip vanish — no payoff.
func tear() -> void:
	if progress <= 0.0:
		return
	var p := CPUParticles2D.new()
	p.name = "TornTicket"
	p.position = METER_AT
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = TEAR_BITS
	p.lifetime = 1.1
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2(0, 260)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 6.0
	var ink := Gradient.new()
	ink.offsets = PackedFloat32Array([0.0, 0.7])
	ink.colors = PackedColorArray([ComicStyle.PAPER, ComicStyle.ORANGE])
	ink.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = ink
	p.finished.connect(p.queue_free)
	add_child(p)


## Glint and hop on the springs.
func shine() -> void:
	_shine = 1.0
	var hop := create_tween()
	hop.tween_property(sprite, "position:y", SPRITE_AT.y - SHINE_HOP_PX, 0.12).set_ease(Tween.EASE_OUT)
	hop.tween_property(sprite, "position:y", SPRITE_AT.y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Pull out after `delay` and drive off away from the player at `px`, then free. A
## `saved` car glints and hops at once — with the win, not later under its burst.
func drive_off(px: float, delay: float = 0.0, saved: bool = false) -> void:
	progress = 0.0
	var x := global_position.x
	var dir := leave_dir(x, px)
	sprite.flip_h = dir > 0
	if saved:
		shine()
	var tw := create_tween()
	tw.tween_interval(delay)
	var leave := tw.tween_property(self, "global_position:x", x + dir * LEAVE_PX, LEAVE_S)
	leave.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	_shine = maxf(_shine - delta * 1.2, 0.0)
	_slip_pop = maxf(_slip_pop - delta * 4.0, 0.0)
	var glint := _shine * (0.6 + 0.4 * absf(sin(_t * 14.0)))
	sprite.modulate = Color.WHITE.lerp(SHINE_TINT, glint).lerp(Color(1.6, 0.7, 0.7), _flash)
	queue_redraw()


func _draw() -> void:
	if ticketed:
		_draw_slip(SLIP_AT, 1.0 + 0.8 * _slip_pop, 1.0)
	elif progress > 0.0:
		_draw_meter()


## The ticket under the wiper: a white slip with a red band, tilted, flapping in the
## breeze — the 12x8 slip was invisible at play zoom, so a ticketed car looked clean.
func _draw_slip(at: Vector2, k: float, fill: float) -> void:
	draw_set_transform(at, -0.35 + 0.12 * sin(_t * 7.0), Vector2.ONE * k)
	var r := Rect2(-SLIP_SIZE * 0.5, SLIP_SIZE)
	draw_rect(r.grow(1.0), ComicStyle.INK)
	draw_rect(r, ComicStyle.PAPER)
	draw_rect(Rect2(r.position, Vector2(r.size.x * fill, 4)), ComicStyle.RED)
	for i in 2:
		var y := r.position.y + 7 + i * 3
		draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 3 - i * 4, y), Color(ComicStyle.INK, 0.5), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Over the roof while a maid writes: the slip fills left to right, red as it lands.
func _draw_meter() -> void:
	var r := Rect2(METER_AT - METER_SIZE * 0.5, METER_SIZE)
	var bob := 1.5 * sin(_t * 12.0)
	r.position.y += bob
	draw_rect(r.grow(1.5), ComicStyle.INK)
	draw_rect(r, ComicStyle.PAPER)
	var fill := r
	fill.size.x *= clampf(progress, 0.0, 1.0)
	draw_rect(fill, ComicStyle.RED if progress > 0.66 else ComicStyle.ORANGE)
	for i in 3:
		var y := r.position.y + 4 + i * 3.5
		draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), Color(ComicStyle.INK, 0.35), 1.0)
