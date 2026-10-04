extends Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var notification_label: Label = $NotificationLabel
@onready var notification_header: Label = $NotificationLabel4
@onready var interact_label: Label = $InteractLabel
@onready var newpaper: TextureRect = $TextureRect

var can_interact: bool = true
var player_in_area: bool = false
var cooldown_time: float = 300.0 # 5 minutes in seconds
var notification_duration: float = 4.0 # seconds
var newspaper_texts := [
	"City Council Approves New Parking Tax: Breathing Near Meters Now $0.25",
	# Straight quotes only: the body font (AldotheApache) has no curly quote or em
	# dash glyph, and the web build has no system font to fall back on, so a smart
	# quote here renders as a blank box on the deployed mobile page.
	"Meter Maid Union Demands Heavier Quarters: 'These Ones Don't Leave a Dent'",
	"Local Tattoo Artist Wins Award for Most Controversial Dolphin Sleeve",
	"Parking Meter Develops Sentience, Immediately Quits Job",
	"Robot Parade Scheduled for Friday!"
]

## One shuffle bag shared by every stand: a run past all five stands reads all five
## headlines before any repeats. Global RNG, so a seeded autoplay run replays.
static var _headline_bag: Array = []

var _reported := false


static func reset_headline_bag() -> void:
	_headline_bag.clear()


static func next_headline(texts: Array) -> String:
	if _headline_bag.is_empty():
		_headline_bag = texts.duplicate()
		_headline_bag.shuffle()
	return _headline_bag.pop_back()

func _ready() -> void:
	area_2d.body_entered.connect(_on_body_entered)
	area_2d.body_exited.connect(_on_body_exited)
	interact_label.hide()
	notification_label.hide()
	newpaper.hide()
	set_process(true)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and can_interact:
		player_in_area = true
		interact_label.show()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_area = false
		interact_label.hide()

func _process(_delta: float) -> void:
	if player_in_area and can_interact and Input.is_action_just_pressed("Interact"):
		_show_notification()

func _show_notification() -> void:
	can_interact = false
	interact_label.hide()
	notification_label.text = next_headline(newspaper_texts)
	if not _reported:
		_reported = true
		Globals.secret_found.emit("news", str(get_path()))
	reveal_fade(0.4)
	# Timer callbacks, not awaits: a freed stand (scene change) drops the connection
	# instead of resuming a coroutine on a dead instance.
	get_tree().create_timer(notification_duration).timeout.connect(fade_out.bind(0.4))
	get_tree().create_timer(notification_duration + cooldown_time).timeout.connect(_rearm)


func _rearm() -> void:
	can_interact = true
	
func fade_out(duration: float = 1.0) -> void:
	notification_label.modulate.a = 1.0
	newpaper.modulate.a = 1.0
	notification_header.modulate.a = 1.0
	notification_label.show()
	notification_header.show()
	newpaper.show()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(notification_label, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(notification_header, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(newpaper, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func reveal_fade(duration: float = 1.0) -> void:
	notification_label.modulate.a = 0
	newpaper.modulate.a = 0
	notification_header.modulate.a = 0
	notification_label.show()
	notification_header.show()
	newpaper.show()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(newpaper, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(notification_header, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(notification_label, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
