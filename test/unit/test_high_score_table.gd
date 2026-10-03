extends RefCounted

# Headless tests for the arcade high-score list (scripts/high_score_table.gd): who
# gets on the board, where they land, and that nothing hostile survives a reload.

var _T
const H = preload("res://scripts/high_score_table.gd")


func _table(scores: Array) -> Array:
	var entries: Array = []
	for s in scores:
		entries.append(H.make_entry("AAA", s, "D"))
	return entries


func _full() -> Array:
	return _table([1000, 900, 800, 700, 600, 500, 400, 300, 200, 100])


# --- Who qualifies -------------------------------------------------------------

func test_empty_board_takes_any_positive_score() -> String:
	var r: String = _T.assert_true(H.qualifies([], 1), "1 point beats an empty board")
	if r != "":
		return r
	return _T.assert_false(H.qualifies([], 0), "a zero run never earns initials")


func test_full_board_needs_to_beat_last_place() -> String:
	var r: String = _T.assert_true(H.qualifies(_full(), 101), "beats 10th")
	if r != "":
		return r
	r = _T.assert_false(H.qualifies(_full(), 100), "tying 10th does not qualify")
	if r != "":
		return r
	return _T.assert_false(H.qualifies(_full(), 50), "below 10th does not qualify")


func test_part_full_board_takes_a_low_score() -> String:
	return _T.assert_true(H.qualifies(_table([1000, 900]), 5), "open rows take anything > 0")


# --- Where it lands ------------------------------------------------------------

func test_slot_for_orders_highest_first() -> String:
	var t := _full()
	for pair in [[5000, 0], [950, 1], [101, 9], [100, -1]]:
		var r: String = _T.assert_eq(H.slot_for(t, pair[0]), pair[1], "score %d" % pair[0])
		if r != "":
			return r
	return ""


func test_tie_goes_below_incumbent() -> String:
	var t := _table([1000, 500])
	var slot: int = H.insert(t, H.make_entry("NEW", 500))
	var r: String = _T.assert_eq(slot, 2, "tie with 2nd lands 3rd")
	if r != "":
		return r
	return _T.assert_eq(String(t[1]["initials"]), "AAA", "incumbent keeps 2nd")


func test_insert_trims_to_size_and_drops_last() -> String:
	var t := _full()
	var slot: int = H.insert(t, H.make_entry("TOP", 99999, "S"))
	var r: String = _T.assert_eq(slot, 0, "new record is 1st")
	if r != "":
		return r
	r = _T.assert_eq(t.size(), H.SIZE, "board stays at SIZE rows")
	if r != "":
		return r
	return _T.assert_eq(int(t[H.SIZE - 1]["score"]), 200, "old 10th (100) fell off")


func test_insert_refuses_non_qualifier() -> String:
	var t := _full()
	var r: String = _T.assert_eq(H.insert(t, H.make_entry("LOW", 10)), -1, "non-qualifier refused")
	if r != "":
		return r
	return _T.assert_eq(int(t[H.SIZE - 1]["score"]), 100, "board untouched")


## Every insert, in any order, must leave the board sorted best-first.
func test_board_always_sorted() -> String:
	var t: Array = []
	for s in [300, 50, 900, 900, 1, 777, 12000, 400, 400, 2, 65, 8000, 3]:
		H.insert(t, H.make_entry("ABC", s))
	for i in range(1, t.size()):
		if int(t[i]["score"]) > int(t[i - 1]["score"]):
			return "row %d (%d) outranks row %d (%d)" % [i, t[i]["score"], i - 1, t[i - 1]["score"]]
	return _T.assert_eq(t.size(), H.SIZE, "13 inserts trim to SIZE")


# --- Initials input ------------------------------------------------------------

func test_sanitize_initials() -> String:
	for pair in [["abc", "ABC"], ["b", "BAA"], ["", "AAA"], ["ABCDEF", "ABC"],
			["<b>", "BAA"], ["A\nB", "ABA"], ["é1z", "ZAA"], ["%s%s%s", "SSS"], ["a b", "ABA"]]:
		var r: String = _T.assert_eq(H.sanitize_initials(pair[0]), pair[1], "sanitize %s" % pair[0].c_escape())
		if r != "":
			return r
	return ""


func test_sanitize_rank_only_known_letters() -> String:
	var r: String = _T.assert_eq(H.sanitize_rank("S"), "S", "S kept")
	if r != "":
		return r
	r = _T.assert_eq(H.sanitize_rank("Z"), "", "unknown letter dropped")
	if r != "":
		return r
	return _T.assert_eq(H.sanitize_rank("SS"), "", "multi-letter dropped")


## Same wheel as atomic-pinball on the same cabinet: A-Z only.
func test_alphabet_is_a_to_z() -> String:
	return _T.assert_eq(H.ALPHABET, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "A-Z, like pinball")


func test_cycle_letter_wraps_both_ways() -> String:
	var last: String = H.ALPHABET[H.ALPHABET.length() - 1]
	for c in [["A", 1, "B"], ["A", -1, last], [last, 1, "A"], ["?", 1, "B"]]:
		var r: String = _T.assert_eq(H.cycle_letter(c[0], c[1]), c[2], "%s%+d" % [c[0], c[1]])
		if r != "":
			return r
	return ""


## A full lap of the alphabet must visit every letter exactly once and come home.
func test_cycle_letter_full_lap() -> String:
	var seen := {}
	var c := "A"
	for i in H.ALPHABET.length():
		seen[c] = true
		c = H.cycle_letter(c, 1)
	var r: String = _T.assert_eq(c, "A", "lap returns to A")
	if r != "":
		return r
	return _T.assert_eq(seen.size(), H.ALPHABET.length(), "every letter reachable")


# --- Untrusted save data -------------------------------------------------------

func test_from_variant_rejects_junk() -> String:
	for junk in [null, 42, "x", {}, [1, "a", null]]:
		var r: String = _T.assert_eq(H.from_variant(junk).size(), 0, "junk %s" % str(junk))
		if r != "":
			return r
	return ""


func test_from_variant_repairs_hostile_rows() -> String:
	var raw: Array = []
	for i in 15:
		raw.append({"initials": "<script>", "score": i * 10, "rank": "ZZ"})
	raw.append({"initials": "neg", "score": -500})
	var t: Array = H.from_variant(raw)
	var r: String = _T.assert_eq(t.size(), H.SIZE, "over-long list trimmed")
	if r != "":
		return r
	r = _T.assert_eq(int(t[0]["score"]), 140, "re-sorted best-first")
	if r != "":
		return r
	r = _T.assert_eq(String(t[0]["initials"]), "SCR", "initials sanitised")
	if r != "":
		return r
	return _T.assert_eq(String(t[0]["rank"]), "", "bad rank dropped")
