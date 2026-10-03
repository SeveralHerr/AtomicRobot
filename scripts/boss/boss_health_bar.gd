extends Control
class_name BossHealthBar

## The boss's HUD card, top-right under the logo: a tilted comic card with his
## portrait, name and health bar — clear of the HP orbs (top-left) and the score /
## combo rows (top-centre), and away from the fighters' feet. The red fill snaps to
## the new value on a hit while a cream "chip" bar lags behind and drains after it,
## so each hit reads as a chunk taken. Notches mark where phases begin.

const SHEET := preload("res://sprites/CityCouncil.png")
## His face in the idle frame of the sheet.
const PORTRAIT_REGION := Rect2(46, 36, 36, 30)
const BAR_SIZE := Vector2(300, 22)
const CHIP_DELAY := 0.35
## Card's top-left, measured from the screen's top-right corner.
const HOME := Vector2(-500, 182)
const SLIDE := 560.0
const TILT := -2.5

var _card: PanelContainer
var _portrait: TextureRect
var _fill: ColorRect
var _chip: ColorRect
var _max: int = 1
var _shown := false


func _init() -> void:
	name = "BossHealthBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_build()
	modulate.a = 0.0


func _build() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", ComicStyle.box(ComicStyle.PAPER, 4, 8, 5))
	_card.rotation_degrees = TILT
	_card.position = HOME + Vector2(SLIDE, 0.0)
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_card.add_child(row)
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", ComicStyle.box(ComicStyle.BLUE, 3, 6, 0))
	row.add_child(face)
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = PORTRAIT_REGION
	_portrait = TextureRect.new()
	_portrait.texture = tex
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(72, 60)
	face.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var title := ComicStyle.heading("COUNCILMAN", 30, ComicStyle.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(title)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ComicStyle.box(ComicStyle.INK, 3, 5, 0))
	col.add_child(frame)
	var well := Control.new()
	well.custom_minimum_size = BAR_SIZE
	well.clip_contents = true
	frame.add_child(well)
	_chip = _bar(well, ComicStyle.CREAM)
	_fill = _bar(well, ComicStyle.RED)
	for start in BossRules.PHASE_STARTS.slice(1):
		var notch := ColorRect.new()
		notch.color = ComicStyle.INK
		notch.position = Vector2(BAR_SIZE.x * start - 2.0, 0.0)
		notch.size = Vector2(4.0, BAR_SIZE.y)
		well.add_child(notch)


static func _bar(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = BAR_SIZE
	parent.add_child(r)
	return r


## Slide in from the right and fill up from empty — the "boss has arrived" beat.
func show_bar(max_health: int) -> void:
	_max = maxi(max_health, 1)
	_shown = true
	_set_frac(_fill, 0.0)
	_set_frac(_chip, 0.0)
	_card.position = HOME + Vector2(SLIDE, 0.0)
	var tw := create_tween()
	tw.tween_property(_card, "position", HOME, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_method(func(f: float) -> void:
		_set_frac(_fill, f)
		_set_frac(_chip, f), 0.0, 1.0, 0.8)


func set_health(health: int) -> void:
	if not _shown:
		return
	var f := clampf(float(health) / float(_max), 0.0, 1.0)
	_set_frac(_fill, f)
	var tw := create_tween()
	tw.tween_interval(CHIP_DELAY)
	tw.tween_property(_chip, "size:x", BAR_SIZE.x * f, 0.3).set_ease(Tween.EASE_OUT)
	# Punch: the fill flashes white, his face flashes red, the card jolts and twists.
	_fill.color = Color.WHITE
	create_tween().tween_property(_fill, "color", ComicStyle.RED, 0.12)
	_portrait.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(_portrait, "modulate", Color.WHITE, 0.25)
	var jolt := create_tween()
	for k in [[-7.0, TILT - 2.0], [5.0, TILT + 1.5], [-3.0, TILT - 0.5], [0.0, TILT]]:
		jolt.tween_property(_card, "position:x", HOME.x + k[0], 0.03)
		jolt.parallel().tween_property(_card, "rotation_degrees", k[1], 0.03)


## Phase change: the card goes angrier — his portrait tints like his sprite does.
func set_tint(c: Color) -> void:
	create_tween().tween_property(_portrait, "self_modulate", c, 0.4)


func hide_bar() -> void:
	_shown = false
	var tw := create_tween()
	tw.tween_property(_card, "position:x", HOME.x + SLIDE, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)


func fill_frac() -> float:
	return _fill.size.x / BAR_SIZE.x


static func _set_frac(bar: ColorRect, f: float) -> void:
	bar.size = Vector2(BAR_SIZE.x * f, BAR_SIZE.y)
