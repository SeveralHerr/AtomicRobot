extends RefCounted
class_name BossJuice

## Game-feel helpers for the boss fight: time-scale hits, screen flashes and
## letterbox bars. Static so the room, the boss and his states share one copy.

## Each slow_mo() call takes a ticket; only the newest restores time, so a quick
## hit-stop landing inside the finale's long slow-mo can't snap it back to 1.0 early.
static var _ticket: int = 0


## Run the game at `scale` for `real_seconds` of wall time, then restore 1.0.
static func slow_mo(node: Node, scale: float, real_seconds: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	_ticket += 1
	var mine := _ticket
	Engine.time_scale = scale
	# ignore_time_scale: the timer must not itself be slowed by what it is timing.
	await node.get_tree().create_timer(real_seconds, true, false, true).timeout
	if mine == _ticket:
		Engine.time_scale = 1.0


## Release any slow-mo still running (leaving the scene mid-finale).
static func reset_time() -> void:
	_ticket += 1
	Engine.time_scale = 1.0


## Full-screen colour flash on `layer` that fades out over `seconds`.
static func flash(layer: Node, color: Color = Color(1, 1, 1, 0.85), seconds: float = 0.35) -> void:
	if layer == null or not layer.is_inside_tree():
		return
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tw := rect.create_tween().set_ignore_time_scale(true)
	tw.tween_property(rect, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_OUT)
	tw.tween_callback(rect.queue_free)


## Cinematic letterbox: two black bars that slide in on `layer`. Returns the bars so
## the caller can slide them back out. The top bar is tall (the CRT bezel swallows its
## outer ~40px); the bottom one is thin, because the fighters stand on the bottom fifth
## of the screen and a tall bar hid the very entrance it was framing.
static func letterbox_in(layer: Node, top_h: float = 130.0, bottom_h: float = 62.0, seconds: float = 0.35) -> Array[ColorRect]:
	# Plain positions, not anchors: a CanvasLayer child's anchor layout isn't settled
	# on the frame it is added, so a tween read from it starts from the wrong place.
	var view: Vector2 = layer.get_viewport().get_visible_rect().size
	var bars: Array[ColorRect] = []
	for top in [true, false]:
		var h: float = top_h if top else bottom_h
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(view.x, h)
		bar.position = Vector2(0.0, -h if top else view.y)
		layer.add_child(bar)
		bar.create_tween().tween_property(bar, "position:y", 0.0 if top else view.y - h, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		bars.append(bar)
	return bars


static func letterbox_out(bars: Array[ColorRect], seconds: float = 0.35) -> void:
	for i in bars.size():
		var bar := bars[i]
		if not is_instance_valid(bar):
			continue
		var to := -bar.size.y if i == 0 else bar.position.y + bar.size.y
		var tw := bar.create_tween()
		tw.tween_property(bar, "position:y", to, seconds).set_ease(Tween.EASE_IN)
		tw.tween_callback(bar.queue_free)
