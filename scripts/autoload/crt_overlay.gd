extends Node

## Full-screen CRT post-process overlay (autoload).
##
## Adds a CanvasLayer above everything (highest scene layer is 2) with a
## full-rect ColorRect whose shader reads hint_screen_texture — so the whole
## composited frame (world + UI + fades) gets the CRT treatment in every scene.
## Toggle with CRTOverlay.set_enabled(false) if a menu/setting needs it off.
##
## Every @export below mirrors a uniform in crt_overlay.gdshader and pushes
## straight to the live ShaderMaterial through its setter. To tweak: run the
## game, select CRTOverlay in the Remote scene tree (Godot editor, bottom of
## the Scene dock while playing), and drag the Inspector sliders to preview
## changes instantly — then copy the values you like back here as defaults.

const CRT_SHADER := preload("res://shaders/crt_overlay.gdshader")

@export_group("Grid")
@export var resolution := Vector2(512.0, 320.0): set = _set_resolution
@export var pixelate := true: set = _set_pixelate

@export_group("Scanlines / Grille")
@export_range(0.0, 1.0) var scanlines_opacity := 0.3: set = _set_scanlines_opacity
@export_range(0.0, 0.5) var scanlines_width := 0.25: set = _set_scanlines_width
@export_range(0.0, 1.0) var grille_opacity := 0.2: set = _set_grille_opacity

@export_group("VHS Roll")
@export var roll := true: set = _set_roll
@export var roll_speed := 8.0: set = _set_roll_speed
@export_range(0.0, 100.0) var roll_size := 15.0: set = _set_roll_size
@export_range(0.1, 5.0) var roll_variation := 1.8: set = _set_roll_variation
@export_range(0.0, 0.2) var distort_intensity := 0.015: set = _set_distort_intensity

@export_group("Noise")
@export_range(0.0, 1.0) var noise_opacity := 0.15: set = _set_noise_opacity
@export var noise_speed := 5.0: set = _set_noise_speed
@export_range(0.0, 1.0) var static_noise_intensity := 0.04: set = _set_static_noise_intensity

@export_group("Color")
@export_range(-1.0, 1.0) var aberration := 0.015: set = _set_aberration
@export var brightness := 1.2: set = _set_brightness
@export var discolor := false: set = _set_discolor

@export_group("Warp / Vignette")
@export_range(0.0, 5.0) var warp_amount := 0.0: set = _set_warp_amount
@export var vignette_intensity := 0.4: set = _set_vignette_intensity
@export_range(0.0, 1.0) var vignette_opacity := 0.4: set = _set_vignette_opacity

var _layer: CanvasLayer
var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	# The shader animates via our `unscaled_time` uniform instead of TIME:
	# Utils.apply_hit_pause zeroes Engine.time_scale, which freezes TIME but
	# not the ticks clock, so VHS noise keeps rolling through hit-pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_material = ShaderMaterial.new()
	_material.shader = CRT_SHADER
	_apply_all_parameters()

	_layer = CanvasLayer.new()
	# Distinctive name so DevTools' HUD-layer fallback never grabs it.
	_layer.name = "CRTOverlayLayer"
	_layer.layer = 100
	add_child(_layer)

	_rect = ColorRect.new()
	_rect.name = "CRTRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_layer.add_child(_rect)


func _process(_delta: float) -> void:
	_material.set_shader_parameter("unscaled_time", Time.get_ticks_msec() / 1000.0)


func set_enabled(enabled: bool) -> void:
	_layer.visible = enabled


func is_enabled() -> bool:
	return _layer.visible


func _apply_all_parameters() -> void:
	_set_resolution(resolution)
	_set_pixelate(pixelate)
	_set_scanlines_opacity(scanlines_opacity)
	_set_scanlines_width(scanlines_width)
	_set_grille_opacity(grille_opacity)
	_set_roll(roll)
	_set_roll_speed(roll_speed)
	_set_roll_size(roll_size)
	_set_roll_variation(roll_variation)
	_set_distort_intensity(distort_intensity)
	_set_noise_opacity(noise_opacity)
	_set_noise_speed(noise_speed)
	_set_static_noise_intensity(static_noise_intensity)
	_set_aberration(aberration)
	_set_brightness(brightness)
	_set_discolor(discolor)
	_set_warp_amount(warp_amount)
	_set_vignette_intensity(vignette_intensity)
	_set_vignette_opacity(vignette_opacity)


func _set_resolution(value: Vector2) -> void:
	resolution = value
	if _material: _material.set_shader_parameter("resolution", value)


func _set_pixelate(value: bool) -> void:
	pixelate = value
	if _material: _material.set_shader_parameter("pixelate", value)


func _set_scanlines_opacity(value: float) -> void:
	scanlines_opacity = value
	if _material: _material.set_shader_parameter("scanlines_opacity", value)


func _set_scanlines_width(value: float) -> void:
	scanlines_width = value
	if _material: _material.set_shader_parameter("scanlines_width", value)


func _set_grille_opacity(value: float) -> void:
	grille_opacity = value
	if _material: _material.set_shader_parameter("grille_opacity", value)


func _set_roll(value: bool) -> void:
	roll = value
	if _material: _material.set_shader_parameter("roll", value)


func _set_roll_speed(value: float) -> void:
	roll_speed = value
	if _material: _material.set_shader_parameter("roll_speed", value)


func _set_roll_size(value: float) -> void:
	roll_size = value
	if _material: _material.set_shader_parameter("roll_size", value)


func _set_roll_variation(value: float) -> void:
	roll_variation = value
	if _material: _material.set_shader_parameter("roll_variation", value)


func _set_distort_intensity(value: float) -> void:
	distort_intensity = value
	if _material: _material.set_shader_parameter("distort_intensity", value)


func _set_noise_opacity(value: float) -> void:
	noise_opacity = value
	if _material: _material.set_shader_parameter("noise_opacity", value)


func _set_noise_speed(value: float) -> void:
	noise_speed = value
	if _material: _material.set_shader_parameter("noise_speed", value)


func _set_static_noise_intensity(value: float) -> void:
	static_noise_intensity = value
	if _material: _material.set_shader_parameter("static_noise_intensity", value)


func _set_aberration(value: float) -> void:
	aberration = value
	if _material: _material.set_shader_parameter("aberration", value)


func _set_brightness(value: float) -> void:
	brightness = value
	if _material: _material.set_shader_parameter("brightness", value)


func _set_discolor(value: bool) -> void:
	discolor = value
	if _material: _material.set_shader_parameter("discolor", value)


func _set_warp_amount(value: float) -> void:
	warp_amount = value
	if _material: _material.set_shader_parameter("warp_amount", value)


func _set_vignette_intensity(value: float) -> void:
	vignette_intensity = value
	if _material: _material.set_shader_parameter("vignette_intensity", value)


func _set_vignette_opacity(value: float) -> void:
	vignette_opacity = value
	if _material: _material.set_shader_parameter("vignette_opacity", value)
