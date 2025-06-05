extends MeleeMeterMaid
class_name MeterMaid3

## Legacy melee meter maid class - now inherits from MeleeMeterMaid

func _ready() -> void:
	super._ready()
	Globals.player_death.connect(_on_player_death)

func _on_player_death() -> void:
	# Could handle player death if needed
	pass
