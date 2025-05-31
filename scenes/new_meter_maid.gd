extends Node2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var rigid_body_2d: RigidBody2D = $RigidBody2D
@onready var collision_shape_2d: CollisionShape2D = $RigidBody2D/CollisionShape2D
const COIN_BULLET = preload("res://scenes/coin_bullet.tscn")

var walk_speed = 100.0
var attack_range = 200.0
var stand_still: bool = false
var attack_timer: Timer

func _ready() -> void:
	attack_timer = Timer.new()
	attack_timer.wait_time = 4.0
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_create_bullet)
	add_child(attack_timer)
	attack_timer.start()

func _physics_process(delta: float) -> void:
	if stand_still:
		rigid_body_2d.linear_velocity = Vector2.ZERO
		return
		
	var direction = (Globals.player.position - position).normalized()
	var distance = position.distance_to(Globals.player.position)
	
	if distance > attack_range:
		# Walk towards player
		rigid_body_2d.linear_velocity = direction * walk_speed
		animated_sprite_2d.play("walk")
		animated_sprite_2d.flip_h = sign(direction.x) == -1
	else:
		# Stop when in range
		rigid_body_2d.linear_velocity = Vector2.ZERO
		animated_sprite_2d.play("idle")

func _create_bullet() -> void:
	var distance = position.distance_to(Globals.player.position)
	if distance <= attack_range and not stand_still:
		stand_still = true
		animated_sprite_2d.play("attack")
		animated_sprite_2d.animation_finished.connect(throw_coin)

	
func throw_coin() -> void:
	stand_still = false
	animated_sprite_2d.animation_finished.disconnect(throw_coin)
	
	var instance = COIN_BULLET.instantiate()
	add_child(instance)
	
	var pos = position 
	instance.start(pos, (Globals.player.position - pos).normalized())
	animated_sprite_2d.play("idle")
