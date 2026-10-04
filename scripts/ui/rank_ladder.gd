class_name RankLadder
extends VBoxContainer

## The end card's rank ladder (under the stamp and score in RunSummary): a chip per
## rank with its threshold, the run's rank lit, then one line saying how far the
## next rank is and the one thing in THIS run that would have got there.
##
## Player report: "my best full clear got ~7k points but still rank C. What do I need
## for a better rank?" The thresholds lived only in score_rules.gd. Chips and gaps
## are derived from ScoreRules.RANK_THRESHOLDS, so re-pinned thresholds show as-is.

## A clear faster than this is not a promise the tip makes (the bot's best 100% run
## is ~180 s).
const FASTEST_SECONDS := 150.0
const CHIP_SIZE := Vector2(72, 36)
const LINE_SIZE := 25
const COMBO_TIP := "CHAIN COMBOS: KILLS PAY UP TO x8"

## Rank letter -> its chip (PanelContainer, meta "lit").
var chips: Dictionary = {}
## One line: the gap to the next rank, then the tip ("+800 FOR B (9,500) · FIND 4
## MORE SECRETS"). One line, not two: the card's tallest state must fit the CRT.
var next_label: Label


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	for letter in ladder_letters():
		var chip := _chip(letter)
		chips[letter] = chip
		row.add_child(chip)
	next_label = ComicStyle.label("", ComicStyle.LABEL, LINE_SIZE, ComicStyle.PLUM)
	add_child(next_label)


## Rank letters worst to best, from the rules table.
static func ladder_letters() -> Array:
	var out: Array = []
	for entry in ScoreRules.RANK_THRESHOLDS:
		out.push_front(String(entry[0]))
	return out


static func threshold_of(letter: String) -> int:
	for entry in ScoreRules.RANK_THRESHOLDS:
		if String(entry[0]) == letter:
			return int(entry[1])
	return 0


## 9500 -> "9.5K", 18000 -> "18K", 0 -> "0".
static func short_points(points: int) -> String:
	if points < 1000:
		return str(points)
	var k := points / 1000.0
	return ("%dK" % int(k)) if is_equal_approx(k, roundf(k)) else ("%.1fK" % k)


## "+800 FOR B (9,500)", "TOP RANK!", or on a death how to get ranked at all.
static func next_text(total: int, won: bool = true) -> String:
	if not won:
		return "CLEAR THE BOSS TO GET RANKED"
	var gap := ScoreRules.points_to_next_rank(total)
	if gap <= 0:
		return "TOP RANK!"
	var next := ScoreRules.rank_for(total + gap)
	return "+%s FOR %s (%s)" % [ComicStyle.format_score(gap), next,
		ComicStyle.format_score(threshold_of(next))]


## The one change to this run that would have reached the next rank, cheapest kind
## first: unfound secrets, a flawless clear, a faster clear, else bigger combos.
## "" at the top rank.
static func tip_text(run: Dictionary) -> String:
	var gap := ScoreRules.points_to_next_rank(int(run.get("total", 0)))
	if gap <= 0:
		return ""
	var totals: Dictionary = run.get("secret_totals", {})
	var found: Dictionary = run.get("secrets", {})
	var missing := 0
	for kind in totals:
		missing += maxi(0, int(totals[kind]) - int(found.get(kind, 0)))
	if missing * ScoreRules.POINTS_PER_SECRET >= gap:
		var n := ceili(float(gap) / ScoreRules.POINTS_PER_SECRET)
		return "FIND %d MORE SECRET%s" % [n, "" if n == 1 else "S"]
	if ScoreRules.PERFECT_BONUS - int(run.get("no_damage_bonus", 0)) >= gap:
		return "CLEAR IT WITHOUT A HIT"
	var save := ceili(float(gap) / ScoreRules.POINTS_PER_SECOND_SAVED)
	var seconds := float(run.get("seconds", 0.0))
	if seconds < ScoreRules.PAR_SECONDS:
		if seconds - save >= FASTEST_SECONDS:
			return "FINISH %s FASTER" % _clock(save)
	elif ScoreRules.PAR_SECONDS - save >= FASTEST_SECONDS:
		return "FINISH UNDER %s" % _clock(int(ScoreRules.PAR_SECONDS) - save)
	return COMBO_TIP


static func _clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


## Fill from a ScoreSystem.last_run.
func show_run(run: Dictionary, won: bool) -> void:
	var rank := String(run.get("rank", ""))
	for letter in chips:
		_light(chips[letter], letter == rank)
	next_label.text = line_text(run, won)


## The ladder's line for `run`: next_text, plus " · " and the tip on a ranked clear.
static func line_text(run: Dictionary, won: bool) -> String:
	var ranked := won and String(run.get("rank", "")) != ""
	var text := next_text(int(run.get("total", 0)), ranked)
	var tip := tip_text(run) if ranked else ""
	return text if tip == "" else text + " · " + tip


func _chip(letter: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = CHIP_SIZE
	chip.set_meta("lit", false)
	# Side by side: stacked, Komika's tall line height ran the letter into its points.
	var col := HBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(col)
	var l := ComicStyle.label(letter, ComicStyle.DISPLAY, 22, ComicStyle.INK)
	l.name = "Letter"
	col.add_child(l)
	var t := ComicStyle.label(short_points(threshold_of(letter)), ComicStyle.LABEL, 17, ComicStyle.PLUM)
	t.name = "Points"
	col.add_child(t)
	_light(chip, false)
	return chip


## Lit: filled in the rank's stamp tone with a thick border, as the stamp itself.
func _light(chip: PanelContainer, lit: bool) -> void:
	chip.set_meta("lit", lit)
	var letter := String((chip.get_child(0).get_node("Letter") as Label).text)
	var tone: Color = ComicStyle.RANK_TONES.get(letter, ComicStyle.BLUE)
	var box := ComicStyle.box(tone if lit else ComicStyle.PAPER, 4 if lit else 2, 6, 3 if lit else 0)
	box.set_content_margin_all(2)
	chip.add_theme_stylebox_override("panel", box)
	chip.modulate.a = 1.0 if lit else 0.8
	var ink := ComicStyle.PAPER if lit and letter != "S" else ComicStyle.INK
	(chip.get_child(0).get_node("Letter") as Label).add_theme_color_override("font_color", ink)
	(chip.get_child(0).get_node("Points") as Label).add_theme_color_override("font_color",
		ink if lit else ComicStyle.PLUM)
