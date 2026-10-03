extends CanvasLayer

const SETTINGS_PATH := "user://settings.cfg"
const AUDIO_SECTION := "audio"
const VOLUME_KEY := "master_volume"
const VIDEO_SECTION := "video"
const CRT_KEY := "crt_enabled"
const MASTER_BUS := 0

@onready var _volume_slider: HSlider = $CenterContainer/Panel/Margin/VBoxContainer/VolumeRow/VolumeSlider
@onready var _crt_checkbox: CheckBox = $CenterContainer/Panel/Margin/VBoxContainer/CRTRow/CRTCheckBox
@onready var _resume_button: Button = $CenterContainer/Panel/Margin/VBoxContainer/ResumeButton
@onready var _exit_button: Button = $CenterContainer/Panel/Margin/VBoxContainer/HeaderRow/ExitButton
@onready var _quit_button: Button = $CenterContainer/Panel/Margin/VBoxContainer/QuitButton
@onready var _controls_button: Button = $CenterContainer/Panel/Margin/VBoxContainer/ControlsButton
@onready var _main_panel: Control = $CenterContainer/Panel
@onready var _remap_panel = $CenterContainer/RemapPanel

## Swappable so tests can press QUIT GAME without ending the test run.
var quit_game: Callable = _quit_game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Apply persisted settings immediately (slider + AudioServer + CRTOverlay)
	# before any signals are connected, so this doesn't trigger a redundant save.
	_load_and_apply_settings()
	# Saved button remaps must apply at boot, not only once the menu is opened.
	InputRemap.load_and_apply()

	_volume_slider.value_changed.connect(_on_volume_changed)
	_crt_checkbox.toggled.connect(_on_crt_toggled)
	_resume_button.pressed.connect(_on_resume_pressed)
	_exit_button.pressed.connect(_on_resume_pressed)
	_quit_button.pressed.connect(func() -> void: quit_game.call())
	_quit_button.visible = QuitGame.available()
	_controls_button.pressed.connect(_show_controls)
	_remap_panel.closed.connect(_hide_controls)


func _process(_delta: float) -> void:
	# Input state sees a press even when _input swallowed it, so the remap panel
	# (open or listening) must veto pause here or binding Start would close the menu.
	if Input.is_action_just_pressed("pause") and not _remap_panel.visible:
		toggle_pause()


func toggle_pause() -> void:
	var new_paused: bool = not get_tree().paused
	get_tree().paused = new_paused
	visible = new_paused
	if new_paused:
		_hide_controls()
		_volume_slider.grab_focus()


func _show_controls() -> void:
	_main_panel.visible = false
	_remap_panel.open()


func _hide_controls() -> void:
	_remap_panel.visible = false
	_main_panel.visible = true
	_controls_button.grab_focus()


func _on_resume_pressed() -> void:
	toggle_pause()


static func can_quit(on_web: bool, query: String) -> bool:
	return QuitGame.can_quit(on_web, query)


func _quit_game() -> void:
	QuitGame.quit(get_tree())


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_save_setting(AUDIO_SECTION, VOLUME_KEY, value)


func _on_crt_toggled(pressed: bool) -> void:
	CRTOverlay.set_enabled(pressed)
	_save_setting(VIDEO_SECTION, CRT_KEY, pressed)


func _apply_volume(value: float) -> void:
	if value <= 0.0001:
		AudioServer.set_bus_mute(MASTER_BUS, true)
	else:
		AudioServer.set_bus_mute(MASTER_BUS, false)
		AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(value))


func _load_and_apply_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)

	var volume: float = 1.0
	var crt_enabled: bool = true
	if err == OK:
		volume = config.get_value(AUDIO_SECTION, VOLUME_KEY, 1.0)
		crt_enabled = config.get_value(VIDEO_SECTION, CRT_KEY, true)

	_volume_slider.value = volume
	_apply_volume(volume)

	_crt_checkbox.button_pressed = crt_enabled
	CRTOverlay.set_enabled(crt_enabled)


func _save_setting(section: String, key: String, value) -> void:
	var config := ConfigFile.new()
	# Ignore load errors here - if the file doesn't exist yet this just
	# starts from an empty ConfigFile, which is fine.
	config.load(SETTINGS_PATH)
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)
