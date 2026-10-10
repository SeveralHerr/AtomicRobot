extends TextureRect

## The swaying street art behind the title, character select and controls splash.
## Placed in code, not by anchors, so it covers the whole visible rect at any aspect
## (stretch aspect "expand": 4:3 cabinet, 5:4, wide phones): the 16:10 framing - an
## overscan `scale` and a (-42, -2) offset - grows uniformly with the screen, so
## 16:10 is unchanged and other screens get no gap and no squashed halftone dots.

const DESIGN := Vector2(1280, 800)
## The art's unscaled top-left at 16:10, before any sway.
const DESIGN_AT := Vector2(-42, -2)

var sway_amount: float = 20.0  # How far the background sways
var sway_duration: float = 4.0  # Time it takes to complete one sway
## Sideways offset from the fitted spot, tweened between +-sway_amount.
var sway := 0.0:
	set(v):
		sway = v
		position = _base + Vector2(sway, 0.0)

var _base := DESIGN_AT


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	get_viewport().size_changed.connect(fit)
	fit()
	# Out to the right, then side to side forever.
	var t := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "sway", sway_amount, sway_duration)
	t.tween_callback(_swing)


func _swing() -> void:
	var t := create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "sway", -sway_amount, sway_duration)
	t.tween_property(self, "sway", sway_amount, sway_duration)


## Size and place the art for the current visible rect (parent assumed at the origin).
func fit() -> void:
	var view := get_viewport_rect().size
	var k := maxf(view.x / DESIGN.x, view.y / DESIGN.y)
	size = DESIGN * k
	# The art's centre keeps its 16:10 offset from the screen centre, scaled by k.
	var centre_off := DESIGN_AT + DESIGN * scale / 2.0 - DESIGN / 2.0
	_base = view / 2.0 + centre_off * k - size * scale / 2.0
	sway = sway
