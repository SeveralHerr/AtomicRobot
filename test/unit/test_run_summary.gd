extends RefCounted

# The YOU WIN card's run summary (scripts/ui/run_summary.gd): STREET / BOSS / BONUS
# subtotals, the secrets line, and the NEW FIGHTER stamp - the pure text first, then
# the card in the real boss room driven by the real signals.

var _T

const BOSS_ROOM := "res://scenes/boss_room.tscn"
const STREET := "res://scenes/main.tscn"
const TEST_SAVE := "user://test_scores_summary.cfg"

var _level: Node
var _saved_path: String


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func setup() -> void:
	_saved_path = ScoreSystem.save_path
	ScoreSystem.save_path = TEST_SAVE
	ScoreSystem.clear_records()


func teardown() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
	ScoreSystem.begin_stage("")
	ScoreSystem.running = false
	ScoreSystem.clear_records()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	ScoreSystem.save_path = _saved_path
	ScoreSystem.reload()
	await _frames()


func _run() -> Dictionary:
	return ScoreRules.summarise(7840, 182.5, 20, 4, ScoreRules.PAR_SECONDS, 3, 7070).merged({
		"secrets": {"wall": 1, "news": 2}, "secret_totals": {"wall": 2, "news": 5}})


func _labels(rows: Array) -> Array:
	return rows.map(func(row: Array) -> String: return String(row[0]).split(" ")[0])


# --- Text -----------------------------------------------------------------------

func test_summary_rows_are_street_boss_bonus_then_bonus_detail() -> String:
	var rows: Array = RunSummary.breakdown_rows(_run())
	var r: String = _T.assert_eq(_labels(rows), ["STREET", "BOSS", "BONUS", "TIME", "HEALTH", "SECRETS"], "row order")
	if r != "":
		return r
	var details: Array = rows.map(func(row: Array) -> bool: return row[2])
	return _T.assert_eq(details, [false, false, false, true, true, true], "bonus itemised beneath")


## The three headline rows must add up to FINAL SCORE.
func test_summary_subtotals_add_up_to_the_total() -> String:
	var run := _run()
	var sum := 0
	for row in RunSummary.breakdown_rows(run):
		if not row[2]:
			sum += int(String(row[1]).replace(",", "").replace("+", ""))
	return _T.assert_eq(sum, int(run["total"]), "STREET + BOSS + BONUS")


func test_summary_boss_only_stage_has_no_street_row() -> String:
	var run := ScoreRules.summarise(900, 40.0, 1, 2)
	return _T.assert_false("STREET" in _labels(RunSummary.breakdown_rows(run)), "no street to show")


func test_summary_death_has_no_rows() -> String:
	return _T.assert_eq(RunSummary.breakdown_rows({"won": false, "total": 700, "rank": ""}), [], "nothing to break down")


func test_summary_secrets_text() -> String:
	var r: String = _T.assert_eq(RunSummary.secrets_text(_run()), "SECRETS 1/2 · NEWS 2/5", "found/total per kind")
	if r != "":
		return r
	return _T.assert_eq(RunSummary.secrets_text({"fight_score": 1}), "", "no level totals, no line")


func test_summary_unlock_text() -> String:
	var r: String = _T.assert_eq(RunSummary.unlock_text({"unlocks": ["Robot"]}), "NEW FIGHTER: ROBOT", "one fighter")
	if r != "":
		return r
	return _T.assert_eq(RunSummary.unlock_text({"unlocks": []}), "", "none, no stamp")


# --- The card in the real boss room ---------------------------------------------

## Street -> boss room through the door, then the real boss_death.
func _clear(street_points: int, before_door: Callable = func() -> void: pass) -> EndCard:
	_level = (load(BOSS_ROOM) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	await _frames()
	ScoreSystem.enter_scene(STREET)
	ScoreSystem.score = street_points
	before_door.call()
	ScoreSystem.enter_scene("", false)
	ScoreSystem.enter_scene(BOSS_ROOM)
	ScoreSystem.score += 600
	Globals.boss_death.emit()
	await _frames()
	return _level.get_node("UI/EndCard") as EndCard


func _row_texts(card: EndCard) -> String:
	var parts := PackedStringArray()
	for child in card.summary.breakdown.get_children():
		parts.append((child as Label).text)
	return " ".join(parts)


func test_summary_card_shows_street_and_boss_subtotals() -> String:
	var card := await _clear(7000)
	var text := _row_texts(card)
	var r: String = _T.assert_true("STREET 7,000" in text, "street subtotal in '%s'" % text)
	if r != "":
		return r
	return _T.assert_true("BOSS 600" in text, "boss subtotal in '%s'" % text)


func test_summary_card_shows_secret_counts() -> String:
	var card := await _clear(7000, func() -> void:
		Globals.secret_found.emit("wall", "A")
		Globals.secret_found.emit("news", "B")
		Globals.secret_found.emit("news", "B"))
	var totals := SecretTally.totals_in(ScoreRules.SCORED_SCENES)
	var want := "SECRETS 1/%d · NEWS 1/%d" % [totals["wall"], totals["news"]]
	return _T.assert_true(want in _row_texts(card), "'%s' in '%s'" % [want, _row_texts(card)])


## The first clear unlocks Robot behind this card: the card has to say so.
func test_summary_card_stamps_the_unlock() -> String:
	var card := await _clear(7000)
	var r: String = _T.assert_true(card.summary.unlock_holder.visible, "stamp shown")
	if r != "":
		return r
	return _T.assert_eq(card.summary.unlock_label.text, "NEW FIGHTER: ROBOT", "names the fighter")


func test_summary_card_without_unlock_has_no_stamp() -> String:
	Globals.unlock_character("Robot")  # beaten before: nothing new this run
	var card := await _clear(7000)
	return _T.assert_false(card.summary.unlock_holder.visible, "no stamp")


func test_summary_death_card_has_no_stamp() -> String:
	_level = (load(BOSS_ROOM) as PackedScene).instantiate()
	_tree().root.add_child(_level)
	await _frames()
	ScoreSystem.enter_scene(BOSS_ROOM)
	var card := _level.get_node("UI/EndCard") as EndCard
	card.present(false)
	await _frames()
	var r: String = _T.assert_false(card.summary.unlock_holder.visible, "no stamp on a death")
	if r != "":
		return r
	return _T.assert_false(card.summary.breakdown.visible, "no breakdown on a death")


## Mutation survivor: a stage with no level secrets (a sandbox) shows no secrets row.
func test_summary_no_secret_row_without_totals() -> String:
	var rows: Array = RunSummary.breakdown_rows(ScoreRules.summarise(900, 40.0, 1, 2))
	return _T.assert_eq(_labels(rows), ["BOSS", "BONUS", "TIME", "HEALTH"], "no empty secrets row")
