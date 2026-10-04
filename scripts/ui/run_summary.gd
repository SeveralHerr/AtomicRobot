class_name RunSummary
extends VBoxContainer

## The end card's left column (scripts/ui/end_card.gd): GAME OVER / YOU WIN!, the
## NEW FIGHTER stamp when the run unlocked someone, the rank stamp beside FINAL SCORE
## and the run's breakdown (STREET / BOSS / BONUS, the bonus itemised beneath), and
## the placement badge.
## Split out of EndCard so the card file stays about flow (show, initials, buttons)
## and this one about what the run scored.

const Juice := preload("res://scripts/ui/select/juice.gd")

const STAMP_TILT := -12.0
const BADGE_TILT := 2.5
const SLAM_SECONDS := 0.52
const STAMP_SIZE := 118.0
const UNLOCK_TILT := -4.0
## The NEW FIGHTER stamp lands after the rank stamp has settled.
const UNLOCK_DELAY := 0.45
const ROW_SIZE := 29
const DETAIL_SIZE := 23

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
var badge_label: Label


func _init() -> void:
	custom_minimum_size.x = 400
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)
	title = ComicStyle.heading("GAME OVER", 58)
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
	rank_row.add_child(ComicStyle.label("RANK", ComicStyle.LABEL, 34, ComicStyle.PLUM))
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
	stamp_label = ComicStyle.heading("S", 84, ComicStyle.YELLOW)
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
	score_label = ComicStyle.label("0", ComicStyle.DISPLAY, 46)
	figures.add_child(score_label)
	breakdown = GridContainer.new()
	breakdown.columns = 2
	breakdown.add_theme_constant_override("h_separation", 18)
	breakdown.add_theme_constant_override("v_separation", -4)
	figures.add_child(breakdown)

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


## Fill the column from a ScoreSystem.last_run. Slams the stamp when there is a rank.
func show_run(run: Dictionary, won: bool) -> void:
	var total := int(run.get("total", ScoreSystem.score))
	var rank := String(run.get("rank", ""))
	title.text = "YOU WIN!" if won else "GAME OVER"
	rank_row.visible = rank != ""
	stamp_label.text = rank
	var tone: Color = ComicStyle.RANK_TONES.get(rank, ComicStyle.BLUE)
	stamp_label.add_theme_color_override("font_color", tone)
	(stamp.get_node("Plate").get_theme_stylebox("panel") as StyleBoxFlat).border_color = tone
	score_label.text = ComicStyle.format_score(total)
	_fill_breakdown(breakdown_rows(run))
	unlock_label.text = unlock_text(run)
	unlock_holder.visible = unlock_label.text != ""
	badge_label.text = ComicStyle.badge_text(int(run.get("slot", -1)))
	badge_holder.visible = badge_label.text != ""
	if rank_row.visible:
		_slam()
	if unlock_holder.visible:
		_slam_unlock()


## The clear's rows as [label, value, detail?]: STREET, BOSS and BONUS add up to the
## final score; the detail rows itemise the bonus. [] on a death (nothing to break
## down). A boss-only stage (debug start) has no STREET row.
static func breakdown_rows(run: Dictionary) -> Array:
	if not run.has("fight_score"):
		return []
	var rows := []
	var street := int(run.get("street_score", 0))
	if street > 0:
		rows.append(["STREET", ComicStyle.format_score(street), false])
	rows.append(["BOSS", ComicStyle.format_score(int(run.get("boss_score", run["fight_score"]))), false])
	rows.append(["BONUS", "+" + ComicStyle.format_score(int(run.get("bonus", 0))), false])
	var seconds := float(run.get("seconds", 0.0))
	rows.append(["TIME %d:%02d" % [int(seconds) / 60, int(seconds) % 60],
		"+" + ComicStyle.format_score(int(run.get("time_bonus", 0))), true])
	rows.append(["NO DAMAGE" if bool(run.get("perfect", false)) else "HEALTH LEFT",
		"+" + ComicStyle.format_score(int(run.get("no_damage_bonus", 0))), true])
	var secrets := secrets_text(run)
	if secrets != "":
		rows.append([secrets, "+" + ComicStyle.format_score(int(run.get("secret_bonus", 0))), true])
	return rows


## Every row's text, for the font-coverage test and quick asserts.
static func breakdown_text(run: Dictionary) -> String:
	var parts := PackedStringArray()
	for row in breakdown_rows(run):
		parts.append("%s  %s" % [row[0], row[1]])
	return "
".join(parts)


## "SECRETS a/b · NEWS c/d" from the run's found/total counts; "" when the run's
## level has no secrets to count (sandboxes, a death).
static func secrets_text(run: Dictionary) -> String:
	var totals: Dictionary = run.get("secret_totals", {})
	if totals.is_empty():
		return ""
	var found: Dictionary = run.get("secrets", {})
	return "SECRETS %d/%d · NEWS %d/%d" % [int(found.get("wall", 0)), int(totals.get("wall", 0)),
		int(found.get("news", 0)), int(totals.get("news", 0))]


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
		var detail: bool = row[2]
		var size := DETAIL_SIZE if detail else ROW_SIZE
		var tone := ComicStyle.PLUM if detail else ComicStyle.INK
		var name_label := ComicStyle.label(row[0], ComicStyle.LABEL, size, tone)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var value_label := ComicStyle.label(row[1], ComicStyle.LABEL, size, tone)
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
	tw.chain().tween_property(stamp, "scale", Vector2.ONE, SLAM_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
