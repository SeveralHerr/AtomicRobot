class_name DoorMouthFx
extends Node2D

## The visual half of a BuildingDoorEncounter's mouth: the telegraph that builds
## while the squad gets ready, and the burst it pours out of. Subclasses are the
## styles (WallMouth: a brick breach, BushMouth: enemies tearing out of a hedge);
## the encounter only ever calls telegraph() / burst() / stop(), so timing stays
## with the encounter and the look stays here.
##
## The node's origin is the ground line under the mouth (DoorMouth + MOUTH_TO_GROUND).

enum Style { WALL, BUSH }

## DoorMouth sits this far above the ground the mouth opens onto.
const MOUTH_TO_GROUND := Vector2(0.0, 24.0)
## Hitstop on the burst: short — a door is a beat, not a finisher.
const BURST_HIT_PAUSE := 0.05
## Camera shake ramp through a telegraph: a rumble that builds into the burst.
const RUMBLE_START := 2.0
const RUMBLE_PEAK := 5.0

static var _soft_dot: Texture2D = null
static var _leaf: Texture2D = null

var _open := false
## Every tween the current telegraph owns, so the burst (or the encounter ending
## mid-rumble) can stop the build-up dead.
var _tweens: Array[Tween] = []


func is_open() -> bool:
	return _open


## Build-up before a wave. `first`: the mouth is still closed; otherwise the
## already-open mouth rattles for a later wave. Lasts `seconds`.
func telegraph(_first: bool, seconds: float) -> void:
	_rumble(seconds)


## The mouth blows open (or re-bursts for a later wave).
func burst() -> void:
	stop()
	_open = true
	Utils.apply_hit_pause(self, BURST_HIT_PAUSE)


## Kills the telegraph build-up (burst, or the encounter ended mid-rumble).
func stop() -> void:
	for t in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()


func _track(t: Tween) -> Tween:
	_tweens.append(t)
	return t


## Shake that climbs from RUMBLE_START to RUMBLE_PEAK across the telegraph.
func _rumble(seconds: float) -> void:
	var steps := 3
	var t := _track(create_tween())
	for i in steps:
		var k := float(i) / float(steps - 1)
		t.tween_callback(ScreenShake.apply_shake.bind(lerpf(RUMBLE_START, RUMBLE_PEAK, k), seconds / steps + 0.05))
		t.tween_interval(seconds / steps)


## Small random hops of `node` around `home` for `seconds` (amplitude `amp` px,
## growing to `amp * grow`), ending back on `home`.
func _jitter(node: Node2D, home: Vector2, amp: float, seconds: float, grow: float = 2.0) -> void:
	var t := _track(create_tween())
	var hops := maxi(2, int(seconds / 0.04))
	for i in hops:
		var a := amp * lerpf(1.0, grow, float(i) / float(hops))
		t.tween_property(node, "position", home + Vector2(randf_range(-a, a), randf_range(-a * 0.5, a * 0.5)).round(), seconds / hops)
	t.tween_property(node, "position", home, 0.02)


## A one-shot soft dust cloud at local `at`: slow, swelling puffs in `color`.
func _dust_puff(at: Vector2, color: Color, amount: int = 14, speed: float = 70.0) -> CPUParticles2D:
	var p := _particles(amount, 0.9)
	p.texture = soft_dot()
	p.position = at
	p.direction = Vector2(0, -1)
	p.spread = 100.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.9
	p.damping_max = speed * 1.3
	p.gravity = Vector2(0, -12)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.scale_amount_curve = _curve([Vector2(0, 0.6), Vector2(1, 1.6)])
	p.color = color
	p.color_ramp = _fade(color)
	p.emitting = true
	return p


## Shared particle defaults: one-shot burst, freed when done, drawn over the street.
func _particles(amount: int, lifetime: float, one_shot: bool = true) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.emitting = false
	p.z_as_relative = false
	p.z_index = 5
	if one_shot:
		p.finished.connect(p.queue_free)
	add_child(p)
	return p


static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	c.max_value = 4.0
	for pt in points:
		c.add_point(pt)
	return c


static func _fade(color: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, color.a), Color(1, 1, 1, 0)])
	return g


## 8 px radial dot, white -> transparent (dust).
static func soft_dot() -> Texture2D:
	if _soft_dot == null:
		var g := GradientTexture2D.new()
		g.width = 8
		g.height = 8
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		g.gradient = grad
		_soft_dot = g
	return _soft_dot


## The 3 px street leaf (images/new/leaf.png) in white, so particles tint it.
static func leaf_texture() -> Texture2D:
	if _leaf == null:
		var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		for p in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]:
			img.set_pixelv(p, Color.WHITE)
		_leaf = ImageTexture.create_from_image(img)
	return _leaf


## One frame of a 3-frame sprite sheet as its own texture.
static func sheet_frame(sheet: Texture2D, index: int, size: Vector2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(Vector2(size.x * index, 0.0), size)
	return a


## A bottom-centre anchored sprite (origin on the ground), hidden until used.
func _ground_sprite(tex: Texture2D, z: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	s.z_index = z
	add_child(s)
	return s
