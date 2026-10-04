extends Control

## Character select: a comic roster strip along the bottom, the focused fighter big
## on a ray-lit stage, stats on a tilted info card. Built in code so every piece is a
## free node tweens can punch.
##
## Arcade has no mouse: a card owns focus the moment the screen opens (last-played
## fighter, else the first unlocked one) or the d-pad has nothing to move.

const CONTROLS_SPLASH: PackedScene = preload("res://scenes/controls_splash.tscn")
const RosterCard := preload("res://scripts/ui/select/roster_card.gd")
const HeroStage := preload("res://scripts/ui/select/hero_stage.gd")
const InfoCard := preload("res://scripts/ui/select/info_card.gd")
const Juice := preload("res://scripts/ui/select/juice.gd")
const BG_ART: Texture2D = preload("res://images/ARTBG.png")
const SWAY: Script = preload("res://scripts/sway.gd")
const TICK: AudioStream = preload("res://sounds/tap.wav")
const DENY: AudioStream = preload("res://sounds/hit3.ogg")
const CHEER: AudioStream = preload("res://sounds/power_up.wav")
const FANFARE: AudioStream = preload("res://sounds/Unlock.wav")
## When the NEW CHALLENGER reveal fires: after the roster has dropped in.
const REVEAL_AT := 0.6

## Semitones per card: a major pentatonic run, so sweeping the strip plays a scale.
const TICK_STEPS: Array[int] = [0, 2, 4, 7, 9, 12]
const ROSTER: Array[String] = ["Cody", "Ryan", "Cass", "Caitlyn", "Sara", "Robot"]
const DESIGN := Vector2(1280, 800)
const STAGE_FEET := Vector2(330, 530)
const INFO_AT := Vector2(700, 128)
const ROSTER_Y := 556.0
## Path, not preload: the title screen preloads this scene.
const TITLE := "res://scenes/startscreen.tscn"
const CARD_GAP := 18
## Seconds the READY! moment holds before the screen cuts to the next scene.
const CONFIRM_HOLD := 1.4
## Freeze before the burst: the beat that makes a pick land like a hit.
const HITSTOP := 0.08
const FADE_TIME := 0.3

var cards: Array[Button] = []
var hero: Control
var info: Panel
var title: Label
var cursor: Control
var exit_button: Button
var flash: ColorRect
var fade: ColorRect
var sfx: AudioStreamPlayer
var confirmed := false
## Seconds after opening before a pick counts, so the A that left the title screen
## (held, or mashed) can't instantly choose a fighter. Tests set 0.
var accept_grace := 0.35
## Game-time seconds since opening. Game time, not wall clock: the autoplay bot runs
## at a high Engine.time_scale and its taps must clear the grace like a player's.
var _age := 0.0
## Last input family seen: "pad", "keys" or "touch". Drives the prompt and two-tap.
var device := "pad"
## Focus owner when the current tap/click began, before the GUI moved focus to it.
## On touch only a tap on this (already previewed) fighter picks.
var _armed: Control
## Swappable so tests can press EXIT GAME without ending the test run.
var quit_game: Callable = func() -> void: QuitGame.quit(get_tree())

var _hot := -1
var _stage: Control  # everything that shakes on confirm
var _cursor_tween: Tween


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks off the cards reach _unhandled_input
	_build_background()
	_stage = Juice.layer(self)
	_stage.pivot_offset = DESIGN / 2.0
	_build_title()
	hero = HeroStage.new()
	hero.position = STAGE_FEET
	_stage.add_child(hero)
	info = InfoCard.new()
	info.position = INFO_AT
	_stage.add_child(info)
	info.set_roster(ROSTER.map(func(c: String) -> CharacterConfig: return Globals.character_dict[c]))
	_build_roster()
	_build_footer()
	flash = _overlay(Color(1, 1, 1, 0))
	fade = _overlay(Color(0, 0, 0, 0))
	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	_wire_focus()
	initial_card().grab_focus()
	_intro()
	var fresh := revealing()
	Globals.unseen_unlocks = PackedStringArray()  # announce once
	if fresh:
		_reveal(fresh)


## The fighter just earned, if any (and it's in this roster).
func revealing() -> Button:
	for c in Globals.unseen_unlocks:
		var card := card_for(c)
		if card and card.is_unlocked():
			return card
	return null


func initial_card() -> Button:
	if revealing():
		return revealing()
	var first_unlocked: Button = null
	for card in cards:
		if not card.is_unlocked():
			continue
		if card.character == Globals.selected_character:
			return card
		if first_unlocked == null:
			first_unlocked = card
	return first_unlocked if first_unlocked else cards[0]


func card_for(character: String) -> Button:
	for card in cards:
		if card.character == character:
			return card
	return null


## A pressed on `card`. Locked: shake no. Unlocked: pick it, celebrate, then go.
func confirm(card: Button) -> void:
	if confirmed or _age < accept_grace:
		return
	if not card.is_unlocked():
		card.reject()
		_play_extra(DENY, 0.6)
		return
	confirmed = true
	Globals.selected_character = card.character
	_lock_input()
	card.chosen()
	hero.freeze()
	_play(card.config().get_attack_sound(), 1.0, 0.0)
	var seq := create_tween()
	seq.tween_interval(HITSTOP)
	seq.tween_callback(_burst.bind(card))
	seq.tween_interval(CONFIRM_HOLD - HITSTOP - FADE_TIME)
	# Fade to black while the stage pushes in: pulled into the fight.
	seq.tween_property(fade, "color:a", 1.0, FADE_TIME)
	seq.parallel().tween_property(_stage, "scale", Vector2.ONE * 1.06, FADE_TIME).set_ease(Tween.EASE_IN)
	seq.tween_callback(start_run)


## The impact after the hitstop: flash, shake, READY!, the rest of the strip dims.
func _burst(card: Button) -> void:
	hero.celebrate()
	_play_extra(CHEER)
	for other in cards:
		if other != card:
			other.create_tween().tween_property(other, "modulate", Color(0.45, 0.45, 0.55, 0.7), 0.2)
	flash.color.a = 0.9
	create_tween().tween_property(flash, "color:a", 0.0, 0.2)
	Juice.shake(_stage, Vector2.ZERO, 14.0, 0.35)


## -1/+1: which way the cursor travelled from `from` to `to` on a wrapping strip
## of `n` (Robot -> Cody is a step right, not five steps left).
static func tick_pitch(index: int) -> float:
	return 1.15 * pow(2.0, TICK_STEPS[index % TICK_STEPS.size()] / 12.0)


static func wrap_dir(from: int, to: int, n: int) -> int:
	var d := to - from
	if absi(d) > n / 2:
		d -= signi(d) * n
	return signi(d)


func _input(event: InputEvent) -> void:
	var d := device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		d = "pad"
	elif event is InputEventKey:
		d = "keys"
	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		d = "touch"
	if d != device:
		device = d
		info.set_device(d)
	if _begins_tap(event):
		_armed = get_viewport().gui_get_focus_owner()


## A finger down, or a real mouse button down. The left-button press the engine
## emulates from that same finger is skipped: by then the GUI may already have moved
## focus to the card under it, which would arm the very card being previewed.
static func _begins_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	return event is InputEventMouseButton and event.pressed 		and event.device != InputEvent.DEVICE_ID_EMULATION


## A tap on a fighter that wasn't already up only previews it; the next tap picks.
## Decided at press time, not by counting frames to the release: Button fires
## `pressed` on release, so a normal ~0.1s tap outlived any frame window and picked
## on the first tap. Pad/keys focus first anyway, so they pick on the first press.
func _on_card_pressed(card: Button) -> void:
	if device == "touch" and card != _armed:
		return
	confirm(card)


## Attack is the cabinet's big button: it picks too. Back leaves for the title.
func _process(delta: float) -> void:
	_age += delta


func _unhandled_input(event: InputEvent) -> void:
	if confirmed:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if event.is_action_pressed("Attack") and focused in cards:
		get_viewport().set_input_as_handled()
		confirm(focused)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_to_title()
	elif _taps_off_strip(event) and focused in cards:
		# "TAP AGAIN TO FIGHT!": a tap off the strip (the big fighter, the prompt)
		# picks the previewed fighter too. Cards and buttons consume their own taps.
		get_viewport().set_input_as_handled()
		confirm(focused)


## A finger, or a left click: a mouse reads as "touch" too, so the prompt says TAP
## AGAIN and a click on it must pick. Reaches here only because the root ignores the
## mouse (_ready); a STOP root ate every click off the cards.
static func _taps_off_strip(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	return event is InputEventMouseButton and event.pressed 		and event.button_index == MOUSE_BUTTON_LEFT


func back_to_title() -> void:
	Transition.change_scene_to_file(TITLE)


## On to the controls splash. The story is told by the street's opening cut scene
## (any button skips it), so there is no story screen and no SKIP INTRO.
func start_run() -> void:
	Transition.change_scene_to_packed(next_scene())


func next_scene() -> PackedScene:
	return CONTROLS_SPLASH


func _on_card_focus(card: Button) -> void:
	var first := _hot < 0
	var dir := 0 if first else wrap_dir(_hot, card.index, cards.size())
	_hot = card.index
	var cfg: CharacterConfig = card.config()
	hero.show_character(cfg, card.is_unlocked(), dir)
	info.show_character(cfg, card.is_unlocked())
	# Up from the footer returns to the fighter you were on, not the nearest card.
	exit_button.focus_neighbor_top = exit_button.get_path_to(card)
	_move_cursor.call_deferred(card, first)
	_dim_cursor(false)
	if not first:
		_play(TICK, tick_pitch(card.index), -8.0)


## Same swaying street art as the title screen (startscreen.tscn's TextureRect), so
## title -> select reads as one place.
func _on_footer_focus() -> void:
	_play(TICK, tick_pitch(0) * 0.75, -8.0)
	_dim_cursor(true)


## P1 fades while focus is down in the footer, so only one thing reads as selected.
func _dim_cursor(dim: bool) -> void:
	cursor.create_tween().tween_property(cursor, "modulate:a", 0.25 if dim else 1.0, 0.12)


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture = BG_ART
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = Vector2(-42, -2)
	bg.size = DESIGN
	bg.scale = Vector2(1.1, 1.15)
	bg.set_script(SWAY)
	add_child(bg)
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
	add_child(shade)


func _build_title() -> void:
	title = ComicStyle.heading("CHOOSE YOUR FIGHTER!", 66, ComicStyle.YELLOW)
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_shadow_color", ComicStyle.INK)
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.add_theme_constant_override("shadow_outline_size", 16)
	title.size = Vector2(DESIGN.x, 110)
	title.position = Vector2(0, 18)
	title.pivot_offset = title.size / 2.0
	title.rotation_degrees = -2.0
	_stage.add_child(title)


func _build_roster() -> void:
	var row := HBoxContainer.new()
	row.name = "Roster"
	row.add_theme_constant_override("separation", CARD_GAP)
	var width := ROSTER.size() * RosterCard.SIZE.x + (ROSTER.size() - 1) * CARD_GAP
	row.position = Vector2((DESIGN.x - width) / 2.0, ROSTER_Y)
	row.size = Vector2(width, RosterCard.SIZE.y)
	_stage.add_child(row)
	for i in ROSTER.size():
		var card: Button = RosterCard.new().setup(ROSTER[i], i)
		row.add_child(card)
		card.focus_entered.connect(_on_card_focus.bind(card))
		card.pressed.connect(_on_card_pressed.bind(card))
		cards.append(card)
	_build_cursor()


## Bobbing "P1" tag that springs between cards.
func _build_cursor() -> void:
	cursor = Control.new()
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.z_index = 2
	var tag := ComicStyle.label("P1", ComicStyle.LABEL, 30, ComicStyle.PAPER)
	tag.add_theme_stylebox_override("normal", ComicStyle.box(ComicStyle.RED, 3, 8, 3))
	tag.size = Vector2(56, 38)
	tag.position = Vector2(-28, -46)
	cursor.add_child(tag)
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-12, -9), Vector2(12, -9), Vector2(0, 6)])
	arrow.color = ComicStyle.RED
	cursor.add_child(arrow)
	_stage.add_child(cursor)
	var bob := cursor.create_tween().set_loops()
	bob.tween_property(tag, "position:y", -54.0, 0.35).set_trans(Tween.TRANS_SINE)
	bob.parallel().tween_property(arrow, "position:y", -8.0, 0.35).set_trans(Tween.TRANS_SINE)
	bob.tween_property(tag, "position:y", -46.0, 0.35).set_trans(Tween.TRANS_SINE)
	bob.parallel().tween_property(arrow, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)


## EXIT GAME, centred under the roster (hidden where the game can't quit).
func _build_footer() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Footer"
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.position = Vector2(0, DESIGN.y - 76)  # clear of the CRT's curved bottom edge
	bar.size = Vector2(DESIGN.x, 50)
	_stage.add_child(bar)
	# Focus = the whole button lights yellow (ComicStyle.button's rule); a thin
	# outline vanishes behind the CRT scanlines.
	var focus_box := ComicStyle.box(ComicStyle.YELLOW, 4, 8, 4)
	focus_box.set_content_margin_all(8)
	focus_box.set_expand_margin_all(4)

	exit_button = Button.new()
	exit_button.focus_entered.connect(_on_footer_focus)
	_footer_style(exit_button, focus_box)
	bar.add_child(exit_button)
	QuitGame.wire(exit_button, func() -> void: quit_game.call())
	exit_button.text = exit_button.text.to_upper()


func _footer_style(b: Button, focus_box: StyleBox) -> void:
	b.flat = true
	b.add_theme_font_override("font", ComicStyle.LABEL)
	b.add_theme_font_size_override("font_size", 40)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, ComicStyle.PAPER)
	b.add_theme_color_override("font_focus_color", ComicStyle.INK)
	# Drop shadow, not outline: an ink outline turns the ink focus text into a blob.
	b.add_theme_color_override("font_shadow_color", ComicStyle.INK)
	b.add_theme_constant_override("shadow_offset_x", 3)
	b.add_theme_constant_override("shadow_offset_y", 3)
	b.add_theme_stylebox_override("focus", focus_box)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())


## Explicit neighbours: geometric search gets lost once cards lift and tilt. The
## strip wraps at both ends - an arcade strip, not a wall.
func _wire_focus() -> void:
	var n := cards.size()
	for i in n:
		var card := cards[i]
		card.focus_neighbor_left = card.get_path_to(cards[(i - 1 + n) % n])
		card.focus_neighbor_right = card.get_path_to(cards[(i + 1) % n])
		# Down reaches EXIT GAME; where it is hidden (web), down stays put.
		card.focus_neighbor_bottom = card.get_path_to(exit_button if exit_button.visible else card)
		card.focus_neighbor_top = card.get_path_to(card)
	for side in ["focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_bottom"]:
		exit_button.set(side, exit_button.get_path_to(exit_button))


func _intro() -> void:
	title.position.y = -160.0
	var t := title.create_tween()
	t.tween_property(title, "position:y", 18.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_callback(_play_extra.bind(DENY, 0.45)).set_delay(0.18)  # thud on first bounce
	var wobble := title.create_tween().set_loops()
	wobble.tween_property(title, "rotation_degrees", 2.0, 1.4).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(title, "rotation_degrees", -2.0, 1.4).set_trans(Tween.TRANS_SINE)
	info.position.x = DESIGN.x + 40
	info.create_tween().tween_property(info, "position:x", INFO_AT.x, 0.45) \
		.set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for card in cards:
		card.enter(0.1 + card.index * 0.06)


## Deferred: the roster's layout lands after _ready, read the target then.
func _reveal(card: Button) -> void:
	card.reveal(REVEAL_AT)
	var t := create_tween()
	t.tween_interval(REVEAL_AT)
	t.tween_callback(func() -> void:
		if confirmed:  # picked before the reveal landed; READY! owns the stage
			return
		if card.has_focus():
			hero.reveal()
		_play_extra(FANFARE)
		flash.color.a = 0.7
		create_tween().tween_property(flash, "color:a", 0.0, 0.3)
		Juice.shake(_stage, Vector2.ZERO, 10.0, 0.3))


func _move_cursor(card: Button, snap: bool) -> void:
	var target: Vector2 = card.position + card.get_parent().position + Vector2(card.size.x / 2.0, RosterCard.LIFT - 8.0)
	if snap:
		cursor.position = target
		return
	if _cursor_tween:
		_cursor_tween.kill()
	_cursor_tween = cursor.create_tween()
	_cursor_tween.tween_property(cursor, "position", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## After A: nothing else may take focus or fire while READY! plays.
func _lock_input() -> void:
	var all: Array[Button] = cards.duplicate()
	all.append(exit_button)
	for b in all:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _play(stream: AudioStream, pitch: float, db: float) -> void:
	if stream == null:
		return
	sfx.stream = stream
	sfx.pitch_scale = pitch
	sfx.volume_db = db
	sfx.play()


## A second voice so a cheer or buzz doesn't cut off the shout or tick.
func _play_extra(stream: AudioStream, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = -6.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _overlay(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(r)
	return r

