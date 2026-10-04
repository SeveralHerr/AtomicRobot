class_name NewsCard
extends CanvasLayer

## The front page a newspaper stand (scripts/interactive_mailbox.gd) hands the player:
## a big comic card (ComicStyle, as atomic-pinball) that spins in to the centre of
## the screen like a movie headline, pauses the game, and stays until the player
## folds it with a fresh press (or a click / tap anywhere).
##
## Player report: with the CRT on the paper was unreadable. It used to be a small
## card in the HUD's left column: at the tube's 512x320 grid its 30 px headline was
## mush, and the bezel's curve ate its left edge. Now it is modal: big type, the
## game dimmed and paused behind it, and the CRT "tunes in" (CRTOverlay.tune_in, as
## the end card) while it is up. test_newspaper_stand.gd keeps it inside the
## CRT-safe area at the desktop and landscape-phone sizes.

signal closed

## Over the HUD (1-2) and the cut-scene / announcer layer (3); under Transition and
## the pause menu (99) and the CRT overlay (100), so it is filmed through the tube.
const LAYER := 4
const WIDTH := 860.0
const PHOTO := Vector2(230.0, 230.0)
const PHOTO_PAD := 12
const PRINT_LINE := 7
const TEXT_GAP := 10
const TILT := -1.5
const MASTHEAD_SIZE := 70
const HEADLINE_FONT: FontFile = ComicStyle.LABEL
const HEADLINE_SIZE := 54
const DIM_ALPHA := 0.62
## The spin-in: whole turns while it grows from a dot, then a punch as it lands.
const SPINS := 2
const SPIN_SECONDS := 0.62
const PUNCH := 1.07
const PUNCH_SECONDS := 0.14
const FOLD_SECONDS := 0.26
## A press this soon after opening is still the one that opened it (or a mash).
const ARM_SECONDS := 0.55
const CLOSE_ACTIONS: Array[StringName] = [&"Interact", &"Attack", &"ui_accept", &"pause"]
const WHOOSH := preload("res://sounds/throw.wav")
const THUD := preload("res://sounds/711657__discofield__stone-crash.wav")
## Photos print in two-tone newsprint ink, whatever the sprite's colours.
const PRINT_SHADER := "shader_type canvas_item;
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	COLOR.rgb = mix(vec3(0.16, 0.14, 0.12), vec3(0.97, 0.93, 0.84), g);
}"

## True while a paper holds the pause: PauseMenu leaves the pause key to the paper.
static var active := false
## The headline while a paper is open, "" once it folds (the autoplay bot reads it
## for as long as a player would, then folds it).
static var active_text := ""

var dim: ColorRect
var card: PanelContainer
var headline: Label
var photo: TextureRect
var prompt: Label
var _open := false
var _was_paused := false
var _armed := false
## Bumped per open, so an old paper's arm timer can't arm a re-read early.
var _gen := 0
## Fake columns of print under the headline; as many show as fill the photo's height.
var _print_lines: Array[ColorRect] = []
var _tween: Tween
var _pulse: Tween
var _whoosh: AudioStreamPlayer
var _thud: AudioStreamPlayer


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(ComicStyle.INK, DIM_ALPHA)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing under the paper takes a click
	add_child(dim)
	var centre := Control.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_preset(Control.PRESET_CENTER)
	add_child(centre)
	card = PanelContainer.new()
	card.name = "Paper"
	var box := ComicStyle.box(ComicStyle.CREAM, 6, 6, 10)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 10
	box.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size.x = WIDTH
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var masthead := ComicStyle.heading("THE DAILY ATOM", MASTHEAD_SIZE, ComicStyle.RED)
	masthead.add_theme_color_override("font_shadow_color", ComicStyle.INK)
	masthead.add_theme_constant_override("shadow_offset_x", 4)
	masthead.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(masthead)
	col.add_child(_dateline())
	col.add_child(_rule(5))
	col.add_child(_story())
	col.add_child(_rule(2))
	prompt = ComicStyle.label("> TAP OR PRESS TO FOLD <", ComicStyle.LABEL, 30)
	col.add_child(prompt)
	_whoosh = _sfx(WHOOSH, -10.0)
	_thud = _sfx(THUD, -14.0)


func _dateline() -> HBoxContainer:
	var row := HBoxContainer.new()
	var parts := [["VOL. XLII", HORIZONTAL_ALIGNMENT_LEFT, ComicStyle.INK],
		["EXTRA! EXTRA!", HORIZONTAL_ALIGNMENT_CENTER, ComicStyle.RED],
		["25 CENTS", HORIZONTAL_ALIGNMENT_RIGHT, ComicStyle.INK]]
	for p: Array in parts:
		var l := ComicStyle.label(p[0], ComicStyle.LABEL, 30, p[2])
		l.horizontal_alignment = p[1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
	return row


func _rule(px: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = ComicStyle.INK
	r.custom_minimum_size.y = px
	return r


## Photo on the left, headline and a few lines of "print" on the right.
func _story() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var frame := PanelContainer.new()
	frame.name = "PhotoFrame"
	var paper := ComicStyle.box(Color("d9cfbb"), 4, 2, 0)
	paper.set_content_margin_all(PHOTO_PAD)
	frame.add_theme_stylebox_override("panel", paper)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	photo = TextureRect.new()
	photo.custom_minimum_size = PHOTO
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = PRINT_SHADER
	photo.material = mat
	frame.add_child(photo)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", TEXT_GAP)
	row.add_child(text)
	headline = ComicStyle.label("", HEADLINE_FONT, HEADLINE_SIZE)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	headline.uppercase = true
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.custom_minimum_size.x = WIDTH - 56.0 - PHOTO.x - 30.0
	text.add_child(headline)
	for w in [1.0, 0.92, 0.97, 0.88, 1.0, 0.94, 0.9, 0.6]:
		var line := ColorRect.new()
		line.color = Color(ComicStyle.INK, 0.28)
		line.custom_minimum_size = Vector2(headline.custom_minimum_size.x * w, PRINT_LINE)
		line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		text.add_child(line)
		_print_lines.append(line)
	return row


## Show as many print lines as fit beside the photo under `text`'s headline (one at
## least), so a short headline doesn't leave a hole and a long one doesn't grow the page.
func _fill_print(text: String) -> void:
	var w := headline.custom_minimum_size.x
	var used := HEADLINE_FONT.get_multiline_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, HEADLINE_SIZE).y
	var room := PHOTO.y + PHOTO_PAD * 2.0 - used - TEXT_GAP
	var n := clampi(int(room / (PRINT_LINE + TEXT_GAP)), 1, _print_lines.size())
	for i in _print_lines.size():
		_print_lines[i].visible = i < n
	_print_lines[n - 1].custom_minimum_size.x = w * 0.6


func _sfx(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	return p


func is_open() -> bool:
	return _open


## Pause the game and show `text` (with `picture`, or no photo). With `animate` the
## paper spins in; without, it is simply there (tests, layout).
func open(text: String, picture: Texture2D = null, animate: bool = true) -> void:
	_open = true
	active = true
	active_text = text
	_was_paused = get_tree().paused
	get_tree().paused = true
	headline.text = text
	_fill_print(text)
	photo.texture = picture
	photo.get_parent().visible = picture != null
	var gen := _gen + 1
	_gen = gen
	# Unscaled game time (not the wall clock): a hitstop can't stall it and a
	# headless --fixed-fps run, faster than real time, arms on the same frame.
	get_tree().create_timer(ARM_SECONDS, true, false, true).timeout.connect(
		func() -> void: if _open and _gen == gen: _arm())
	_armed = false
	_kill()
	prompt.modulate.a = 0.0
	card.reset_size()
	card.position = -card.size * 0.5
	card.pivot_offset = card.size * 0.5
	visible = true
	CRTOverlay.tune_in(true)
	HudFade.fade(get_tree(), HudFade.CINEMATIC, 0.0, 0.2)
	if not animate:
		_pose(1.0, TILT, 1.0)
		return
	_pose(0.06, TILT - 360.0 * SPINS, 0.0)
	_whoosh.play()
	_tween = create_tween().set_ignore_time_scale()
	_tween.set_parallel()
	_tween.tween_property(dim, "color:a", DIM_ALPHA, SPIN_SECONDS * 0.5)
	_tween.tween_property(card, "scale", Vector2.ONE * PUNCH, SPIN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "rotation_degrees", TILT, SPIN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "modulate:a", 1.0, SPIN_SECONDS * 0.25)
	_tween.chain().tween_callback(_thud.play)
	_tween.tween_property(card, "scale", Vector2.ONE, PUNCH_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pose(s: float, degrees: float, alpha: float) -> void:
	card.scale = Vector2.ONE * s
	card.rotation_degrees = degrees
	card.modulate.a = alpha
	dim.color.a = DIM_ALPHA * alpha


## Fold the paper away (it drops off the bottom) and give the game back.
func close() -> void:
	if not _open:
		return
	_open = false
	active_text = ""
	CRTOverlay.tune_in(false)
	HudFade.fade(get_tree(), HudFade.CINEMATIC, 1.0, 0.25)
	_whoosh.play()
	_kill()
	_tween = create_tween().set_ignore_time_scale()
	_tween.set_parallel()
	_tween.tween_property(card, "position:y", card.position.y + 640.0, FOLD_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(card, "rotation_degrees", TILT + 9.0, FOLD_SECONDS).set_ease(Tween.EASE_IN)
	_tween.tween_property(dim, "color:a", 0.0, FOLD_SECONDS)
	_tween.chain().tween_callback(_release_game)


func _release_game() -> void:
	visible = false
	if active:
		active = false
		if not _was_paused:
			get_tree().paused = false
	closed.emit()


## Polled (not _input): the autoplay bot and touch buttons press actions, not keys.
func _process(_delta: float) -> void:
	if not _open:
		return
	if _armed and CLOSE_ACTIONS.any(func(a: StringName) -> bool: return Input.is_action_just_pressed(a)):
		close()


## From now a fresh press folds the paper; the prompt starts to pulse to say so.
func _arm() -> void:
	if _armed:
		return
	_armed = true
	_pulse = create_tween().set_ignore_time_scale().set_loops()
	_pulse.tween_property(prompt, "modulate:a", 1.0, 0.3)
	_pulse.tween_property(prompt, "modulate:a", 0.6, 0.5)


## A click or a tap anywhere folds it: the on-screen pad is paused with the game.
## _input, not the dim's gui_input: no hit-test for another layer to swallow.
func _input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed
	if tap and _open and _armed:
		get_viewport().set_input_as_handled()
		close()


func _kill() -> void:
	for t: Tween in [_tween, _pulse]:
		if t != null and t.is_valid():
			t.kill()


## Freed mid-read (scene change, stand freed): never leave the game paused.
func _exit_tree() -> void:
	if active and visible:
		active = false
		_open = false
		if not _was_paused:
			get_tree().paused = false
		CRTOverlay.reset_focus()
		HudFade.fade(get_tree(), HudFade.CINEMATIC, 1.0, 0.0)
