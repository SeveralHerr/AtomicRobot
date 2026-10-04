class_name BushMouth
extends DoorMouthFx

## Enemies bursting out of a hedge. Closed: a shrub cut from the hedge art sits in
## front of it, so the mouth is hidden in the foliage; now and then it twitches and
## drops a leaf (the tell). Telegraph: the shrub shakes harder and harder, leaves
## shed and a pair of eyes peeks out. Burst: the shrub tears apart — two halves
## swing open like curtains over a dark hollow, leaves blast out and litter the
## sidewalk. Later waves: the parted halves thrash and the eyes peek again.

## clump | hollow | litter | left half | right half, 64x56 each, bottom-aligned
## (sprites/door_bush.png).
const SHEET := preload("res://sprites/door_bush.png")
const FRAME := Vector2(64, 56)
const RUSTLE := preload("res://sounds/Retro FootStep Grass 01.wav")
## Hedge leaf shades (images/new/Background_bush2.png) plus a little fresh green.
const LEAF_COLORS: Array[Color] = [Color("#445250"), Color("#586864"), Color("#2e393a"), Color("#3b7a48")]
## On the burst the halves are shoved OPEN_SHOVE px apart and tip OPEN_SWING rad
## outward, then settle at OPEN_SLIDE px / OPEN_REST rad: two shrub halves framing
## the dark tunnel between them. (Pure rotation about the feet left a V-shaped gap
## that read as a black vase.)
const OPEN_SHOVE := 14.0
const OPEN_SLIDE := 9.0
const OPEN_SWING := 0.4
const OPEN_REST := 0.16
## Seconds between idle twitches while closed.
const TWITCH_MIN := 2.5
const TWITCH_MAX := 5.0
const EYE_COLOR := Color("#ffe9a8")

## The hedge's own modulate (Bush sprites in building_group_3 are 0.73).
var foliage_shade := 1.0

var clump: Sprite2D
var hollow: Sprite2D
var litter: Sprite2D
var left_half: Sprite2D
var right_half: Sprite2D
var eyes: Node2D
var shed: CPUParticles2D
var _twitch: Timer


func _ready() -> void:
	var tint := Color(foliage_shade, foliage_shade, foliage_shade)
	hollow = _ground_sprite(sheet_frame(SHEET, 1, FRAME))
	hollow.modulate = tint
	left_half = _half(3, -1)
	right_half = _half(4, 1)
	clump = _ground_sprite(sheet_frame(SHEET, 0, FRAME))
	litter = _ground_sprite(sheet_frame(SHEET, 2, FRAME))
	litter.position = Vector2(0.0, 3.0)
	for s in [clump, left_half, right_half, litter]:
		s.modulate = tint
	for s in [hollow, left_half, right_half, litter]:
		s.visible = false
	eyes = _make_eyes()
	shed = _particles(8, 1.4, false)
	shed.position = Vector2(0.0, -FRAME.y * 0.7)
	shed.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	shed.emission_rect_extents = Vector2(20.0, 8.0)
	_leafy(shed, 30.0, 140.0)
	_twitch = Timer.new()
	_twitch.one_shot = true
	_twitch.timeout.connect(_on_twitch)
	add_child(_twitch)
	_twitch.start(randf_range(TWITCH_MIN, TWITCH_MAX))


## One half of the torn shrub (sheet frame 3 = left, 4 = right: the clump split
## down a leafy zig-zag, so the two rebuild it exactly). It pivots on its outer
## foot, 0.4 of the frame out from the centre, so it tips open outward.
func _half(index: int, side: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = sheet_frame(SHEET, index, FRAME)
	s.centered = false
	s.position = Vector2(side * FRAME.x * 0.4, 0.0)
	s.offset = Vector2(-FRAME.x * 0.5 - s.position.x, -FRAME.y)
	add_child(s)
	return s


func _make_eyes() -> Node2D:
	var n := Node2D.new()
	n.position = Vector2(0.0, -30.0)
	n.visible = false
	n.z_index = 1
	for x in [-4.0, 2.0]:
		var e := Polygon2D.new()
		e.color = EYE_COLOR
		e.polygon = PackedVector2Array([Vector2(x, 0), Vector2(x + 2, 0), Vector2(x + 2, 1), Vector2(x, 1)])
		n.add_child(e)
	add_child(n)
	return n


## Leaf particle look: the 3 px leaf in hedge shades, tumbling down.
func _leafy(p: CPUParticles2D, v_min: float, v_max: float) -> void:
	p.texture = leaf_texture()
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector2(0, 240)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 0.75, 1.0])
	ramp.colors = PackedColorArray(LEAF_COLORS)
	p.color_initial_ramp = ramp


func _on_twitch() -> void:
	if _open or not is_inside_tree():
		return
	var t := create_tween()
	for k in [0.06, -0.05, 0.03, 0.0]:
		t.tween_property(clump, "skew", k, 0.07)
	_drop_leaves(1)
	_twitch.start(randf_range(TWITCH_MIN, TWITCH_MAX))


func _drop_leaves(n: int) -> void:
	var p := _particles(n, 1.4)
	p.position = Vector2(randf_range(-14.0, 14.0), -FRAME.y * 0.6)
	_leafy(p, 10.0, 40.0)
	p.emitting = true


func telegraph(first: bool, seconds: float) -> void:
	super(first, seconds)
	_twitch.stop()
	shed.emitting = true
	_drop_leaves(5)  # the first shove knocks a handful loose at once
	var targets: Array = [clump] if first else [left_half, right_half]
	for s in targets:
		_thrash(s, seconds, s.rotation)
	# The eyes peek out once the shaking has had a moment to land.
	var peek := _track(create_tween())
	peek.tween_interval(seconds * 0.25)
	peek.tween_callback(func() -> void: eyes.visible = true)
	# One blink, late: they have seen you.
	peek.tween_interval(seconds * 0.5)
	peek.tween_callback(func() -> void: eyes.scale = Vector2(1.0, 0.0))
	peek.tween_interval(0.05)
	peek.tween_callback(func() -> void: eyes.scale = Vector2.ONE)
	var rustles := _track(create_tween())
	for i in 3:
		rustles.tween_callback(SecretFx.play_once.bind(self, RUSTLE, -10.0 + i * 3.0, randf_range(0.9, 1.2)))
		rustles.tween_interval(seconds / 3.0)


## Skews and squashes `s` back and forth, harder as the telegraph goes on.
func _thrash(s: Sprite2D, seconds: float, base_rot: float) -> void:
	var t := _track(create_tween())
	var beats := maxi(3, int(seconds / 0.06))
	for i in beats:
		var k := lerpf(0.08, 0.24, float(i) / float(beats))
		var dir := 1.0 if i % 2 == 0 else -1.0
		t.tween_property(s, "skew", dir * k, seconds / beats)
		t.parallel().tween_property(s, "scale", Vector2(1.0 + k * 0.4, 1.0 - k * 0.5), seconds / beats)
		t.parallel().tween_property(s, "rotation", base_rot + dir * k * 0.3, seconds / beats)
	t.tween_property(s, "skew", 0.0, 0.03)
	t.parallel().tween_property(s, "scale", Vector2.ONE, 0.03)


func burst() -> void:
	var reburst := _open
	super()
	_twitch.stop()
	shed.emitting = false
	eyes.visible = false
	clump.visible = false
	hollow.visible = true
	litter.visible = true
	for half in [left_half, right_half]:
		half.visible = true
		half.skew = 0.0
		half.scale = Vector2.ONE
		var side := -1.0 if half == left_half else 1.0
		var home := side * FRAME.x * 0.4
		var t := create_tween()
		t.tween_property(half, "rotation", side * OPEN_SWING, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(half, "position:x", home + side * OPEN_SHOVE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(half, "rotation", side * OPEN_REST, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(half, "position:x", home + side * OPEN_SLIDE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var blast := _particles(34 if not reburst else 16, 1.3)
	blast.position = Vector2(0.0, -FRAME.y * 0.45)
	blast.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	blast.emission_rect_extents = Vector2(10.0, 14.0)
	_leafy(blast, 110.0, 260.0)
	blast.spread = 85.0
	blast.emitting = true
	var dust := Color(0.42, 0.48, 0.44, 0.6)
	_dust_puff(Vector2(0.0, -4.0), dust, 8, 50.0)
	SecretFx.play_once(self, RUSTLE, -2.0, 0.8)


func stop() -> void:
	super()
	if shed != null:
		shed.emitting = false
	if eyes != null and not _open:
		eyes.visible = false
	for s in [clump, left_half, right_half]:
		if s != null:
			s.skew = 0.0
			s.scale = Vector2.ONE
