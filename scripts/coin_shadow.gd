extends Node2D
class_name CoinShadow

## A flat ellipse on a lane's floor line under an airborne coin. Lanes are only 24px
## apart, so a coin alone doesn't say which lane it is flying down; its shadow does.
## Shrinks and fades with the coin's height so a lob reads as coming down.

## World Y of the lane floor the shadow lies on.
var floor_y: float = INF

const RADIUS := 4.0
const SQUASH := 0.4
const COLOR := Color(0.0, 0.0, 0.0, 0.5)
## Height (px) at which the shadow reaches its smallest/faintest.
const FADE_HEIGHT := 120.0
const MIN_SCALE := 0.45

var _scale: float = 1.0


func _ready() -> void:
	top_level = true
	# Under the coin, which draws at its lane's z.
	z_index = -1


func _process(_delta: float) -> void:
	var coin := get_parent() as Node2D
	if coin == null or not is_finite(floor_y):
		visible = false
		return
	visible = true
	global_position = Vector2(coin.global_position.x, floor_y)
	var s := scale_for_height(floor_y - coin.global_position.y)
	if not is_equal_approx(s, _scale):
		_scale = s
		queue_redraw()


## 1.0 on the floor, down to MIN_SCALE at FADE_HEIGHT and above.
static func scale_for_height(height: float) -> float:
	var t := clampf(height / FADE_HEIGHT, 0.0, 1.0)
	return lerpf(1.0, MIN_SCALE, t)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_scale, _scale * SQUASH))
	var c := COLOR
	c.a *= _scale
	draw_circle(Vector2.ZERO, RADIUS, c)
