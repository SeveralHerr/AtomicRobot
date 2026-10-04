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
const STAMP_TILT := -12.0
const BADGE_TILT := 2.5
const SLAM_SECONDS := 0.52
const STAMP_SIZE := 118.0
const DIM_SHADER := preload("res://shaders/end_card_dim.gdshader")
## Pinball's cursor-pop: the card grows in from this scale with an overshoot.
const POP_FROM := 0.85
const POP_SECONDS := 0.3

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

var _title: Label
var _rank_row: Control
var _stamp: PanelContainer
var _stamp_label: Label
var _score_label: Label
var _breakdown: Label
var _badge_holder: Control
var _badge_label: Label
var _buttons: HBoxContainer
var _center: CenterContainer
var _card: PanelContainer
var _pop: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	beat = DeathBeat.new()
	beat.material = dim_material
	add_child(beat)


func _ready() -> void:
	Globals.player_death.connect(_on_player_death)
	Globals.boss_death.connect(present.bind(true))


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
	card_box.content_margin_top = 14
	card_box.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", card_box)
	center.add_child(tilted(card, CARD_TILT))

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	card.add_child(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	body.add_child(columns)
	columns.add_child(_build_left())
	columns.add_child(_DashedRule.new())
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 420
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_child(right)
	entry = InitialsEntry.new()
	entry.submitted.connect(_on_initials_submitted)
	right.add_child(entry)
	table = ScoreTableView.new()
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


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 10)
	_title = ComicStyle.heading("GAME OVER", 58)
	left.add_child(_title)

	# Stamp beside the score, so the column is as short as the list beside it.
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 22)
	left.add_child(mid)
	_rank_row = VBoxContainer.new()
	_rank_row.add_theme_constant_override("separation", 0)
	mid.add_child(_rank_row)
	_rank_row.add_child(ComicStyle.label("RANK", ComicStyle.LABEL, 34, ComicStyle.PLUM))
	# Stamp: ink ring around a square white plate with a tone-coloured border, as pinball.
	_stamp = PanelContainer.new()
	var ring := ComicStyle.box(ComicStyle.INK, 0, 16, 0)
	ring.set_content_margin_all(4)
	_stamp.add_theme_stylebox_override("panel", ring)
	var plate := PanelContainer.new()
	plate.name = "Plate"
	plate.add_theme_stylebox_override("panel", ComicStyle.box(ComicStyle.PAPER, 8, 12, 0))
	plate.custom_minimum_size = Vector2(STAMP_SIZE, STAMP_SIZE)
	_stamp.add_child(plate)
	# The letter floats in a zero-minimum box: Komika's tall line height would
	# otherwise stretch the plate into a portrait rectangle.
	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(face)
	_stamp_label = ComicStyle.heading("S", 84, ComicStyle.YELLOW)
	_stamp_label.add_theme_constant_override("outline_size", 10)
	_stamp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stamp_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	face.add_child(_stamp_label)
	_rank_row.add_child(tilted(_stamp, STAMP_TILT))

	var figures := VBoxContainer.new()
	figures.alignment = BoxContainer.ALIGNMENT_CENTER
	figures.add_theme_constant_override("separation", 2)
	mid.add_child(figures)
	figures.add_child(ComicStyle.label("FINAL SCORE", ComicStyle.LABEL, 32, ComicStyle.PLUM))
	_score_label = ComicStyle.label("0", ComicStyle.DISPLAY, 46)
	figures.add_child(_score_label)
	_breakdown = ComicStyle.label("", ComicStyle.LABEL, 29)
	figures.add_child(_breakdown)

	var badge := PanelContainer.new()
	var badge_box := ComicStyle.box(ComicStyle.YELLOW, 3, 4, 3)
	badge_box.content_margin_left = 14
	badge_box.content_margin_right = 14
	badge.add_theme_stylebox_override("panel", badge_box)
	_badge_label = ComicStyle.label("", ComicStyle.LABEL, 32)
	badge.add_child(_badge_label)
	_badge_holder = tilted(badge, BADGE_TILT)
	_badge_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(_badge_holder)
	return left


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
	show()
	await beat.play()
	if is_inside_tree() and not _center.visible:
		present(false)


## Show the card for the run that just ended. Safe to call twice (a second death
## signal) - it just repaints.
func present(did_win: bool) -> void:
	won = did_win
	if won:
		_freeze_player()
	var run := ScoreSystem.last_run
	var total := int(run.get("total", ScoreSystem.score))
	var rank := String(run.get("rank", ""))
	_title.text = "YOU WIN!" if won else "GAME OVER"
	_rank_row.visible = rank != ""
	_stamp_label.text = rank
	var tone: Color = ComicStyle.RANK_TONES.get(rank, ComicStyle.BLUE)
	_stamp_label.add_theme_color_override("font_color", tone)
	(_stamp.get_node("Plate").get_theme_stylebox("panel") as StyleBoxFlat).border_color = tone
	_score_label.text = ComicStyle.format_score(total)
	_breakdown.text = breakdown_text(run)
	_breakdown.visible = _breakdown.text != ""
	_badge_label.text = ComicStyle.badge_text(int(run.get("slot", -1)))
	_badge_holder.visible = _badge_label.text != ""
	_disable_touch_controls()
	dim_material.set_shader_parameter("grey", 0.0 if won else 1.0)
	dim_material.set_shader_parameter("dim", 1.0)
	var popping := not (visible and _center.visible)
	_center.show()
	show()
	if popping:
		_pop_card()
	if _rank_row.visible:
		_slam()
	if ScoreSystem.awaiting_initials:
		table.hide()
		_buttons.hide()
		var owner := get_viewport().gui_get_focus_owner()
		if owner:
			owner.release_focus()
		entry.open(ScoreSystem.last_initials)
	else:
		entry.hide()
		table.show_entries(ScoreSystem.high_scores)
		_show_buttons()


## The clear's three score parts, one per line; "" on a death (nothing to break down).
static func breakdown_text(run: Dictionary) -> String:
	if not run.has("fight_score"):
		return ""
	var seconds := float(run.get("seconds", 0.0))
	return "\n".join([
		"FIGHT  %s" % ComicStyle.format_score(int(run["fight_score"])),
		"TIME %d:%02d  +%s" % [int(seconds) / 60, int(seconds) % 60, ComicStyle.format_score(int(run.get("time_bonus", 0)))],
		"%s  +%s" % ["NO DAMAGE" if bool(run.get("perfect", false)) else "HEALTH LEFT",
			ComicStyle.format_score(int(run.get("no_damage_bonus", 0)))],
	])


func _on_initials_submitted(initials: String) -> void:
	var slot := ScoreSystem.submit_initials(initials)
	entry.hide()
	table.show_entries(ScoreSystem.high_scores, slot)
	_show_buttons()


func _show_buttons() -> void:
	_buttons.show()
	EndCard.arm(restart_button)


## Pinball's stamp slam: in from big, tilted and transparent, overshoot, settle.
func _slam() -> void:
	_stamp.scale = Vector2.ONE * 2.6
	_stamp.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_stamp, "scale", Vector2.ONE * 0.92, SLAM_SECONDS * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_stamp, "modulate:a", 1.0, SLAM_SECONDS * 0.4)
	tw.chain().tween_property(_stamp, "scale", Vector2.ONE, SLAM_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pinball's cursor-pop: grow in from POP_FROM with an overshoot while fading up.
func _pop_card() -> void:
	if _pop:
		_pop.kill()
	_card.scale = Vector2.ONE * POP_FROM
	_card.modulate.a = 0.0
	_pop = create_tween().set_parallel()
	_pop.tween_property(_card, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_property(_card, "modulate:a", 1.0, POP_SECONDS * 0.5)


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
