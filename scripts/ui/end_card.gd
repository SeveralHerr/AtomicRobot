class_name EndCard
extends Control

## The ONE end-of-run screen, laid out like atomic-pinball's game-over card
## (src/ui/screens.js): the frozen level dimmed behind one white comic card with
##   left:  GAME OVER / YOU WIN!, the rank stamp, FINAL SCORE, the clear breakdown and
##          the placement badge
##   right: (past a dashed rule) ENTER YOUR INITIALS when the run made the list, which
##          is replaced in place by HIGH SCORES with the new row lit once saved
##   foot:  RESTART / EXIT GAME, hidden until the initials are in
## It replaces the old Game Over / You Win containers, the separate rank card and the
## overlay initials/board screens, so nothing ever stacks on top of anything else.
##
## Shown on Globals.player_death / boss_death. ScoreSystem connected to those signals
## first (autoloads connect before any level), so ScoreSystem.last_run is already
## filled in when present() reads it. A death plays the DeathBeat first (slow-mo, then
## the level drains to grey under this card's own backdrop); a win shows at once - the
## boss finale already was its beat.

const CHARACTER_SELECT := "res://scenes/character_select.tscn"
## Seconds RESTART ignores presses after appearing. JUMP is also A, and a player
## mashing it as they die would otherwise restart by accident.
const ARM_DELAY := 0.6
const CARD_TILT := -1.5
## Above anything else in the level's UI layer: tree order alone loses to a z_index,
## and the HUD orbs (hp_1.tscn, z 2) drew over the card's top edge.
const CARD_Z := 10
const DIM_SHADER := preload("res://shaders/end_card_dim.gdshader")
## Pinball's cursor-pop: the card grows in from this scale with an overshoot.
const POP_FROM := 0.85
const POP_SECONDS := 0.3
## The rank stamp landing: the card jolts and thuds under it.
const STAMP_SHAKE := 9.0
const STAMP_SOUND: AudioStream = preload("res://Sounds/hit3.ogg")
const Juice := preload("res://scripts/ui/select/juice.gd")
## The HP orbs, portrait and score column fade out under the card: one less thing to
## read past.
const HUD_FADE_SECONDS := 0.25

var won: bool = false
## The backdrop's grey/dim (shaders/end_card_dim.gdshader).
var dim_material: ShaderMaterial
var beat: DeathBeat
var restart_button: Button
var exit_button: Button
var entry: InitialsEntry
var table: ScoreTableView
## Swappable so tests can press EXIT GAME without ending the test run.
var quit_game: Callable = func() -> void: QuitGame.quit(get_tree())
## Swappable so tests can press RESTART without changing scene.
var restart_game: Callable = func() -> void:
	Globals.reset()
	Transition.change_scene_to_file(CHARACTER_SELECT)

## Left column: title, rank stamp, score, breakdown, badge (scripts/ui/run_summary.gd).
var summary: RunSummary
var _buttons: HBoxContainer
var _center: CenterContainer
var _card: PanelContainer
var _pop: Tween
var _thud: AudioStreamPlayer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = CARD_Z
	visible = false
	_build()
	beat = DeathBeat.new()
	beat.material = dim_material
	add_child(beat)


func _ready() -> void:
	Globals.player_death.connect(_on_player_death)
	Globals.boss_death.connect(present.bind(true))
	get_parent().child_entered_tree.connect(_on_sibling_added)


## Leaving (restart, exit, scene change): the tube goes back to its normal look.
func _exit_tree() -> void:
	CRTOverlay.reset_focus()
	if is_inside_tree():
		HudFade.release(get_tree(), HudFade.CINEMATIC)


## Anything added to the UI layer while the card is up (boss letterbox bars, a
## phase flash during the death beat) would draw over it; push the card back up.
func _on_sibling_added(node: Node) -> void:
	if visible and node != self and node.get_parent() == get_parent():
		move_to_front.call_deferred()


# --- Build ---------------------------------------------------------------------

## Wrap `inner` so it can be tilted: a Container resets its children's rotation on
## every layout, so the tilted node lives in a plain Control that only takes its size.
static func tilted(inner: Control, degrees: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(inner)
	inner.rotation_degrees = degrees
	inner.resized.connect(func() -> void:
		holder.custom_minimum_size = inner.size
		inner.pivot_offset = inner.size * 0.5)
	return holder


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim_material = ShaderMaterial.new()
	dim_material.shader = DIM_SHADER
	dim_material.set_shader_parameter("tint", ComicStyle.DIM)
	dim.material = dim_material
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	_center = center
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	_card = card
	card.name = "Card"
	var card_box := ComicStyle.box(ComicStyle.PAPER, 5, 10, 9)
	card_box.content_margin_left = 30
	card_box.content_margin_right = 30
	card_box.content_margin_top = 8
	card_box.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_box)
	center.add_child(tilted(card, CARD_TILT))

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	card.add_child(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	body.add_child(columns)
	summary = RunSummary.new()
	summary.stamped.connect(_on_stamped)
	columns.add_child(summary)
	columns.add_child(_DashedRule.new())
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 420
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_child(right)
	entry = InitialsEntry.new()
	entry.submitted.connect(_on_initials_submitted)
	right.add_child(entry)
	table = ScoreTableView.new(30)
	right.add_child(table)

	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 24)
	body.add_child(_buttons)
	restart_button = ComicStyle.button("RESTART", 36)
	restart_button.name = "RestartButton"
	restart_button.custom_minimum_size.x = 260
	restart_button.pressed.connect(func() -> void: restart_game.call())
	_buttons.add_child(restart_button)
	exit_button = ComicStyle.button(QuitGame.EXIT_TEXT.to_upper(), 36)
	exit_button.custom_minimum_size.x = 260
	_buttons.add_child(exit_button)
	QuitGame.wire(exit_button, func() -> void: quit_game.call())
	exit_button.text = QuitGame.EXIT_TEXT.to_upper()
	# Pad focus only ever moves between these two.
	for b in [restart_button, exit_button]:
		b.focus_neighbor_top = NodePath(".")
		b.focus_neighbor_bottom = NodePath(".")
	restart_button.focus_neighbor_right = NodePath("../ExitButton")
	restart_button.focus_neighbor_left = NodePath("../ExitButton")
	exit_button.focus_neighbor_left = NodePath("../RestartButton")
	exit_button.focus_neighbor_right = NodePath("../RestartButton")


# --- Show ----------------------------------------------------------------------

## The killing blow: play the beat over the live level, then the card. A second death
## signal mid-beat is ignored; one after the card just repaints it.
func _on_player_death() -> void:
	if beat.running:
		return
	if _center.visible and visible:
		present(false)
		return
	_disable_touch_controls()
	_center.hide()
	_show_on_top()
	await beat.play()
	if is_inside_tree() and not _center.visible:
		present(false)


## Show the card for the run that just ended. Safe to call twice (a second death
## signal) - it just repaints.
func present(did_win: bool) -> void:
	won = did_win
	if won:
		_freeze_player()
	_disable_touch_controls()
	dim_material.set_shader_parameter("grey", 0.0 if won else 1.0)
	dim_material.set_shader_parameter("dim", 1.0)
	var popping := not (visible and _center.visible)
	# The tube tunes in under the card: at the CRT's normal 512x320 grid with its
	# fringe and glare the card's text was mush (user report).
	CRTOverlay.tune_in(true)
	HudFade.fade(get_tree(), HudFade.CINEMATIC, 0.0, HUD_FADE_SECONDS)
	_center.show()
	_show_on_top()
	if popping:
		_pop_card()
	summary.show_run(ScoreSystem.last_run, won, popping)
	if ScoreSystem.awaiting_initials:
		table.hide()
		_buttons.hide()
		var owner := get_viewport().gui_get_focus_owner()
		if owner:
			owner.release_focus()
		entry.open(ScoreSystem.last_initials)
	else:
		entry.hide()
		table.show_entries(ScoreSystem.high_scores, -1, false)
		_show_buttons()


func _on_initials_submitted(initials: String) -> void:
	var slot := ScoreSystem.submit_initials(initials)
	entry.hide()
	table.show_entries(ScoreSystem.high_scores, slot, false)
	_show_buttons()


func _show_buttons() -> void:
	_buttons.show()
	EndCard.arm(restart_button)


## Show above every sibling: the boss room adds its health card and banner to the same
## UI layer after the card, and they drew over GAME OVER / the grey-out.
func _show_on_top() -> void:
	move_to_front()
	show()


func _on_stamped() -> void:
	Juice.shake(_card, Vector2.ZERO, STAMP_SHAKE, 0.25)
	if _thud == null:
		_thud = AudioStreamPlayer.new()
		_thud.stream = STAMP_SOUND
		_thud.volume_db = -4.0
		add_child(_thud)
	_thud.play()


## Pinball's cursor-pop: grow in from POP_FROM with an overshoot while fading up.
func _pop_card() -> void:
	if _pop:
		_pop.kill()
	_card.scale = Vector2.ONE * POP_FROM
	_card.modulate.a = 0.0
	_pop = create_tween().set_parallel()
	_pop.tween_property(_card, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_property(_card, "modulate:a", 1.0, POP_SECONDS * 0.3)


## The level's on-screen joystick and buttons claim touches by position in their own
## _input, before the GUI: left live, a tap on EXIT GAME over the jump button would
## jump instead. The card owns every touch until the scene changes.
func _disable_touch_controls() -> void:
	var mobile := get_parent().get_node_or_null("MobileUI")
	if mobile:
		mobile.hide()
		mobile.set_process_input(false)


func _freeze_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_process(false)
		player.set_physics_process(false)
		player.set_process_input(false)


## Select `button` at once (so the player sees where focus is) but keep it disabled
## until ARM_DELAY has passed.
static func arm(button: Button) -> void:
	button.disabled = true
	button.grab_focus()
	await button.get_tree().create_timer(ARM_DELAY).timeout
	if is_instance_valid(button):
		button.disabled = false


## Pinball's 3px dashed divider between the run summary and the list.
class _DashedRule:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(6, 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_dashed_line(Vector2(3, 0), Vector2(3, size.y), ComicStyle.INK, 3.0, 9.0)
