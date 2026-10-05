extends RefCounted

## The Picade target (Pi 5, 1 GB shared RAM) can't afford art far bigger than it is
## drawn. These were: the power-up and heart pickup logo (1600 px drawn at ~52 / ~120 px),
## the HUD HP orb stages (1463 px in a 108 px box) and the pause background (2000x1260
## behind a 1280x800 viewport). They were right-sized without changing what's on screen.
## (a) pins each drawn size to its pre-swap value; (b) caps each texture at a small
## multiple of its biggest drawn size, so swapping a huge image back in fails here.

var _T

const HP_ORB := preload("res://scenes/hp_1.tscn")
const PAUSE := preload("res://scenes/pause_menu.tscn")
const HEALTH_CONTAINER := preload("res://scripts/health_container.gd")

const VIEWPORT := Vector2(1280, 800)
## Gameplay camera zoom (player.tscn Camera2D).
const CAMERA_ZOOM := 2.5
## Pre-swap drawn sizes in world px: the 1600 px logo at scale 0.013 (power-up) and
## 0.03 (heart); then 2000x1260 covering a 1280x800 viewport (x0.64) for the pause.
const PICKUP_WORLD_PX_BEFORE := {
	"res://scenes/powerup_pickup.tscn": 20.8,
	"res://scenes/atomic_heart_pickup.tscn": 48.0,
}
const PAUSE_BG_BEFORE := Vector2(1280.0, 806.4)
## Height of the HUD's "HP" row in main.tscn (font 100 label); the orb rect fits its width to it.
const HUD_ROW_PX := 108.0
## An icon may be at most this many times its largest on-screen size.
const ICON_BUDGET := 4.0
## A full-screen background may only exceed the viewport by this much.
const BACKGROUND_BUDGET := 1.1


func _pickup_sprite(path: String) -> Sprite2D:
	var pickup := (load(path) as PackedScene).instantiate()
	var sprite := (pickup.get_node("Sprite2D") as Sprite2D).duplicate() as Sprite2D
	pickup.free()
	return sprite


func _pause_background() -> TextureRect:
	var pause := PAUSE.instantiate()
	var bg := (pause.get_node("Background") as TextureRect).duplicate() as TextureRect
	pause.free()
	return bg


## Size of `tex` under TextureRect.STRETCH_KEEP_ASPECT_COVERED in `box`.
func _covered(tex: Texture2D, box: Vector2) -> Vector2:
	var s := tex.get_size()
	return s * maxf(box.x / s.x, box.y / s.y)


func test_pickup_drawn_size_unchanged() -> String:
	for path in PICKUP_WORLD_PX_BEFORE:
		var before: float = PICKUP_WORLD_PX_BEFORE[path]
		var sprite := _pickup_sprite(path)
		var drawn := sprite.texture.get_size() * sprite.scale
		sprite.free()
		if maxf(absf(drawn.x - before), absf(drawn.y - before)) * CAMERA_ZOOM > 1.0:
			return _T.assert_true(false, "%s drawn %s world px, was %.1f (1 screen px slack)" % [path, drawn, before])
	return ""


func test_pickup_texture_within_budget() -> String:
	for path in PICKUP_WORLD_PX_BEFORE:
		var sprite := _pickup_sprite(path)
		var tex_px := sprite.texture.get_size().x
		# Biggest it ever gets: the collect pop swells the sprite by BURST_SCALE.
		var max_screen_px := tex_px * sprite.scale.x * CAMERA_ZOOM * PowerupGlow.BURST_SCALE
		sprite.free()
		if tex_px > max_screen_px * ICON_BUDGET:
			return _T.assert_true(false, "%s texture %d px for at most %.0f screen px" % [path, tex_px, max_screen_px])
	return ""


func test_pause_background_drawn_size_unchanged() -> String:
	var bg := _pause_background()
	var ok := bg.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var drawn := _covered(bg.texture, VIEWPORT)
	bg.free()
	return _T.assert_true(ok and drawn.distance_to(PAUSE_BG_BEFORE) <= 1.0,
			"pause background covers %s, was %s" % [drawn, PAUSE_BG_BEFORE])


func test_pause_background_within_budget() -> String:
	var bg := _pause_background()
	var size := bg.texture.get_size()
	bg.free()
	return _T.assert_true(size.x <= VIEWPORT.x * BACKGROUND_BUDGET and size.y <= VIEWPORT.y * BACKGROUND_BUDGET * 1.01,
			"pause background %s for a %s viewport" % [size, VIEWPORT])


## Every texture the HUD orb can show: the scene's own and each damage stage.
func _orb_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var orb := HP_ORB.instantiate() as TextureRect
	out.append(orb.texture)
	orb.free()
	for t in HEALTH_CONTAINER.ORB_TEXTURES:
		out.append(t)
	return out


## The orb that flies from a secret wall to the HUD is a 64 px CPU shrink of this.
func test_secret_orb_source_within_budget() -> String:
	return _T.assert_true(SecretFx.ORB_TEXTURE.get_width() <= HUD_ROW_PX * ICON_BUDGET,
			"SecretFx.ORB_TEXTURE is %d px" % SecretFx.ORB_TEXTURE.get_width())


func test_hp_orb_drawn_size_unchanged() -> String:
	# The orb fits its width to the HUD row height times the texture's aspect, so the
	# drawn size is unchanged as long as every stage stays square. Laid out for real.
	var tree := Engine.get_main_loop() as SceneTree
	for tex in _orb_textures():
		var row := HBoxContainer.new()
		var strut := Control.new()
		strut.custom_minimum_size = Vector2(1, HUD_ROW_PX)
		row.add_child(strut)
		var orb := HP_ORB.instantiate() as TextureRect
		orb.texture = tex
		row.add_child(orb)
		tree.root.add_child(row)
		await tree.process_frame
		var drawn := orb.size
		row.free()
		if drawn.distance_to(Vector2(HUD_ROW_PX, HUD_ROW_PX)) > 1.0:
			return _T.assert_true(false, "%s draws %s in a %d px row" % [tex.resource_path, drawn, HUD_ROW_PX])
	return ""


func test_hp_orb_textures_within_budget() -> String:
	for tex in _orb_textures():
		if tex.get_width() > HUD_ROW_PX * ICON_BUDGET:
			return _T.assert_true(false, "%s is %d px for a %d px orb" % [tex.resource_path, tex.get_width(), HUD_ROW_PX])
	return ""
