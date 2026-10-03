extends RefCounted

## The Picade cabinet's GPU (Pi 5, WebGL2) caps textures at 4096 px; anything
## larger renders as a black square. Every character's SpriteFrames must stay
## under it, including the sheet behind an AtlasTexture region.

const MAX_TEXTURE_PX := 4096
const SPRITES_DIR := "res://sprites"

var _T

func _sprite_frames() -> Array[SpriteFrames]:
	var found: Array[SpriteFrames] = []
	for file in DirAccess.get_files_at(SPRITES_DIR):
		if file.get_extension() != "tres":
			continue
		var res := load(SPRITES_DIR.path_join(file))
		if res is SpriteFrames:
			found.append(res)
	return found

func test_sprite_frames_are_found() -> String:
	return _T.assert_gt(_sprite_frames().size(), 5, "SpriteFrames .tres files under %s" % SPRITES_DIR)

func test_no_sprite_sheet_exceeds_gpu_limit() -> String:
	for frames in _sprite_frames():
		for anim in frames.get_animation_names():
			for i in frames.get_frame_count(anim):
				var tex: Texture2D = frames.get_frame_texture(anim, i)
				var sheet: Texture2D = tex.atlas if tex is AtlasTexture else tex
				# Headless textures report 0x0, so measure the source image itself.
				var size := Image.load_from_file(sheet.resource_path).get_size()
				if maxf(size.x, size.y) > MAX_TEXTURE_PX:
					return "%s (%s frame %d) uses %s at %dx%d > %d px" % [
						frames.resource_path, anim, i, sheet.resource_path, size.x, size.y, MAX_TEXTURE_PX]
	return ""


## Scenes reach textures directly too (TextureRect, Sprite2D, Parallax layers), so
## sweep every image any scene or resource in the project references.
func _referenced_images() -> PackedStringArray:
	var found := {}
	var re := RegEx.create_from_string('path="(res://[^"]+\\.(?:png|jpg|webp))"')
	for file in _project_files("res://", ["tscn", "tres"]):
		for m in re.search_all(FileAccess.get_file_as_string(file)):
			found[m.get_string(1)] = true
	return PackedStringArray(found.keys())


func _project_files(dir: String, exts: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and sub != "addons":
			out.append_array(_project_files(dir.path_join(sub), exts))
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in exts:
			out.append(dir.path_join(file))
	return out


func test_scene_images_are_found() -> String:
	return _T.assert_gt(_referenced_images().size(), 50, "images referenced by scenes/resources")


func test_no_referenced_image_exceeds_gpu_limit() -> String:
	var over := []
	for path in _referenced_images():
		var image := Image.load_from_file(path)
		if image == null:
			continue  # reported by test_referenced_images_exist_with_exact_case
		var size := image.get_size()
		if maxf(size.x, size.y) > MAX_TEXTURE_PX:
			over.append("%s %dx%d" % [path, size.x, size.y])
	return _T.assert_eq(over, [], "images over %d px" % MAX_TEXTURE_PX)


## Windows matches paths case-insensitively; Linux CI and the exported pck do not, so a
## "Tiles/" vs "tiles/" slip passes locally and ships a missing texture. Walk each
## segment against the real directory listing.
func _exact_case_exists(path: String) -> bool:
	var dir := "res://"
	for part in path.trim_prefix("res://").split("/"):
		var names := DirAccess.get_directories_at(dir) + DirAccess.get_files_at(dir)
		if part not in names:
			return false
		dir = dir.path_join(part)
	return true


func test_referenced_images_exist_with_exact_case() -> String:
	var bad := []
	for path in _referenced_images():
		if not _exact_case_exists(path):
			bad.append(path)
	return _T.assert_eq(bad, [], "referenced images missing or wrong-cased")
