extends Node


signal fade_started
signal fade_finished

const DEFAULT_DURATION := 1.0
const DEFAULT_COLOR := Color(0, 0, 0, 1.0)

var _fade_overlay: ColorRect
var _current_tween: Tween
var _is_fading := false

func _ready() -> void:
	# Create the fade overlay
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = DEFAULT_COLOR
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.visible = false
	add_child(_fade_overlay)
	
	# Make it cover the entire screen
	_fade_overlay.anchor_right = 1.0
	_fade_overlay.anchor_bottom = 1.0
	_fade_overlay.grow_horizontal = 2 # GROW_BOTH
	_fade_overlay.grow_vertical = 2 # GROW_BOTH
	
	# Ensure it's always on top
	_fade_overlay.z_index = 100

func fade_in(duration: float = DEFAULT_DURATION, color: Color = DEFAULT_COLOR) -> void:
	if _is_fading:
		await _current_tween.finished
	
	_is_fading = true
	_fade_overlay.color = color
	_fade_overlay.color.a = 1.0
	_fade_overlay.visible = true
	
	_current_tween = create_tween()
	_current_tween.tween_property(_fade_overlay, "color:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	fade_started.emit()
	await _current_tween.finished
	_fade_overlay.visible = false
	_is_fading = false
	fade_finished.emit()

func fade_out(duration: float = DEFAULT_DURATION, color: Color = DEFAULT_COLOR) -> void:
	if _is_fading:
		await _current_tween.finished
	
	_is_fading = true
	_fade_overlay.color = color
	_fade_overlay.color.a = 0.0
	_fade_overlay.visible = true
	
	_current_tween = create_tween()
	_current_tween.tween_property(_fade_overlay, "color:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	fade_started.emit()
	await _current_tween.finished
	_is_fading = false
	fade_finished.emit()

func fade_to_scene(scene: PackedScene, duration: float = DEFAULT_DURATION) -> void:
	await fade_out(duration)
	get_tree().change_scene_to_packed(scene)
	await fade_in(duration)

func fade_to_scene_file(path: String, duration: float = DEFAULT_DURATION) -> void:
	var scene = load(path)
	if scene:
		await fade_to_scene(scene, duration)

func cross_fade(from: Node, to: Node, duration: float = DEFAULT_DURATION) -> void:
	if _is_fading:
		await _current_tween.finished
	
	_is_fading = true
	to.modulate.a = 0.0
	to.visible = true
	
	_current_tween = create_tween()
	_current_tween.parallel().tween_property(from, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	_current_tween.parallel().tween_property(to, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	fade_started.emit()
	await _current_tween.finished
	from.visible = false
	_is_fading = false
	fade_finished.emit()
