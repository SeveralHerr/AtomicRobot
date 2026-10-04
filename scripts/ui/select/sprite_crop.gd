extends RefCounted

## Character frames carry lots of transparent padding (128px cells, figure ~60px).
## Measure the opaque box so portraits fill their card and feet land on the shadow.


static var _cache := {}


## Opaque pixels of `tex`; the full texture when the image can't be read (headless).
## Cached: get_image() is a GPU readback, a stall per d-pad step on the Pi.
static func used_rect(tex: Texture2D) -> Rect2i:
	if not _cache.has(tex):
		_cache[tex] = _measure(tex)
	return _cache[tex]


static func _measure(tex: Texture2D) -> Rect2i:
	var full := Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
	var img := tex.get_image()
	if img == null or img.is_empty():
		return full
	if img.is_compressed():
		img.decompress()
	var r := img.get_used_rect()
	return r if r.has_area() else full


## `tex` trimmed to its opaque box.
static func cropped(tex: Texture2D) -> Texture2D:
	var r := Rect2(used_rect(tex))
	var a := AtlasTexture.new()
	a.atlas = tex
	if tex is AtlasTexture:  # re-region the sheet rather than nest atlases
		a.atlas = tex.atlas
		r.position += tex.region.position
	a.region = r
	return a
