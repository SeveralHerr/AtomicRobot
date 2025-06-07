extends RigidBody2D
class_name DroppedLeaf
@onready var sprite: Sprite2D = $Sprite
@onready var floor_raycast: RayCast2D = $"Floor Raycast"
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

var x_mult: float
var y_mult: float
var original_scale: Vector2
var frames = 0
var is_pooled: bool = false
@export var change_color: bool = true

func _ready() -> void:
	original_scale = $Sprite.scale

	randomize_properties()

func randomize_properties() -> void:
	x_mult = randf() * 0.65
	y_mult = randf() * 0.65
	
	if change_color: 
		var rand = randf_range(0.7, 1.0)
		# Add some visual variety
		sprite.modulate = Color(
			rand, rand, rand
		)
		sprite.scale = original_scale *  randf_range(1.6, 2.2)
		collision_shape_2d.scale = sprite.scale
		floor_raycast.scale = collision_shape_2d.scale
	rotate(deg_to_rad(randf_range(0, 190)))

	


func _physics_process(delta: float) -> void:
	$"Floor Raycast".global_rotation = 0
	if $"Floor Raycast".is_colliding():
		linear_damp = 8.0
		angular_damp = 8.0
		#$Sprite.scale = lerp($Sprite.scale, original_scale*0.8, 0.03)
	else:
		linear_damp = 3.0
		angular_damp = 1.0
		turbulence(delta)

func do_gust(power: float, source_position: Vector2):
	var direction = (source_position - global_position).normalized()
	var randomiser = randf_range(0.5, 1.5)
	linear_velocity.y -= 10 * power * randomiser
	linear_velocity.x -= direction.x * power * 10 * randomiser
	angular_velocity = direction.x * power * randomiser * 0.5
	
	# Reset to active state when interacted with
	if is_pooled:
		is_pooled = false

func turbulence(delta: float):
	delta *= 260
	frames += 1
	linear_velocity.x += sin(frames * x_mult * 0.1) * 4
	linear_velocity.y += sin(frames * y_mult * 0.1) * 2

# Pooling helpers
func reset_for_pool():
	is_pooled = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	frames = 0
	set_physics_process(false)
	visible = false

func activate_from_pool(position: Vector2):
	is_pooled = false
	global_position = position
	randomize_properties()
	set_physics_process(true)
	visible = true
	frames = 0
