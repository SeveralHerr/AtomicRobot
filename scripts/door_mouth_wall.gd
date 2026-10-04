class_name WallMouth
extends DoorMouthFx

## A brick wall that breaks open. Closed: the hairline crack (the encounter's
## `Crack`, sprites/crack.png) is the permanent tell. Telegraph: the crack widens
## and twitches, grit trickles and chips ping off as the rumble builds. Burst: a
## jagged breach — broken brick rim, a deep shadowed inside, rubble on the
## sidewalk — with a dust cloud and a brick-chunk blast in the wall's own colour.
## Later waves rattle the breach and shake more grit off its lip.

## hole | rim | rubble, 64x56 each, bottom-aligned (sprites/door_breach.png).
## The rim and rubble are neutral greys where 128 is the wall itself: they are
## modulated by `wall_color * 2`, so one sheet fits every wall it is set into.
const SHEET := preload("res://sprites/door_breach.png")
const FRAME := Vector2(64, 56)
const CRUMBLE := preload("res://sounds/422762__kierankeegan__footsteps_stone_4.wav")
## Breach half-width / height (world px) — the opening enemies step out of.
const HALF_WIDTH := 20.0
const HEIGHT := 44.0
## The breach pops in from this squash (scale about the ground line), overshooting.
const POP_FROM := Vector2(0.5, 0.65)
const POP_OVER := Vector2(1.12, 1.08)
const CRACK_WIDEST_FRAME := 4

var wall_color := Color("#6d574e")
var crack: AnimatedSprite2D

var hole: Sprite2D
var rim: Sprite2D
var rubble: Sprite2D
var breach: Node2D
var trickle: CPUParticles2D
var _crack_home := Vector2.ZERO


func _ready() -> void:
	breach = Node2D.new()
	add_child(breach)
	hole = _ground_sprite(sheet_frame(SHEET, 0, FRAME))
	rim = _ground_sprite(sheet_frame(SHEET, 1, FRAME))
	for s in [hole, rim]:
		s.reparent(breach, false)
	rubble = _ground_sprite(sheet_frame(SHEET, 2, FRAME))
	# The pile spills onto the sidewalk in front of the wall base.
	rubble.position = Vector2(0.0, 3.0)
	var rock := wall_color * 2.0
	rock.a = 1.0
	rim.modulate = rock
	rubble.modulate = rock
	breach.visible = false
	rubble.visible = false
	trickle = _particles(10, 0.7, false)
	trickle.position = Vector2(0.0, -HEIGHT + 6.0)
	trickle.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	trickle.emission_rect_extents = Vector2(8.0, 2.0)
	trickle.direction = Vector2(0, 1)
	trickle.spread = 10.0
	trickle.gravity = Vector2(0, 260)
	trickle.initial_velocity_min = 5.0
	trickle.initial_velocity_max = 20.0
	trickle.scale_amount_min = 1.0
	trickle.scale_amount_max = 1.5
	trickle.color = grit_color()
	if crack != null:
		_crack_home = crack.position


## Mortar dust: the wall colour washed toward white.
func grit_color() -> Color:
	return wall_color.lerp(Color(0.92, 0.88, 0.82), 0.4)


## Brick shades for flying chunks: lit, face, shadow, mortar.
func chunk_colors() -> Array[Color]:
	return [_shade(1.5), _shade(1.15), _shade(0.6), grit_color()]


func _shade(k: float) -> Color:
	var c := wall_color * k
	c.a = 1.0
	return c


func telegraph(first: bool, seconds: float) -> void:
	super(first, seconds)
	trickle.emitting = true
	if first and crack != null:
		trickle.position = crack.position - position + Vector2(0.0, -6.0)
		_track(create_tween()).tween_property(crack, "frame", CRACK_WIDEST_FRAME, seconds)
		_jitter(crack, _crack_home, 0.5, seconds, 3.0)
	else:
		trickle.position = Vector2(0.0, -HEIGHT + 4.0)
		_jitter(breach, Vector2.ZERO, 0.6, seconds, 2.5)
	# Chips ping off as it gives: three little cracks of brick on the build.
	var chips := _track(create_tween())
	for i in 3:
		chips.tween_interval(seconds / 3.0)
		chips.tween_callback(_chip.bind(first))


func _chip(first: bool) -> void:
	var at := global_position + Vector2(randf_range(-6.0, 6.0), -HEIGHT * (0.55 if first else 0.95))
	SecretFx.brick_burst(self, at, 3, 70.0, chunk_colors())
	SecretFx.play_once(self, CRUMBLE, -14.0, randf_range(0.7, 0.9))


func burst() -> void:
	var reburst := _open
	super()
	if crack != null:
		crack.visible = false
		crack.position = _crack_home
	breach.visible = true
	breach.position = Vector2.ZERO
	var pop := create_tween()
	if not reburst:
		breach.scale = POP_FROM
		pop.tween_property(breach, "scale", POP_OVER, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(breach, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rubble.visible = true
		rubble.scale = Vector2(1.0, 0.0)
		var drop := create_tween()
		drop.tween_interval(0.08)
		drop.tween_property(rubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		breach.scale = POP_OVER
		pop.tween_property(breach, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var centre := global_position + Vector2(0.0, -HEIGHT * 0.5)
	SecretFx.brick_burst(self, centre, 26 if not reburst else 12, 260.0, chunk_colors())
	var dust := grit_color()
	dust.a = 0.85
	_dust_puff(Vector2(0.0, -6.0), dust, 16 if not reburst else 9)
	# Grit keeps sifting off the broken lip for a beat after the blast.
	trickle.position = Vector2(0.0, -HEIGHT + 4.0)
	trickle.emitting = true
	# Untracked: the settle outlives stop(), it is not part of the build-up.
	var settle := create_tween()
	settle.tween_interval(1.2)
	settle.tween_callback(func() -> void: trickle.emitting = false)


func stop() -> void:
	super()
	if crack != null:
		crack.position = _crack_home
	if breach != null:
		breach.position = Vector2.ZERO
	if trickle != null and not _open:
		trickle.emitting = false
