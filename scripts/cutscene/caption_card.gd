extends Control
class_name CaptionCard

## A comic-book caption box for the street cut scenes: a yellow panel with an ink
## border hangs off the top letterbox bar, the kicker ("HALFWAY THERE...") types in
## with blips, then the place name SLAMS in under it. Animates an inner panel —
## never this Control, and never a Container child (layout resets their scale).

## Emitted the frame the title lands, for the director's thud and shake.
signal landed

const KICKER_PX := 34
const TITLE_PX := 58
## Top-left of the box: just inside the CRT bezel, overlapping the top bar's edge.
const ORIGIN := Vector2(78, 92)
const TILT := -2.5
const TYPE_STEP := 0.025
const POP := 0.32
const SLAM := 0.16
## A new caption over an old one: the old box lifts away this fast first.
const SWAP := 0.14
## Typing starts this long into the pop.
const TYPE_LEAD := 0.12
const BLIP := preload("res://sounds/tap.wav")
const THUD := preload("res://sounds/711657__discofield__stone-crash.wav")

var _panel: PanelContainer
var _kicker: Label
var _title: Label
var _blip: AudioStreamPlayer
var _thud: AudioStreamPlayer
## Bumped per show/leave, so an overtaken entrance stops typing.
var _gen := 0


func _init() -> void:
	name = "CaptionCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", -6)
	_panel.add_child(rows)
	_kicker = ComicStyle.label("", ComicStyle.LABEL, KICKER_PX, ComicStyle.INK)
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rows.add_child(_kicker)
	_title = ComicStyle.heading("", TITLE_PX, ComicStyle.RED)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_color_override("font_shadow_color", ComicStyle.INK)
	_title.add_theme_constant_override("shadow_offset_x", 4)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	rows.add_child(_title)
	_blip = _sfx(BLIP, -16.0)
	_thud = _sfx(THUD, -12.0)


static func _box() -> StyleBoxFlat:
	var b := ComicStyle.box(ComicStyle.YELLOW, 5, 3, 7)
	b.content_margin_left = 22
	b.content_margin_right = 26
	b.content_margin_top = 8
	b.content_margin_bottom = 6
	return b


func _sfx(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	return p


## Drop the box in, type the kicker, slam the title. `tint` colours the title.
func present(kicker: String, title: String, tint: Color) -> void:
	if _panel.visible:
		await leave(SWAP)
	_gen += 1
	var gen := _gen
	_kicker.text = kicker
	_kicker.visible_characters = 0
	_title.text = title
	_title.add_theme_color_override("font_color", tint)
	_title.modulate.a = 0.0
	_panel.reset_size()
	_panel.position = ORIGIN
	_panel.pivot_offset = Vector2(0, 0)
	_panel.rotation_degrees = -14.0
	_panel.scale = Vector2(0.4, 0.4)
	_panel.modulate.a = 0.0
	_panel.visible = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "scale", Vector2.ONE, POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "rotation_degrees", TILT, POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.12)
	# Type as the box settles: an empty yellow box reads as dead time.
	await get_tree().create_timer(TYPE_LEAD).timeout
	for i in kicker.length():
		if gen != _gen:
			return
		_kicker.visible_characters = i + 1
		if i % 2 == 0 and kicker[i] != " ":
			_blip.pitch_scale = randf_range(0.85, 1.15)
			_blip.play()
		await get_tree().create_timer(TYPE_STEP).timeout
	if gen != _gen:
		return
	_slam_title()


func _slam_title() -> void:
	_title.pivot_offset = _title.size * Vector2(0.3, 0.5)
	_title.scale = Vector2(1.7, 1.7)
	var tw := create_tween().set_parallel()
	tw.tween_property(_title, "modulate:a", 1.0, 0.08)
	tw.tween_property(_title, "scale", Vector2.ONE, SLAM).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		_thud.play()
		landed.emit())
	# A squash on the box as the title hits it.
	tw.chain().tween_property(_panel, "scale", Vector2(1.04, 0.94), 0.05)
	tw.chain().tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Seconds from present() until the title lands: pop, typing, slam.
static func lands_after(kicker: String) -> float:
	return TYPE_LEAD + kicker.length() * TYPE_STEP + SLAM


## Lift the box away. `seconds` short for a skip.
func leave(seconds: float = 0.25) -> void:
	_gen += 1
	if not _panel.visible:
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "position:y", ORIGIN.y - 60.0, seconds).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "modulate:a", 0.0, seconds)
	await tw.finished
	_panel.visible = false


func is_showing() -> bool:
	return _panel.visible


func panel_rect() -> Rect2:
	return _panel.get_global_rect()
