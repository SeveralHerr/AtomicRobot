extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	$Indicator.hide()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_enter(body: Node2D) -> void: 
	$Indicator.show()
	
func _on_exit(body: Node2D) -> void: 
	$Indicator.hide()
