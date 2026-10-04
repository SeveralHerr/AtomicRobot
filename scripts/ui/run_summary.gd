class_name RunSummary
extends VBoxContainer

## The end card's left column (scripts/ui/end_card.gd): GAME OVER / YOU WIN!, the rank
## stamp beside FINAL SCORE and the clear's breakdown, and the placement badge.
## Split out of EndCard so the card file stays about flow (show, initials, buttons)
## and this one about what the run scored.

const STAMP_TILT := -12.0
const BADGE_TILT := 2.5
const SLAM_SECONDS := 0.52
const STAMP_SIZE := 118.0

var title: Label
var rank_row: Control
var stamp: PanelContainer
var stamp_label: Label
var score_label: Label
var breakdown: Label
var badge_holder: Control
var badge_label: Label


func _init() -> void:
	custom_minimum_size.x = 400
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)
	title = ComicStyle.heading("GAME OVER", 58)
	add_child(title)

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
	breakdown = ComicStyle.label("", ComicStyle.LABEL, 29)
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
	breakdown.text = breakdown_text(run)
	breakdown.visible = breakdown.text != ""
	badge_label.text = ComicStyle.badge_text(int(run.get("slot", -1)))
	badge_holder.visible = badge_label.text != ""
	if rank_row.visible:
		_slam()


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


## Pinball's stamp slam: in from big, tilted and transparent, overshoot, settle.
func _slam() -> void:
	stamp.scale = Vector2.ONE * 2.6
	stamp.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(stamp, "scale", Vector2.ONE * 0.92, SLAM_SECONDS * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(stamp, "modulate:a", 1.0, SLAM_SECONDS * 0.4)
	tw.chain().tween_property(stamp, "scale", Vector2.ONE, SLAM_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
