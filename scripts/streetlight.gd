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

# Player detection
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
	if player and can_change_state:
		var distance = global_position.distance_to(player.global_position)
		if distance <= detection_radius and current_state == LightState.RED:
			change_to_green()

func change_to_green():
	can_change_state = false
	current_state = LightState.GREEN
	red_light.visible = false
	green_light.visible = true

	var car = CAR.instantiate()
	add_child(car)
	car.global_position = Vector2(player.position.x + car_position.x, 0)
	car.speed = 0
	car.start = true
	
	# Wait for green duration
	await get_tree().create_timer(green_duration).timeout
	
	# Change back to red
	red_light.visible = true
	green_light.visible = false
	car.hide()
	car.start = false
	car.area_2d.monitorable = false
	car.area_2d.monitoring = false

	car.global_position = Vector2(player.position.x + car_position.x, 0)
	current_state = LightState.RED
	
	# Wait for red duration before allowing state change again
	await get_tree().create_timer(red_duration).timeout
	car.queue_free()
	can_change_state = true

func _on_detection_area_body_entered(body):
	if body is Player:
		player = body

func _on_detection_area_body_exited(body):
	if body == player:
		player = null
