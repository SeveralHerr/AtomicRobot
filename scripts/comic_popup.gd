extends Node2D
class_name ComicPopup

## Comic-book action word ("POW!", "BAM!", "KO!") that pops over a hit and fades.
##
## Ported from atomic-pinball's juice layer (src/juice/curves.js, anim.js, recipes.js
## and renderer/fx/paint.js paintWord): an ink-shadowed starburst with a highlight
## burst inside, the word in Komika Title Paint with a fat ink outline and a hard
## offset shadow, popped in with an overshoot "boing",
## a small random tilt, then a quick fade.
##
## Readability rules carried over from pinball:
##   * ONE word on screen at a time â€” a new word retires the live one (0.12s fade),
##     so stacked words never overprint each other or the fighters.
##   * Per-kind cooldowns, so mash-hitting doesn't spam a word every swing.
##   * Placement is clamped inside the camera view and kept below the HUD band.
##
## Usage (no autoload): `ComicPopup.spawn(some_node_in_tree, world_pos, &"hit")`.
## The popup is parented to the current scene, not the anchor, so it outlives a
## corpse being freed and does not ride an enemy's knockback.

## Brand palette (pinball core/config.js PALETTE).
const INK := Color("#141414")
const RED := Color("#C8202A")
const YELLOW := Color("#FFC72C")
const CREAM := Color("#FFF4DC")

## Starburst fill / inner highlight / text colour per style (pinball paint.js STYLES).
const STYLES := {
	&"yellow": [Color("#FFC72C"), Color("#FFE27A"), Color("#C8202A")],
	&"orange": [Color("#F2762E"), Color("#FFA766"), Color("#FFF4DC")],
	&"blue": [Color("#3D86D6"), Color("#8CC6FF"), Color("#FFF4DC")],
	&"cream": [Color("#FFF4DC"), Color("#FFFFFF"), Color("#C8202A")],
	&"gold": [Color("#FFB81C"), Color("#FFF0A0"), Color("#C8202A")],
	&"red": [Color("#C8202A"), Color("#F2762E"), Color("#FFF4DC")],
}

## Word pools and feel per event kind. `cooldown` is real seconds between two words
## of that kind; `life` is how long the word stays; `size` scales the whole card;
## `from` is the pop-in start scale (default 0.35). Combat words start big because a
## hitstop freezes their first frame on screen; above 1 the card slams DOWN into place.
## hit / finisher / ko are picked per blow by HitWords (one rising word per string).
const KINDS := {
	# The opening cut scene: slapped on the red car as AROUND THE CLOCK! lands.
	&"ticket": {
		"words": ["TICKET!"],
		"style": &"cream", "anim": &"pop", "cooldown": 0.0, "life": 1.4, "size": 1.1,
		"from": 1.4,
	},
	&"hit": {
		"words": ["POW!", "BAM!", "WHAP!", "SMACK!", "BONK!"],
		"style": &"yellow", "anim": &"pop", "cooldown": 0.45, "life": 0.55, "size": 1.0,
		"from": 0.6,
	},
	&"finisher": {
		"words": ["WHAM!", "KA-POW!", "THWACK!", "KRAK!"],
		"style": &"orange", "anim": &"pop", "cooldown": 0.0, "life": 0.65, "size": 1.25,
		"from": 0.9,
	},
	&"ko": {
		"words": ["KO!"],
		"style": &"red", "anim": &"pop", "cooldown": 0.0, "life": 0.75, "size": 1.3,
		"from": 1.1, "exit": &"shrink",
	},
	&"boss_hit": {
		"words": ["KRAK!", "BOOM!", "WHAM!", "THWACK!"],
		"style": &"orange", "anim": &"pop", "cooldown": 0.45, "life": 0.6, "size": 1.15,
		"from": 0.6,
	},
	&"hurt": {
		"words": ["OOF!", "OUCH!", "ACK!"],
		"style": &"cream", "anim": &"float", "cooldown": 0.6, "life": 0.6, "size": 0.85,
	},
	# Orange, not blue: blue vanished into the grey-blue brick it pops over.
	&"smash": {
		"words": ["CRASH!", "SMASH!", "KRSSH!"],
		"style": &"orange", "anim": &"pop", "cooldown": 0.3, "life": 0.7, "size": 0.8,
		"exit": &"shrink",
	},
	# Street side jobs (StreetObjective): the payoff word over the spot it was won...
	&"job": {
		"words": ["NICE!"],
		"style": &"gold", "anim": &"pop", "cooldown": 0.0, "life": 1.2, "size": 1.2,
		"from": 1.2, "exit": &"shrink",
	},
	# ...and the thief's grab, cream like TICKET!: a maid's doing, not the player's.
	&"snatch": {
		"words": ["YOINK!"],
		"style": &"cream", "anim": &"pop", "cooldown": 0.0, "life": 0.9, "size": 1.0,
		"from": 1.2,
	},
	&"secret": {
		"words": ["SECRET!"],
		"style": &"gold", "anim": &"pop", "cooldown": 0.0, "life": 1.4, "size": 1.35,
		"exit": &"shrink",
	},
}

const FONT := preload("res://styles/KomikaTitlePaint-D3x.ttf")

## Card size in local units. Drawn big and scaled down by BASE_SCALE so the text is
## rasterised near screen resolution under the 2.5x gameplay camera (crisp, not blurry).
const CARD_W := 220.0
const CARD_H := 110.0
const BASE_SCALE := 0.4
const SPIKES := 14
## How far above the anchor point the card centre sits (world px, before clamping).
const LIFT := 14.0
## Horizontal jitter so repeat words don't land on exactly the same spot (world px).
const JITTER_X := 8.0
## Fraction of the camera view kept clear at the top for the score/health HUD.
const HUD_BAND := 0.16
## Fade-out at the end of life, and the faster fade used when retired by a new word.
const FADE := 0.25
const RETIRE_FADE := 0.12
## A re-punched word (HitWords "bump") restarts its pop from this scale and grows
## by BUMP_GROW per punch, up to BUMP_MAX x its kind's size.
const BUMP_FROM := 0.75
const BUMP_GROW := 1.1
const BUMP_MAX := 1.25

static var _last_spawn_ms: Dictionary = {}
static var _live: WeakRef = null

var word: String = ""
var kind: StringName = &""
var style: StringName = &"yellow"
var anim: StringName = &"pop"
## How the word leaves: &"fade" (alpha) or &"shrink" (scales away at full opacity â€”
## for words over busy brick, where a half-faded card turns to mud).
var exit: StringName = &"fade"
var life: float = 0.55
var size_mult: float = 1.0
var pop_from: float = 0.35
var age: float = 0.0
var tilt: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO
var _seed: int = 1


## Spawns a word for `kind` at `world_pos`, unless that kind is cooling down.
## `anchor` is any node already in the tree (used to find the scene and viewport).
## Pass `text` to force a specific word instead of picking from the pool.
## Returns the popup, or null when rate-limited / not in a tree / unknown kind.
static func spawn(anchor: Node, world_pos: Vector2, kind: StringName, text: String = "") -> ComicPopup:
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return null
	if not KINDS.has(kind) or not try_acquire(kind):
		return null
	var cfg: Dictionary = KINDS[kind]
	var popup := ComicPopup.new()
	popup.word = text if text != "" else pick_word(kind)
	popup.kind = kind
	popup.pop_from = cfg.get("from", 0.35)
	popup.style = cfg["style"]
	popup.anim = cfg["anim"]
	popup.exit = cfg.get("exit", &"fade")
	popup.life = cfg["life"]
	popup.size_mult = cfg["size"]
	popup.tilt = randf_range(-0.15, 0.15)
	popup._seed = hash(popup.word) | 1
	var tree := anchor.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	_retire_live()
	parent.add_child(popup)
	popup._base_pos = popup.clamp_to_view(world_pos + Vector2(randf_range(-JITTER_X, JITTER_X), -LIFT))
	popup.global_position = popup._base_pos
	_live = weakref(popup)
	return popup


## A random word from `kind`'s pool ("" for an unknown kind).
static func pick_word(kind: StringName) -> String:
	if not KINDS.has(kind):
		return ""
	var words: Array = KINDS[kind]["words"]
	return words[randi() % words.size()]


## True (and stamps the time) when `kind` has not fired within its cooldown.
static func try_acquire(kind: StringName, now_ms: int = -1) -> bool:
	if now_ms < 0:
		# Game clock, not wall clock: matches real time whenever physics keeps up (it
		# only lags below ~7 fps), and is deterministic under --fixed-fps, so seeded
		# autoplay runs replay exactly.
		now_ms = int(Engine.get_physics_frames() * 1000.0 / Engine.physics_ticks_per_second)
	var gap_ms := int(float(KINDS.get(kind, {}).get("cooldown", 0.0)) * 1000.0)
	if _last_spawn_ms.has(kind) and now_ms - int(_last_spawn_ms[kind]) < gap_ms:
		return false
	_last_spawn_ms[kind] = now_ms
	return true


## Forgets all cooldowns (tests, scene restarts).
static func reset_rate_limits() -> void:
	_last_spawn_ms.clear()
	_live = null


## The popup currently on screen, if any.
static func live() -> ComicPopup:
	if _live == null:
		return null
	var p: Variant = _live.get_ref()
	return p as ComicPopup if is_instance_valid(p) else null


static func _retire_live() -> void:
	var p := live()
	if p != null:
		p.retire()


# --- curves (pinball src/juice/curves.js) -------------------------------------

## Ease-out with overshoot: the comic "boing". Lands on 1 at k = 1.
static func ease_out_back(k: float, s: float = 1.70158) -> float:
	var x := clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + (s + 1.0) * x * x * x + s * x * x


## Pop-in scale: from `from` up past 1, settling on 1 within `dur` seconds.
static func pop_scale(t: float, dur: float = 0.18, from: float = 0.35) -> float:
	return from + (1.0 - from) * ease_out_back(t / dur, 2.4)


## Alpha that holds at 1 and fades over the last `fade` seconds of `total`.
static func fade_alpha(t: float, total: float, fade: float = FADE) -> float:
	return clampf((total - t) / fade, 0.0, 1.0)


# --- instance -----------------------------------------------------------------

func _ready() -> void:
	z_as_relative = false
	z_index = 4000
	_apply(0.0)


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	_apply(age)


## Shrinks this word away quickly (a newer word is taking the stage). Shrink, not
## fade: a half-faded card behind the new one read as a muddy double word.
func retire() -> void:
	life = minf(life, age + RETIRE_FADE)
	exit = &"shrink"


## Re-punches this word for another blow of the same weight: pops it again from
## BUMP_FROM, a notch bigger, tilted the other way, over `world_pos` — one word that
## rides the string instead of a new card per swing.
func restrike(world_pos: Vector2) -> void:
	var cfg: Dictionary = KINDS.get(kind, {})
	var base := float(cfg.get("size", size_mult))
	size_mult = minf(size_mult * BUMP_GROW, base * BUMP_MAX)
	life = float(cfg.get("life", life))
	age = 0.0
	pop_from = BUMP_FROM
	tilt = -tilt
	_base_pos = clamp_to_view(world_pos)
	_apply(0.0)


## Sets scale / rotation / offset / alpha for time `t`.
func _apply(t: float) -> void:
	var s := 1.0
	var rise := 0.0
	match anim:
		&"float":
			s = pop_scale(t, 0.2, 0.2)
			rise = 10.0 * (1.0 - pow(1.0 - clampf(t / 0.7, 0.0, 1.0), 3.0))
		_:
			s = pop_scale(t, 0.18, pop_from)
	var out := fade_alpha(t, life, minf(FADE, life))
	if exit == &"shrink":
		s *= out
		out = 1.0
	scale = Vector2.ONE * s * BASE_SCALE * size_mult
	rotation = tilt
	global_position = _base_pos - Vector2(0.0, rise)
	modulate.a = out


## Keeps the card (at rest size) inside the camera view and below the HUD band.
func clamp_to_view(p: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return p
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var half := Vector2(CARD_W, CARD_H) * 0.5 * BASE_SCALE * size_mult * 1.1
	var top := view.position.y + view.size.y * HUD_BAND + half.y
	var bottom := view.end.y - half.y
	var left := view.position.x + half.x
	var right := view.end.x - half.x
	if left > right or top > bottom:
		return p
	return Vector2(clampf(p.x, left, right), clampf(p.y, top, bottom))


func _draw() -> void:
	var c: Array = STYLES.get(style, STYLES[&"yellow"])
	var ink := maxf(4.0, CARD_H * 0.045)
	var rx := CARD_W * 0.47
	var ry := CARD_H * 0.46
	var outer := starburst(SPIKES, Vector2.ZERO, rx, ry, _seed)
	draw_colored_polygon(_offset(outer, Vector2(ink, ink)), INK)
	draw_colored_polygon(outer, c[0])
	var ring := outer.duplicate()
	ring.append(outer[0])
	draw_polyline(ring, INK, ink, true)
	draw_colored_polygon(starburst(SPIKES, Vector2.ZERO, CARD_W * 0.36, CARD_H * 0.33, _seed ^ 0x55), c[1])
	_draw_word(c[2])


func _draw_word(fill: Color) -> void:
	var px := fit_font_px(word, CARD_W * 0.68, int(CARD_H * 0.5))
	var w := CARD_W
	var base_y := FONT.get_ascent(px) - FONT.get_height(px) * 0.5
	var pos := Vector2(-w * 0.5, base_y)
	var outline := maxi(6, int(px * 0.3))
	var shadow := Vector2.ONE * maxf(3.0, px * 0.07)
	draw_string_outline(FONT, pos + shadow, word, HORIZONTAL_ALIGNMENT_CENTER, w, px, outline, INK)
	draw_string(FONT, pos + shadow, word, HORIZONTAL_ALIGNMENT_CENTER, w, px, INK)
	draw_string_outline(FONT, pos, word, HORIZONTAL_ALIGNMENT_CENTER, w, px, outline, INK)
	draw_string(FONT, pos, word, HORIZONTAL_ALIGNMENT_CENTER, w, px, fill)


## Largest font size <= max_px whose `text` fits `max_w`.
static func fit_font_px(text: String, max_w: float, max_px: int, min_px: int = 8) -> int:
	var px := max_px
	while px > min_px and FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
		px -= 2
	return px


## Starburst outline: `n` spikes alternating outer/inner radius with deterministic
## jitter from `rng_seed` (same LCG as pinball paint.js, so a word keeps its shape).
static func starburst(n: int, center: Vector2, rx: float, ry: float, rng_seed: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var h := rng_seed if rng_seed != 0 else 1
	for i in n * 2:
		h = (h * 1664525 + 1013904223) & 0xFFFFFFFF
		var j := float(h) / 4294967296.0
		var k := (0.9 + 0.1 * j) if i % 2 == 0 else (0.62 + 0.1 * j)
		var a := float(i) / float(n * 2) * TAU - PI * 0.5
		out.append(center + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return out


static func _offset(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out
