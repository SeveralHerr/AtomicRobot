extends CenterContainer

@onready var notification_label: Label = $VBoxContainer/NotificationLabel

func _ready() -> void:
	hide()
	Globals.event.connect(_event_started)

func _event_started(status: bool ) -> void:
	if status:
		notification_label.text = "Event Started"
		reveal_fade(0.4)
		await get_tree().create_timer(2).timeout
		fade_out(0.4)
	else:
		notification_label.text = "Event Completed"
		reveal_fade(0.4)
		await get_tree().create_timer(2).timeout
		fade_out(0.4)		

	

func fade_out(duration: float = 1.0) -> void:
	modulate.a = 1.0
	show()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func reveal_fade(duration: float = 1.0) -> void:
	modulate.a = 0
	show()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
