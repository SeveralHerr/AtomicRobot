class_name ComicStyle
extends RefCounted

## The comic-card look shared with atomic-pinball (src/ui/screens.js, styles.css) so
## both games on the cabinet end a run the same way: white card, thick ink border,
## hard offset shadow, slight tilt; Komika for headings/letters/numbers, Bangers for
## labels.

const DISPLAY: FontFile = preload("res://styles/KomikaTitlePaint-D3x.ttf")
const LABEL: FontFile = preload("res://styles/Bangers-Regular.ttf")

const INK := Color("141414")
const YELLOW := Color("FFC72C")
const ORANGE := Color("F2762E")
const RED := Color("C8202A")
const PLUM := Color("8A3A6A")
const BLUE := Color("2A5B9E")
const CREAM := Color("FFF4DC")
const PAPER := Color("FFFFFF")
const DIM := Color(0.08, 0.08, 0.08, 0.5)

## Rank letter -> stamp tone, as pinball's RANK_TONES.
const RANK_TONES := {"S": YELLOW, "A": ORANGE, "B": RED, "C": PLUM, "D": BLUE}

## Touch targets in the 1280x800 design space. canvas_items stretch scales the canvas
## ~0.5x on a landscape phone, so 88px lands at ~44pt, the comfortable-tap minimum.
const TOUCH := Vector2(104, 88)


## Flat box: `fill`, ink border, optional hard shadow drawn by a StyleBoxFlat shadow
## with zero blur (shadow_size 1 is the smallest Godot draws; it reads as hard).
static func box(fill: Color, border: int = 3, radius: int = 8, shadow: int = 3) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.set_border_width_all(border)
	b.border_color = INK
	b.set_corner_radius_all(radius)
	if shadow > 0:
		b.shadow_color = INK
		b.shadow_size = 1
		b.shadow_offset = Vector2(shadow, shadow)
	return b


static func label(text: String, font: Font, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Heading with an ink stroke, like pinball's -webkit-text-stroke titles.
static func heading(text: String, size: int, color: Color = RED) -> Label:
	var l := label(text, DISPLAY, size, color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 6)
	return l


## Comic button: white card, ink border; focused/selected turns yellow so a pad
## player always sees where A will land.
static func button(text: String, size: int = 34) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = TOUCH
	b.add_theme_font_override("font", LABEL)
	b.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.35))
	var normal := box(PAPER)
	normal.set_content_margin_all(10)
	var lit := box(YELLOW, 4)
	lit.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("disabled", normal)
	# Button draws the focus box over the normal one and under the text, so a filled
	# yellow focus box reads as the whole button lighting up.
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", lit)
	return b


## 1650000 -> "1,650,000" (pinball's formatScore).
static func format_score(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## Placement badge text, or "" when the run did not make the list.
static func badge_text(slot: int) -> String:
	if slot < 0:
		return ""
	return "NEW HIGH SCORE!" if slot == 0 else "YOU PLACED #%d!" % (slot + 1)
