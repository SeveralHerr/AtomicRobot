#extends Node2D
#
#@onready var boss_sprite: AnimatedSprite2D = $BossSprite
extends Enemy
class_name FinalBoss


func _ready() -> void:
	super._ready()
	coins = 2999
	#enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new(self))
	enemy_state_machine.add_state("BossAttackPlayerState", BossAttackPlayerState.new(self))
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new(self))
	
	enemy_state_machine.change_state("BossAttackPlayerState")

	
func receive_hit(damage: int, knockback_strength: float = 200.0) -> void:
	super.receive_hit(damage, knockback_strength)
	if health <= 0:
		Globals.boss_death.emit()
	
#@onready var attack_timer: Timer = $AttackTimer
#@onready var briefcase_spawn_point: Node2D = $BulletSpawnPoint
#
#const BRIEFCASE_BULLET = preload("res://scenes/briefcase_bullet2.tscn")
#
#var player: Player
#var is_attacking: bool = false
#var attack_cooldown: float = 2.0
#var briefcases_per_attack: int = 1
#var time_between_briefcases: float = 0.1
#var spiral_angle: float = 0.0
#var spiral_radius: float = 100.0
#var last_dir: int = -1
#
#
#func _face_player() -> void:
	#var direction = (global_position - player.global_position ).normalized()
	#_handle_direction( direction.x  )
	#
#func _handle_direction(direction) -> void:
	#if direction:
		#if direction < 0:
			#if last_dir != -1:
				#if scale.x == -1:
					#scale.x *= -1
					#last_dir = -1
					#return
				#scale.x *= -1
				#last_dir = -1
#
		#elif direction > 0:
			#if last_dir != 1 :
				#scale.x *= -1
				#last_dir = 1
#
#func _ready() -> void:
	#player = get_tree().get_first_node_in_group("player")
	#_face_player()
	#attack_timer.wait_time = attack_cooldown
	#attack_timer.timeout.connect(_on_attack_timer_timeout)
	#attack_timer.start()
	#boss_sprite.animation_finished.connect(func():
		#if boss_sprite.animation == "Attack":
			#boss_sprite.play("Idle")
			#is_attacking = false
			## Return to idle animation
			#attack_timer.start()
		#)
	#
#func _process(delta: float) -> void:
	#_face_player()
#
#func _on_attack_timer_timeout() -> void:
	#if player and not player.is_dead and not is_attacking:
		#_perform_briefcase_attack()
#
#func _perform_briefcase_attack() -> void:
	#if is_attacking:
		#return
		#
	#is_attacking = true
	#boss_sprite.play("Attack")  # Assumes attack animation exists
	#
	## Reset spiral for new attack
	#spiral_angle = 0.0
	#
	## Spawn briefcases in rapid spiral pattern
	#for i in briefcases_per_attack:
		#await get_tree().create_timer(time_between_briefcases).timeout
		#_spawn_briefcase_spiral(i)
	#
#
#
#func _spawn_briefcase_spiral(index: int) -> void:
	#if not player or player.is_dead:
		#return
		#
	#Utils.throw_briefcase_from_enemy(self,  false,  0)
	#
	### Calculate spiral target position around player
	##var angle_increment = PI * 0.5  # 90 degrees per briefcase for rapid spiral
	##spiral_angle += angle_increment
	##
	### Calculate target position in spiral pattern around player
	##var player_pos = player.global_position
	##var spiral_offset = Vector2(
		##cos(spiral_angle) * spiral_radius,
		##sin(spiral_angle) * spiral_radius * 0.6  # Flatter spiral
	##)
	##var target_position = player_pos + spiral_offset
	##
	### Calculate direction from spawn to spiral target
	##var direction = (target_position - spawn_position).normalized()
	#
	## Start the briefcase movement
##	briefcase.start_movement()
