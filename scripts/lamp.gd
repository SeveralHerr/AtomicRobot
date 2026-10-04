extends Sprite2D

## A street lamp: ledge maids turn back at it instead of walking through its head.


func _ready() -> void:
	add_to_group(PlatformPatrolState.BLOCKERS_GROUP)
