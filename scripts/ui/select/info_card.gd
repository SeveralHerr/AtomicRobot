extends Panel

## Tilted comic card beside the stage: fighter name, one-line bio, HEALTH and POWER
## pips. Laid out by hand (no Containers) so every piece can be punched by tweens.

const Juice := preload("res://scripts/ui/select/juice.gd")
const SIZE := Vector2(500, 346)
const TILT := 2.0
const PIP := Vector2(40, 30)
const PIP_GAP := 10.0
## Pips start after the row label and must end inside the card, however many there are.
const PIP_LEFT := 140.0
const PIP_ROOM := SIZE.x - PIP_LEFT - 2 * 28.0
const LOCKED_HINT := "KEEP PLAYING TO UNLOCK!"
## Call-to-action per input device, so the prompt never names the wrong button
## (keyboard "A" is ui_left here).
const FIGHT_TEXT := {"pad": "PRESS A TO FIGHT!", "keys": "PRESS ENTER TO FIGHT!", "touch": "TAP AGAIN TO FIGHT!"}

var name_label: Label
var bio_label: Label
var prompt: Label
var lock_icon: TextureRect
var op_badge: Label
## Per stat (0 HEALTH, 1 POWER): pips drawn ("best" on the roster) and the roster's
## second-best value ("usual"); pips past "usual" glow gold. See roster_scale().
var _best := [1, 1]
var _usual := [1, 1]
var stat_rows: Array[Control] = []
var _pips: Array = []  # one Array[Panel] per stat row
var _pip_on: StyleBoxFlat
var _pip_off: StyleBoxFlat
var _pip_gold: StyleBoxFlat
var _motion: Array[Tween] = []  # this card's live tweens; killed on every change


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	pivot_offset = SIZE / 2.0
	rotation_degrees = TILT
	add_theme_stylebox_override("panel", ComicStyle.box(ComicStyle.PAPER, 5, 12, 10))
	_pip_on = ComicStyle.box(ComicStyle.RED, 3, 6, 3)
	_pip_off = ComicStyle.box(ComicStyle.CREAM, 3, 6, 0)
	_pip_gold = ComicStyle.box(ComicStyle.YELLOW, 3, 6, 3)

	name_label = ComicStyle.heading("", 76, ComicStyle.RED)
	name_label.add_theme_constant_override("outline_size", 10)
	name_label.position = Vector2(20, 14)
	name_label.size = Vector2(SIZE.x - 40, 100)
	name_label.pivot_offset = name_label.size / 2.0
	add_child(name_label)

	bio_label = ComicStyle.label("", ComicStyle.LABEL, 34)
	bio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio_label.position = Vector2(24, 112)
	bio_label.size = Vector2(SIZE.x - 48, 72)
	add_child(bio_label)

	for i in 2:
		_add_stat_row(["HEALTH", "POWER"][i], Vector2(28, 188 + i * 54))
	_build_prompt()
	lock_icon = TextureRect.new()
	lock_icon.texture = Juice.LOCK_ICON
	lock_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.size = Vector2(150, 150)
	lock_icon.position = Vector2((SIZE.x - 150) / 2.0, 180)
	lock_icon.modulate = ComicStyle.INK  # the grey pixel lock is mush through the CRT
	lock_icon.pivot_offset = lock_icon.size / 2.0
	lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lock_icon)
	_build_op_badge()


## Read pip scale off the whole roster, once.
func set_roster(configs: Array) -> void:
	var s := roster_scale(configs)
	_best = s.best
	_usual = s.usual


## For each stat, the roster's best and second-best values. Derived, not authored,
## so a rebalance moves the gold line and the OVERPOWERED badge with it.
static func roster_scale(configs: Array) -> Dictionary:
	var best := [1, 1]
	var usual := [1, 1]
	for i in 2:
		var vals: Array = configs.map(func(c: CharacterConfig) -> int:
			return c.get_starting_health() if i == 0 else c.get_starting_damage())
		vals.sort()
		vals.reverse()
		best[i] = vals[0]
		usual[i] = vals[1] if vals.size() > 1 else vals[0]
	return {"best": best, "usual": usual}


## Beats everyone else on BOTH stats.
func is_overpowered(cfg: CharacterConfig) -> bool:
	return cfg.get_starting_health() > _usual[0] and cfg.get_starting_damage() > _usual[1]


func show_character(cfg: CharacterConfig, unlocked: bool) -> void:
	for t in _motion:
		t.kill()
	_motion.clear()
	name_label.text = cfg.get_character_name().to_upper() if unlocked else "LOCKED"
	bio_label.text = bio(cfg) if unlocked else _hint(cfg)
	_motion.append(Juice.pop(name_label, 1.3, 1.0, 0.3))
	for row in stat_rows:
		row.visible = unlocked
	lock_icon.visible = not unlocked
	if not unlocked:
		_motion.append(Juice.pop(lock_icon, 1.4, 1.0, 0.3))
	prompt.visible = unlocked  # the heading already says LOCKED
	if unlocked:
		_fill(0, cfg.get_starting_health())
		_fill(1, cfg.get_starting_damage())
	op_badge.visible = unlocked and is_overpowered(cfg)
	if op_badge.visible:
		_motion.append(Juice.slam(op_badge, -9.0, 0.3))
	var wob := create_tween()
	_motion.append(wob)
	wob.tween_property(self, "rotation_degrees", TILT - 2.5, 0.06)
	wob.tween_property(self, "rotation_degrees", TILT, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## First line of the config description; the "+2 hp" line is drawn as pips instead.
static func bio(cfg: CharacterConfig) -> String:
	return cfg.get_description().split("\n")[0].strip_edges().to_upper()


## Lit pip count per row, for tests and screenshots.
func lit(row: int) -> int:
	var n := 0
	for pip in _pips[row]:
		if pip.visible and pip.get_theme_stylebox("panel") in [_pip_on, _pip_gold]:
			n += 1
	return n


## Gold pips alone read as "more"; the stamp says "this one breaks the rules".
func _build_op_badge() -> void:
	# Red, unlike the yellow prompt: a warning label, not a button.
	op_badge = ComicStyle.label("OVERPOWERED!", ComicStyle.LABEL, 40, ComicStyle.PAPER)
	op_badge.add_theme_stylebox_override("normal", ComicStyle.box(ComicStyle.RED, 4, 8, 5))
	op_badge.size = Vector2(250, 56)
	op_badge.position = Vector2(SIZE.x - 210, -34)
	op_badge.pivot_offset = op_badge.size / 2.0
	op_badge.hide()
	add_child(op_badge)


## Pulsing call to action along the card's bottom edge.
func _build_prompt() -> void:
	prompt = ComicStyle.label(FIGHT_TEXT.pad, ComicStyle.LABEL, 36)
	prompt.add_theme_stylebox_override("normal", ComicStyle.box(ComicStyle.YELLOW, 4, 10, 5))
	prompt.size = Vector2(360, 54)
	prompt.position = Vector2((SIZE.x - prompt.size.x) / 2.0, SIZE.y - 58)
	prompt.pivot_offset = prompt.size / 2.0
	add_child(prompt)
	var pulse := prompt.create_tween().set_loops()
	pulse.tween_property(prompt, "scale", Vector2.ONE * 1.07, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(prompt, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func set_device(device: String) -> void:
	prompt.text = FIGHT_TEXT[device]


func _hint(cfg: CharacterConfig) -> String:
	var h := cfg.get_unlock_hint().strip_edges()
	return h.to_upper() if h != "" else LOCKED_HINT


func _add_stat_row(title: String, at: Vector2) -> void:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = at
	add_child(row)
	var label := ComicStyle.label(title, ComicStyle.LABEL, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size = Vector2(130, PIP.y)
	row.add_child(label)
	stat_rows.append(row)
	_pips.append([])


## Pip i: lit red up to `value`, gold past the roster's usual best, empty after.
## Pitch shrinks so `_best` pips always fit inside the card.
func _fill(row: int, value: int) -> void:
	var pips: Array = _pips[row]
	var of: int = _best[row]
	var pitch := minf(PIP.x + PIP_GAP, PIP_ROOM / of)
	var w := pitch * PIP.x / (PIP.x + PIP_GAP)
	while pips.size() < of:
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_rows[row].add_child(p)
		pips.append(p)
	for i in pips.size():
		var pip: Panel = pips[i]
		pip.visible = i < of
		pip.size = Vector2(w, PIP.y)
		pip.pivot_offset = pip.size / 2.0
		pip.position = Vector2(PIP_LEFT + i * pitch, 0)
		var on := i < value
		var gold: bool = on and i >= int(_usual[row])
		pip.add_theme_stylebox_override("panel", _pip_gold if gold else (_pip_on if on else _pip_off))
		if on:
			pip.scale = Vector2.ZERO
			var t := pip.create_tween()
			_motion.append(t)
			t.tween_interval(0.05 * i)
			t.tween_property(pip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			pip.scale = Vector2.ONE
