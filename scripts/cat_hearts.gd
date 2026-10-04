class_name CatHearts

## The little puff of pixel hearts a petted cat (scripts/cat.gd) gives off.

const GROUP := "cat_hearts"
const RED := Color("#ff4f7b")
const SHINE := Color("#ffd1dc")
const INK := Color("#2a0d17")
## World px each heart pixel is drawn at (the cat is pixel art too).
const PIXEL := 1.2  # x2.5 camera zoom = 3 screen px: crisp
const RISE := 26.0
const LIFE := 0.9
const STAGGER := 0.14
const DRIFT := 12.0

const SHAPE := [
	".XX...XX.",
	"XXXX.XXXX",
	"XXXXXXXXX",
	"XXXXXXXXX",
	".XXXXXXX.",
	"..XXXXX..",
	"...XXX...",
	"....X....",
]

static var _texture: Texture2D = null


## A 9x8 heart with a dark outline and one shine pixel, built once.
static func texture() -> Texture2D:
	if _texture != null:
		return _texture
	var w: int = SHAPE[0].length() + 2
	var h: int = SHAPE.size() + 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in SHAPE.size():
		for x in SHAPE[y].length():
			if SHAPE[y][x] == "X":
				for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var p := Vector2i(x + 1, y + 1) + o
					if img.get_pixelv(p).a == 0.0:
						img.set_pixelv(p, INK)
	for y in SHAPE.size():
		for x in SHAPE[y].length():
			if SHAPE[y][x] == "X":
				img.set_pixel(x + 1, y + 1, RED)
	img.set_pixel(2, 3, SHINE)
	_texture = ImageTexture.create_from_image(img)
	return _texture


## `count` hearts rise from `world_pos`, fanned out and staggered, owned by `owner`,
## drifting toward `away` (-1 left, 1 right) so they clear the petter's face.
static func puff(owner: Node2D, world_pos: Vector2, count: int, away := 0) -> void:
	for i in count:
		var heart := Sprite2D.new()
		heart.texture = texture()
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart.top_level = true
		heart.z_index = 3
		heart.scale = Vector2.ZERO
		heart.add_to_group(GROUP)
		owner.add_child(heart)
		var fan := (float(i) - (count - 1) / 2.0) * 12.0
		heart.global_position = world_pos + Vector2(fan * 0.4, 0)
		var delay := i * STAGGER
		var size := PIXEL if i % 2 == 0 else 0.8  # big, small, big; 0.8 x2.5 = 2 px
		heart.rotation = signf(fan) * 0.18
		var end := heart.global_position + Vector2(fan + away * DRIFT, -RISE - i * 5.0)
		var t := heart.create_tween()
		t.tween_interval(delay)
		t.tween_property(heart, "scale", Vector2.ONE * size, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(heart, "global_position", end, LIFE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(heart, "modulate:a", 0.0, LIFE * 0.45).set_delay(LIFE * 0.55)
		t.tween_callback(heart.queue_free)
