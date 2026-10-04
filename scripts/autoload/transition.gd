extends CanvasLayer

## The one fader every menu/level change goes through (autoload `Transition`):
## OUT_SECONDS to black, swap the scene, IN_SECONDS back - pinball's splash fade-out /
## reveal. The tree is paused for the whole fade, so no press (polled or evented)
## reaches either scene mid-fade, and a second request while one runs is refused.
## Globals.debug_start_game stays instant: it is a dev/test entry, not a player flow.

const OUT_SECONDS := 0.25
const IN_SECONDS := 0.3
## Above every scene layer (levels top out at 2) and the pause menu (99) - nothing
## shows through the black - but below CRTOverlay.OVERLAY_LAYER, so the fade is
## filmed through the same tube as the game.
const LAYER := 99

var busy := false
var _rect: ColorRect
var _sting: AudioStreamPlayer


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "Fade"
	_rect.color = Color.BLACK
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_rect.hide()
	add_child(_rect)
	# On the autoload, not the old scene: a door slam must outlive the room it slams.
	_sting = AudioStreamPlayer.new()
	add_child(_sting)


## Fade out, change to `path`, fade in. `sting` plays as the fade starts. Returns
## false when a transition is already running (the request is dropped).
func change_scene_to_file(path: String, sting: AudioStream = null) -> bool:
	return await fade_through(func() -> Error: return get_tree().change_scene_to_file(path), sting)


func change_scene_to_packed(scene: PackedScene, sting: AudioStream = null) -> bool:
	return await fade_through(func() -> Error: return get_tree().change_scene_to_packed(scene), sting)


## The fade around any `swap` (returns an Error). Public so tests can drive it with a
## swap that does not replace the test runner's scene.
func fade_through(swap: Callable, sting: AudioStream = null) -> bool:
	if busy:
		return false
	busy = true
	if sting:
		_sting.stream = sting
		_sting.play()
	var tree := get_tree()
	tree.paused = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.show()
	await _fade(1.0, OUT_SECONDS)
	# A slow-mo left running (death beat, boss finale) must not leak into the next scene.
	Engine.time_scale = 1.0
	var err: Error = swap.call()
	if err != OK:
		push_error("Transition: scene change failed (%s)" % error_string(err))
	# The swap is flushed at the end of this frame; the frame after it carries the
	# whole load time in its delta, which would eat the fade-in in one step.
	await tree.process_frame
	await tree.process_frame
	await _fade(0.0, IN_SECONDS)
	_rect.hide()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.paused = false
	busy = false
	return err == OK


func _fade(to: float, seconds: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_rect, "modulate:a", to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
