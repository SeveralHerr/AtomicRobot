extends Node2D
class_name PowerupPickup

## A dropped power-up waiting to be collected. Spawned by Utils.drop_powerup() from
## Enemy.die(); grants its buff through PowerupSystem on contact.
##
## Lane-aware: only a player standing on the SAME lane can collect it, matching the
## rule combat already uses. Area overlap alone cannot express that — lanes are 24px
## apart (Lanes.LANE_SPACING) and the pickup radius is 30, so the Area2D genuinely
## overlaps two or three lanes at once.

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D

## Height above the lane's FLOOR line that the pickup hovers at. Kept low so the
## small sprite reads as sitting in the street rather than floating over it.
const HOVER_HEIGHT := 18.0
const BOB_HEIGHT := 3.0
const BOB_TIME := 0.9
const SPIN_TIME := 2.5
## Blinks per second once the pickup is inside PowerupRules.PICKUP_BLINK_LEAD of
## despawning, scaled up as the last second runs out.
const BLINK_HZ := 4.0

## Set by Utils.drop_powerup() between instantiate() and add_child(), so _ready()
## already sees the final values.
var powerup_id: String = PowerupRules.RAGE
var lane: int = Lanes.GROUND_LANE

var _collected: bool = false
var _life: float = PowerupRules.PICKUP_LIFETIME


func _ready() -> void:
	z_index = Lanes.z_for(lane)
	add_to_group("powerup_pickups")
	# No new art: the buff reads purely as a colour on the shared pickup sprite.
	sprite.modulate = PowerupRules.color(powerup_id)
	# Deferred: reparenting inside _ready trips "parent node is busy setting up children".
	Lanes.join_sort_layer.call_deferred(self)
	_start_idle_motion()


func _start_idle_motion() -> void:
	var base_y: float = sprite.position.y
	var bob := create_tween().set_loops()
	bob.tween_property(sprite, "position:y", base_y - BOB_HEIGHT, BOB_TIME * 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprite, "position:y", base_y, BOB_TIME * 0.5).set_trans(Tween.TRANS_SINE)
	var spin := create_tween().set_loops()
	spin.tween_property(sprite, "rotation", TAU, SPIN_TIME).from(0.0)


func _process(delta: float) -> void:
	if _collected:
		return
	_check_for_player()
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _life <= PowerupRules.PICKUP_BLINK_LEAD:
		# Blink faster the closer it gets to gone, so "about to expire" and "just
		# dropped" can never be confused at a glance.
		var urgency: float = 1.0 + (PowerupRules.PICKUP_BLINK_LEAD - _life)
		sprite.visible = fmod(_life * BLINK_HZ * urgency, 1.0) > 0.35


## Polled against the live overlap set rather than latched on body_entered.
##
## The latch cannot express this rule: the player very often walks into the pickup's
## radius on the wrong lane and only THEN taps to the right one, and body_entered has
## already fired and will not fire again. (Enemy._refresh_player_in_attack_range
## carries the same fix for the same reason.)
func _check_for_player() -> void:
	if not area.monitoring:
		return
	for body in area.get_overlapping_bodies():
		if body is Player and not body.is_dead and body.current_lane == lane:
			_collect(body)
			return


func _collect(player: Player) -> void:
	_collected = true
	area.monitoring = false
	PowerupSystem.grant(powerup_id)
	if player.pickup_audio != null:
		player.pickup_audio.play()
	ScreenShake.apply_shake(4)
	sprite.visible = true
	var burst := create_tween().set_parallel()
	burst.tween_property(sprite, "scale", sprite.scale * 2.5, 0.18)
	burst.tween_property(sprite, "modulate:a", 0.0, 0.18)
	await burst.finished
	queue_free()
