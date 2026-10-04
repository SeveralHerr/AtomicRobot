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
## Party Code acknowledgement: the prompt line reads PARTY MODE! this long.
const PARTY_ACK_SECONDS := 2.0
const PARTY_TEXT := "PARTY MODE!"
## The prompt line cycles these: only colours that stay readable on the red/orange art.
const PARTY_FLASH: Array[Color] = [Color("#ffe14d"), Color("#7ff6ff"), Color("#ffe14d"), Color.WHITE]
const PARTY_STING_PITCH := 1.3
const PARTY_STING: AudioStream = preload("res://sounds/Unlock.wav")
var delay: bool = false
var board: Control
var table: ScoreTableView
var _attract: float = 0.0
var _code := PartyCode.new()
var _ack_id := 0
@onready var prompt: Label = $MarginContainer/VBoxContainer/Label
@onready var _prompt_text := prompt.text

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

## Directions and the code's next B/A are code input, never a start press; the
## completed code is acknowledged and the title keeps waiting for a real press.
func _input(event: InputEvent) -> void:
	match _code.feed(event):
		PartyCode.Step.DONE:
			_party_on()
			return
		PartyCode.Step.HELD:
			return
	if delay and AnyButton.is_press(event):
		_advance()

func _party_on() -> void:
	Globals.party_mode = true
	_attract = 0.0
	board.hide()
	var sting := AudioStreamPlayer.new()
	sting.stream = PARTY_STING
	sting.pitch_scale = PARTY_STING_PITCH  # higher than the secret-wall reveal: not a secret
	add_child(sting)
	sting.finished.connect(sting.queue_free)
	sting.play()
	# Two party cannons from the bottom corners, crossing over the logo.
	var view := get_viewport_rect().size
	for side in [-1.0, 1.0]:
		var corner := Vector2(view.x * (0.5 + side * 0.43), view.y - 40.0)  # inside the CRT edge
		PartyFx.cannon(self, corner, Vector2(-side * 0.35, -1.0))
	prompt.text = PARTY_TEXT
	prompt.pivot_offset = prompt.size / 2.0
	var pop := create_tween()
	pop.tween_property(prompt, "scale", Vector2.ONE * 1.35, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(prompt, "scale", Vector2.ONE, 0.25)
	var flash := create_tween()
	for c in PARTY_FLASH:
		flash.tween_property(prompt, "modulate", c, PARTY_ACK_SECONDS / PARTY_FLASH.size())
	_ack_id += 1
	var id := _ack_id
	await get_tree().create_timer(PARTY_ACK_SECONDS).timeout
	if id == _ack_id:
		prompt.text = _prompt_text

func _advance() -> void:
	Transition.change_scene_to_packed(CHARACTER_SELECT)

func _delay() -> void:
	delay = true
