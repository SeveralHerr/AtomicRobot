class_name ArrowButton
extends Button

## Touch button that draws a triangle instead of a "▲" glyph: neither card font has
## arrow characters and the web build has no system font to fall back on (see
## test_font_glyph_coverage.gd).

var up: bool = true
## Drawn red when this arrow's letter is the selected one, so the stick's up/down
## visibly belongs to that column.
var active: bool = false:
	set(value):
		if value != active:
			active = value
			queue_redraw()


func _init(points_up: bool = true) -> void:
	up = points_up
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = ComicStyle.TOUCH
	var rest := StyleBoxEmpty.new()
	var down := ComicStyle.box(ComicStyle.YELLOW, 3, 8, 0)
	for state in ["normal", "hover", "disabled", "focus"]:
		add_theme_stylebox_override(state, rest)
	add_theme_stylebox_override("pressed", down)


func _draw() -> void:
	var c := size * 0.5
	var w := minf(size.x, size.y) * 0.7
	var h := w * 0.75 * (1.0 if up else -1.0)
	var tri := PackedVector2Array([
		c + Vector2(0, -h * 0.5), c + Vector2(w * 0.5, h * 0.5), c + Vector2(-w * 0.5, h * 0.5)])
	draw_colored_polygon(tri, ComicStyle.RED if active else ComicStyle.INK)
