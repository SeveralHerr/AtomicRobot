extends RayCast2D


@onready var line_of_sight: RayCast2D = self

var previous_mouse_pos: Vector2
# Called when the node enters the scene tree for the first time.



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var mouse_pos: Vector2 = get_global_mouse_position()
	line_of_sight.target_position = Globals.player.global_position
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		print("click")
		var space = get_world_2d().direct_space_state
		
		var query = PhysicsRayQueryParameters2D.create(previous_mouse_pos, mouse_pos, 2)
		var result = space.intersect_ray(query)
		if result != {}:
			print(result)

	previous_mouse_pos = mouse_pos
