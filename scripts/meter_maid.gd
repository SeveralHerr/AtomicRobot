extends CharacterBody2D
class_name Enemy

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

var enemy_state_machine: EnemyStateMachine


func _ready() -> void:
	node = Config.player.get_parent()
	enemy_state_machine = EnemyStateMachine.new(self)
	enemy_state_machine.add_state("PatrolState", PatrolState.new())
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new())
	enemy_state_machine.add_state("FindMeterState", FindMeterState.new())
	
	enemy_state_machine.change_state("PatrolState")

func _process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 300 * delta

	enemy_state_machine.update(delta)
	move_and_slide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _procdess(delta: float) -> void:
	print(ray_cast_2d_left.is_colliding())
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
		if not ray_cast_2d_left.is_colliding():
			direction = 1
			animated_sprite_2d.flip_h = false
			ray_cast_2d_left.enabled = false
			await get_tree().create_timer(0.3).timeout
			ray_cast_2d_left.enabled = true
			
		elif not ray_cast_2d_right.is_colliding():
			direction = -1
			animated_sprite_2d.flip_h = true
			ray_cast_2d_right.enabled = false
			await get_tree().create_timer(0.3).timeout
			ray_cast_2d_right.enabled = true

		var t = velocity.x + (direction * 50)
		velocity.x = move_toward(velocity.x, t, 30 * delta)
	move_and_slide()



	pass
