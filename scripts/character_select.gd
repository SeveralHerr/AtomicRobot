extends Control

## Arcade has no mouse: something must own focus the moment the screen opens or the
## d-pad has nothing to move. Prefer the last-played character, else the first
## unlocked slot.
@onready var slots: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer
@onready var _skip_intro: CheckBox = $MarginContainer2/HBoxContainer/CheckBox
const EXIT_GAP := 48.0
var exit_button: Button
## Swappable so tests can press EXIT GAME without ending the test run.
var quit_game: Callable = func() -> void: QuitGame.quit(get_tree())

func _ready() -> void:
	exit_button = _add_exit_button()
	initial_slot().button.grab_focus()

## EXIT GAME sits beside SKIP INTRO and borrows its font and focus box.
func _add_exit_button() -> Button:
	var b := Button.new()
	b.flat = true
	b.add_theme_font_override("font", _skip_intro.get_theme_font("font"))
	b.add_theme_font_size_override("font_size", _skip_intro.get_theme_font_size("font_size"))
	b.add_theme_stylebox_override("focus", _skip_intro.get_theme_stylebox("focus"))
	var spacer := Control.new()
	spacer.custom_minimum_size.x = EXIT_GAP
	_skip_intro.get_parent().add_child(spacer)
	_skip_intro.get_parent().add_child(b)
	return QuitGame.wire(b, func() -> void: quit_game.call())

func initial_slot() -> Control:
	var first_unlocked: Control = null
	for slot in slots.get_children():
		if not slot.is_unlocked():
			continue
		if slot.character == Globals.selected_character:
			return slot
		if first_unlocked == null:
			first_unlocked = slot
	return first_unlocked if first_unlocked else slots.get_child(0)
