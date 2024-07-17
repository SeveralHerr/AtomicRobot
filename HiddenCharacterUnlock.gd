extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	$Indicator.hide()
	pass # Replace with function body.


func _input(event: InputEvent) -> void:
	if $Indicator.visible: 
		if event.is_action_pressed("ui_down"):
			Config.cody_unlocked = true
			print("Unlocked Cody")
			
			queue_free()
	pass

func _on_enter(body: Node2D) -> void: 
	$Indicator.show()
	
func _on_exit(body: Node2D) -> void: 
	$Indicator.hide()
