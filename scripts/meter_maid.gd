extends Enemy
class_name MeterMaid

func _ready() -> void:
	health = 3
	_setup_initial_state()
	Globals.player_death.connect(_on_player_death)

func _setup_initial_state() -> void:
	_setup_state_machine()
	_setup_sprite_direction()
	node = Globals.player.get_parent()

func _setup_state_machine() -> void:
	enemy_state_machine = EnemyStateMachine.new(self)
	enemy_state_machine.add_state("PatrolState", PatrolState.new())
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new())
	enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new())
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new())
	
	# Only add refill state if refills are enabled
	if refills_enabled:
		enemy_state_machine.add_state("FindMeterState", FindMeterState.new())
	
	add_child(enemy_state_machine)
	enemy_state_machine.change_state("PatrolState")

func _setup_sprite_direction() -> void:
	var direction_to_player = (Globals.player.position - global_position).normalized().x
	_update_sprite_direction(direction_to_player)

func _on_player_death() -> void:
	# Could return to patrol state if needed
	pass

func _process(delta: float) -> void:
	enemy_state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if enemy_state_machine.enemy == null:
		return
		
	_apply_gravity(delta)
	enemy_state_machine.physics_update(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 300 * delta

func die() -> void:
	enemy_state_machine.change_state("DeadEnemyState")

func receive_hit(damage: int) -> void:
	_play_hit_effects()
	_apply_damage(damage)
	_apply_knockback()

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
	var knockback_direction = (position - Globals.player.position).normalized()
	var knockback_strength = 300.0
	velocity += knockback_direction * knockback_strength
	velocity.y = -50.0
