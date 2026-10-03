extends CenterContainer
class_name  GameOver


@onready var player: Player = $"../../Player"
const CHARACTER_SELECT ="res://scenes/character_select.tscn"
@onready var button: Button = $VBoxContainer/Button
var exit_button: Button
## Swappable so tests can press EXIT GAME without ending the test run.
var quit_game: Callable = func() -> void: QuitGame.quit(get_tree())

func _ready() -> void:
	hide()
	button.pressed.connect(func(): 
		Globals.reset()
		get_tree().change_scene_to_file(CHARACTER_SELECT ))
	exit_button = QuitGame.add_button_after(button, func() -> void: quit_game.call())

	Globals.player_death.connect(_present)

## Arcade (pad-only): focus must land on RESTART when the overlay appears. Grabbing it
## in _ready, while hidden, loses it to whatever grabs next (in the boss room that is
## the hidden Win button, so pad A pressed nothing).
func _present() -> void:
	show()
	GameOver.arm(button)


## Seconds RESTART ignores presses after appearing. A is also Jump, so a player mashing
## jump as they die would otherwise restart the run by accident.
const ARM_DELAY := 0.6

## Select `button` at once (so the player sees where focus is) but keep it disabled
## until ARM_DELAY has passed.
static func arm(button: Button) -> void:
	button.disabled = true
	button.grab_focus()
	await button.get_tree().create_timer(ARM_DELAY).timeout
	if is_instance_valid(button):
		button.disabled = false
