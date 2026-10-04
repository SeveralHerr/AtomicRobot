extends RefCounted

# SecretTally (scripts/secret_tally.gd): unique secrets per run, and the totals the
# YOU WIN card shows as "a/b", derived from the level files.

var _T

const MAIN := "res://scenes/main.tscn"
const RUN := ["res://scenes/main.tscn", "res://scenes/boss_room.tscn"]


func test_secret_record_counts_each_id_once() -> String:
	var t := SecretTally.new()
	var r: String = _T.assert_true(t.record("wall", "a"), "first claim counts")
	if r != "":
		return r
	r = _T.assert_false(t.record("wall", "a"), "same id again does not")
	if r != "":
		return r
	t.record("wall", "b")
	t.record("news", "a")
	r = _T.assert_eq(t.counts(), {"wall": 2, "news": 1}, "per-kind counts; ids are per kind")
	if r != "":
		return r
	return _T.assert_eq(t.found_total(), 3, "total across kinds")


func test_secret_unknown_kind_is_ignored() -> String:
	var t := SecretTally.new()
	var r: String = _T.assert_false(t.record("cheese", "a"), "not a secret kind")
	if r != "":
		return r
	return _T.assert_eq(t.found_total(), 0, "nothing counted")


func test_secret_clear_starts_a_new_run() -> String:
	var t := SecretTally.new()
	t.record("news", "a")
	t.clear()
	var r: String = _T.assert_eq(t.found_total(), 0, "cleared")
	if r != "":
		return r
	return _T.assert_true(t.record("news", "a"), "and claimable again")


func test_secret_counts_report_every_kind() -> String:
	return _T.assert_eq(SecretTally.new().counts().keys(), SecretTally.KIND_SCRIPTS.keys(), "zeros included")


## Both directions: the static SceneState walk must agree with the nodes a live
## main.tscn actually has, and there must be some of each kind to find.
func test_secret_totals_match_the_live_level() -> String:
	var totals: Dictionary = SecretTally.totals_in([MAIN])
	var live := {}
	for kind in SecretTally.KIND_SCRIPTS:
		live[kind] = 0
	var level := (load(MAIN) as PackedScene).instantiate()
	for node in level.find_children("*", "", true, false):
		var s: Script = node.get_script()
		for kind in SecretTally.KIND_SCRIPTS:
			if s != null and s.resource_path == SecretTally.KIND_SCRIPTS[kind]:
				live[kind] += 1
	level.free()
	print("  secret totals in main.tscn: ", totals)
	var r: String = _T.assert_eq(totals, live, "derived totals == live nodes")
	if r != "":
		return r
	for kind in totals:
		if int(totals[kind]) <= 0:
			return "no %s secrets found in main.tscn" % kind
	return ""


func test_secret_totals_sum_over_scenes() -> String:
	var main: Dictionary = SecretTally.totals_in([MAIN])
	var both: Dictionary = SecretTally.totals_in(RUN)
	var boss: Dictionary = SecretTally.totals_in([RUN[1]])
	for kind in main:
		if int(both[kind]) != int(main[kind]) + int(boss[kind]):
			return "%s: %d != %d + %d" % [kind, both[kind], main[kind], boss[kind]]
	return ""
