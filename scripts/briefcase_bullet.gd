extends CharacterBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

const HIT_FX = preload("res://scenes/hit_fx.tscn")

var speed: float = 1.0
var has_hit_player: bool = false
var player: Player
var spiral_angle: float = 0.0
var spiral_speed: float = 10
var spiral_radius: float = 30.0
var center_position: Vector2
var center_move_speed: float = 100.0

func start_movement() -> void:
	player = get_tree().get_first_node_in_group("player")
	center_position = global_position

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	
	# Clean up after 10 seconds if nothing happens
	await get_tree().create_timer(10.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	if not player:
		return

	# Move center position towards player
	var direction_to_player = (player.global_position - center_position).normalized()
	center_position += direction_to_player * center_move_speed * delta
	
	# Update spiral angle
	spiral_angle += spiral_speed * delta
	rotation_degrees -= 2
	
	# Calculate circular movement around moving center
	var new_position = center_position + Vector2(
		cos(spiral_angle) * spiral_radius,
		sin(spiral_angle) * spiral_radius
	)
	
	global_position = new_position
	
	move_and_slide()
	
	# Check for collision with player
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		
		if body is Player and not has_hit_player:
			_hit_player(body)

func _hit_player(body: Player) -> void:
	pass
	print("Briefcase hit player")
	body.receive_hit(global_position, 1)
	has_hit_player = true
	
	# Create hit effect
	var instance = HIT_FX.instantiate()
	body.get_tree().root.add_child(instance)
	instance.global_position = global_position
	
	# Remove briefcase after hit
	queue_free()
