extends Node2D
class_name DropMarker

## Floor warning for a ceiling briefcase drop: a red shadow that grows and blinks
## faster as the drop gets close, then frees itself once the briefcase has passed.

const RADIUS := Vector2(34, 9)

var warn: float = BossRules.DROP_WARN
var _t := 0.0


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_t += delta
	if _t > warn + 0.5:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / warn, 0.0, 1.0)
	# Blink rate climbs from 4 Hz to 12 Hz as the drop arrives.
	var blink := 0.55 + 0.45 * sin(_t * TAU * lerpf(4.0, 12.0, k))
	var r := RADIUS * lerpf(0.4, 1.0, k)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, Color(0.78, 0.13, 0.16, 0.35 + 0.4 * blink * k))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.08, 0.08, 0.08, 0.7), 2.0)
