extends RigidBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
#@onready var hit_audio: AudioStreamPlayer2D = $HitAudio

const HIT_FX = preload("res://scenes/hit_fx.tscn")

var initial_speed: float = 400.0
var arc_height: float = 200.0
var has_hit_player: bool = false
var target_position: Vector2
var start_position: Vector2

func start_movement(direction: Vector2, target_pos: Vector2) -> void:
	target_position = target_pos
	start_position = global_position
	
	# Calculate arc trajectory similar to Hammer Bros
	var distance_to_target = start_position.distance_to(target_position)
	var time_to_reach = distance_to_target / initial_speed
	
	# Calculate horizontal velocity
	var horizontal_velocity = (target_position.x - start_position.x) / time_to_reach
	
	# Calculate initial vertical velocity for arc (accounting for gravity)
	var vertical_velocity = ((target_position.y - start_position.y) / time_to_reach) - (0.5 * gravity_scale * ProjectSettings.get_setting("physics/2d/default_gravity") * time_to_reach)
	
	# Apply arc height boost for that classic Hammer Bros feel
	vertical_velocity -= arc_height
	
	# Set the velocity
	linear_velocity = Vector2(horizontal_velocity, vertical_velocity)
	
	# Configure physics properties
	gravity_scale = 1.0
	mass = 0.5
	linear_damp = 0.1
	angular_damp = 2.0
	
	# Create physics material for bouncing
	var material = PhysicsMaterial.new()
	material.bounce = 0.4
	material.friction = 0.5
	physics_material_override = material
	
	# Add some rotation for visual effect
	angular_velocity = randf_range(-3.0, 3.0)

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 10
	body_entered.connect(_on_body_entered)
	
	# Clean up after 10 seconds if nothing happens
	await get_tree().create_timer(10.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# Stop the briefcase if it's moving very slowly
	if linear_velocity.length() < 30.0 and abs(angular_velocity) < 0.5:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		freeze = true

func _on_body_entered(body: Node) -> void:
	if body is not Player:
		# Stop tracking player collisions after hitting ground/walls
		set_collision_mask_value(1, false)
	
	if body is Player and not has_hit_player:
		print("Briefcase hit player")
		body.receive_hit(global_position, 1)
		has_hit_player = true
		
		# Create hit effect
		var instance = HIT_FX.instantiate()
		body.get_tree().root.add_child(instance)
		instance.global_position = global_position
		
		## Play hit sound if available
		#if hit_audio:
			#hit_audio.play()
		#
		# Remove briefcase after hit
		await get_tree().create_timer(0.1).timeout
		queue_free()
