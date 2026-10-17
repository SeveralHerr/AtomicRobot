extends Control
class_name SkipPrompt

## "HOLD TO SKIP" in the top letterbox bar, right side: hidden until the player
## presses something, then a ring fills while they hold. Let go and it drains and
## fades. Drawn, not built from nodes, so it costs one Control.

const TEXT := "HOLD TO SKIP"
## Ring centre as an inset from the top-right corner, inside the CRT bezel and the
## 130px top bar: the same distance in on a 4:3 cabinet as on a wide phone.
const INSET := Vector2(84, 84)
const RADIUS := 18.0

## 0..1 fill.
var progress := 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()
var _label: Label


func _init() -> void:
	name = "SkipPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0
	_label = ComicStyle.label(TEXT, ComicStyle.LABEL, 28, ComicStyle.PAPER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.size = Vector2(260, 40)
	add_child(_label)
	resized.connect(_place)
	_place()


func centre() -> Vector2:
	return Vector2(size.x - INSET.x, INSET.y)


func _place() -> void:
	_label.position = centre() - Vector2(RADIUS + 14.0 + 260.0, 20.0)
	queue_redraw()


## Fade in (a button went down) or out (released, or the scene is ending).
func show_prompt(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0 if on else 0.0, 0.12 if on else 0.3)


func _draw() -> void:
	draw_arc(centre(), RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 4.0, true)
	if progress > 0.0:
		draw_arc(centre(), RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, ComicStyle.YELLOW, 5.0, true)
