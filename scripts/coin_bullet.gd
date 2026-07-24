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
var lane: int = Lanes.GROUND_LANE
# Coins arced down by platform/window maids hit whichever lane they land on.
var lane_agnostic: bool = false
## Absolute Y of the virtual floor this coin lands on; INF = ride real collision.
var virtual_floor_y: float = INF

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
	contact_monitor = true
	max_contacts_reported = 10
	body_entered.connect(_on_body_entered)
	# Clean up after 15 seconds if nothing happens
	await get_tree().create_timer(15).timeout
	queue_free()
	
## Put this coin on a road lane's virtual floor. The walkway tiles' collision boxes
## fill the road strip below the walkway line, so a coin flying at a road-lane Y is
## inside solid Ground geometry and smacks into it immediately. Road-lane bodies
## solve this by dropping Ground(2)/Platforms(6) and standing on a virtual floor —
## coins do the same (see Player._set_ground_collision / Enemy._apply_gravity).
func set_lane_floor(floor_lane: int, baseline_y: float) -> void:
	if floor_lane == Lanes.GROUND_LANE or not is_finite(baseline_y):
		return
	virtual_floor_y = Lanes.floor_y(baseline_y, floor_lane)
	set_collision_mask_value(2, false)
	set_collision_mask_value(6, false)
	z_index = Lanes.z_for(floor_lane)

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

func _on_body_entered(body: Node) -> void:
	#if body is not Player:
		#set_collision_mask_value(1, false)
	if body is Player and not has_hit_player:
		if not lane_agnostic and body.current_lane != lane:
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
