class_name SecretFx
extends RefCounted

## Payoff effects for a secret wall (scripts/crack.gd): brick chunks, the orb that
## waits in the hole, and its flight to the HP bar when claimed. Static helpers on
## purpose — the crack owns every node they make, so a scene change frees them all.

## Wall brick, shadow and mortar dust, sampled from the building art around crack B.
const BRICK_COLORS: Array[Color] = [Color("#a28b7e"), Color("#8f786c"), Color("#524242"), Color("#d8c6b4")]
## Seconds from the hole to the HP bar.
const FLIGHT := 0.75
## Orb size in world px while it sits in the hole, and in screen px on the HUD.
const HOLE_ORB_PX := 18.0
const HUD_ORB_PX := 40.0
## HUD orbs are 40 px TextureRects packed with -2 separation.
const HUD_ORB_STEP := 38.0
## Mid-flight the orb swells by this much (sin bump), so it reads crossing the screen.
const FLIGHT_POP := 1.2
const TRAIL_GOLD := Color(1.0, 0.78, 0.17, 0.8)
const TRAIL_WIDTH := 20.0
const TRAIL_POINTS := 28
const ORB_TEXTURE := preload("res://images/Logo+Web.png")
## Hole interior: dark plaster at the rim, a warm glow in the middle where the orb sits.
const INTERIOR_SHADER := preload("res://scripts/crack_interior.gdshader")

static var _small_orb: Texture2D = null


## The orb logo shrunk once on the CPU: the 1463 px source has no mipmaps, so
## drawing it at 14 px straight from the GPU shimmers.
static func small_orb() -> Texture2D:
	if _small_orb == null:
		var img := ORB_TEXTURE.get_image()
		if img == null:
			return ORB_TEXTURE
		if img.is_compressed():
			img.decompress()
		img.resize(64, 64, Image.INTERPOLATE_LANCZOS)
		_small_orb = ImageTexture.create_from_image(img)
	return _small_orb


## A one-shot burst of brick chunks at `world_pos`, owned by `owner`. `colors`
## (4 shades, light to dust) defaults to this building's brick.
static func brick_burst(owner: Node2D, world_pos: Vector2, amount: int, speed: float,
		colors: Array[Color] = BRICK_COLORS) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 520)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	ramp.colors = PackedColorArray(colors)
	p.color_initial_ramp = ramp
	p.z_as_relative = false
	p.z_index = 5
	owner.add_child(p)
	p.global_position = world_pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Margin (px) around a hole's silhouette that rim_texture() draws into.
const RIM_PX := 3


## Broken-brick rim for a hole silhouette (`frame`, any opaque pixel = hole): the
## brick right at the edge shows its dark broken face, chunks a pixel further out
## catch the light, and the outline is chipped so it never reads as a clean
## sticker. The result is `frame` grown by RIM_PX on every side — draw it centred
## on the hole, behind it.
static func rim_texture(frame: Texture2D, colors: Array[Color] = BRICK_COLORS, seed: int = 1) -> ImageTexture:
	var src := frame.get_image()
	if src.is_compressed():
		src.decompress()
	var w := src.get_width() + RIM_PX * 2
	var h := src.get_height() + RIM_PX * 2
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for y in h:
		for x in w:
			var d := _hole_distance(src, x - RIM_PX, y - RIM_PX)
			if d == 0 or d > RIM_PX:
				continue
			# Chunky: whole 2x2 cells drop out past the first ring.
			var chunk := RandomNumberGenerator.new()
			chunk.seed = seed * 7919 + (x / 2) * 131 + (y / 2) * 17
			if d >= 2 and chunk.randf() < 0.45 + 0.2 * (d - 2):
				continue
			var c: Color = colors[2] if d == 1 else (colors[3] if d == 2 and chunk.randf() < 0.3 else colors[0])
			out.set_pixel(x, y, c)
	return ImageTexture.create_from_image(out)


## Chebyshev distance (0..RIM_PX+1) from (x, y) to the nearest opaque pixel of `img`.
static func _hole_distance(img: Image, x: int, y: int) -> int:
	for d in range(0, RIM_PX + 1):
		for yy in range(y - d, y + d + 1):
			for xx in range(x - d, x + d + 1):
				if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height() 						and img.get_pixel(xx, yy).a > 0.5:
					return d
	return RIM_PX + 1


## Screen point where the next HUD orb will appear (right of the last one).
static func hud_orb_slot(tree: SceneTree) -> Vector2:
	var scene := tree.current_scene
	var hud := scene.find_child("HealthContainer", true, false) if scene else null
	var row := hud.find_child("HBoxContainer", true, false) as Control if hud else null
	if row == null:
		return Vector2(80, 30)
	var r := row.get_global_rect()
	var shown := 0
	for c in row.get_children():
		if c is CanvasItem and c.visible:
			shown += 1
	return Vector2(r.position.x + HUD_ORB_STEP * (shown + 0.5), r.position.y + HUD_ORB_PX * 0.5)


## Flies an orb on screen from `world_pos` to the HP bar, then calls `on_arrive`.
## The flight lives under `owner`, so it is dropped (no heal) if the scene goes.
static func fly_orb(owner: Node2D, world_pos: Vector2, on_arrive: Callable) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 3  # over the HUD (2), under the CRT overlay
	owner.add_child(layer)
	var trail := Line2D.new()
	trail.width = TRAIL_WIDTH
	trail.width_curve = Curve.new()
	trail.width_curve.add_point(Vector2(0, 0))
	trail.width_curve.add_point(Vector2(1, 1))
	trail.default_color = TRAIL_GOLD
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	layer.add_child(trail)
	var orb := Sprite2D.new()
	orb.texture = small_orb()
	layer.add_child(orb)
	var start := owner.get_viewport().get_canvas_transform() * world_pos
	var end := hud_orb_slot(owner.get_tree())
	var zoom := owner.get_viewport().get_canvas_transform().get_scale().x
	var px_to_scale := 1.0 / float(orb.texture.get_width())
	var from_scale := HOLE_ORB_PX * zoom * px_to_scale
	var to_scale := HUD_ORB_PX * px_to_scale
	# Up out of the hole first, then a dive into the bar.
	var lift := start + Vector2((end.x - start.x) * 0.15, -minf(220.0, start.y * 0.6))
	orb.position = start
	orb.scale = Vector2.ONE * from_scale
	var t := layer.create_tween()
	t.tween_method(func(k: float) -> void:
		orb.position = start.lerp(lift, k).lerp(lift.lerp(end, k), k)
		orb.rotation = k * TAU
		orb.scale = Vector2.ONE * lerpf(from_scale, to_scale, k) * (1.0 + FLIGHT_POP * sin(k * PI))
		trail.add_point(orb.position)
		while trail.get_point_count() > TRAIL_POINTS:
			trail.remove_point(0),
		0.0, 1.0, FLIGHT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(on_arrive)
	t.tween_callback(layer.queue_free)
	return layer


## Plays `stream` once (at `pitch`) on a throwaway player under `owner`.
static func play_once(owner: Node, stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var a := AudioStreamPlayer.new()
	a.stream = stream
	a.volume_db = volume_db
	a.pitch_scale = pitch
	owner.add_child(a)
	a.finished.connect(a.queue_free)
	a.play()
