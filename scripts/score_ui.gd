extends CanvasLayer

## Score / combo / active-power-up HUD. The end-of-run rank, initials and high-score
## list live on the level's EndCard (scripts/ui/end_card.gd), not here.
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
## Every live animation here runs off a decaying float ticked in _process rather than
## off a Tween. Hits, kills and pickups arrive faster than a tween's duration during a
## real scrap, and overlapping tweens on the same property fight each other and leave a
## label stuck scaled or tinted — the same failure scripts/health_container.gd works
## around with its per-orb tween bookkeeping. A float that is re-set to 1.0 on every
## event simply restarts the animation, which is exactly the wanted behaviour.

@onready var hud: Control = $Hud
@onready var score_label: Label = $Hud/Rows/ScoreLabel
@onready var combo_label: Label = $Hud/Rows/ComboSlot/ComboLabel
@onready var powerup_label: Label = $Hud/Rows/PowerupLabel

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

## --- Score punch -------------------------------------------------------------
## Seconds for a score award's punch to settle back to rest.
const SCORE_POP_TIME := 0.24
## Extra scale at the instant of an award, before it is scaled by the award's size.
const SCORE_POP_SCALE := 0.20
## Award worth a full-strength punch. A hit at 1x is 10 points and a kill at 8x is
## 800, so scaling between them is what makes a big kill read differently from a jab.
const SCORE_POP_FULL_AWARD := 400.0
## ...but never punch less than this fraction of full, or ordinary hits look dead.
const SCORE_POP_MIN := 0.4

## --- Combo readout -----------------------------------------------------------
## This used to be "x3  ·  12 HITS" sitting over a draining ProgressBar. It is now
## just the hit count: each hit scrolls the line up from below with a scale punch, and
## the line fades and drifts upward as the combo window drains. The fade IS the timer,
## which is why the bar is gone — one moving element instead of two static ones.
const COMBO_POP_TIME := 0.30
const COMBO_POP_SCALE := 0.45
## Bigger punch on the hit that tiers the multiplier up — the one moment in the combo
## worth grabbing the eye, now that the "x3" that used to announce it is gone.
const COMBO_TIER_POP_SCALE := 0.95
## Pixels below rest the line scrolls up from on each hit.
const COMBO_POP_RISE := 18.0
## Pixels the line floats up over a full combo window as it fades out.
const COMBO_DRIFT := 16.0
## Exponent on the remaining-window fraction that becomes alpha. Below 1 it holds the
## line bright through most of the window and drops it off late, so the fade reads as
## "you are about to lose this" rather than as a constant dimming.
const COMBO_FADE_EXP := 0.65
## Hits before the line shows: a lone "1 HIT!" is not a combo, just noise on every
## first jab. The first hit still scores and opens the window the second extends.
const COMBO_MIN_SHOWN := 2

## --- Power-up timers ---------------------------------------------------------
const POWERUP_POP_TIME := 0.35
const POWERUP_POP_SCALE := 0.35
## Seconds left at which a buff starts blinking so it can be seen running out.
const POWERUP_WARN_SECONDS := 1.5
## Full blinks per second during that warning window.
const POWERUP_WARN_HZ := 4.0

var _shown_score: float = 0.0
var _last_multiplier: int = 1
var _last_score: int = 0

var _score_pop: float = 0.0
var _score_pop_amount: float = 0.0
## Last colour actually pushed onto each label. add_theme_color_override() notifies the
## whole control on every call, so the per-frame animations only push on a change —
## which means they push nothing at all once the animation has settled.
var _score_color: Color = Color.WHITE

var _combo_pop: float = 0.0
var _combo_pop_amount: float = 0.0

var _powerup_pop: float = 0.0
var _powerup_color: Color = Color.WHITE



func _ready() -> void:
	ScoreSystem.score_changed.connect(_on_score_changed)
	ScoreSystem.combo_changed.connect(_on_combo_changed)
	ScoreSystem.stage_started.connect(_on_stage_started)
	PowerupSystem.powerup_started.connect(_on_powerup_started)
	# The run is over: the EndCard shows the final score, and a still-rolling fight
	# score above it would disagree with it.
	Globals.player_death.connect(_on_run_ended)
	Globals.boss_death.connect(_on_run_ended)
	_shown_score = float(ScoreSystem.score)
	_last_score = ScoreSystem.score
	_on_combo_changed(ScoreSystem.combo, ScoreSystem.multiplier())


func _process(delta: float) -> void:
	_roll_score(delta)
	_animate_score(delta)
	_animate_combo(delta)
	_refresh_powerups(delta)


func _roll_score(delta: float) -> void:
	var target := float(ScoreSystem.score)
	var rate := maxf(SCORE_ROLL_MIN, absf(target - _shown_score) * SCORE_ROLL_CATCHUP)
	_shown_score = move_toward(_shown_score, target, rate * delta)
	score_label.text = "%08d" % roundi(_shown_score)


## Punch the score line on an award and flash it toward the combo tier's colour, so a
## kill landed deep in a combo is visibly worth more than the first jab of one.
func _animate_score(delta: float) -> void:
	_score_pop = maxf(0.0, _score_pop - delta / SCORE_POP_TIME)
	# Squared, so most of the travel happens in the first frames and the tail is a
	# gentle settle rather than a linear slide.
	var pop := _score_pop * _score_pop
	score_label.pivot_offset = score_label.size * 0.5
	score_label.scale = Vector2.ONE * (1.0 + _score_pop_amount * pop)
	var color := Color.WHITE.lerp(_color_for(ScoreSystem.multiplier()), pop)
	if color != _score_color:
		_score_color = color
		score_label.add_theme_color_override("font_color", color)


func _animate_combo(delta: float) -> void:
	var fraction := ScoreSystem.combo_fraction()
	if ScoreSystem.combo < COMBO_MIN_SHOWN or fraction <= 0.0:
		# Hidden rather than left at alpha 0: a transparent-but-visible Control still
		# costs a draw, and validate-ui flags it as a ui_transparent issue.
		combo_label.visible = false
		return
	combo_label.visible = true
	_combo_pop = maxf(0.0, _combo_pop - delta / COMBO_POP_TIME)
	var pop := _combo_pop * _combo_pop
	combo_label.pivot_offset = combo_label.size * 0.5
	combo_label.scale = Vector2.ONE * (1.0 + _combo_pop_amount * pop)
	# Scroll up from below on the hit, then keep drifting up as the window drains. The
	# label owns its position outright — that is what the plain ComboSlot Control it
	# sits in is for, since a VBoxContainer would re-sort it back every time the text
	# changed width.
	combo_label.position.y = COMBO_POP_RISE * pop - COMBO_DRIFT * (1.0 - fraction)
	combo_label.modulate.a = pow(fraction, COMBO_FADE_EXP)


func _refresh_powerups(delta: float) -> void:
	_powerup_pop = maxf(0.0, _powerup_pop - delta / POWERUP_POP_TIME)
	var ids := PowerupSystem.active_ids()
	if ids.is_empty():
		powerup_label.text = ""
		powerup_label.modulate.a = 1.0
		powerup_label.scale = Vector2.ONE
		return
	var parts: Array[String] = []
	var soonest := INF
	for id in ids:
		var left := PowerupSystem.remaining(id)
		soonest = minf(soonest, left)
		parts.append("%s %.1f" % [PowerupRules.label(id), left])
	powerup_label.text = "\n".join(parts)
	# Tint to the buff that is actually running (the first, in PowerupRules.IDS
	# order, when two overlap) so the HUD colour matches the character's recolour.
	var color := PowerupRules.color(ids[0])
	if color != _powerup_color:
		_powerup_color = color
		powerup_label.add_theme_color_override("font_color", color)

	var pop := _powerup_pop * _powerup_pop
	powerup_label.pivot_offset = powerup_label.size * 0.5
	powerup_label.scale = Vector2.ONE * (1.0 + POWERUP_POP_SCALE * pop)
	# Blink out the last second and a half so a buff about to lapse is noticed without
	# having to read the number. Driven off the countdown itself, so the blink lands on
	# the same beat every time rather than wherever a free-running clock happens to be.
	if soonest <= POWERUP_WARN_SECONDS:
		powerup_label.modulate.a = 0.4 + 0.6 * absf(sin(soonest * PI * POWERUP_WARN_HZ))
	else:
		powerup_label.modulate.a = 1.0


func _on_score_changed(score: int) -> void:
	# The roll-up in _process reads ScoreSystem.score directly; this only sizes the
	# punch. A stage reset lands here with score 0 and must not fire one.
	var award := score - _last_score
	_last_score = score
	if award <= 0:
		return
	var strength := clampf(float(award) / SCORE_POP_FULL_AWARD, SCORE_POP_MIN, 1.0)
	_score_pop = 1.0
	_score_pop_amount = SCORE_POP_SCALE * strength


func _on_combo_changed(combo: int, multiplier: int) -> void:
	if combo < COMBO_MIN_SHOWN:
		combo_label.text = ""
		combo_label.visible = false
		_last_multiplier = multiplier
		return
	combo_label.text = "%d HITS!" % combo
	combo_label.add_theme_color_override("font_color", _color_for(multiplier))
	_combo_pop = 1.0
	_combo_pop_amount = COMBO_TIER_POP_SCALE if multiplier > _last_multiplier else COMBO_POP_SCALE
	_last_multiplier = multiplier


func _on_powerup_started(_id: String, _duration: float) -> void:
	_powerup_pop = 1.0


func _color_for(multiplier: int) -> Color:
	var index := clampi(multiplier - 1, 0, MULTIPLIER_COLORS.size() - 1)
	return MULTIPLIER_COLORS[index]


func _on_run_ended() -> void:
	hud.hide()


func _on_stage_started(_scene_path: String) -> void:
	hud.show()
	_shown_score = 0.0
	_last_score = 0
	_last_multiplier = 1
	_score_pop = 0.0
	_combo_pop = 0.0
	_powerup_pop = 0.0
