extends Button

## One fighter in the roster strip. The Button itself is the focus owner and sits in
## an HBoxContainer; everything visible hangs off `drop` (intro slide) > `visual`
## (focus lift/tilt) so tweens never fight the container's layout.

const Juice := preload("res://scripts/ui/select/juice.gd")
const SpriteCrop := preload("res://scripts/ui/select/sprite_crop.gd")
const SIZE := Vector2(150, 164)
const LIFT := -22.0
const HOT_SCALE := 1.12

var character: String
var index: int
var drop: Control
var visual: Control
var frame: Panel
var portrait: TextureRect
var plate: Label
var _frame_cold: StyleBoxFlat
var _frame_hot: StyleBoxFlat
var _hot_tween: Tween


func setup(character_name: String, slot: int) -> Button:
	character = character_name
	index = slot
	name = "Card%s" % character_name
	return self


func _ready() -> void:
	custom_minimum_size = SIZE
	flat = true
	focus_mode = Control.FOCUS_ALL
	for state in ["focus", "normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(grab_focus)
	focus_entered.connect(_set_hot.bind(true))
	focus_exited.connect(_set_hot.bind(false))
	_build()
	resized.connect(_center_pivot)
	_center_pivot()


func config() -> CharacterConfig:
	return Globals.character_dict[character]


func is_unlocked() -> bool:
	return config().unlocked


func is_hot() -> bool:
	return frame.get_theme_stylebox("panel") == _frame_hot


## Slide up from below after `delay`, for the screen's staggered entrance.
func enter(delay: float) -> void:
	drop.position.y = 320.0
	drop.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(drop, "position:y", 0.0, 0.45).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(drop, "modulate:a", 1.0, 0.15).set_delay(delay)


## Just unlocked: start as the locked silhouette, then flash into colour.
func reveal(delay: float) -> void:
	portrait.modulate = Juice.SILHOUETTE
	plate.text = "???"
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(portrait, "modulate", Color(3, 3, 3), 0.2)
	t.tween_callback(func() -> void: plate.text = character.to_upper())
	t.tween_property(portrait, "modulate", Color.WHITE, 0.35)


## A on a locked fighter: head-shake "no" around the lifted spot.
func reject() -> void:
	_restart_tween()
	_hot_tween = Juice.shake(visual, Vector2(0, LIFT if has_focus() else 0.0), 12.0, 0.25, Vector2.RIGHT)


## A on this fighter: punch, then hold lit while the rest of the strip dims.
func chosen() -> void:
	_set_hot(true)  # focus was released to lock input; stay lit anyway
	_restart_tween()
	_hot_tween = Juice.pop(visual, HOT_SCALE * 1.3, HOT_SCALE, 0.35)


func _build() -> void:
	drop = Juice.layer(self)
	visual = Juice.layer(drop)
	# Cold cards recede into the art; only the hot one is a bright panel.
	_frame_cold = ComicStyle.box(Color("3A2F55"), 4, 10, 6)
	_frame_hot = ComicStyle.box(ComicStyle.YELLOW, 5, 10, 9)
	frame = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _frame_cold)
	visual.add_child(frame)

	portrait = TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = SpriteCrop.cropped(config().sprite_frames.get_frame_texture("idle", 0))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 10
	portrait.offset_right = -10
	portrait.offset_top = 10
	portrait.offset_bottom = -40
	visual.add_child(portrait)

	plate = ComicStyle.label(character.to_upper(), ComicStyle.LABEL, 32, ComicStyle.PAPER)
	var plate_bg := ComicStyle.box(ComicStyle.INK, 0, 6, 0)
	plate.add_theme_stylebox_override("normal", plate_bg)
	plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	plate.offset_top = -40
	plate.offset_left = 6
	plate.offset_right = -6
	plate.offset_bottom = -6
	visual.add_child(plate)

	if not is_unlocked():
		portrait.modulate = Juice.SILHOUETTE
		plate.text = "???"
		var lock := TextureRect.new()
		lock.texture = Juice.LOCK_ICON
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock.offset_left = -36
		lock.offset_right = 36
		lock.offset_top = -50
		lock.offset_bottom = 22
		visual.add_child(lock)


## One motion owner per card: a new lift/shake/punch replaces the old, never fights it.
func _restart_tween() -> void:
	if _hot_tween:
		_hot_tween.kill()


func _center_pivot() -> void:
	visual.pivot_offset = size / 2.0


func _set_hot(on: bool) -> void:
	frame.add_theme_stylebox_override("panel", _frame_hot if on else _frame_cold)
	_restart_tween()
	_hot_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tilt := (-3.0 if index % 2 == 0 else 3.0) if on else 0.0
	_hot_tween.tween_property(visual, "position:y", LIFT if on else 0.0, 0.22)
	_hot_tween.tween_property(visual, "scale", Vector2.ONE * (HOT_SCALE if on else 1.0), 0.22)
	_hot_tween.tween_property(visual, "rotation_degrees", tilt, 0.22)
	z_index = 1 if on else 0
