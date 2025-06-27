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
@onready var meter_line_of_sight: LineOfSight = $MeterLineOfSight



var is_player_in_attack_range: bool = false

# Stats
var health: int = 2
var move_speed: float = 100.0
var coins: int = 1
var attack_range: int = 120
var attack_cooldown: float = 4
var detection_range: float = 600.0
var last_dir: int = -1
# Knockback variables
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 8.0  # How fast knockback decays



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
	_apply_knockback_decay(delta)
	enemy_state_machine.update(delta)

	move_and_slide()


func is_player_in_line_of_sight() -> bool:
	return line_of_sight.is_player_line_of_sight()

func is_meter_in_line_of_sight() -> bool:
	return meter_line_of_sight.is_meter_line_of_sight(Globals.nearest_meter(global_position).global_position)


# Virtual methods to be overridden
func attack():
	pass




func move_towards_target(target_pos: Vector2, delta: float):
	#var direction = sign(dir.x)
	var direction = (target_pos - global_position).normalized()
	var target_velocity = direction * move_speed
	#_update_sprite_direction(direction.x)
	velocity.x = move_toward(velocity.x, target_velocity.x, 2000 * delta)
	pass




	
func _face_player() -> void:
	var direction = (global_position - player.global_position ).normalized()
	_handle_direction( direction.x  )
	
func _handle_direction(direction) -> void:
	if direction:
		if direction < 0:
			if last_dir != -1:
				if scale.x == -1:
					scale.x *= -1
					last_dir = -1
					return
				scale.x *= -1
				last_dir = -1

		elif direction > 0:
			if last_dir != 1 :
				scale.x *= -1
				last_dir = 1
	
	
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
	var knockback_direction = (global_position - player.global_position).normalized()
	var knockback_strength = 200.0  # Increased for more noticeable effect
	knockback_velocity = knockback_direction * knockback_strength
	velocity.y = -50.0

func _apply_knockback_decay(delta: float) -> void:
	# Apply knockback to velocity
	velocity.x += knockback_velocity.x * delta
	
	# Decay knockback over time
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta * 100)
	
	# Apply friction to horizontal movement when not being controlled by states
	if abs(knockback_velocity.x) < 10.0:  # Only apply friction when knockback is minimal
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	
func get_distance_to_player() -> float:
	return global_position.distance_to(player.global_position)

func can_see_player() -> bool:
	return  get_distance_to_player() <= detection_range

func is_too_far() -> bool:
	return  get_distance_to_player() >= 1500

func can_see_player_threshold(threshold_multiplier: float) -> bool:
	return get_distance_to_player() <= detection_range * threshold_multiplier
	
func is_the_player_in_attack_range() -> bool:
	return is_player_in_attack_range
	
func has_state(state: String) -> bool:
	return enemy_state_machine.states.has(state)


func chase_player(delta: float) -> void: 
	# Handle animation and movement (but don't override knockback)
	if not is_the_player_in_attack_range()  and is_player_in_line_of_sight():
		# Only move if not being knocked back
		if abs(knockback_velocity.x) < 10.0:
			move_towards_target(player.global_position, delta)
		animated_sprite_2d.play("walk")
	else:
		_face_player()
		animated_sprite_2d.play("idle")
		# Only stop movement if not being knocked back
		if abs(knockback_velocity.x) < 10.0:
			velocity.x = 0	
			
func chase_player_melee(delta: float) -> void: 
	# Handle animation and movement (but don't override knockback)
	if not is_the_player_in_attack_range()  and is_player_in_line_of_sight():
		# Only move if not being knocked back
		if abs(knockback_velocity.x) < 10.0:
			move_towards_target(player.global_position, delta)
		animated_sprite_2d.play("walk")
	else:
		_face_player()
		animated_sprite_2d.play("idle")
		# Only stop movement if not being knocked back
		if abs(knockback_velocity.x) < 10.0:
			velocity.x = 0	

func can_attack() -> bool:
	return attack_timer.is_stopped() and is_player_in_attack_range
	
