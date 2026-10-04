class_name NewsCard
extends CanvasLayer

## The paper a newspaper stand (scripts/interactive_mailbox.gd) hands the player:
## a tilted comic card (ComicStyle, as atomic-pinball) pinned in the left column
## under the HP orbs.
##
## It used to be a world-space sprite above the stand, which put it straight under
## the score and the combo line (the HUD column is centred, and so is the player at
## the stand): the HUD drew over the headline. Screen-space, in a slot the HUD never
## uses, it reads the same on every lane, at every camera position and on a phone.
## test_newspaper_stand.gd lays it out next to the real HUD to keep it that way.

## Top-left of the card in design px: clear of the CRT bezel (~40 px) and of the HP
## orbs (down to y 118); width keeps it left of the HUD column (centre - 260).
const SLOT := Vector2(52.0, 146.0)
const WIDTH := 316.0
const TILT := -2.0
const HEADLINE_FONT: FontFile = ComicStyle.LABEL
const HEADLINE_SIZE := 30
const POP_SECONDS := 0.32
const OUT_SECONDS := 0.22

## Anchors the slot; never animated (one tween owner: the card).
var holder: Control
var card: PanelContainer
var headline: Label
var _open := false
var _tween: Tween


func _init() -> void:
	layer = 1  # with the HUD, under the level UI (end card) and the callouts
	holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = SLOT
	add_child(holder)
	card = PanelContainer.new()
	card.name = "Paper"
	var box := ComicStyle.box(ComicStyle.CREAM, 4, 6, 6)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size.x = WIDTH
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	holder.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	col.add_child(ComicStyle.heading("DAILY ATOM", 34, ComicStyle.RED))
	var rule := ColorRect.new()
	rule.color = ComicStyle.INK
	rule.custom_minimum_size.y = 3
	col.add_child(rule)
	headline = ComicStyle.label("", HEADLINE_FONT, HEADLINE_SIZE)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.custom_minimum_size.x = WIDTH - 36.0
	col.add_child(headline)


func is_open() -> bool:
	return _open


## Show `text`. With `animate`, the paper flies out of `from` (the stand, in screen
## px) to the slot with an overshoot; without, it is simply there (tests, layout).
func open(text: String, from: Vector2, animate: bool = true) -> void:
	_open = true
	headline.text = text
	card.reset_size()
	card.pivot_offset = card.size * 0.5
	card.visible = true
	_kill()
	if not animate:
		card.position = Vector2.ZERO
		card.scale = Vector2.ONE
		card.rotation_degrees = TILT
		card.modulate.a = 1.0
		return
	card.position = from - SLOT - card.size * 0.5
	card.scale = Vector2.ONE * 0.2
	card.rotation_degrees = 14.0
	card.modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(card, "position", Vector2.ZERO, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "rotation_degrees", TILT, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "modulate:a", 1.0, POP_SECONDS * 0.4)


## Fold the paper away: a short drop and fade.
func close() -> void:
	if not _open:
		return
	_open = false
	_kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(card, "position:y", card.position.y + 28.0, OUT_SECONDS).set_ease(Tween.EASE_IN)
	_tween.tween_property(card, "modulate:a", 0.0, OUT_SECONDS)
	_tween.chain().tween_callback(card.hide)


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
