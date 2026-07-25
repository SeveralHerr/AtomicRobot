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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Apply persisted settings immediately (slider + AudioServer + CRTOverlay)
	# before any signals are connected, so this doesn't trigger a redundant save.
	_load_and_apply_settings()

	_volume_slider.value_changed.connect(_on_volume_changed)
	_crt_checkbox.toggled.connect(_on_crt_toggled)
	_resume_button.pressed.connect(_on_resume_pressed)
	_exit_button.pressed.connect(_on_resume_pressed)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_pause()


func toggle_pause() -> void:
	var new_paused: bool = not get_tree().paused
	get_tree().paused = new_paused
	visible = new_paused
	if new_paused:
		_volume_slider.grab_focus()


func _on_resume_pressed() -> void:
	toggle_pause()


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
