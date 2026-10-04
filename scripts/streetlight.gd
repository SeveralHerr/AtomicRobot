extends Sprite2D
@onready var red_light: PointLight2D = $RedLight
@onready var green_light: PointLight2D = $GreenLight
#@onready var car: Node2D = $Car
# car.start = true, it will show the car automatically 
const CAR = preload("res://scenes/car.tscn")
# Traffic light states
enum LightState {RED, GREEN}
var current_state: LightState = LightState.RED
var car_position: Vector2 = Vector2(713, 62)
var car_y_pos: float 

# Player detection: horizontal reach only, so the whole vertical column above and
# below the light triggers it (the road sits well below the lamp head).
@export var detection_radius: float = 100.0
@export var player: Player = null

# Timer variables
var can_change_state: bool = true
@export var red_duration: float = 5.0
@export var green_duration: float = 10.0

func _ready():
	# Initialize lights

	red_light.visible = true
	green_light.visible = false

func _process(_delta):
	if can_change_state and current_state == LightState.RED and player_in_range():
		change_to_green()

func player_in_range() -> bool:
	return player != null and absf(global_position.x - player.global_position.x) <= detection_radius

func change_to_green():
	can_change_state = false
	current_state = LightState.GREEN
	red_light.visible = false
	green_light.visible = true

	var car: Car = CAR.instantiate()
	add_child(car)
	var car_lane: int = _pick_car_lane()
	car.launch(car_lane, Vector2(player.position.x + car_position.x, Car.road_y(player, car_lane)))
	
	# Wait for green duration
	await get_tree().create_timer(green_duration).timeout
	
	# Change back to red
	red_light.visible = true
	green_light.visible = false
	car.hide()
	car.start = false
	car.area_2d.monitorable = false
	car.area_2d.monitoring = false
	current_state = LightState.RED
	
	# Wait for red duration before allowing state change again
	await get_tree().create_timer(red_duration).timeout
	car.queue_free()
	can_change_state = true

## Cars use the road lanes only — never the sidewalk (GROUND_LANE).
func _pick_car_lane() -> int:
	return randi_range(Lanes.GROUND_LANE + 1, Lanes.FRONT_LANE)

func _on_detection_area_body_entered(body):
	if body is Player:
		player = body

func _on_detection_area_body_exited(body):
	if body == player:
		player = null
