extends TextureRect

const GAME: PackedScene = preload("res://game2.tscn")
@export var character: String
var slot_name: String
var description: String
@onready var character_name_label: Label = $"../../CharacterNameLabel"
@onready var character_description_label: Label = $"../../CharacterDescriptionLabel"
@onready var locked: TextureRect = $Locked
@onready var character_image: TextureRect = $Character
@onready var button: Button = $Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Button.pressed.connect(_on_press)
	$Button.mouse_entered.connect(_on_focus)
	$Button.mouse_exited.connect(_on_focus_exit)

	character_name_label.text = ""
	character_description_label.text = ""
	
	if character == "Cody" and not Globals.cody_unlocked:
		locked.show()
		character_image.hide()
		

	pass # Replace with function body.

func _on_press() -> void:
	get_tree().change_scene_to_packed(GAME)

func _on_focus() -> void:
	if character == "Robot":
		character_name_label.text = Globals.ROBOT_NAME
		character_description_label.text = Globals.ROBOT_DESCRIPTION
		Globals.selected_character = "Robot"
		
	elif character == "Cody":
		if Globals.cody_unlocked:
			character_name_label.text = Globals.DEFAULT_NAME
			character_description_label.text = Globals.DEFAULT_DESCRIPTION
			Globals.selected_character = "Cody"
		else: 
			button.disabled = true
			character_name_label.text = "Locked"
			character_description_label.text = "HINT: If only there was a sign"
func _on_focus_exit() -> void:
	button.disabled = false
	character_name_label.text = ""
	character_description_label.text = ""
