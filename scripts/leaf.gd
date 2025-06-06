extends RigidBody2D
class_name DroppedLeaf
@onready var sprite: Sprite2D = $Sprite
@onready var floor_raycast: RayCast2D = $"Floor Raycast"

var x_mult: float
var y_mult: float
var original_scale: Vector2
var frames = 0

func _ready() -> void:
	original_scale = $Sprite.scale
	#sprite.region_rect = sprite.region
	x_mult = randf()*0.65
	y_mult = randf()*0.65


func _physics_process(delta: float) -> void:
	$"Floor Raycast".global_rotation = 0
	if $"Floor Raycast".is_colliding() or not floor_raycast.enabled:
		linear_damp = 8.0
		angular_damp = 8.0
		#$Sprite.scale = lerp($Sprite.scale, original_scale*0.8, 0.03)
	else:
		linear_damp = 3.0
		angular_damp = 1.0
		turbulence(delta)

func do_gust(power, source_position: Vector2):
	var direction = (source_position - global_position).normalized()
	var randomiser = randf_range(0.5, 1.5)
	linear_velocity.y -= 10*power*randomiser
	linear_velocity.x -= direction.x*power*10*randomiser
	angular_velocity = direction.x*power*randomiser*0.5

func turbulence(delta: float):
	delta *= 260
	linear_velocity.x += sin(frames * x_mult * 0.1) * 4
	linear_velocity.y += sin(frames * y_mult * 0.1) * 2
	#$Sprite.scale.x = sin(frames * 0.01 * linear_velocity.x * 0.01 * x_mult) * original_scale.x
	#$Sprite.scale.y = sin(frames * 0.035 * y_mult) * original_scale.y
