extends Node

const METER_MAID_BOSS = preload("res://scenes/meter_maid_boss.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Globals.meter_maid_death.connect(_spawn_boss)
	Globals.meter_maid_death.connect(_spawn_final_boss)
	Globals.meter_maid_boss_death.connect(_spawn_final_boss)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _spawn_boss() -> void:
	if Globals.meter_maids_killed >= 2:
		var instance = METER_MAID_BOSS.instantiate()
		add_child(instance)

func _spawn_final_boss() -> void:
	# if metermaid_dead_count >= 2 AND meter_maid_boss_count == 1
	if Globals.meter_maids_killed >= 2 and Globals.meter_maid_boss_killed == 1:
		print("final boss unlocked")
