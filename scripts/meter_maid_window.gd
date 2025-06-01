extends Enemy
class_name MeterMaidWindow
@onready var cpu_particles_2d: CPUParticles2D = $BrokenWindow/CPUParticles2D
var spawned: bool = false

func _ready() -> void:
	#hide()
	# Set health to 3
	health = 3
	
	call_deferred("set_sprite")

	enemy_state_machine = EnemyStateMachine.new(self)

	enemy_state_machine.add_state("EnemyAttackState", EnemyAttackState.new())
	#enemy_state_machine.add_state("FindMeterState", FindMeterState.new())
	#enemy_state_machine.add_state("AttackPlayerState", AttackPlayerState.new())
	add_child(enemy_state_machine)
	#await get_tree().create_timer(1.5).timeout

	
	Globals.player_death.connect(_on_player_death)
	#show()


	
func set_sprite():
	var dir = (Globals.player.position - global_position).normalized().x
	_update_sprite_direction(dir)
	node = Globals.player.get_parent()
	
func _on_player_death() -> void:
	print("Player died, changing state...")
	#enemy_state_machine.change_state("PatrolState")
func _physics_process(delta: float) -> void:
	if enemy_state_machine.enemy == null:
		return
		
	
	var dist = position.distance_to(Globals.player.position)
#
	if dist < attack_range and spawned == false:
		show()
		spawned = true
		animated_sprite_2d.play("idle")
		cpu_particles_2d.emitting = true
		await get_tree().create_timer(0.5).timeout
		cpu_particles_2d.emitting = false
		await get_tree().create_timer(1).timeout
		enemy_state_machine.change_state("EnemyAttackState")

		
	enemy_state_machine.physics_update(delta)
func _process(delta: float) -> void:
	enemy_state_machine.update(delta)
