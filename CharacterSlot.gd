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
	
	var focus_character = Globals.character_dict[character]
	if !focus_character.unlocked:
		locked.show()
		character_image.hide()

	pass # Replace with function body.

func _on_press() -> void:
	Globals.selected_character = character
	get_tree().change_scene_to_packed(GAME)

func _on_focus() -> void:
	var focus_character = Globals.character_dict[character]
	var unlocked = focus_character.unlocked
	button.disabled = !unlocked
	character_name_label.text = focus_character.name if unlocked else "Locked"
	character_description_label.text = focus_character.description if unlocked else focus_character.unlock_hint

func _on_focus_exit() -> void:
	button.disabled = false
	character_name_label.text = ""
	character_description_label.text = ""
