extends Node2D
class_name EnemyHpPips

## A tiny health bar that pops over an enemy's head when a blow lands, so a 3-4 hit
## kill shows progress. Hidden at full health; lingers a moment after the last hit,
## then fades. Notched once per blow of the current fighter's damage, so it reads as
## "N more hits" at this pixel scale. Same red-fill / lagging cream "chip" language as
## the boss's HUD bar (BossHealthBar), in miniature.
##
## World pixels (camera zoom 2.5): 20x4 is ~50x10 on screen.

const NODE_NAME := &"HpPips"
const SIZE := Vector2(20, 4)
## Bar centre relative to the enemy's origin: at her feet (a maid's soles are ~27 px
## below it). Over the head it sat under the comic hit words (spawned at -40) on the
## very frames the blow lands; down here nothing covers it.
const OFFSET := Vector2(0.0, 31.0)
## The fill snaps on a hit; the chip holds this long, then drains at CHIP_RATE (of max/s).
const CHIP_DELAY := 0.22
const CHIP_RATE := 2.2
## Seconds visible after the last hit, then the fade.
const LINGER := 1.8
const FADE := 0.3
## On a hit the bar punches up by this much scale and settles back over PUNCH_TIME.
const PUNCH := 0.45
const PUNCH_TIME := 0.15
## On the kill: the empty bar flashes white and is gone after this long.
const DEATH_FADE := 0.35

const INK := Color("1b1420")
const BACK := Color("4a2a2f")
const FILL := Color("e8413b")
const CHIP := Color("fff1c9")

var enemy: Enemy
var fill := 1.0
var chip := 1.0
var _chip_hold := 0.0
var _since_hit := 0.0
var _punch := 0.0
## Fraction of max health one of the current fighter's blows takes; 0 = no notches.
var notch := 0.0


## Show (or refresh) the bar on `e` after it took damage.
static func show_on(e: Enemy) -> EnemyHpPips:
	var bar := e.get_node_or_null(NodePath(NODE_NAME)) as EnemyHpPips
	if bar == null:
		bar = EnemyHpPips.new()
		bar.name = NODE_NAME
		bar.enemy = e
		bar.top_level = true  # immune to the maid's mirrored, scaled transform
		bar.z_as_relative = false
		bar.z_index = 100
		var cfg := Globals.get_current_character()
		if cfg != null and e.max_health > 0:
			bar.notch = float(cfg.get_starting_damage()) / float(e.max_health)
		e.add_child(bar)
	bar.hit()
	return bar


func hit() -> void:
	var f := clampf(float(enemy.health) / float(maxi(enemy.max_health, 1)), 0.0, 1.0)
	chip = maxf(chip, fill)
	fill = f
	_chip_hold = CHIP_DELAY
	_since_hit = 0.0
	_punch = PUNCH
	_follow()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(enemy):
		queue_free()
		return
	_since_hit += delta
	_punch = maxf(0.0, _punch - delta * PUNCH / PUNCH_TIME)
	if _chip_hold > 0.0:
		_chip_hold -= delta
	elif chip > fill:
		chip = maxf(fill, chip - CHIP_RATE * delta)
	modulate.a = alpha_at(_since_hit, enemy.is_dead)
	_follow()
	queue_redraw()


## Opacity `since_hit` seconds after the last blow. Pure, for tests.
static func alpha_at(since_hit: float, dead: bool) -> float:
	if dead:
		return clampf(1.0 - since_hit / DEATH_FADE, 0.0, 1.0)
	if since_hit <= LINGER:
		return 1.0
	return clampf(1.0 - (since_hit - LINGER) / FADE, 0.0, 1.0)


func _follow() -> void:
	global_position = enemy.global_position + OFFSET
	scale = Vector2.ONE * (1.0 + _punch)


func _draw() -> void:
	var r := Rect2(-SIZE / 2.0, SIZE)
	draw_rect(r.grow(1.0), INK)
	draw_rect(r, BACK)
	if enemy != null and enemy.is_dead:
		draw_rect(r, Color.WHITE)  # the kill: one white blink, then gone
		return
	draw_rect(Rect2(r.position, Vector2(SIZE.x * chip, SIZE.y)), CHIP)
	draw_rect(Rect2(r.position, Vector2(SIZE.x * fill, SIZE.y)), FILL)
	if notch > 0.0 and notch < 1.0:
		var x := notch
		while x < 0.999:
			var px := roundf(r.position.x + SIZE.x * x)
			draw_line(Vector2(px, r.position.y), Vector2(px, r.end.y), INK, 1.0)
			x += notch
