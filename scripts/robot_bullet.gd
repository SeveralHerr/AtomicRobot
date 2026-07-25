extends Node2D

@onready var area_2d: Area2D = $Area2D

## World px the bullet may travel before it despawns. The camera (zoom 2.5 on a
## 1280-wide viewport) shows 512 px of world, so the screen edge sits ~256 px from
## the player — anything beyond this would land hits on enemies that are off-frame.
const MAX_TRAVEL: float = 220.0
## 600 px/s == the old 10 px per 60 Hz physics frame, but delta-driven so it is
## frame-rate independent and respects Engine.time_scale.
const SPEED: float = 600.0

var dir = 0
var player: Player
## Set by the spawner right after instantiation. Road lanes fly over the road tiles,
## so the projectile must take the lane's z or the TileMapLayer (z=1) hides it.
var lane: int = Lanes.GROUND_LANE:
	set(value):
		lane = value
		z_index = Lanes.z_for(value)

var _travelled: float = 0.0

func _ready() -> void:
	area_2d.body_entered.connect(_hit)

func _physics_process(delta: float) -> void:
	if dir == 0:
		return
	var step: float = SPEED * delta
	position.x += dir * step
	_travelled += step
	if _travelled >= MAX_TRAVEL:
		queue_free()

func _hit(body: Node2D):
	if body is Enemy and body.lane == lane:
		ScreenShake.apply_shake(7)
		player.land_hit(body)
		queue_free()
