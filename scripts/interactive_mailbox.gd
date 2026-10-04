extends Sprite2D

## A newspaper stand. Interact at it to read today's headline on a comic card
## (scripts/ui/news_card.gd) in the screen's left column; the first read is a secret
## (Globals.secret_found "news"). The paper stays up while the player stays at the
## stand, and for at least ReadingTime.seconds() once they walk off; Interact at the
## stand again re-reads the same paper (no new credit).

@onready var area_2d: Area2D = $Area2D
@onready var interact_label: Label = $InteractLabel

var player_in_area: bool = false
var newspaper_texts := [
	"City Council Approves New Parking Tax: Breathing Near Meters Now $0.25",
	# Straight quotes only: the fonts have no curly quote or em dash glyph, and the
	# web build has no system font to fall back on, so a smart quote here renders as
	# a blank box on the deployed mobile page.
	"Meter Maid Union Demands Heavier Quarters: 'These Ones Don't Leave a Dent'",
	"Local Tattoo Artist Wins Award for Most Controversial Dolphin Sleeve",
	"Parking Meter Develops Sentience, Immediately Quits Job",
	"Robot Parade Scheduled for Friday!"
]
## The card's headline label (the autoplay recorder reads `.text` on secret_found).
var notification_label: Label

## One shuffle bag shared by every stand: a run past all five stands reads all five
## headlines before any repeats. Global RNG, so a seeded autoplay run replays.
static var _headline_bag: Array = []

var _reported := false
## This stand's paper, drawn from the bag on the first read and kept for re-reads.
var _headline := ""
var _card: NewsCard
## Seconds the paper has been up this time.
var _shown_for := 0.0


static func reset_headline_bag() -> void:
	_headline_bag.clear()


static func next_headline(texts: Array) -> String:
	if _headline_bag.is_empty():
		_headline_bag = texts.duplicate()
		_headline_bag.shuffle()
	return _headline_bag.pop_back()


## Least time the paper stays up once the player walks off (the shared pop-up rule).
static func min_read_seconds(text: String) -> float:
	return ReadingTime.seconds(text)


func _ready() -> void:
	area_2d.body_entered.connect(_on_body_entered)
	area_2d.body_exited.connect(_on_body_exited)
	interact_label.hide()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_area = true
		_refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_area = false
		_refresh_prompt()


func _process(delta: float) -> void:
	if player_in_area and not is_reading() and Input.is_action_just_pressed("Interact"):
		_show_notification()
	advance(delta)


func is_reading() -> bool:
	return _card != null and _card.is_open()


## Open the paper (first read: draw a headline and claim the secret).
func _show_notification() -> void:
	if _headline == "":
		_headline = next_headline(newspaper_texts)
	if _card == null:
		_card = NewsCard.new()
		add_child(_card)
		notification_label = _card.headline
	_card.open(_headline, get_global_transform_with_canvas().origin)
	_shown_for = 0.0
	if not _reported:
		_reported = true
		Globals.secret_found.emit("news", str(get_path()))
	_refresh_prompt()


## Count `delta` seconds of reading; fold the paper once the player has walked off
## AND it has been up long enough to read.
func advance(delta: float) -> void:
	if not is_reading():
		return
	_shown_for += delta
	if not player_in_area and _shown_for >= min_read_seconds(_headline):
		_card.close()
		_refresh_prompt()


## "[interact]" over the stand whenever pressing it would open the paper.
func _refresh_prompt() -> void:
	interact_label.visible = player_in_area and not is_reading()
