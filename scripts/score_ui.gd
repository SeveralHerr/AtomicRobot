extends CanvasLayer

## Score / combo / active-power-up HUD, plus the end-of-stage rank card.
##
## Injected into the running level by ScoreSystem rather than authored into each
## level scene: it is driven entirely by autoload signals, so there is nothing to
## wire up per level, and one injection point covers main.tscn, boss_room.tscn and
## every enemy sandbox under test/scenes/ without three copies drifting apart.
##
## The whole HUD is one column centred at the top of the screen, in the same Bangers
## face (styles/white_font.tres) the character-select screen uses, so score, combo and
## buff timers all read from one spot. It starts at y=126 rather than hard against the
## top edge: the health orbs run to x=544, y=118, and the column is wide enough that a
## long buff line ("ATOMIC RAGE 8.0") would otherwise clip their right-hand orb.
##
## The rank card deliberately centres in the TOP 45% of the screen: the existing Win
## container (scripts/win_container.gd) shows its RESTART button dead-centre on the
## same boss_death signal, and this layer draws above it.

@onready var score_label: Label = $Hud/Rows/ScoreLabel
@onready var combo_label: Label = $Hud/Rows/ComboLabel
@onready var combo_bar: ProgressBar = $Hud/Rows/ComboBar
@onready var powerup_label: Label = $Hud/Rows/PowerupLabel
@onready var rank_card: CenterContainer = $RankCard
@onready var rank_label: Label = $RankCard/Panel/Lines/RankLabel
@onready var breakdown_label: Label = $RankCard/Panel/Lines/Breakdown
@onready var best_label: Label = $RankCard/Panel/Lines/BestLabel

## Bar/label colour per multiplier tier, indexed by multiplier - 1. Runs cool-to-hot
## so the tier is readable from peripheral vision without reading the number.
const MULTIPLIER_COLORS: Array[Color] = [
	Color(1.00, 1.00, 1.00),
	Color(1.00, 0.95, 0.55),
	Color(1.00, 0.85, 0.20),
	Color(1.00, 0.62, 0.12),
	Color(1.00, 0.38, 0.10),
	Color(1.00, 0.22, 0.30),
	Color(0.90, 0.35, 1.00),
	Color(0.45, 0.90, 1.00),
]

## Score rolls up toward the real value instead of snapping, arcade-style. Minimum
## roll rate in points/sec, so small awards still visibly tick over.
const SCORE_ROLL_MIN := 400.0
const SCORE_ROLL_CATCHUP := 6.0

var _shown_score: float = 0.0
var _last_multiplier: int = 1


func _ready() -> void:
	rank_card.hide()
	ScoreSystem.score_changed.connect(_on_score_changed)
	ScoreSystem.combo_changed.connect(_on_combo_changed)
	ScoreSystem.stage_started.connect(_on_stage_started)
	ScoreSystem.stage_finished.connect(_on_stage_finished)
	_shown_score = float(ScoreSystem.score)
	_on_combo_changed(ScoreSystem.combo, ScoreSystem.multiplier())


func _process(delta: float) -> void:
	_roll_score(delta)
	_refresh_combo_bar()
	_refresh_powerups()


func _roll_score(delta: float) -> void:
	var target := float(ScoreSystem.score)
	var rate := maxf(SCORE_ROLL_MIN, absf(target - _shown_score) * SCORE_ROLL_CATCHUP)
	_shown_score = move_toward(_shown_score, target, rate * delta)
	score_label.text = "%08d" % roundi(_shown_score)


func _refresh_combo_bar() -> void:
	var fraction := ScoreSystem.combo_fraction()
	combo_bar.value = fraction
	combo_bar.visible = fraction > 0.0


func _refresh_powerups() -> void:
	var ids := PowerupSystem.active_ids()
	if ids.is_empty():
		powerup_label.text = ""
		return
	var parts: Array[String] = []
	for id in ids:
		parts.append("%s %.1f" % [PowerupRules.label(id), PowerupSystem.remaining(id)])
	powerup_label.text = "\n".join(parts)
	# Tint to the buff that is actually running (the first, in PowerupRules.IDS
	# order, when two overlap) so the HUD colour matches the character's recolour.
	powerup_label.add_theme_color_override("font_color", PowerupRules.color(ids[0]))


func _on_score_changed(_score: int) -> void:
	pass  # The roll-up in _process reads ScoreSystem.score directly.


func _on_combo_changed(combo: int, multiplier: int) -> void:
	var color := _color_for(multiplier)
	if combo <= 0:
		combo_label.text = ""
	else:
		combo_label.text = "x%d  ·  %d HIT%s" % [multiplier, combo, "" if combo == 1 else "S"]
	combo_label.add_theme_color_override("font_color", color)
	combo_bar.modulate = color
	if multiplier > _last_multiplier:
		_pop(combo_label)
	_last_multiplier = multiplier


func _color_for(multiplier: int) -> Color:
	var index := clampi(multiplier - 1, 0, MULTIPLIER_COLORS.size() - 1)
	return MULTIPLIER_COLORS[index]


## Quick scale punch when the multiplier tiers up — the one moment in the HUD that
## deserves to grab the eye.
func _pop(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.35, 1.35), 0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)


func _on_stage_started(_scene_path: String) -> void:
	rank_card.hide()
	_shown_score = 0.0
	_last_multiplier = 1


func _on_stage_finished(result: Dictionary) -> void:
	rank_label.text = String(result.get("rank", "?"))
	rank_label.add_theme_color_override("font_color", _rank_color(String(result.get("rank", ""))))
	var seconds := float(result.get("seconds", 0.0))
	var lines: Array[String] = [
		"FIGHT  %d" % int(result.get("fight_score", 0)),
		"TIME  %d:%02d   +%d" % [int(seconds) / 60, int(seconds) % 60, int(result.get("time_bonus", 0))],
		"%s  +%d" % [
			"NO DAMAGE" if bool(result.get("perfect", false)) else "HEALTH LEFT",
			int(result.get("no_damage_bonus", 0)),
		],
		"TOTAL  %d" % int(result.get("total", 0)),
	]
	breakdown_label.text = "\n".join(lines)
	if bool(result.get("is_new_best", false)):
		best_label.text = "NEW BEST!"
	else:
		best_label.text = "BEST  %d" % int(result.get("best", 0))
	rank_card.show()
	_pop(rank_label)


func _rank_color(rank: String) -> Color:
	match rank:
		"S": return Color(0.45, 0.90, 1.00)
		"A": return Color(1.00, 0.85, 0.20)
		"B": return Color(0.80, 1.00, 0.60)
		"C": return Color(1.00, 1.00, 1.00)
		_: return Color(0.75, 0.75, 0.75)
