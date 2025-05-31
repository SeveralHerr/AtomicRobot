extends Enemy
class_name MeterMaid




func _ready() -> void:
	node = Globals.player.get_parent()

	enemy_state_machine = EnemyStateMachine.new(self)
	enemy_state_machine.add_state("PatrolState", PatrolState.new())
	enemy_state_machine.add_state("ChasePlayerState", ChasePlayerState.new())
	#enemy_state_machine.add_state("FindMeterState", FindMeterState.new())
	#enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new())
	add_child(enemy_state_machine)
	
	enemy_state_machine.change_state("PatrolState")
	Globals.player_death.connect(_on_player_death)

	
func _on_player_death() -> void:
	print("Player died, changing state...")
	enemy_state_machine.change_state("PatrolState")

func _process(delta: float) -> void:
	enemy_state_machine.update(delta)

	
func _physics_process(delta: float) -> void:
	if enemy_state_machine.enemy == null:
		return
	if not is_on_floor():
		velocity.y += 300 * delta
		
	enemy_state_machine.physics_update(delta)
	move_and_slide()
	
func receive_hit(damage: int) -> void:

	if animation_player.is_playing():
		animation_player.stop()
	
	animation_player.play("Hit")
	health -= damage
	
	if health <= 0: 
		Globals.meter_maids_killed += 1
		Globals.meter_maid_death.emit()

		call_deferred("queue_free")
	
	# Calculate knockback direction based on the player's position
	var knockback_direction = (position - Globals.player.position).normalized()
	
	# Apply knockback force
	var knockback_strength = 300.0  # Adjust this value as needed
	velocity += knockback_direction * knockback_strength

	# Optionally, you could also reset velocity.y to create a more distinct knockback effect
	velocity.y = -50.0  # Adjust this value as needed for vertical knockback
