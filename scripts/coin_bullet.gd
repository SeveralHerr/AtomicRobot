extends RigidBody2D
class_name Bullet

const HIT_FX = preload("res://scenes/hit_fx.tscn")
@onready var area_2d: Area2D = $Area2D
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer
@onready var ground_area_2d: Area2D = $GroundArea2D

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var speed: float = 200.0
var direction: Vector2


func start(_position: Vector2, _direction: Vector2, is_arc: bool = false) -> void:
	position = _position
	#direction = _direction.normalized()
	coin_audio_player.play()
	if is_arc:
		#$Sprite2D.scale = Vector2(0.5, 0.5)
		linear_velocity  = _direction #* 2 #* speed

	else: 
		linear_velocity  = _direction * speed		
	#linear_velocity.y -= 300



func _process(delta: float) -> void:
	pass

func _hit(body: Node2D) -> void:
	if body is Bullet or body is Enemy:
		return
	set_collision_layer_value(10, false)
	set_collision_mask_value(9, false)
	area_2d.set_collision_layer_value(1, false)
	area_2d.set_collision_layer_value(9, false)	
	area_2d.set_collision_mask_value(1, false)
	area_2d.set_collision_mask_value(9, false)	
	if body is Player:
		body.receive_hit(global_position)
		var instance = HIT_FX.instantiate()
		body.get_tree().root.add_child(instance)
		instance.global_position = global_position
		instance.start()

	
	await get_tree().create_timer(2).timeout


	freeze_mode = FREEZE_MODE_KINEMATIC
	freeze = true
	pass

func _ready() -> void:
	area_2d.body_entered.connect(_hit)
	#var tween = get_tree().create_tween().parallel()
	#tween.set_ease(Tween.EASE_IN)
	#tween.set_trans(Tween.TRANS_SINE)
	#tween.tween_property($Sprite2D, "scale", Vector2(1, 1), 0.8)

	#tween.tween_property(self, "linear_velocity",linear_velocity * 2, 0.8)
	await get_tree().create_timer(15).timeout
	queue_free()

func is_off_screen() -> bool:
	# Optional: Implement logic to detect if the bullet is off-screen
	# This can help in cleaning up bullets that leave the screen area
	return false
