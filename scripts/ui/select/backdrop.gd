extends RefCounted

## The character select's screen-filling layers: the street art, its plum shade, and
## the centred DESIGN-sized frame the stage lives in. With stretch aspect "expand" the
## screen can be wider or taller than 1280x800; the art fills it all, the stage stays
## a 1280x800 box in the middle (16:10 is unchanged).

const BG_ART: Texture2D = preload("res://images/ARTBG.png")
const SWAY: Script = preload("res://scripts/sway.gd")


## Same swaying street art as the title screen (startscreen.tscn's TextureRect), so
## title -> select reads as one place.
static func build(parent: Control) -> void:
	var bg := TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture = BG_ART
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.scale = Vector2(1.1, 1.15)
	bg.set_script(SWAY)  # sizes itself to cover the screen
	parent.add_child(bg)
	# Plum shade over the bright left of the art so yellow rays/title/stamps read.
	var shade := TextureRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(ComicStyle.PLUM.darkened(0.35), 0.62))
	grad.gradient.set_color(1, Color(ComicStyle.PLUM.darkened(0.35), 0.12))
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(1, 0)
	shade.texture = grad
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parent.add_child(shade)


## A click-through `design`-sized box kept centred in the full-screen `parent` as
## it resizes. On the parent's own signal, so the hook dies with the screen.
static func centred_frame(parent: Control, design: Vector2) -> Control:
	var frame := Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE  # a STOP box here eats every tap
	frame.size = design
	parent.add_child(frame)
	var centre := func() -> void:
		frame.position = ((parent.size - design) / 2.0).floor()
	parent.resized.connect(centre)
	centre.call()
	return frame
