extends CanvasLayer
class_name EncounterAnnouncer

## Comic-book callouts for a BuildingDoorEncounter: "WAVE 2/3" slams onto a stripe
## as each wave of a multi-wave squad rumbles at the door, a small "WAVE CLEAR!"
## pops as each earlier wave goes down, and "STREET CLEAR!"
## bursts out when the last wave goes down (the user's pick over "BUSTED!"; it
## counts the door's squad only — ambient maids that walked in before the lock
## can still be up). Reuses the boss fight's BossBanner (one
## text system, not two) and follows atomic-pinball's callout rules: one message at
## a time (a new slam overtakes the old), short holds (well under its 2.5s cap).
##
## Listens to the encounter's signals only — the encounter never calls into it.

## Above the HUD (UI layer 2, score 1), below the pause menu (99) and CRT overlay.
const LAYER := 3
## WAVE n/N is glanced, not read, and timed to the door's rearm (0.7 s): the maids
## step out right after it, so it keeps its short hold (no ReadingTime).
const WAVE_HOLD := 0.55
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
## Seconds BossBanner.slam_title takes to land a title (stripe/burst + title punch).
const SLAM_IN := 0.3
const CLEAR_STING := preload("res://sounds/power_up.wav")
## STREET CLEAR! + its subtitle is the one callout here with words to read and no
## fight waiting on it, so it stays up for the shared pop-up reading time.
static func clear_hold() -> float:
	return ReadingTime.seconds(CLEAR_TITLE + " " + CLEAR_SUB) - SLAM_IN


## Mid-door beat: same burst, smaller, quicker, no sting — it must read as a breath
## between waves, not as the door's payoff, and be gone before the next wave's
## stripe (wave_gap_seconds 0.8 after the kill) slams over it.
const WAVE_CLEAR_TITLE := "WAVE CLEAR!"
const WAVE_CLEAR_SIZE_K := 0.4
const WAVE_CLEAR_HOLD := 0.3

var banner: BossBanner
var _sting: AudioStreamPlayer
var _cleared: bool = false


func _init() -> void:
	name = "EncounterAnnouncer"
	layer = LAYER


## Hook up to `enc`'s wave_started / squad_cleared / encounter_finished.
func watch(enc: Node) -> void:
	enc.wave_started.connect(_on_wave_started)
	enc.wave_cleared.connect(_on_wave_cleared)
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
	_slam(title, wave_subtitle(index, total), STRIPE_Y, SIZE_K, WAVE_HOLD, tint)


func _on_wave_cleared(_index: int, _total: int) -> void:
	_slam(WAVE_CLEAR_TITLE, "", CLEAR_Y, WAVE_CLEAR_SIZE_K, WAVE_CLEAR_HOLD, ComicStyle.BLUE, true)


func _on_squad_cleared() -> void:
	_cleared = true
	_slam(CLEAR_TITLE, CLEAR_SUB, CLEAR_Y, CLEAR_SIZE_K, clear_hold(), ComicStyle.BLUE, true)
	if _sting == null:
		_sting = AudioStreamPlayer.new()
		_sting.stream = CLEAR_STING
		_sting.volume_db = -8.0
		add_child(_sting)
	_sting.play()


## Slam a callout centred at `y` (fraction of screen height) at scale `k`; `burst`
## for a starburst instead of a stripe. Both the stripe and the bursts land on the
## power-up timer stack (down to ~y 340 with both buffs up), and there is no room
## for a burst between it and the player's head, so the timers duck out for the
## callout's life: slam-in + hold, back as it clears away.
func _slam(title: String, sub: String, y: float, k: float, hold: float, tint: Color, burst: bool = false) -> void:
	_banner().stripe_y = y
	banner.size_k = k
	banner.slam_title(title, sub, hold, tint, burst)
	HudFade.duck(get_tree(), HudFade.POWERUPS, SLAM_IN + hold)


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
