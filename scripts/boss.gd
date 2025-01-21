extends CharacterBody2D
class_name Boss

const COIN_BULLET = preload("res://scenes/coin_bullet.tscn")


@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
@onready var coin_spawn_position: Node2D = $CoinSpawnPosition
@onready var timer: Timer = $Timer

@onready var animation_player: AnimationPlayer = $AnimationPlayer



var health: int = 3
var direction: int = -1
var speed: int = 50
var target: Node2D = null
var coins: int = 4
var node: Node
var dir
var landed: bool = false
var stand_still: bool = false


func _ready() -> void:
	node = Globals.player.get_parent()
	position = Globals.player.boss_spawn_position.position + Globals.player.position

	Globals.player_death.connect(_on_player_death)
	timer.timeout.connect(_create_bullet)

	Globals.boss_fight.emit(true)
	
func _on_player_death() -> void:
	print("Player died, changing state...")
	#enemy_state_machine.change_state("PatrolState")

func _process(delta: float) -> void:
	dir = (Globals.player.position - position).normalized()
	_update_sprite_direction()
	if not is_on_floor():
		velocity.y += 300 * delta
	if is_on_floor() and not landed:
		ScreenShake.apply_shake(10)
		landed = true
		timer.start()
	if stand_still:
		return


	var dist = position.distance_to(Globals.player.position)
	if dist > 100:
		animated_sprite_2d.play("Walk")
		velocity.x = move_toward(velocity.x, dir.x * 50, 2009 * delta)
	else:
		velocity.x = 0

	move_and_slide()
		
func _update_sprite_direction() -> void:
	animated_sprite_2d.flip_h = sign(dir.x) == -1

	

	
func receive_hit(damage: int) -> void:
	#ScreenShake.apply_shake(10)
	animation_player.play("Hit")
	health -= damage
	
	if health <= 0: 
		Globals.meter_maid_boss_killed += 1	
		Globals.meter_maid_boss_death.emit()

		Globals.boss_fight.emit(false)
		call_deferred("queue_free")
	
	# Calculate knockback direction based on the player's position
	var knockback_direction = (position - Globals.player.position).normalized()
	
	# Apply knockback force
	var knockback_strength = 200.0  # Adjust this value as needed
	velocity += knockback_direction * knockback_strength

	# Optionally, you could also reset velocity.y to create a more distinct knockback effect
	velocity.y = -100.0  # Adjust this value as needed for vertical knockback
	
func _create_bullet() -> void:
	if Globals.player.is_dead:
		return

		
	
	stand_still = true
	animated_sprite_2d.animation_finished.connect(throw_coin)
	animated_sprite_2d.play("ThrowCoin")
	
func throw_coin() -> void:
	animated_sprite_2d.animation_finished.disconnect(throw_coin)
	for i in range(10):


		
		var instance = COIN_BULLET.instantiate()

		#instance.player_only = true
		#instance.scale = Vector2(4, 4)
		node.add_child(instance)
		var pos = position + coin_spawn_position.position
		instance.start(pos,  (Globals.player.position - pos).normalized())
	animated_sprite_2d.play("Idle")
	stand_still = false
func randomOffset() -> int:
	return randi_range(-14,14)
