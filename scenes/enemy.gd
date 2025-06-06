extends CharacterBody2D
class_name Enemy

## Base enemy class with common functionality and state management

# State management
var enemy_state_machine: EnemyStateMachine

# Resources - moved to Utils for shared access

# Node references - cached for performance
@onready var coin_spawn_point: Node2D = $CoinSpawnPoint
@onready var ray_cast_2d_left_down: RayCast2D = $RayCast2D_LeftDown
@onready var ray_cast_2d_left_wall: RayCast2D = $RayCast2D_LeftWall
@onready var ray_cast_2d_right_down: RayCast2D = $RayCast2D_RightDown
@onready var ray_cast_2d_right_wall: RayCast2D = $RayCast2D_RightWall
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_detection: Area2D = $Area2D
@onready var attack_timer: Timer = $Timer
@onready var coin_audio_player: AudioStreamPlayer2D = $CoinAudioPlayer
@onready var range_timer: Timer = $RangeTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var receive_hit_audio: AudioStreamPlayer = $ReceiveHitAudio
@onready var line_of_sight: LineOfSight = $LineOfSight


var is_player_in_attack_range: bool = false

# Stats
var health: int = 3
var move_speed: float = 100.0
var coins: int = 1
var attack_range: int = 120
var attack_cooldown: float = 4
var detection_range: float = 300.0



# Runtime data
var player: Node2D

func _init() -> void:
	enemy_state_machine = EnemyStateMachine.new(self)
	add_child(enemy_state_machine)

func _ready() -> void:
	attack_timer.wait_time = attack_cooldown
	player = get_tree().get_first_node_in_group("player")
	
	player_detection.body_entered.connect(func(body: Node2D): is_player_in_attack_range = true)
	player_detection.body_exited.connect(func(body: Node2D): is_player_in_attack_range = false)


	
	

	
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	enemy_state_machine.update(delta)

	move_and_slide()


func is_player_in_line_of_sight() -> bool:
	return line_of_sight.is_player_line_of_sight()




# Virtual methods to be overridden
func attack():
	pass




func move_towards_target(target_pos: Vector2, delta: float):
	#var direction = sign(dir.x)
	var direction = (target_pos - global_position).normalized()
	var target_velocity = direction * move_speed
	_update_sprite_direction(direction.x)
	velocity.x = move_toward(velocity.x, target_velocity.x, 2000 * delta)
	pass



## Efficiently update sprite direction with early return
func _update_sprite_direction(direction: float) -> void:
	animated_sprite_2d.flip_h = direction < 0.0
	
func _face_player() -> void:
	var direction = (player.global_position - global_position).normalized()
	animated_sprite_2d.flip_h = direction.x < 0.0
	
	
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 300 * delta

func die() -> void:
	velocity = Vector2.ZERO
	Globals.meter_maids_killed += 1
	Globals.meter_maid_death.emit()
	animated_sprite_2d.play("death")
	attack_timer.stop()
	range_timer.stop()
	player_detection.monitorable = false
	player_detection.monitoring = false
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	await get_tree().create_timer(1.5).timeout
	
	# Create blinking effect
	var tween = create_tween()
	#tween.set_loops(6) # 3 full blinks (fade out + fade in = 2 tweens per blink)

	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.chain().tween_property(self, "modulate:a", 1.0, 0.1).set_delay(0.2)

	tween.chain().tween_property(self, "modulate:a", 0.0, 0.1).set_delay(0.5)
	tween.chain().tween_property(self, "modulate:a", 1.0, 0.1).set_delay(0.2)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.1).set_delay(0.5)
	tween.chain().tween_property(self, "modulate:a", 1.0, 0.1).set_delay(0.2)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.1).set_delay(0.4)
	tween.chain().tween_property(self, "modulate:a", 1.0, 0.1).set_delay(0.2)
	# Wait for blinking to finish, then free the self
	await tween.finished
	queue_free()	


func receive_hit(damage: int) -> void:
	_play_hit_effects()
	_apply_damage(damage)
	_apply_knockback()
	
	if health <= 0 and has_state("DeadEnemyState"):
		enemy_state_machine.change_state("DeadEnemyState")

func _play_hit_effects() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	animation_player.play("Hit")
	receive_hit_audio.play()

func _apply_damage(damage: int) -> void:
	health -= damage
	if health <= 0:
		call_deferred("die")

func _apply_knockback() -> void:
	var knockback_direction = (global_position - Globals.player.global_position).normalized()
	var knockback_strength = 300.0
	velocity += knockback_direction * knockback_strength
	velocity.y = -50.0
	
func get_distance_to_player() -> float:
	if player:
		return global_position.distance_to(player.global_position)
	return INF

func can_see_player() -> bool:
	return  get_distance_to_player() <= detection_range
	
func has_state(state: String) -> bool:
	return enemy_state_machine.states.has(state)


func can_attack() -> bool:
	return attack_timer.is_stopped() and is_player_in_attack_range
	
