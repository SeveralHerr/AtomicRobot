extends Control

const CHARACTER_SELECT: PackedScene = preload("res://scenes/character_select.tscn")
const AnyButton := preload("res://scripts/any_button.gd")
## Attract loop: the title and a HIGH SCORES card (atomic-pinball's title-screen card:
## white, 3px ink border, hard shadow, tilted 1.5deg) swap every ATTRACT_SECONDS while
## nobody presses anything. Skipped while the list is empty.
const ATTRACT_SECONDS := 6.0
## Room left under the card for the title's PRESS ANY BUTTON line.
const PROMPT_GAP := 110.0
## The Jamcraft studio logo plays once per boot, over this title (atomic-pinball's boot
## splash): the title loads underneath and is revealed as the black fades away.
static var splash_played := false
var delay: bool = false
var board: Control
var table: ScoreTableView
var _attract: float = 0.0

func _ready() -> void:
	$Timer.timeout.connect(_delay)
	board = CenterContainer.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.offset_bottom = -PROMPT_GAP
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.visible = false
	add_child(board)
	var card := PanelContainer.new()
	var box := ComicStyle.box(ComicStyle.PAPER, 3, 10, 4)
	box.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", box)
	table = ScoreTableView.new(30)
	card.add_child(table)
	board.add_child(EndCard.tilted(card, 1.5))
	if not splash_played:
		splash_played = true
		_play_splash()

## The splash swallows the press that skips it; the title's anti-skip delay (and the
## attract clock) only start once the logo is gone, so a mash can't fall through.
func _play_splash() -> void:
	$Timer.stop()
	var splash := JamcraftSplash.new()
	splash.layer = Transition.LAYER  # under the CRT scanlines, like every screen
	add_child(splash)
	await splash.finished
	_attract = 0.0
	$Timer.start()

func _process(delta: float) -> void:
	_attract += delta
	if _attract < ATTRACT_SECONDS:
		return
	_attract = 0.0
	if board.visible:
		board.hide()
	elif not ScoreSystem.high_scores.is_empty():
		table.show_entries(ScoreSystem.high_scores, -1, false)
		board.show()

func _input(event: InputEvent) -> void:
	if delay and AnyButton.is_press(event):
		_advance()

func _advance() -> void:
	Transition.change_scene_to_packed(CHARACTER_SELECT)

func _delay() -> void:
	delay = true
