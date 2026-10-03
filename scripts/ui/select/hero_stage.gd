extends Control

## The focused fighter, big, on a spinning ray burst. Changing fighter slides the
## old one off and squash-drops the new one in from the side the cursor moved to.
## Origin of this Control = the fighter's feet.

const Juice := preload("res://scripts/ui/select/juice.gd")
const SpriteCrop := preload("res://scripts/ui/select/sprite_crop.gd")
const RAYS: Material = preload("res://shaders/rays_shader_mat.tres")
const SPRITE_SCALE := 4.0
const RAYS_SIZE := 640.0
const SLIDE := 140.0

var rays: ColorRect
var shadow: Panel
var sprite: AnimatedSprite2D
var mystery: Label
var stamp: Label
var _swap: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays = ColorRect.new()
	rays.material = RAYS.duplicate()
	rays.material.set_shader_parameter("ray2_intensity", 0.15)
	rays.modulate.a = 0.6  # a glow behind the fighter, not a white-out over pale sprites
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.size = Vector2.ONE * RAYS_SIZE
	rays.position = Vector2(-RAYS_SIZE / 2.0, -RAYS_SIZE / 2.0 - 170.0)
	rays.pivot_offset = rays.size / 2.0
	add_child(rays)

	shadow = Panel.new()
	var ellipse := StyleBoxFlat.new()
	ellipse.bg_color = Color(0, 0, 0, 0.45)
	ellipse.set_corner_radius_all(60)
	shadow.add_theme_stylebox_override("panel", ellipse)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.size = Vector2(220, 34)
	shadow.position = Vector2(-110, -17)
	shadow.pivot_offset = shadow.size / 2.0
	add_child(shadow)

	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(sprite)

	mystery = ComicStyle.heading("?", 220, ComicStyle.RED)
	mystery.add_theme_color_override("font_outline_color", ComicStyle.PAPER)
	mystery.add_theme_constant_override("outline_size", 18)
	mystery.size = Vector2(240, 260)
	mystery.position = Vector2(-120, -300)
	mystery.pivot_offset = mystery.size / 2.0
	mystery.hide()
	add_child(mystery)

	stamp = ComicStyle.heading("READY!", 96, ComicStyle.YELLOW)
	stamp.add_theme_constant_override("outline_size", 16)
	stamp.add_theme_color_override("font_shadow_color", ComicStyle.RED)
	stamp.add_theme_constant_override("shadow_offset_x", 6)
	stamp.add_theme_constant_override("shadow_offset_y", 6)
	stamp.add_theme_constant_override("shadow_outline_size", 16)
	stamp.size = Vector2(620, 130)
	stamp.position = Vector2(-310, -392)  # above the head, below the title
	stamp.pivot_offset = stamp.size / 2.0
	stamp.hide()
	add_child(stamp)


## `dir` is -1/+1 for the way the cursor moved (0 on open: drop straight down).
func show_character(cfg: CharacterConfig, unlocked: bool, dir: int) -> void:
	if dir != 0 and sprite.sprite_frames:
		_ghost_out(dir)
	sprite.sprite_frames = cfg.sprite_frames
	sprite.play("idle")
	# Feet (bottom of the opaque box) on the origin, body centred over the shadow.
	var tex := cfg.sprite_frames.get_frame_texture("idle", 0)
	var body := SpriteCrop.used_rect(tex)
	sprite.offset = tex.get_size() / 2.0 - Vector2(body.get_center().x, body.end.y)
	sprite.modulate = Color.WHITE if unlocked else Juice.SILHOUETTE
	mystery.visible = not unlocked
	stamp.hide()  # a stamp belongs to the fighter it was stamped on
	if _swap:
		_swap.kill()
	sprite.position = Vector2(dir * SLIDE, -60.0 if dir == 0 else 0.0)
	sprite.scale = SPRITE_SCALE * Vector2(1.3, 0.7)
	sprite.self_modulate.a = 0.0
	_swap = create_tween().set_parallel()
	_swap.tween_property(sprite, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swap.tween_property(sprite, "scale", Vector2.ONE * SPRITE_SCALE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_swap.tween_property(sprite, "self_modulate:a", 1.0, 0.08)
	Juice.pop(shadow, 1.25, 1.0, 0.3)
	Juice.pop(rays, 1.08, 1.0, 0.25)
	if not unlocked:
		Juice.pop(mystery, 1.4, 1.0, 0.3)


## The outgoing fighter: a frozen copy that slides off the other way and fades.
func _ghost_out(dir: int) -> void:
	var ghost := AnimatedSprite2D.new()
	ghost.sprite_frames = sprite.sprite_frames
	ghost.frame = sprite.frame
	ghost.offset = sprite.offset
	ghost.scale = Vector2.ONE * SPRITE_SCALE
	ghost.modulate = sprite.modulate
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(ghost)
	move_child(ghost, sprite.get_index())
	var t := ghost.create_tween().set_parallel()
	t.tween_property(ghost, "position:x", -dir * SLIDE, 0.12).set_ease(Tween.EASE_IN)
	t.tween_property(ghost, "modulate:a", 0.0, 0.12)
	t.chain().tween_callback(ghost.queue_free)


## A fighter just earned: the silhouette floods with colour under a NEW CHALLENGER!
## stamp, as fighting games announce one.
func reveal() -> void:
	_set_stamp("NEW CHALLENGER!", 66)
	sprite.modulate = Juice.SILHOUETTE
	mystery.hide()
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(3, 3, 3), 0.25)  # overbright flash
	t.tween_property(sprite, "modulate", Color.WHITE, 0.35)
	(rays.material as ShaderMaterial).set_shader_parameter("speed", 4.0)
	Juice.pop(rays, 1.3, 1.0, 0.5)
	Juice.slam(stamp, -6.0, 0.35)


func _set_stamp(text: String, font_size: int) -> void:
	stamp.text = text
	stamp.add_theme_font_size_override("font_size", font_size)


## Hitstop: hold the fighter on its current frame.
func freeze() -> void:
	if _swap:
		_swap.kill()
	sprite.speed_scale = 0.0


## Fighter picked: hop, squash on landing, stamp READY!, rays spin up.
func celebrate() -> void:
	_set_stamp("READY!", 96)
	sprite.speed_scale = 1.0
	(rays.material as ShaderMaterial).set_shader_parameter("speed", 5.0)
	Juice.pop(rays, 1.15, 1.0, 0.4)
	Juice.slam(stamp, -8.0)
	var hop := create_tween()
	hop.tween_property(sprite, "position:y", -90.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(sprite, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hop.tween_callback(func() -> void: Juice.pop(shadow, 1.3, 1.0, 0.25))
	hop.tween_property(sprite, "scale", SPRITE_SCALE * Vector2(1.25, 0.8), 0.05)
	hop.tween_property(sprite, "scale", Vector2.ONE * SPRITE_SCALE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
