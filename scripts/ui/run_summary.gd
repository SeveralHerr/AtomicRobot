class_name RunSummary
extends VBoxContainer

## The end card's left column (scripts/ui/end_card.gd): GAME OVER / YOU WIN!, the
## NEW FIGHTER stamp when the run unlocked someone, the rank stamp beside FINAL SCORE
## and the run's breakdown (STREET / BOSS / BONUS), the rank hint and the placement
## badge.
## On a fresh card it plays as one beat: the rows drop in, FINAL SCORE rolls up with
## coin ticks, the rank stamp slams on the last tick (`stamped`, the card shakes),
## then the hint and badge pop.
## Split out of EndCard so the card file stays about flow (show, initials, buttons)
## and this one about what the run scored.

const Juice := preload("res://scripts/ui/select/juice.gd")

const STAMP_TILT := -12.0
const BADGE_TILT := 2.5
const SLAM_SECONDS := 0.52
const STAMP_SIZE := 136.0
const UNLOCK_TILT := -4.0
## The NEW FIGHTER stamp lands after the rank stamp has settled.
const UNLOCK_DELAY := 0.45
const ROW_SIZE := 34
## Breakdown rows fade in this far apart while the score rolls.
const ROW_STAGGER := 0.12
const TALLY_DELAY := 0.15
const BADGE_SOUND: AudioStream = preload("res://Sounds/power_up.wav")

## The rank stamp has just landed (the card shakes and thuds on it).
signal stamped

var title: Label
var rank_row: Control
var stamp: PanelContainer
var stamp_label: Label
var score_label: Label
## Two columns (label, value) filled from breakdown_rows().
var breakdown: GridContainer
## "NEW FIGHTER: ROBOT" — the unlock would otherwise fire behind this card unseen.
var unlock_holder: Control
var unlock_label: Label
var badge_holder: Control
## The gap to the next rank and a tip (scripts/ui/rank_ladder.gd).
var ladder: RankLadder
var badge_label: Label
var tally: ScoreTally
var _beat: Tween
var _badge_audio: AudioStreamPlayer


func _init() -> void:
	custom_minimum_size.x = 400
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 5)
	title = ComicStyle.heading("GAME OVER", 66)
	add_child(title)
	_build_unlock_stamp()

	# Stamp beside the score, so the column is as short as the list beside it.
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 22)
	add_child(mid)
	rank_row = VBoxContainer.new()
	rank_row.add_theme_constant_override("separation", 0)
	mid.add_child(rank_row)
	# Stamp: ink ring around a square white plate with a tone-coloured border, as pinball.
	stamp = PanelContainer.new()
	var ring := ComicStyle.box(ComicStyle.INK, 0, 16, 0)
	ring.set_content_margin_all(4)
	stamp.add_theme_stylebox_override("panel", ring)
	var plate := PanelContainer.new()
	plate.name = "Plate"
	plate.add_theme_stylebox_override("panel", ComicStyle.box(ComicStyle.PAPER, 8, 12, 0))
	plate.custom_minimum_size = Vector2(STAMP_SIZE, STAMP_SIZE)
	stamp.add_child(plate)
	# The letter floats in a zero-minimum box: Komika's tall line height would
	# otherwise stretch the plate into a portrait rectangle.
	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(face)
	stamp_label = ComicStyle.heading("S", 96, ComicStyle.YELLOW)
	stamp_label.add_theme_constant_override("outline_size", 10)
	stamp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	stamp_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	face.add_child(stamp_label)
	rank_row.add_child(EndCard.tilted(stamp, STAMP_TILT))

	var figures := VBoxContainer.new()
	figures.alignment = BoxContainer.ALIGNMENT_CENTER
	figures.add_theme_constant_override("separation", 2)
	mid.add_child(figures)
	figures.add_child(ComicStyle.label("FINAL SCORE", ComicStyle.LABEL, 32, ComicStyle.PLUM))
	score_label = ComicStyle.label("0", ComicStyle.DISPLAY, 60)
	figures.add_child(score_label)
	breakdown = GridContainer.new()
	breakdown.columns = 2
	breakdown.add_theme_constant_override("h_separation", 18)
	breakdown.add_theme_constant_override("v_separation", -2)
	figures.add_child(breakdown)

	ladder = RankLadder.new()
	add_child(ladder)

	var badge := PanelContainer.new()
	var badge_box := ComicStyle.box(ComicStyle.YELLOW, 3, 4, 3)
	badge_box.content_margin_left = 14
	badge_box.content_margin_right = 14
	badge.add_theme_stylebox_override("panel", badge_box)
	badge_label = ComicStyle.label("", ComicStyle.LABEL, 32)
	badge.add_child(badge_label)
	badge_holder = EndCard.tilted(badge, BADGE_TILT)
	badge_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(badge_holder)

	tally = ScoreTally.new()
	tally.finished.connect(_on_tally_finished)
	add_child(tally)
	_badge_audio = AudioStreamPlayer.new()
	_badge_audio.stream = BADGE_SOUND
	_badge_audio.volume_db = -8.0
	add_child(_badge_audio)


## Fill the column from a ScoreSystem.last_run. `animate` plays the reveal beat
## (fresh card); false shows the settled card at once (a repaint).
func show_run(run: Dictionary, won: bool, animate: bool = true) -> void:
	var total := int(run.get("total", ScoreSystem.score))
	var rank := String(run.get("rank", ""))
	title.text = "YOU WIN!" if won else "GAME OVER"
	rank_row.visible = rank != ""
	stamp_label.text = rank
	var tone: Color = ComicStyle.RANK_TONES.get(rank, ComicStyle.BLUE)
	stamp_label.add_theme_color_override("font_color", tone)
	(stamp.get_node("Plate").get_theme_stylebox("panel") as StyleBoxFlat).border_color = tone
	_fill_breakdown(breakdown_rows(run))
	ladder.show_run(run, won)
	unlock_label.text = unlock_text(run)
	unlock_holder.visible = unlock_label.text != ""
	badge_label.text = ComicStyle.badge_text(int(run.get("slot", -1)))
	badge_holder.visible = badge_label.text != ""
	if _beat:
		_beat.kill()
	if not animate:
		for node in _revealed():
			node.modulate.a = 1.0
		stamp.modulate.a = 1.0
		stamp.scale = Vector2.ONE
		tally.play(score_label, total)
		tally.finish()
		return
	# Everything after the score waits for it: hidden now, revealed in order.
	for node in _revealed():
		node.modulate.a = 0.0
	stamp.modulate.a = 0.0
	var rows := _row_pairs()
	if not rows.is_empty():  # an empty Tween logs an engine error (a death card)
		_beat = create_tween()
	for row in rows:
		_beat.tween_interval(ROW_STAGGER)
		for l in row:
			_beat.parallel().tween_property(l, "modulate:a", 1.0, ROW_STAGGER)
	tally.play(score_label, total, TALLY_DELAY)


## Nodes the beat reveals after the tally (breakdown rows reveal during it).
func _revealed() -> Array:
	var out: Array = [ladder, badge_holder]
	for row in _row_pairs():
		out.append_array(row)
	return out


func _row_pairs() -> Array:
	var kids := breakdown.get_children()
	var out: Array = []
	for i in range(0, kids.size() - 1, 2):
		out.append([kids[i], kids[i + 1]])
	return out


## Last tick: stamp slams (a ranked clear), then hint, badge and unlock follow.
func _on_tally_finished() -> void:
	if stamp.modulate.a >= 1.0 and ladder.modulate.a >= 1.0:
		return  # a repaint: already settled
	if _beat and _beat.is_running():
		_beat.custom_step(INF)  # rows fully in before the payoff
	var settle := 0.0
	if rank_row.visible:
		_slam()
		settle = SLAM_SECONDS
	var tw := create_tween()
	tw.tween_interval(settle * 0.5)
	tw.tween_property(ladder, "modulate:a", 1.0, 0.2)
	if badge_holder.visible and badge_holder.modulate.a < 1.0:
		tw.tween_callback(_pop_badge)
	if unlock_holder.visible:
		_slam_unlock()


func _pop_badge() -> void:
	badge_holder.modulate.a = 1.0
	Juice.pop(badge_holder.get_child(0) as Control, 1.35)
	if _badge_audio.is_inside_tree():
		_badge_audio.play()


## The clear's rows as [label, value]: STREET, BOSS and BONUS add up to the final
## score. The bonus is not itemised: through the CRT six rows of small type read as
## noise, and the rank hint names the one part worth chasing. [] on a death (nothing
## to break down). A boss-only stage (debug start) has no STREET row.
static func breakdown_rows(run: Dictionary) -> Array:
	var street := int(run.get("street_score", 0))
	if not run.has("fight_score"):
		# A death after the boss door: show the split, so it is plain the street's
		# points are in the total (a player read a boss-room death as boss-only).
		if street <= 0:
			return []
		return [["STREET", ComicStyle.format_score(street)],
			["BOSS", ComicStyle.format_score(int(run.get("total", 0)) - street)]]
	var rows := []
	if street > 0:
		rows.append(["STREET", ComicStyle.format_score(street)])
	rows.append(["BOSS", ComicStyle.format_score(int(run.get("boss_score", run["fight_score"])))])
	rows.append(["BONUS", "+" + ComicStyle.format_score(int(run.get("bonus", 0)))])
	return rows


## Every row's text, for the font-coverage test and quick asserts.
static func breakdown_text(run: Dictionary) -> String:
	var parts := PackedStringArray()
	for row in breakdown_rows(run):
		parts.append("%s  %s" % [row[0], row[1]])
	return "
".join(parts)


## "NEW FIGHTER: ROBOT" for the fighters this run unlocked; "" when none.
static func unlock_text(run: Dictionary) -> String:
	var names: Array = run.get("unlocks", [])
	if names.is_empty():
		return ""
	return "NEW FIGHTER: " + " & ".join(PackedStringArray(names)).to_upper()


func _fill_breakdown(rows: Array) -> void:
	for child in breakdown.get_children():
		breakdown.remove_child(child)
		child.queue_free()
	for row in rows:
		var name_label := ComicStyle.label(row[0], ComicStyle.LABEL, ROW_SIZE, ComicStyle.PLUM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var value_label := ComicStyle.label(row[1], ComicStyle.DISPLAY, ROW_SIZE - 4)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		breakdown.add_child(name_label)
		breakdown.add_child(value_label)
	breakdown.visible = not rows.is_empty()


## Pinball-style comic stamp: ink ring, white plate with a red border, red letters.
func _build_unlock_stamp() -> void:
	var ring := PanelContainer.new()
	var ring_box := ComicStyle.box(ComicStyle.INK, 0, 10, 4)
	ring_box.set_content_margin_all(4)
	ring.add_theme_stylebox_override("panel", ring_box)
	var plate := PanelContainer.new()
	var plate_box := ComicStyle.box(ComicStyle.CREAM, 5, 7, 0)
	plate_box.border_color = ComicStyle.RED
	plate_box.content_margin_left = 16
	plate_box.content_margin_right = 16
	plate.add_theme_stylebox_override("panel", plate_box)
	ring.add_child(plate)
	unlock_label = ComicStyle.label("", ComicStyle.LABEL, 34, ComicStyle.RED)
	plate.add_child(unlock_label)
	unlock_holder = EndCard.tilted(ring, UNLOCK_TILT)
	unlock_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	unlock_holder.hide()
	add_child(unlock_holder)


func _slam_unlock() -> void:
	var ring := unlock_holder.get_child(0) as Control
	ring.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(UNLOCK_DELAY)
	tw.tween_callback(func() -> void: Juice.slam(ring, UNLOCK_TILT, 0.32))


## Pinball's stamp slam: in from big, tilted and transparent, overshoot, settle.
func _slam() -> void:
	stamp.scale = Vector2.ONE * 2.6
	stamp.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(stamp, "scale", Vector2.ONE * 0.92, SLAM_SECONDS * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(stamp, "modulate:a", 1.0, SLAM_SECONDS * 0.4)
	tw.chain().tween_callback(func() -> void: stamped.emit())
	tw.tween_property(stamp, "scale", Vector2.ONE, SLAM_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
