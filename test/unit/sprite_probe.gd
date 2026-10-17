extends RefCounted

## Pixel probes for art checks (test_payton.gd, test_cass_throw.gd): they read the real
## textures, so a test re-measures the art instead of trusting a stored number.


static func frames(c: String) -> SpriteFrames:
	return Globals.character_dict[c].sprite_frames


static func img(c: String, anim: String, i: int) -> Image:
	return frames(c).get_frame_texture(anim, i).get_image()


## [legs centre x, feet y] in cell px: lowest opaque row, and the middle of the opaque
## span over the bottom 10 rows (the legs).
static func stance(image: Image) -> Vector2:
	var bottom := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				bottom = y
				break
	var lo := 9999
	var hi := -1
	for y in range(maxi(bottom - 9, 0), bottom + 1):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return Vector2((lo + hi) / 2.0, bottom)


## Pixels matching `is_px(Color) -> bool`.
static func count(image: Image, is_px: Callable) -> int:
	var n := 0
	for y in image.get_height():
		for x in image.get_width():
			if is_px.call(image.get_pixel(x, y)):
				n += 1
	return n


## Rightmost matching pixel (x, mean y of the matching px in that column band of
## `band` px); (-1, -1) if none.
static func rightmost(image: Image, is_px: Callable, band: int = 3) -> Vector2:
	var right := -1
	for y in image.get_height():
		for x in image.get_width():
			if is_px.call(image.get_pixel(x, y)):
				right = maxi(right, x)
	if right < 0:
		return Vector2(-1, -1)
	var sum := 0.0
	var n := 0
	for y in image.get_height():
		for x in range(maxi(right - band, 0), right + 1):
			if is_px.call(image.get_pixel(x, y)):
				sum += y
				n += 1
	return Vector2(right, sum / n)


## Opaque bounding box.
static func bbox(image: Image) -> Rect2:
	var used := image.get_used_rect()
	return Rect2(used.position, used.size)


## Cell px -> world, through the sprite that draws it (centered, offset, flip via scale).
static func to_world(sprite: Node2D, cell_px: Vector2, tex_size: Vector2, offset: Vector2) -> Vector2:
	return sprite.global_transform * (cell_px - tex_size / 2.0 + offset)
