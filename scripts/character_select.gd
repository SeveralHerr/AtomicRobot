extends Control

## Arcade has no mouse: something must own focus the moment the screen opens or the
## d-pad has nothing to move. Prefer the last-played character, else the first
## unlocked slot.
@onready var slots: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer

func _ready() -> void:
	initial_slot().button.grab_focus()

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
