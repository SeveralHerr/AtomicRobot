extends Control
class_name BossBanner

## The boss fight's big text, comic-book style: a slanted ink-edged stripe sweeps
## across the screen and a tilted, ink-outlined title SLAMS onto it with a subtitle
## skidding in under it; "FIGHT!" bursts out of a spinning starburst instead; the
## boss's lines pop up in a speech bubble over his head and type out with blips.
## Replaces the old plain fade-in labels (BossIntroContainer) — one text layer, not two.

## Emitted the frame a title lands, so the room can shake the screen / thud on it.
signal landed

const STRIPE_H := 150.0
## Stripe centre as a fraction of screen height — above the fighters, below the HUD.
const STRIPE_Y := 0.42

const TITLE_PX := 112
const SUB_PX := 48

## Per-banner stripe height (fraction of screen). Street encounters raise it: the
## boss room's fighters stand lower than a street squad on the walkway lane.
var stripe_y: float = STRIPE_Y
## Scales the whole callout (stripe, title, subtitle, starburst). The boss room's
## full size is a set piece; a street callout must not bury the HUD or the squad.
var size_k: float = 1.0:
	set(k):
		size_k = k
		_title.add_theme_font_size_override("font_size", int(TITLE_PX * k))
		_sub.add_theme_font_size_override("font_size", int(SUB_PX * k))
const SLANT := 46.0
const BLIP := preload("res://sounds/tap.wav")

var _stripe: float = 0.0  # 0..1 sweeping in, 1..2 sweeping out
var _stripe_color: Color = ComicStyle.RED
var _burst: float = 0.0
var _burst_spin: float = 0.0
var _title: Label
var _sub: Label
var _sub_tag: PanelContainer
var _bubble: PanelContainer
var _bubble_text: Label
var _speaker: Node2D
## Bumped per slam_title(): a slam that is overtaken (the finale landing mid phase
## banner) must not run its clear-out over the newer title.
var _gen: int = 0
var _blip: AudioStreamPlayer


func _init() -> void:
	name = "BossBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_title = ComicStyle.heading("", TITLE_PX, ComicStyle.YELLOW)
	_title.add_theme_constant_override("outline_size", 16)
	_title.add_theme_color_override("font_shadow_color", ComicStyle.INK)
	_title.add_theme_constant_override("shadow_offset_x", 7)
	_title.add_theme_constant_override("shadow_offset_y", 7)
	_title.modulate.a = 0.0
	add_child(_title)
	# Subtitle: yellow on an ink tag, so it reads on the white wall under the stripe.
	_sub_tag = PanelContainer.new()
	_sub_tag.add_theme_stylebox_override("panel", ComicStyle.box(ComicStyle.INK, 0, 4, 4))
	_sub_tag.modulate.a = 0.0
	add_child(_sub_tag)
	_sub = ComicStyle.label("", ComicStyle.LABEL, SUB_PX, ComicStyle.YELLOW)
	_sub_tag.add_child(_sub)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", ComicStyle.box(ComicStyle.CREAM, 4, 18, 5))
	_bubble.visible = false
	add_child(_bubble)
	_bubble_text = ComicStyle.label("", ComicStyle.LABEL, 38, ComicStyle.INK)
	_bubble.add_child(_bubble_text)
	_blip = AudioStreamPlayer.new()
	_blip.stream = BLIP
	_blip.volume_db = -14.0
	add_child(_blip)


func _process(delta: float) -> void:
	_burst_spin += delta * 0.6
	if _bubble.visible and is_instance_valid(_speaker):
		_place_bubble()
	if _stripe > 0.0 or _burst > 0.0 or _bubble.visible:
		queue_redraw()


# --- Titles ----------------------------------------------------------------------

## Slam `text` (with optional `sub` under it) onto a stripe, hold, then clear.
## `burst`: a starburst instead of the stripe (for "FIGHT!").
func slam_title(text: String, sub: String = "", hold: float = 1.0, tint: Color = ComicStyle.RED, burst: bool = false) -> void:
	_gen += 1
	var gen := _gen
	_set_stripe(0.0)
	_set_burst(0.0)
	_title.text = text
	_title.reset_size()
	var centre := Vector2(size.x * 0.5, size.y * stripe_y)
	_title.position = centre - _title.size * 0.5
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2.ONE * 3.2
	_title.rotation_degrees = -16.0
	_title.modulate.a = 0.0
	_stripe_color = tint
	var tw := _tw().set_parallel(true)
	if burst:
		tw.tween_method(_set_burst, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_method(_set_stripe, 0.0, 1.0, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.06)
	tw.tween_property(_title, "rotation_degrees", -4.0, 0.26).set_delay(0.06)
	tw.tween_property(_title, "modulate:a", 1.0, 0.1).set_delay(0.06)
	await tw.finished
	if gen != _gen:
		return
	landed.emit()
	if sub != "":
		_sub.text = sub
		_sub_tag.reset_size()
		var home := Vector2(centre.x - _sub_tag.size.x * 0.5 + 70.0, centre.y + STRIPE_H * size_k * 0.5 - 4.0)
		_sub_tag.position = home + Vector2(size.x * 0.6, 0.0)
		_sub_tag.rotation_degrees = -3.0
		_sub_tag.modulate.a = 1.0
		_tw().tween_property(_sub_tag, "position", home, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A slow push-in while it holds keeps the title alive.
	_tw().tween_property(_title, "scale", Vector2.ONE * 1.06, hold)
	await _wait(hold).timeout
	if gen == _gen:
		await clear_title()


func clear_title() -> void:
	var tw := _tw().set_parallel(true)
	tw.tween_property(_title, "scale", _title.scale * 1.35, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_property(_title, "modulate:a", 0.0, 0.16)
	tw.tween_property(_sub_tag, "modulate:a", 0.0, 0.12)
	if _stripe > 0.0:
		tw.tween_method(_set_stripe, 1.0, 2.0, 0.2).set_ease(Tween.EASE_IN)
	if _burst > 0.0:
		tw.tween_method(_set_burst, _burst, 0.0, 0.18)
	await tw.finished
	_set_stripe(0.0)
	_set_burst(0.0)


# Setters redraw themselves: _process only redraws while something is showing, so
# the frame that reaches 0 must redraw here or its last shape sticks on screen.
func _set_stripe(k: float) -> void:
	_stripe = k
	queue_redraw()


func _set_burst(k: float) -> void:
	_burst = k
	queue_redraw()


# --- Speech bubble ---------------------------------------------------------------

## Pop a speech bubble over `speaker` and type `text` into it, hold, pop it away.
func say(text: String, speaker: Node2D, hold: float = 1.2) -> void:
	_speaker = speaker
	_bubble_text.text = text
	_bubble_text.visible_characters = 0
	_bubble.reset_size()
	_bubble.visible = true
	_place_bubble()
	_bubble.pivot_offset = Vector2(_bubble.size.x * 0.5, _bubble.size.y)
	_bubble.scale = Vector2.ZERO
	await _tw().tween_property(_bubble, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).finished
	var n := text.length()
	for i in n:
		_bubble_text.visible_characters = i + 1
		if i % 2 == 0 and text[i] != " ":
			_blip.pitch_scale = randf_range(0.8, 1.1)
			_blip.play()
		await _wait(0.03).timeout
	await _wait(hold).timeout
	await _tw().tween_property(_bubble, "scale", Vector2.ZERO, 0.12).set_ease(Tween.EASE_IN).finished
	_bubble.visible = false
	queue_redraw()  # clear the tail, which _draw paints outside the bubble


## Above the speaker's head, kept on screen.
func _place_bubble() -> void:
	var tip := _tail_tip()
	var pos := tip - Vector2(_bubble.size.x * 0.5, _bubble.size.y + 34.0)
	pos.x = clampf(pos.x, 60.0, size.x - _bubble.size.x - 60.0)
	pos.y = maxf(pos.y, 200.0)
	_bubble.position = pos


func _tail_tip() -> Vector2:
	if not is_instance_valid(_speaker):
		return Vector2(size.x * 0.5, size.y * 0.6)
	return _speaker.get_global_transform_with_canvas() * Vector2(0.0, -34.0)


## Banner motion runs on real time, so a slam during the finale's slow-mo still snaps.
func _tw() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func _wait(seconds: float) -> SceneTreeTimer:
	return get_tree().create_timer(seconds, true, false, true)


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	if _stripe > 0.0:
		_draw_stripe()
	if _burst > 0.0:
		_draw_burst(Vector2(size.x * 0.5, size.y * stripe_y))
	if _bubble.visible:
		_draw_tail()


## A slanted band that wipes in from the left and out to the right.
func _draw_stripe() -> void:
	var cy := size.y * stripe_y
	var x0 := (size.x + SLANT * 2.0) * clampf(_stripe - 1.0, 0.0, 1.0) - SLANT
	var x1 := (size.x + SLANT * 2.0) * clampf(_stripe, 0.0, 1.0) - SLANT
	var h := STRIPE_H * size_k * 0.5
	var band := PackedVector2Array([Vector2(x0 + SLANT, cy - h), Vector2(x1 + SLANT, cy - h),
		Vector2(x1 - SLANT, cy + h), Vector2(x0 - SLANT, cy + h)])
	var shadow := PackedVector2Array()
	for p in band:
		shadow.append(p + Vector2(8, 8))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_colored_polygon(band, _stripe_color)
	draw_polyline(band + PackedVector2Array([band[0]]), ComicStyle.INK, 6.0)
	# Speed lines along the band.
	for i in 3:
		var y := cy - h + 18.0 + i * 8.0
		draw_line(Vector2(x0 + SLANT, y), Vector2(x1 + SLANT * 0.6, y), Color(1, 1, 1, 0.25), 2.0)


func _draw_burst(c: Vector2) -> void:
	for layer in [[1.0, ComicStyle.RED], [0.78, ComicStyle.YELLOW]]:
		var pts := PackedVector2Array()
		var spikes := 18
		for i in spikes * 2:
			# Sized to the word, so a long one ("ADJOURNED!") still sits inside —
			# but only sideways: height is capped, or a long word grows the burst
			# up over the HUD and down over the fighters.
			var reach := maxf(300.0 * size_k, _title.size.x * 0.62)
			var k: float = (1.0 if i % 2 == 0 else 0.64) * _burst * layer[0]
			var a := TAU * i / (spikes * 2.0) + _burst_spin
			var ry := minf(reach, 360.0 * size_k) * 0.62
			pts.append(c + Vector2(cos(a) * reach * k, sin(a) * ry * k))
		draw_colored_polygon(pts, layer[1])
		draw_polyline(pts + PackedVector2Array([pts[0]]), ComicStyle.INK, 5.0)


func _draw_tail() -> void:
	var tip := _tail_tip()
	var b := _bubble.position + Vector2(_bubble.size.x * 0.5, _bubble.size.y - 4.0)
	var base_x := clampf(tip.x, _bubble.position.x + 30.0, _bubble.position.x + _bubble.size.x - 30.0)
	var k := _bubble.scale.x
	var tri := PackedVector2Array([Vector2(base_x - 16.0 * k, b.y), Vector2(base_x + 16.0 * k, b.y),
		b.lerp(tip, 1.0).lerp(Vector2(base_x, b.y), 1.0 - k)])
	draw_colored_polygon(tri, ComicStyle.CREAM)
	draw_line(tri[0], tri[2], ComicStyle.INK, 4.0)
	draw_line(tri[1], tri[2], ComicStyle.INK, 4.0)
