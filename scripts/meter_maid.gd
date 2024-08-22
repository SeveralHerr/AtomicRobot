extends CharacterBody2D

const COIN_BULLET = preload("res://scenes/coin_bullet.tscn")

@onready var ray_cast_2d_left: RayCast2D = $RayCast2D_Left
@onready var ray_cast_2d_right: RayCast2D = $RayCast2D_Right
@onready var ray_cast_2d_left2: RayCast2D = $RayCast2D_Left2
@onready var ray_cast_2d_right2: RayCast2D = $RayCast2D_Right2
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
@onready var range_area_2d: Area2D = $RangeArea2D
@onready var timer: Timer = $Timer
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer

var direction: int = -1
var speed: int = 50
var target: Node2D = null
var coins: int = 4
var node: Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	node = Config.player.get_parent()
	if direction == -1:
		animated_sprite_2d.flip_h = true
	elif direction == 1:
		animated_sprite_2d.flip_h = false
		
	range_area_2d.body_entered.connect(_attack)
	range_area_2d.body_exited.connect(_no_target)
	
	timer.timeout.connect(_create_bullet)
	
	#timer.start()

	pass # Replace with function body.
	
func _no_target(body: Node2D) -> void:
	if target is Meter:
		return
	if body is not Player:
		return
		
	target = null
	timer.stop()

func _attack(body: Node2D) -> void:
	if target is Meter:
		return
	if body is not Player:
		return

	target = body
	timer.start()


func _create_bullet() -> void:
	if coins <= 0:
		target = Config.nearest_meter(position)
		if target == null:
			return
		return	
		
	if Config.player.state_machine.current_state is DeadState: 
		return
	
	var instance = COIN_BULLET.instantiate()

	coins -= 1
	node.call_deferred("add_child", instance)
	instance.position = position


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print(ray_cast_2d_right2.is_colliding())
	if not is_on_floor():
		velocity.y += 300 * delta
	if target:
		var dir = (target.position - position).normalized()
		velocity.x = move_toward(velocity.x, dir.x * 50, 30 * delta)
		var dist = position.distance_to(target.position)
	
		if target is Meter and dist < 5:
			velocity.x = 0
			
			print("more coins")
			coins += 4
			target.play_animation()
			target = null
			var bodies = range_area_2d.get_overlapping_bodies()
			for body in bodies: 
				if body is Player:
					target = body

			
			coin_audio_player.play()
			await get_tree().create_timer(1).timeout
			coin_audio_player.stop()		
		
		if dir.x <= -1:
			animated_sprite_2d.flip_h = true
		elif dir.x >= 1:
			animated_sprite_2d.flip_h = false
	else:
		if not ray_cast_2d_left.is_colliding() or not ray_cast_2d_left2.is_colliding():
			direction = -1
			animated_sprite_2d.flip_h = true
			ray_cast_2d_left.enabled = false
			ray_cast_2d_left2.enabled = false
			await get_tree().create_timer(0.3).timeout
			ray_cast_2d_left.enabled = true			
			ray_cast_2d_left2.enabled = true
			
	
		elif not ray_cast_2d_right.is_colliding() or  not ray_cast_2d_right2.is_colliding():
			direction = 1
			animated_sprite_2d.flip_h = false
			ray_cast_2d_right.enabled = false
			ray_cast_2d_right2.enabled = false
			await get_tree().create_timer(0.3).timeout
			ray_cast_2d_right.enabled = true

			ray_cast_2d_right2.enabled = true

		velocity.x = move_toward(velocity.x, direction * 50, 30 * delta)
	move_and_slide()



	pass
