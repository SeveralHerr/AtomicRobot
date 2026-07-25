extends RayCast2D
class_name LineOfSight

## Single-ray sight check from an enemy to the player (or to a parking meter).
##
## The ray is aimed and stepped on demand inside the query methods rather than in
## _process. Two reasons: the queries are called from _physics_process (state
## machine update), so an idle-frame aim was always one step stale; and aiming
## only when asked means a state that forgets to flip `enabled` can't silently
## leave the ray pointing at wherever the player was last frame.

## Maximum world distance this ray probes. Seeded from the authored
## `target_position` but raised by Enemy._ready() to the owner's detection_range:
## a maid that "detects" at 600px through a ray that only reached 450 stalled out
## of sight at spawn distance (EnemySpawner drops enemies ~477px away) and, with
## no PatrolState to fall back to, stood still forever.
var max_range: float = 0.0
var player: Player
var is_meter: bool = false

## Ends the ray a hair past the target so a body sitting exactly at the endpoint
## still registers. Safe to overshoot: a raycast reports its FIRST hit, so this
## can never see past something in the way.
const REACH_EPSILON := 4.0


func _ready() -> void:
	max_range = maxf(absf(target_position.y), target_position.length())
	_resolve_player()


## The player is not guaranteed to be in the group yet when a hand-placed enemy
## readies (scene node order decides), and it is a different instance after a
## reload — so re-resolve instead of caching a null/freed one forever.
func _resolve_player() -> Player:
	if player != null and is_instance_valid(player):
		return player
	player = get_tree().get_first_node_in_group("player") as Player
	return player


## Aims at a world point (clamped to max_range) and steps the ray immediately.
## Returns the first collider, or null if the ray reached the end unobstructed.
func _probe(world_target: Vector2) -> Object:
	var to_target := world_target - global_position
	var dist := to_target.length()
	if dist < 0.001:
		return null
	var reach: float = minf(dist, max_range) + REACH_EPSILON
	# target_position is LOCAL and inherits the parent Enemy's transform, which
	# Enemy.set_facing() mirrors on x when facing left. to_local() inverts that (and
	# any other parent transform) rather than us hand-guessing the sign — which is
	# what the old `* sign(last_dir * -1)` did, backwards, aiming the ray away from
	# the player whenever the enemy faced left.
	target_position = to_local(global_position + to_target / dist * reach)
	force_raycast_update()
	return get_collider() if is_colliding() else null


func is_player_line_of_sight() -> bool:
	if _resolve_player() == null:
		return false
	if global_position.distance_to(player.global_position) > max_range:
		return false
	return _probe(player.global_position) is Player


func is_meter_line_of_sight(meter_position: Vector2) -> bool:
	var was_enabled := enabled
	enabled = true
	var hit := _probe(meter_position)
	enabled = was_enabled
	if hit == null:
		return false
	return hit is Node and (hit as Node).get_parent() is Meter
