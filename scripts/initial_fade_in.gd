extends Control

@onready var fade_overlay: FadeOverlay = $FadeOverlay

func _ready() -> void:
	fade_overlay.fade_in()
