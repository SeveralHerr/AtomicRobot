extends Node2D
class_name KeysProp

## A customer's car keys: the loot in a SnatchChase. Drawn, not a texture (no new art
## asset to ship or audit): a ring with a brass and a steel key, inked like the
## game's sprites, inside the same PowerupGlow every pickup wears (skills/godot-pickup-fx)
## so it reads as "something to get" from across the street.

const BRASS := Color("FFC72C")
const STEEL := Color("C9D3DC")
const INK := Color("141414")
## Height of the keys' centre above the floor line they lie on (world px).
const LIFT := 8.0

var _glow: PowerupGlow
## Gentle sway so it glints while it lies there or bobs over the thief's head.
var _t: float = 0.0


func _ready() -> void:
	_glow = PowerupGlow.new(BRASS)
	# A parent draws before its children: without this the additive halo washed the keys.
	_glow.show_behind_parent = true
	add_child(_glow)
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	rotation = 0.18 * sin(_t * 5.0)
	queue_redraw()


## Pop + sparkle, then free (the keys went home).
func collect() -> void:
	set_process(false)
	await PowerupGlow.collect_burst(self, self).finished
	queue_free()


func _draw() -> void:
	# Ring.
	draw_arc(Vector2(-3, -4), 4.0, 0.0, TAU, 16, INK, 3.0)
	draw_arc(Vector2(-3, -4), 4.0, 0.0, TAU, 16, STEEL, 1.4)
	_key(Vector2(-1, -1), 0.5, BRASS)
	_key(Vector2(-4, 0), 1.6, STEEL)


## One key hanging off the ring: bow, shaft and two teeth, ink outline first.
func _key(at: Vector2, angle: float, fill: Color) -> void:
	draw_set_transform(at, angle, Vector2.ONE)
	var shaft := Rect2(2, -1.5, 9, 3)
	var bow := Vector2(1, 0)
	draw_circle(bow, 3.4, INK)
	draw_rect(shaft.grow(1.0), INK)
	draw_rect(Rect2(8, 1, 2, 3).grow(1.0), INK)
	draw_rect(Rect2(5, 1, 2, 2).grow(1.0), INK)
	draw_circle(bow, 2.4, fill)
	draw_rect(shaft, fill)
	draw_rect(Rect2(8, 1, 2, 3), fill)
	draw_rect(Rect2(5, 1, 2, 2), fill)
	draw_circle(bow, 0.9, INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
