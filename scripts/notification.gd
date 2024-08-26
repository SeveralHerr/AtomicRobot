extends Control

@onready var header_label: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	Globals.unlocked.connect(_show_ui)
	pass # Replace with function body.

func _show_ui(header: String, description: String) -> void:
	header_label.text = header
	description_label.text = description
	
	show()
	await get_tree().create_timer(2).timeout
	hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
