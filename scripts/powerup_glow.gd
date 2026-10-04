class_name PowerupGlow
extends Node2D

## Halo + twinkles behind every collectible (PowerupPickup adds one itself; the heart
## scene has one authored as a child), so a pickup reads as "go get that" rather than
## as a stray decal — or, for a heart, as a HUD orb. Drawn additively in the buff
## colour. collect_burst() is the matching shared "got it" pop.
##
## No randf(): the global RNG feeds the drop rolls, and seeded autoplay runs must
## replay identically. Twinkles walk the golden angle instead.

const HALO_RADIUS := 15.0
const HALO_RINGS := 5
const HALO_ALPHA := 0.16
const PULSE_TIME := 1.4
const PULSE_SCALE := 1.25
## One twinkle every TWINKLE_EVERY seconds, each lasting TWINKLE_LIFE.
const TWINKLE_EVERY := 0.35
const TWINKLE_LIFE := 0.45
const TWINKLE_SIZE := 5.0
const TWINKLE_RADIUS := 14.0
const GOLDEN_ANGLE := 2.39996
const BURST_SCALE := 2.5
const BURST_TIME := 0.18

@export var color: Color = Color.WHITE
var _t: float = 0.0


func _init(tint: Color = Color.WHITE) -> void:
	name = "Glow"
	color = tint


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	# Behind the pickup sprite (same z, earlier sibling draws first).
	get_parent().move_child.call_deferred(self, 0)


## Shared collect pop: the sprite swells while the whole pickup (sprite + glow) fades.
static func collect_burst(pickup: Node2D, sprite: Node2D) -> Tween:
	sprite.visible = true
	var burst := pickup.create_tween().set_parallel()
	burst.tween_property(sprite, "scale", sprite.scale * BURST_SCALE, BURST_TIME)
	burst.tween_property(pickup, "modulate:a", 0.0, BURST_TIME)
	return burst


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## 0..1 halo breath, smooth at both ends.
func pulse() -> float:
	return 0.5 - 0.5 * cos(TAU * _t / PULSE_TIME)


func _draw() -> void:
	var r := HALO_RADIUS * lerpf(1.0, PULSE_SCALE, pulse())
	for i in HALO_RINGS:
		var f := float(i + 1) / HALO_RINGS
		draw_circle(Vector2.ZERO, r * f, Color(color, HALO_ALPHA * (1.0 - f * 0.5)))
	# The two newest twinkles, each fading out over its life.
	var n := int(_t / TWINKLE_EVERY)
	for k in 2:
		var idx := n - k
		var age := _t - idx * TWINKLE_EVERY
		if idx < 0 or age > TWINKLE_LIFE:
			continue
		var a := 1.0 - age / TWINKLE_LIFE
		var at := Vector2.from_angle(idx * GOLDEN_ANGLE) * TWINKLE_RADIUS * (0.6 + 0.4 * fmod(idx * 0.618, 1.0))
		var s := TWINKLE_SIZE * a
		var c := Color(Color.WHITE.lerp(color, 0.3), a)
		draw_line(at - Vector2(s, 0), at + Vector2(s, 0), c, 1.0)
		draw_line(at - Vector2(0, s), at + Vector2(0, s), c, 1.0)
