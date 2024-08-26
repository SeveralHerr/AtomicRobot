extends Node
const CHAT_BUBBLE_CONTAINER: PackedScene = preload("res://scenes/chat_bubble_container.tscn")

func create(parent: Node, text: String) -> void:
	var instance = CHAT_BUBBLE_CONTAINER.instantiate()
	var label = instance.get_node("ChatBubble/PanelContainer/MarginContainer/Label")
	label.text = text

	parent.add_child(instance)
	#instance.position = parent.position
	instance.show()
	
	await parent.get_tree().create_timer(2).timeout
	if instance != null:
		instance.queue_free()
	
