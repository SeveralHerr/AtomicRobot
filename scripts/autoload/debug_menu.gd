extends CanvasLayer

## In-game debug/cheat overlay. Toggle with F3 (the "debug_menu" input action).
## Spawns enemies/cars near the player, teleports the player between map
## sections, and toggles a god-mode cheat (invincible + one-hit-kill).

const CAR_SCENE := preload("res://scenes/car.tscn")

## World-space X of each BuildingGroup in main.tscn (SceneItemsBackground
## origin (1875, -1) + each group's local offset — see docs/LEVELS.md).
## Only Y is left alone on teleport so the player stays on solid ground.
const SECTIONS := {
	"Atomic Robot Bldg": 0.0,
	"Building Group 1": 581.0,
	"Building Group 3": 1875.0,
	"Building Group 2": 4424.0,
}

var _panel: PanelContainer
var _god_mode_button: Button
var _menu_open: bool = false
var _saved_damage: int = -1


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		_menu_open = not _menu_open
		_panel.visible = _menu_open
		get_viewport().set_input_as_handled()


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(200, 0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.8)
	bg.set_content_margin_all(10)
	bg.set_border_width_all(1)
	bg.border_color = Color(1, 1, 1, 0.4)
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	vbox.add_child(_label("DEBUG MENU (F3)"))

	vbox.add_child(_label("-- Spawn --"))
	vbox.add_child(_button("Melee Maid", _spawn_melee))
	vbox.add_child(_button("Ranged Maid", _spawn_ranged))
	vbox.add_child(_button("Wave (3)", _spawn_wave))
	vbox.add_child(_button("Car", _spawn_car))

	vbox.add_child(_label("-- Teleport --"))
	for section_name: String in SECTIONS:
		vbox.add_child(_button(section_name, _teleport.bind(SECTIONS[section_name])))

	vbox.add_child(_label("-- Cheats --"))
	_god_mode_button = _button("God Mode: OFF", _toggle_god_mode)
	vbox.add_child(_god_mode_button)
	vbox.add_child(_button("Full Heal", _full_heal))
	vbox.add_child(_button("Kill All Enemies", _kill_all_enemies))


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	return b


# --- Spawning ---


func _spawn_melee() -> void:
	_spawn_enemy_near_player(true)


func _spawn_ranged() -> void:
	_spawn_enemy_near_player(false)


func _spawn_enemy_near_player(melee: bool) -> void:
	var player := _player()
	if player == null:
		return
	var lane := player.current_lane if player.lane_baseline_y != INF else Lanes.GROUND_LANE
	EnemySpawner.spawn_enemy_at(get_tree().current_scene, player, player.global_position.x + 300, lane, melee)


func _spawn_wave() -> void:
	var player := _player()
	if player == null:
		return
	EnemySpawner.spawn_wave(get_tree().current_scene, player, get_viewport().get_visible_rect().size, 3)


func _spawn_car() -> void:
	var player := _player()
	if player == null:
		return
	var car: Node2D = CAR_SCENE.instantiate()
	get_tree().current_scene.add_child(car)
	var lane: int = randi_range(Lanes.GROUND_LANE + 1, Lanes.FRONT_LANE)
	var y := player.global_position.y
	if player.lane_baseline_y != INF:
		y = Lanes.floor_y(player.lane_baseline_y, lane)
	car.lane = lane
	car.global_position = Vector2(player.global_position.x + 600, y)
	car.start = true


# --- Teleport ---


func _teleport(world_x: float) -> void:
	var player := _player()
	if player == null:
		return
	player.global_position.x = world_x
	player.velocity = Vector2.ZERO


# --- Cheats ---


func _toggle_god_mode() -> void:
	var player := _player()
	if player == null:
		return
	player.god_mode = not player.god_mode
	_god_mode_button.text = "God Mode: ON" if player.god_mode else "God Mode: OFF"
	if player.god_mode:
		_saved_damage = player.damage
		player.damage = 999
		player.health = max(player.health, 10)
		player.player_health_updated.emit(player.health)
	elif _saved_damage >= 0:
		player.damage = _saved_damage
		_saved_damage = -1


func _full_heal() -> void:
	var player := _player()
	if player == null:
		return
	player.health = 10
	player.player_health_updated.emit(player.health)


func _kill_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("die"):
			enemy.die()
