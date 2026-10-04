class_name JamcraftSplash
extends CanvasLayer
## Self-contained Jamcraft logo intro. Copy this file + the logo png into any Godot 4 project.
##
## From the jamcraft-splash skill (v0.28.0), minus its `next_scene` mode: this game changes
## scenes only through the Transition autoload, and the splash plays over the title
## (scripts/startscreen.gd), so nothing here changes scene.
##     var splash := JamcraftSplash.new()
##     add_child(splash)
##     await splash.finished
##
## Timeline: black -> logo pops in (scale + fade) with an additive flash -> hold (slow drift)
## -> logo fades to background_color -> `finished` is emitted (screen is fully background_color,
## build/show your menu now) -> background fades away revealing what is underneath -> queue_free.
## Any key / click / joypad button / touch skips straight to the fade-out.

signal finished

const DEFAULT_LOGO_PATH := "res://images/jamcraft_logo.png"

@export var logo: Texture2D
## Seconds the logo stays fully visible after the pop-in.
@export var hold_time := 0.7
@export var skippable := true
@export var background_color := Color.BLACK
## Seconds of plain background before the logo appears (absorbs startup hitches).
@export var start_delay := 0.1
## Seconds for the pop-in (scale settle). The fade-in is the first ~40% of it.
@export var intro_time := 0.45
## Seconds for the logo to fade to background_color.
@export var fade_out_time := 0.3
## Seconds for the background to fade away after `finished` (0 = hard cut).
@export var reveal_time := 0.35
## Peak strength of the additive flash on impact (0 disables it).
@export var flash_strength := 0.55
@export var flash_color := Color.WHITE
## Scale the logo starts at before settling to 1.0.
@export var pop_scale := 1.12

var _background: ColorRect
var _logo_rect: TextureRect
var _flash: ColorRect
var _tween: Tween
var _leaving := false
var _done := false


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if logo == null and ResourceLoader.exists(DEFAULT_LOGO_PATH):
		logo = load(DEFAULT_LOGO_PATH)
	_build()
	# Let the first frames (often a loading hitch) pass before timing anything.
	await get_tree().process_frame
	await get_tree().process_frame
	if not _leaving:
		_play_intro()


func _build() -> void:
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = background_color
	_background.mouse_filter = Control.MOUSE_FILTER_STOP # swallow clicks meant for the game
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	_logo_rect = TextureRect.new()
	_logo_rect.name = "Logo"
	_logo_rect.texture = logo
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_logo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Slightly oversized so the back-ease overshoot below 1.0 never exposes the screen edges.
	_logo_rect.anchor_left = -0.03
	_logo_rect.anchor_top = -0.03
	_logo_rect.anchor_right = 1.03
	_logo_rect.anchor_bottom = 1.03
	_logo_rect.modulate.a = 0.0
	_logo_rect.scale = Vector2.ONE * pop_scale
	_background.add_child(_logo_rect)
	_logo_rect.resized.connect(_center_pivot)
	_center_pivot()

	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = flash_color
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = additive
	_background.add_child(_flash)


func _center_pivot() -> void:
	_logo_rect.pivot_offset = _logo_rect.size * 0.5


func _new_tween() -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if _tween.has_method("set_ignore_time_scale"): # Godot 4.3+
		_tween.call("set_ignore_time_scale", true)
	return _tween


func _play_intro() -> void:
	var d := start_delay
	var fade_in := intro_time * 0.4
	var flash_rise := fade_in * 0.35
	var t := _new_tween()
	t.set_parallel(true)
	# Pop: fade in fast while the scale settles with a little overshoot.
	t.tween_property(_logo_rect, "modulate:a", 1.0, fade_in).set_delay(d) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_logo_rect, "scale", Vector2.ONE, intro_time).set_delay(d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Flash peaks the moment the logo is fully opaque, then decays fast.
	t.tween_property(_flash, "modulate:a", flash_strength, flash_rise).set_delay(d + fade_in - flash_rise) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_flash, "modulate:a", 0.0, maxf(intro_time * 0.7, 0.1)).set_delay(d + fade_in) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Hold with a slow push-in so the frame never feels frozen.
	t.tween_property(_logo_rect, "scale", Vector2.ONE * 1.025, hold_time + fade_out_time) \
		.set_delay(d + intro_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(_play_outro).set_delay(d + intro_time + maxf(hold_time, 0.0))


func _play_outro() -> void:
	if _leaving:
		return
	_leaving = true
	var t := _new_tween()
	t.set_parallel(true)
	t.tween_property(_logo_rect, "modulate:a", 0.0, fade_out_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_logo_rect, "scale", _logo_rect.scale * 1.04, fade_out_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_flash, "modulate:a", 0.0, fade_out_time * 0.5)
	t.chain().tween_callback(_finish)


func _finish() -> void:
	if _done:
		return
	_done = true
	# Stop blocking input for whatever is being revealed underneath.
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()
	_play_reveal()


func _play_reveal() -> void:
	if reveal_time <= 0.0:
		queue_free()
		return
	var t := _new_tween()
	t.tween_property(_background, "self_modulate:a", 0.0, reveal_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(queue_free)


func _input(event: InputEvent) -> void:
	if _done:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		get_viewport().set_input_as_handled()
		if skippable:
			_play_outro()
