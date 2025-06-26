extends HBoxContainer

@onready var player: Player = $"../../../../Player"

# Dynamic heart management
const HEART_SCENE = preload("res://scenes/hp_1.tscn")
var heart_instances: Array[Node] = []
var max_hearts: int = 0

func _ready() -> void:
	player.player_health_updated.connect(_update_health)
	# Initialize with player's starting health
	_update_health(player.health)

func _update_health(current_health: int) -> void:
	print("Health updated to: ", current_health)
	
	# Determine the maximum hearts we need (current health or existing max, whichever is higher)
	var needed_hearts = max(current_health, max_hearts)
	
	# Create additional heart instances if needed
	while heart_instances.size() < needed_hearts:
		_create_heart_instance()
	
	# Update visibility of all heart instances
	for i in range(heart_instances.size()):
		if i < current_health:
			heart_instances[i].show()
		else:
			heart_instances[i].hide()

func _create_heart_instance() -> void:
	var heart_instance = HEART_SCENE.instantiate()
	add_child(heart_instance)
	heart_instances.append(heart_instance)
	max_hearts = heart_instances.size()
	print("Created heart instance. Total hearts: ", max_hearts)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
