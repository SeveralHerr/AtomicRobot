class_name RankLadder
extends VBoxContainer

## The end card's rank hint (under the stamp and score in RunSummary): one line saying
## how far the next rank is and the one thing in THIS run that would have got there.
##
## Player report: "my best full clear got ~7k points but still rank C. What do I need
## for a better rank?" Gaps are derived from ScoreRules.RANK_THRESHOLDS. A chip row of
## every threshold was tried and cut as UI noise: the one next goal is what matters.

## A clear faster than this is not a promise the tip makes (the bot's best 100% run
## is ~180 s).
const FASTEST_SECONDS := 150.0
const LINE_SIZE := 25
const COMBO_TIP := "CHAIN COMBOS: KILLS PAY UP TO x8"

## One line: the gap to the next rank, then the tip ("+800 FOR B (9,500) · FIND 4
## MORE SECRETS"). One line, not two: the card's tallest state must fit the CRT.
var next_label: Label


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 2)
	next_label = ComicStyle.label("", ComicStyle.LABEL, LINE_SIZE, ComicStyle.PLUM)
	add_child(next_label)


static func threshold_of(letter: String) -> int:
	for entry in ScoreRules.RANK_THRESHOLDS:
		if String(entry[0]) == letter:
			return int(entry[1])
	return 0


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
	next_label.text = line_text(run, won)


## The ladder's line for `run`: next_text, plus " · " and the tip on a ranked clear.
static func line_text(run: Dictionary, won: bool) -> String:
	var ranked := won and String(run.get("rank", "")) != ""
	var text := next_text(int(run.get("total", 0)), ranked)
	var tip := tip_text(run) if ranked else ""
	return text if tip == "" else text + " · " + tip

