extends CanvasLayer
class_name ObjectiveHud

## The goal card for a street side job (StreetObjective): what to do, how long is
## left, and — for jobs with a count — how it is going, in one comic card tucked
## under the ART badge in the top-right corner.
##
## Why there: the HP orbs own the top-left (to x 544, y 118), the score/combo/power-up
## column owns the centre, and the ART badge the top-right down to y ~171. The strip
## under the badge is the one HUD spot no other piece uses. RIGHT_EDGE keeps the card
## clear of the ~40 px the CRT bezel hides on every screen edge.
##
## Drawn, not built from Controls: it is one small card that animates as a whole
## (slide in, punch on change, stamp + slide out), and the score HUD's lesson holds —
## overlapping tweens on Control properties leave labels stuck mid-scale.

## Under the HUD (score 1, UI 2 share its layer) and the callout banner (3).
const LAYER := 2
## Card box in the 1280x800 design space (canvas_items stretch keeps it).
const SIZE := Vector2(340, 98)
const RIGHT_EDGE := 1226.0
const TOP := 182.0
## Slide-in distance and time; the stamp's hold before the card leaves.
const SLIDE_PX := 380.0
const SLIDE_IN_S := 0.32
const STAMP_HOLD_S := 1.6
## Seconds a status change punches the card for.
const PUNCH_S := 0.22
## Timer bar turns red, and the card starts to throb, under this fraction left.
const URGENT := 0.3

const TITLE_PX := 34
const STATUS_PX := 40
const STAMP_PX := 40

var title: String = ""
var status: String = ""
## Pips: `pip_total` slots, the first `pip_filled` of them marked (tickets landed).
var pip_total: int = 0
var pip_filled: int = 0
## -1 / +1: the target is off that side of the screen (arrow on the card); 0 none.
var arrow: int = 0
var time_frac: float = 1.0
var accent: Color = ComicStyle.RED
## "" while the job runs; the stamp word once it has ended.
var stamp: String = ""
var stamp_ok: bool = true

var _card: Control
var _slide: float = 1.0  # 1 = off to the right, 0 = in place
var _punch: float = 0.0
var _age: float = 0.0


func _init() -> void:
	name = "ObjectiveHud"
	layer = LAYER


func _ready() -> void:
	_card = Control.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size = SIZE
	_card.pivot_offset = SIZE * 0.5
	# Cut scenes fade the HUD by group; the card goes with it.
	_card.add_to_group(HudFade.CINEMATIC)
	_card.draw.connect(_draw_card)
	add_child(_card)
	_place()


## Slide the card in with `goal` as its title.
func open(goal: String, tint: Color = ComicStyle.RED) -> void:
	title = goal
	accent = tint
	stamp = ""
	visible = true
	_slide = 1.0
	var tw := create_tween()
	tw.tween_property(self, "_slide", 0.0, SLIDE_IN_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card.queue_redraw()


func set_status(text: String) -> void:
	if text != status:
		status = text
		_punch = 1.0


func set_pips(total: int, filled: int) -> void:
	if filled != pip_filled and total == pip_total:
		_punch = 1.0
	pip_total = total
	pip_filled = filled


func set_time(frac: float) -> void:
	time_frac = clampf(frac, 0.0, 1.0)


func set_arrow(dir: int) -> void:
	arrow = signi(dir)


## Stamp the outcome over the card, hold it, then slide out and free.
func close(ok: bool, word: String) -> void:
	stamp = word
	stamp_ok = ok
	# The clock and arrow are over: a stale "9" beside the stamp read as time left.
	status = ""
	arrow = 0
	_punch = 1.0
	var tw := create_tween()
	tw.tween_interval(STAMP_HOLD_S)
	tw.tween_property(self, "_slide", 1.0, SLIDE_IN_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## Close at once, no stamp (the player died: the death beat owns the screen).
func dismiss() -> void:
	queue_free()


func _process(delta: float) -> void:
	_age += delta
	_punch = maxf(_punch - delta / PUNCH_S, 0.0)
	_place()
	_card.queue_redraw()


func _place() -> void:
	if _card == null:
		return
	_card.position = Vector2(RIGHT_EDGE - SIZE.x + _slide * SLIDE_PX, TOP)
	var throb := 0.0
	if stamp == "" and time_frac < URGENT:
		throb = 0.03 * absf(sin(_age * 9.0))
	_card.scale = Vector2.ONE * (1.0 + 0.12 * _punch + throb)
	_card.rotation = deg_to_rad(-1.5)


static func urgent(frac: float) -> bool:
	return frac < URGENT


func _draw_card() -> void:
	var c := _card
	var r := Rect2(Vector2.ZERO, SIZE)
	c.draw_style_box(ComicStyle.box(ComicStyle.CREAM, 4, 10, 5), r)
	# Accent tab down the left edge: the job's colour, so two jobs never read alike.
	c.draw_rect(Rect2(6, 6, 10, SIZE.y - 12), accent)
	var font: Font = ComicStyle.LABEL
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX).x
	var x0 := 26.0
	if arrow < 0:
		_draw_arrow(c, Vector2(x0 + 10, 29), -1)
		x0 += 26.0
	c.draw_string(font, Vector2(x0, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX, ComicStyle.INK)
	if arrow > 0:
		_draw_arrow(c, Vector2(minf(x0 + title_w + 18, SIZE.x - 18), 30), 1)
	var row_y := 74.0
	var sx := 26.0
	for i in pip_total:
		_draw_pip(c, Vector2(sx + i * 40, row_y - 24), i < pip_filled)
	if status != "":
		# Right-aligned and big: the clock is what the eye comes back to the card for.
		# Tucked under the arrow at the left it read as part of the arrow.
		var num: Font = ComicStyle.DISPLAY
		var w := num.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_PX).x
		var at := Vector2(SIZE.x - 20.0 - w, row_y + 2.0)
		c.draw_string_outline(num, at, status, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_PX, 7, ComicStyle.INK)
		c.draw_string(num, at, status, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_PX, ComicStyle.RED if urgent(time_frac) else accent)
	# Time left drains along the bottom edge, inside the ink border.
	var bar := Rect2(22, SIZE.y - 17, SIZE.x - 34, 9)
	c.draw_rect(bar, Color(ComicStyle.INK, 0.25))
	var fill := bar
	fill.size.x *= time_frac
	c.draw_rect(fill, ComicStyle.RED if urgent(time_frac) else ComicStyle.YELLOW)
	if stamp != "":
		_draw_stamp(c)


func _draw_arrow(c: Control, at: Vector2, dir: int) -> void:
	# Bobs toward the target, so it reads as "that way", not as decoration.
	var bob := 3.0 * sin(_age * 10.0) * dir
	var tip := at + Vector2(14 * dir + bob, 0)
	var pts := PackedVector2Array([tip, at + Vector2(-9 * dir + bob, -14), at + Vector2(-9 * dir + bob, 14)])
	c.draw_colored_polygon(pts, ComicStyle.RED)
	pts.append(tip)
	c.draw_polyline(pts, ComicStyle.INK, 3.0)


## A little ticket slip: white while the car is safe, red once a ticket landed.
func _draw_pip(c: Control, at: Vector2, filled: bool) -> void:
	var r := Rect2(at, Vector2(32, 25))
	c.draw_rect(r, ComicStyle.RED if filled else ComicStyle.PAPER)
	c.draw_rect(r, ComicStyle.INK, false, 3.0)
	var line := ComicStyle.PAPER if filled else Color(ComicStyle.INK, 0.35)
	c.draw_line(at + Vector2(6, 9), at + Vector2(26, 9), line, 2.5)
	c.draw_line(at + Vector2(6, 16), at + Vector2(20, 16), line, 2.5)


func _draw_stamp(c: Control) -> void:
	var font: Font = ComicStyle.DISPLAY
	var w := font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_PX).x
	var box := Rect2(SIZE.x * 0.5 - w * 0.5 - 14, SIZE.y * 0.5 - 30, w + 28, 58)
	var fill := ComicStyle.YELLOW if stamp_ok else ComicStyle.PAPER
	c.draw_set_transform(SIZE * 0.5, deg_to_rad(-6.0), Vector2.ONE)
	box.position -= SIZE * 0.5
	c.draw_style_box(ComicStyle.box(fill, 4, 6, 4), box)
	var at := Vector2(box.position.x + 14, box.position.y + 44)
	var ink := ComicStyle.RED if stamp_ok else ComicStyle.INK
	c.draw_string_outline(font, at, stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_PX, 6, ComicStyle.INK)
	c.draw_string(font, at, stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_PX, ink if stamp_ok else ComicStyle.CREAM)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
