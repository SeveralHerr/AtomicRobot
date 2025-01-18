extends CanvasLayer

@onready var ui: CanvasLayer = $"."
@onready var button: Button = $MarginContainer/Button


var instance

const MENU = preload("res://scenes/menu.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.pressed.connect(_menu)

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _menu() -> void: 
	instance = MENU.instantiate()
	ui.add_child(instance)
	

	
