class_name InteractPrompt

## The newspaper stand's "[interact]" prompt (scenes/interactive_mailbox.tscn), lent to
## other props so every world-space prompt reads the same through the CRT. Look and
## text come from the stand's own InteractLabel, not copied values, so restyling the
## stand restyles every borrower.

const SOURCE := preload("res://scenes/interactive_mailbox.tscn")

static var _settings: LabelSettings
static var _text := ""
static var _size := Vector2.ZERO
static var _h_align := HORIZONTAL_ALIGNMENT_CENTER
static var _v_align := VERTICAL_ALIGNMENT_CENTER
## Floor (the stand's art bottom) up to the top of its prompt box, world px.
static var _rise := 0.0


static func _load() -> void:
	if _settings != null:
		return
	var stand := SOURCE.instantiate()  # not added to the tree: no _ready runs
	var src := stand.get_node("InteractLabel") as Label
	_settings = src.label_settings
	_text = src.text
	_size = Vector2(src.offset_right - src.offset_left, src.offset_bottom - src.offset_top)
	_h_align = src.horizontal_alignment
	_v_align = src.vertical_alignment
	_rise = _art_bottom(stand as Sprite2D) - src.offset_top
	stand.free()


## Where the stand's visible art ends (its feet on the floor), relative to its origin.
static func _art_bottom(stand: Sprite2D) -> float:
	var img := stand.texture.get_image()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	return used.end.y - (img.get_height() / 2.0 if stand.centered else 0.0) + stand.offset.y


static func rise() -> float:
	_load()
	return _rise


## Styles `label` as the stand's prompt at the stand's height above the floor, centred.
## The label's parent origin must sit on the floor (a prop's feet). Height is measured
## from the floor, not the prop's top, so a small prop's prompt still clears the
## player's cap exactly as the stand's does. `text` replaces the stand's "[interact]"
## wording in the same bracket format (the cat says "[pet]").
static func apply(label: Label, text := "") -> void:
	_load()
	label.label_settings = _settings
	label.text = text if text != "" else _text
	label.horizontal_alignment = _h_align
	label.vertical_alignment = _v_align
	label.custom_minimum_size = Vector2(_size.x, 0)
	label.size = _size
	label.position = Vector2(-_size.x / 2.0, -_rise)
