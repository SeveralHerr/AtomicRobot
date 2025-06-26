extends Node
const CHAT_BUBBLE_CONTAINER: PackedScene = preload("res://scenes/chat_bubble_container.tscn")

func create(parent: Node, text: String) -> void:
	if parent.has_node("ChatBubble"):
		var existing_chat_bubble = parent.get_node("ChatBubble")
		existing_chat_bubble.queue_free()
	
	var instance = CHAT_BUBBLE_CONTAINER.instantiate()
	instance.name = "ChatBubble"
	var label = instance.get_node("ChatBubble/PanelContainer/MarginContainer/Label")
	label.text = text

	parent.add_child(instance)
	instance.global_position = Vector2(parent.global_position.x, parent.global_position.y - 63)

	instance.show()
	
	await parent.get_tree().create_timer(2).timeout
	if instance != null:
		instance.queue_free()
	
