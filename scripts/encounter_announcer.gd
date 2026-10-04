extends CanvasLayer
class_name EncounterAnnouncer

## Comic-book callouts for a BuildingDoorEncounter: "WAVE 2/3" slams onto a stripe
## as each wave of a multi-wave squad rumbles at the door, and "STREET CLEAR!"
## bursts out when the last wave goes down (the user's pick over "BUSTED!"; it
## counts the door's squad only — ambient maids that walked in before the lock
## can still be up). Reuses the boss fight's BossBanner (one
## text system, not two) and follows atomic-pinball's callout rules: one message at
## a time (a new slam overtakes the old), short holds (well under its 2.5s cap).
##
## Listens to the encounter's signals only — the encounter never calls into it.

## Above the HUD (UI layer 2, score 1), below the pause menu (99) and CRT overlay.
const LAYER := 3
const WAVE_HOLD := 0.55
const CLEAR_HOLD := 0.9
const CLEAR_TITLE := "STREET CLEAR!"
const CLEAR_SUB := "GO! GO! GO!"
## Stripe centre as a fraction of screen height, and callout scale: together they
## keep even the payoff starburst between the HUD rows and the heads of
## maids on the walkway lane (the boss room's 0.42 at full size buries both).
const STRIPE_Y := 0.36
const SIZE_K := 0.8
## The payoff burst sits lower and smaller than the wave stripe: at STRIPE_Y its
## top spikes hid the score, and at 0.42 / SIZE_K they still cut the combo line
## ("3 HITS!") that the clearing blow had just bumped. The squad is down by then,
## so only the player's lane is below it, and the burst stops short of his head.
const CLEAR_Y := 0.45
const CLEAR_SIZE_K := 0.5
const CLEAR_STING := preload("res://sounds/power_up.wav")

var banner: BossBanner
var _sting: AudioStreamPlayer
var _cleared: bool = false


func _init() -> void:
	name = "EncounterAnnouncer"
	layer = LAYER


## Hook up to `enc`'s wave_started / squad_cleared / encounter_finished.
func watch(enc: Node) -> void:
	enc.wave_started.connect(_on_wave_started)
	enc.squad_cleared.connect(_on_squad_cleared)
	enc.encounter_finished.connect(_on_finished)


## Banner title for wave `index` (1-based) of `total`; "" when there is nothing to
## announce (a one-wave squad just bursts out — the door is telegraph enough).
static func wave_title(index: int, total: int) -> String:
	if total <= 1:
		return ""
	return "WAVE %d/%d" % [index, total]


static func wave_subtitle(index: int, total: int) -> String:
	if index >= total:
		return "LAST ONES!"
	return "HERE THEY COME!" if index == 1 else "MORE MAIDS!"


func _on_wave_started(index: int, total: int) -> void:
	var title := wave_title(index, total)
	if title == "":
		return
	# Yellow title on blue reads; on orange it washed out. Red marks the last wave.
	var tint := ComicStyle.RED if index >= total else ComicStyle.BLUE
	_banner().stripe_y = STRIPE_Y
	banner.size_k = SIZE_K
	banner.slam_title(title, wave_subtitle(index, total), WAVE_HOLD, tint)


func _on_squad_cleared() -> void:
	_cleared = true
	_banner().stripe_y = CLEAR_Y
	banner.size_k = CLEAR_SIZE_K
	banner.slam_title(CLEAR_TITLE, CLEAR_SUB, CLEAR_HOLD, ComicStyle.BLUE, true)
	if _sting == null:
		_sting = AudioStreamPlayer.new()
		_sting.stream = CLEAR_STING
		_sting.volume_db = -8.0
		add_child(_sting)
	_sting.play()


## A forced end (player death, watchdog) cuts any callout still on screen: a
## "WAVE 3/3" sliding over the death beat would read as the fight carrying on.
func _on_finished() -> void:
	if not _cleared:
		visible = false


## Built on first use: most encounters a player never reaches cost nothing.
func _banner() -> BossBanner:
	visible = true
	if banner == null:
		banner = BossBanner.new()
		add_child(banner)
		banner.landed.connect(_thud)
		# Sized by hand, not by full-rect anchors: those haven't laid out on the
		# frame the banner is added (wave 1 slams that same frame), and slam_title
		# centres on `size`. Top-left anchors so setting size is legal.
		banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	banner.size = banner.get_viewport_rect().size
	return banner


func _thud() -> void:
	ScreenShake.apply_shake(4)
