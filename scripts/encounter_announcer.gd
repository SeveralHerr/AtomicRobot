extends CanvasLayer
class_name EncounterAnnouncer

## Comic-book callouts for a BuildingDoorEncounter: "WAVE 2/3" slams onto a stripe
## as each wave of a multi-wave squad rumbles at the door, and "STREET CLEAR!"
## bursts out when the last wave goes down. Reuses the boss fight's BossBanner (one
## text system, not two) and follows atomic-pinball's callout rules: one message at
## a time (a new slam overtakes the old), short holds (well under its 2.5s cap).
##
## Listens to the encounter's signals only — the encounter never calls into it.

## Above the HUD (UI layer 2, score 1), below the pause menu (99) and CRT overlay.
const LAYER := 3
const WAVE_HOLD := 0.55
const CLEAR_HOLD := 0.9
const CLEAR_STING := preload("res://sounds/power_up.wav")

var banner: BossBanner
var _sting: AudioStreamPlayer
var _cleared: bool = false


func _init() -> void:
	name = "EncounterAnnouncer"
	layer = LAYER


## Hook up to `enc`'s wave_started / street_cleared / encounter_finished.
func watch(enc: Node) -> void:
	enc.wave_started.connect(_on_wave_started)
	enc.street_cleared.connect(_on_street_cleared)
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
	var tint := ComicStyle.RED if index >= total else ComicStyle.ORANGE
	_banner().slam_title(title, wave_subtitle(index, total), WAVE_HOLD, tint)


func _on_street_cleared() -> void:
	_cleared = true
	_banner().slam_title("STREET CLEAR!", "GO! GO! GO!", CLEAR_HOLD, ComicStyle.BLUE, true)
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
	# Sized explicitly: a CanvasLayer child's anchors haven't laid out on the frame
	# it was added, and slam_title centres on `size`.
	banner.size = banner.get_viewport_rect().size
	return banner


func _thud() -> void:
	ScreenShake.apply_shake(4)
