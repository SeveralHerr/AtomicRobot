extends Label

@onready var hp_1: TextureRect = $"../HBoxContainer/HP1"
@onready var hp_2: TextureRect = $"../HBoxContainer/HP2"
@onready var hp_3: TextureRect = $"../HBoxContainer/HP3"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Globals.player.player_health_updated.connect(_update_health)
	pass # Replace with function body.

func _update_health(current_health: int) -> void: 
	text = "HP: " + str(current_health)
	if current_health == 0:
		hp_1.hide()
	elif current_health == 1: 
		hp_2.hide() 
	elif current_health == 2:
		hp_3.hide()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
