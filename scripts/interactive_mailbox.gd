extends Sprite2D

## A newspaper stand. Interact at it to read today's headline: a front page
## (scripts/ui/news_card.gd) spins in and pauses the game until the player folds it.
## The first read is a secret (Globals.secret_found "news"); Interact at the stand
## again re-reads the same paper (no new credit).

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
## Front-page photo: the first [keyword, SpriteFrames or Texture2D path] whose
## keyword is in the headline (a SpriteFrames shows its "idle" first frame).
const PHOTOS := [
	["Council", "res://sprites/boss_ani.tres"],
	["Union", "res://sprites/metermaid_sprite_frames.tres"],
	["Tattoo", "res://sprites/cody_sprite_frames.tres"],
	["Parking Meter", "res://images/new/Parking_Meter.png"],
	["Robot", "res://sprites/robot_sprite_frames.tres"],
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
## False for a moment after the paper folds: a mash through the fold must not re-open
## it the moment the game resumes (autoplay read one stand three times that way).
var _reopen_ok := true


static func reset_headline_bag() -> void:
	_headline_bag.clear()


static func next_headline(texts: Array) -> String:
	if _headline_bag.is_empty():
		_headline_bag = texts.duplicate()
		_headline_bag.shuffle()
	return _headline_bag.pop_back()


static func photo_for(text: String) -> Texture2D:
	for p: Array in PHOTOS:
		if text.contains(p[0]):
			var res: Resource = load(p[1])
			return _cropped(res.get_frame_texture(&"idle", 0) if res is SpriteFrames else res as Texture2D)
	return null


## `tex` cut to its opaque pixels, so the subject fills the photo instead of
## standing small in its animation cell.
static func _cropped(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:  # headless dummy renderer
		return tex
	var used := Rect2(img.get_used_rect())
	var out := AtlasTexture.new()
	out.atlas = tex.atlas if tex is AtlasTexture else tex
	var origin: Vector2 = tex.region.position if tex is AtlasTexture else Vector2.ZERO
	out.region = Rect2(origin + used.position, used.size)
	return out


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


func _process(_delta: float) -> void:
	if player_in_area and not is_reading() and Input.is_action_just_pressed("Interact") \
			and _reopen_ok:
		_show_notification()


func is_reading() -> bool:
	return _card != null and _card.is_open()


## Open the paper (first read: draw a headline and claim the secret).
func _show_notification() -> void:
	if _headline == "":
		_headline = next_headline(newspaper_texts)
	if _card == null:
		_card = NewsCard.new()
		add_child(_card)
		_card.closed.connect(_on_paper_closed)
		notification_label = _card.headline
	_card.open(_headline, photo_for(_headline))
	if not _reported:
		_reported = true
		Globals.secret_found.emit("news", str(get_path()))
	_refresh_prompt()


func _on_paper_closed() -> void:
	_reopen_ok = false
	get_tree().create_timer(NewsCard.ARM_SECONDS, true, false, true).timeout.connect(
		func() -> void: _reopen_ok = true)
	_refresh_prompt()


## "[interact]" over the stand whenever pressing it would open the paper.
func _refresh_prompt() -> void:
	interact_label.visible = player_in_area and not is_reading()
