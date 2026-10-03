extends Control

const STORY: PackedScene = preload("res://scenes/story.tscn")
@export var character: String
var slot_name: String
var description: String
@onready var character_name_label: Label = $"../../CharacterNameLabel"
@onready var character_description_label: Label = $"../../CharacterDescriptionLabel"
@onready var locked: TextureRect = $Locked
@onready var character_image: TextureRect = $Character
@onready var button: Button = $Button
@onready var texture_rect: PanelContainer = $Background/TextureRect
@onready var check_box: CheckBox = $"../../../../MarginContainer2/HBoxContainer/CheckBox"
const CONTROLS_SPLASH = preload("res://scenes/controls_splash.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Button.pressed.connect(_on_press)
	# Focus drives the highlight so d-pad/stick and mouse share one selection.
	$Button.focus_entered.connect(_on_focus)
	$Button.focus_exited.connect(_on_focus_exit)
	$Button.mouse_entered.connect($Button.grab_focus)
	
	texture_rect.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	character_name_label.text = ""
	character_description_label.text = ""
	
	var focus_character = Globals.character_dict[character]
	if !focus_character.unlocked:
		locked.show()
		character_image.hide()

	pass # Replace with function body.

func is_unlocked() -> bool:
	return Globals.character_dict[character].unlocked

func _on_press() -> void:
	# Locked slots stay focusable so the unlock hint can be read, but never start a run.
	if not is_unlocked():
		return
	Globals.selected_character = character
	if check_box.button_pressed:
		get_tree().change_scene_to_packed(CONTROLS_SPLASH)
	else:
		get_tree().change_scene_to_packed(STORY)

func _on_focus() -> void:
	texture_rect.show()
	var focus_character = Globals.get_current_character_by_name(character)
	var unlocked = focus_character.unlocked
	character_name_label.text = focus_character.get_character_name() if unlocked else "Locked"
	character_description_label.text = focus_character.get_description() if unlocked else focus_character.unlock_hint

func _on_focus_exit() -> void:
	texture_rect.hide()
	character_name_label.text = ""
	character_description_label.text = ""
