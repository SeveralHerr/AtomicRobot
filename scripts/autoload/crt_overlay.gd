extends Node

## Full-screen CRT post-process overlay (autoload).
##
## Adds a CanvasLayer above everything (highest scene layer is 2) with a
## full-rect ColorRect whose shader reads hint_screen_texture — so the whole
## composited frame (world + UI + fades) gets the CRT treatment in every scene.
## Toggle with CRTOverlay.set_enabled(false) if a menu/setting needs it off.

const CRT_SHADER := preload("res://shaders/crt_overlay.gdshader")

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
