extends RigidBody2D
class_name Bullet

const HIT_FX = preload("res://scenes/hit_fx.tscn")
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

var initial_speed: float = 600.0
var has_hit_player: bool = false
# Restitution used when bouncing off a virtual lane floor; matches the physics
# material bounce applied in start(), so both floors feel the same.
var bounce_damping: float = 0.3
var is_falling: bool = false
var has_landed: bool = false
## The ONE lane this coin can hurt in. A coin never re-targets: step out of its
## lane (or be mid-step) and it sails past. Throwers line up in your lane first.
var lane: int = Lanes.GROUND_LANE
## Absolute Y of the virtual floor this coin lands on; INF = ride real collision.
var virtual_floor_y: float = INF
## Extra px around the player's body box that still counts as contact (coin radius).
const HIT_PAD := 2.0
## A resting coin's origin sits this far above its lane floor (its radius).
const REST_LIFT := 2.0
var _shadow: CoinShadow

## Reflect (parry): a melee blow in the coin's lane knocks it back at the maids.
## The player's attack calls reflect(player) on overlapping areas in this group;
## the coin's ReflectArea sits on the Leaf layer (8), which that area already scans.
const REFLECT_GROUP := "reflectable"
## Reflected speed vs. a fresh throw, and the small lift that sells the swat.
const REFLECT_SPEEDUP := 1.35
const REFLECT_LIFT := -60.0
const REFLECT_DAMAGE := 1
const REFLECT_STOP := 0.06
const REFLECT_PITCH := 1.7
## True once swatted: the coin now hunts enemies in its lane and never the player.
var reflected: bool = false

func start(_position: Vector2, _direction: Vector2, is_arc: bool = false, gravity: float = 0.55) -> void:
	global_position = _position
	coin_audio_player.play()
	
	# Set collision layers and masks for coin physics

	
	# Configure physics properties for projectile behavior
	gravity_scale = gravity  # Reduced gravity for better projectile arc
	mass = 0.38  # Light mass like a real coin
	linear_damp = 0.7  # Damping to slow down movement over time
	angular_damp = 2.0  # Damping to slow down rotation
	
	# Create physics material for bouncing
	var material = PhysicsMaterial.new()
	material.bounce = 0.3
	material.friction = 0.7
	physics_material_override = material
	
	if is_arc:
		linear_velocity = _direction
	else: 
		linear_velocity = _direction * initial_speed

func _ready() -> void:
	# Only scenes that carry a ReflectArea (the coin, not the boss's briefcases).
	if has_node("ReflectArea"):
		add_to_group(REFLECT_GROUP)
	contact_monitor = true
	max_contacts_reported = 10
	body_entered.connect(_on_body_entered)
	# Clean up after 15 seconds if nothing happens
	await get_tree().create_timer(15).timeout
	queue_free()
	
## Put this coin on a lane's virtual floor. The walkway tiles' collision boxes fill
## the road strip below the walkway line, so a coin flying at a road-lane Y is inside
## solid Ground geometry. All lanes, including GROUND_LANE, drop Ground(2)/Platforms(6)
## and stand on a virtual floor instead, so every coin behaves the same way whatever
## lane it is on (see Player._set_ground_collision / Enemy._apply_gravity).
##
## `rest_y` is the ABSOLUTE world Y this coin's origin should settle at on that lane,
## resolved by the caller (Utils.throw_coin: the lane floor minus REST_LIFT, so a
## landed coin lies on the street next to its shadow).
##
## `spawn_y` is where the coin was thrown from. Keeping the lower (larger-y) of the
## two means a coin thrown from below its floor line never snaps up-screen.
func set_lane_floor(floor_lane: int, rest_y: float, spawn_y: float = -INF) -> void:
	if not is_finite(rest_y):
		return
	virtual_floor_y = maxf(rest_y, spawn_y)
	set_collision_mask_value(2, false)
	set_collision_mask_value(6, false)
	z_index = Lanes.z_for(floor_lane)


## Drop a ground shadow on the lane's floor line so the coin's lane reads in flight.
func show_shadow(floor_y: float) -> void:
	if not is_finite(floor_y):
		return
	if _shadow == null:
		_shadow = CoinShadow.new()
		add_child(_shadow)
	_shadow.floor_y = floor_y

## Bounce/rest on the virtual floor, since there is no body there to collide with.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if virtual_floor_y == INF or state.linear_velocity.y < 0.0:
		return
	var xform := state.transform
	if xform.origin.y < virtual_floor_y:
		return
	xform.origin.y = virtual_floor_y
	state.transform = xform
	var v := state.linear_velocity
	v.y = -v.y * bounce_damping
	v.x *= 0.85  # rolling friction, stands in for the material's friction
	if absf(v.y) < 30.0:
		v.y = 0.0
	state.linear_velocity = v

func enable_passthrough() -> void:
	#set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(5, false)
	set_collision_layer_value(9, false)
	set_collision_mask_value(9, false)
	is_falling = true

func _physics_process(delta: float) -> void:
	# Stop the coin if it's moving very slowly
	if linear_velocity.length() < 50 and abs(angular_velocity) < 1.0:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		# Set to kinematic mode to prevent further movement
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		freeze = true
		has_landed = true
	if reflected:
		_check_enemy_contact()
	else:
		_check_player_contact()


## Swat the coin back the way it came. One reflect per coin; a coin lying on the
## street is a pickup-sized prop, not a projectile, and can't be swatted.
func reflect(by: Node2D) -> void:
	if reflected or has_landed or has_hit_player:
		return
	var by_lane: Variant = by.get("current_lane")
	if by_lane != null and int(by_lane) != lane:
		return
	reflected = true
	var away := signf(global_position.x - by.global_position.x)
	if away == 0.0:
		away = -signf(linear_velocity.x) if linear_velocity.x != 0.0 else 1.0
	linear_velocity = reflect_velocity(linear_velocity, away, initial_speed)
	angular_velocity = 0.0
	_reflect_juice()


## Back along X (away from the swatter), faster than it came, with a little lift.
static func reflect_velocity(v: Vector2, away: float, base_speed: float) -> Vector2:
	var speed := maxf(absf(v.x), base_speed) * REFLECT_SPEEDUP
	return Vector2(signf(away) * speed, REFLECT_LIFT)


func _reflect_juice() -> void:
	var fx = HIT_FX.instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.start()
	coin_audio_player.pitch_scale = REFLECT_PITCH
	coin_audio_player.play()
	Utils.apply_hit_pause(self, REFLECT_STOP)
	ScoreSystem.register_hit()


## A reflected coin hits the first live enemy in its lane whose body it overlaps.
func _check_enemy_contact() -> void:
	if has_landed:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.is_dead or e.lane != lane or not _overlaps_body(e):
			continue
		e.receive_hit(REFLECT_DAMAGE)
		HitFeel.hit_landed(self, e, e.is_dead)
		queue_free()
		return


## Coins don't physically collide with the player (that made them bounce off a
## player in a neighbouring lane — lanes are 24px apart, the body is 51px tall).
## Contact is a lane test plus an overlap of the player's body box instead.
func _check_player_contact() -> void:
	if has_hit_player or has_landed:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not _overlaps(player):
		return
	_on_body_entered(player)


func _overlaps(player: Player) -> bool:
	return _shape_has(player.collision_shape_2d_body)


func _overlaps_body(e: Enemy) -> bool:
	return _shape_has(e.get_node_or_null("CollisionShape2D") as CollisionShape2D)


func _shape_has(cs: CollisionShape2D) -> bool:
	if cs == null or cs.shape == null:
		return false
	var box: Rect2 = cs.global_transform * cs.shape.get_rect()
	return box.grow(HIT_PAD).has_point(global_position)


## A coin hurts only a player standing in its lane. Mid-step counts as out of it:
## the step IS the dodge, so it must work from its first frame.
static func lane_allows_hit(coin_lane: int, player_lane: int, player_changing_lane: bool) -> bool:
	return coin_lane == player_lane and not player_changing_lane


func _on_body_entered(body: Node) -> void:
	if body is Player and not has_hit_player:
		if has_landed or reflected:
			return
		if not lane_allows_hit(lane, body.current_lane, body.is_changing_lane):
			return
		print("hit player")
		body.receive_hit(global_position, 1)
		var instance = HIT_FX.instantiate()
		body.get_tree().root.add_child(instance)
		instance.global_position = global_position
		instance.start()
		
		# Mark as hit and reduce bounce for more realistic behavior
		has_hit_player = true
		
		if not is_falling:
			var p = PhysicsMaterial.new()
			p.bounce = 0.1
			p.friction = 0.9
			physics_material_override = p
		
		# Clean up after hitting player
		queue_free()
	
	# For ground/wall collisions, just let physics handle it naturally
	# Coins will bounce and roll realistically

func is_off_screen() -> bool:
	# Optional: Implement logic to detect if the bullet is off-screen
	# This can help in cleaning up bullets that leave the screen area
	return false
