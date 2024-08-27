extends Node2D
class_name Train

@onready var end_area_2d: Area2D = $Sprite2D/EndArea2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	end_area_2d.body_entered.connect(_on_enter)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	position.x -= 40 * delta
	pass
	
func _on_enter(body: Node2D) -> void:
	if body.name == "TrainLeftWallEnd":
		position.x += 3000
		
