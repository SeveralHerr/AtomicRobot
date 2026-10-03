class_name ScoreTableView
extends VBoxContainer

## "HIGH SCORES" list in pinball's format (src/ui/score-table.js): rows read
## `1  ART  2,450,000` - plum place number, Komika initials, right-aligned comma score
## - and the run just saved is lit yellow with an ink outline, pulsing to orange.
## Empty places show dashes so the list always reads as a full top ten.
##
## Used inside the end card and on the title screen.

const PULSE_SECONDS := 0.6
const ROW_HEIGHT := 25.0

var highlight: int = -1
var _rows: Array = []      # [PanelContainer, place, initials, score] per row
var _pulse: float = 0.0
var _lit: StyleBoxFlat = ComicStyle.box(ComicStyle.YELLOW, 2, 4, 0)
var _plain: StyleBoxEmpty = StyleBoxEmpty.new()


func _init(font_size: int = 26) -> void:
	add_theme_constant_override("separation", 0)
	add_child(ComicStyle.label("HIGH SCORES", ComicStyle.LABEL, font_size + 8, ComicStyle.PLUM))
	for i in HighScoreTable.SIZE:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _plain)
		panel.custom_minimum_size.y = ROW_HEIGHT
		add_child(panel)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)
		var place := ComicStyle.label(str(i + 1), ComicStyle.LABEL, font_size + 2, ComicStyle.PLUM)
		place.custom_minimum_size.x = 30
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var ini := ComicStyle.label("", ComicStyle.DISPLAY, font_size)
		ini.custom_minimum_size.x = 90
		ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var score := ComicStyle.label("", ComicStyle.DISPLAY, font_size)
		score.custom_minimum_size.x = 170
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for l in [place, ini, score]:
			row.add_child(l)
		_rows.append([panel, place, ini, score])


## Fill from `entries` (HighScoreTable rows, best first); `lit` is the row to light.
## `show_empty` false hides unfilled places (the title card) instead of dashing them.
func show_entries(entries: Array, lit: int = -1, show_empty: bool = true) -> void:
	highlight = lit
	_pulse = 0.0
	for i in HighScoreTable.SIZE:
		var r: Array = _rows[i]
		var filled := i < entries.size()
		r[0].visible = filled or show_empty
		r[2].text = String(entries[i]["initials"]) if filled else "---"
		r[3].text = ComicStyle.format_score(int(entries[i]["score"])) if filled else "-"
		var alpha := 1.0 if filled else 0.35
		for l in [r[1], r[2], r[3]]:
			l.modulate.a = alpha
		r[0].add_theme_stylebox_override("panel", _lit if i == lit else _plain)
	show()


func _process(delta: float) -> void:
	if highlight < 0 or not is_visible_in_tree():
		return
	_pulse += delta
	var t := absf(sin(_pulse * PI / PULSE_SECONDS))
	_lit.bg_color = ComicStyle.YELLOW.lerp(ComicStyle.ORANGE, t)
