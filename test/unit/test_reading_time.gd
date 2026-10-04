extends RefCounted

# ReadingTime: the one rule for how long a pop-up with text to read stays up.

var _T

const R := preload("res://scripts/ui/reading_time.gd")


func test_short_text_gets_the_minimum() -> String:
	return _T.assert_float_eq(R.seconds("GO!"), R.MIN, 0.001, "a word still stays MIN")


func test_longer_text_stays_longer() -> String:
	var a := R.seconds("Robot Parade Scheduled for Friday!")
	var b := R.seconds("City Council Approves New Parking Tax: Breathing Near Meters Now $0.25")
	return _T.assert_true(b > a, "70 chars (%.2f) outlast 34 (%.2f)" % [b, a])


func test_rate_is_base_plus_per_char() -> String:
	var text := "x".repeat(40)
	return _T.assert_float_eq(R.seconds(text), R.BASE + 40 * R.PER_CHAR, 0.001, "base + per char")


func test_capped_at_max() -> String:
	return _T.assert_float_eq(R.seconds("x".repeat(500)), R.MAX, 0.001, "never parks forever")


func test_edge_whitespace_does_not_count() -> String:
	var t := "x".repeat(40)
	return _T.assert_float_eq(R.seconds("   " + t + "\n"), R.seconds(t), 0.001, "trimmed")


func test_every_minimum_is_at_least_three_seconds() -> String:
	return _T.assert_gte(R.MIN, 3.0, "the user asked for a moment longer; 3 s floor")


# --- Every pop-up with text to read uses the rule --------------------------------

func test_street_clear_stays_up_for_its_reading_time() -> String:
	var A := EncounterAnnouncer
	var total: float = A.SLAM_IN + A.clear_hold()
	return _T.assert_float_eq(total, R.seconds(A.CLEAR_TITLE + " " + A.CLEAR_SUB), 0.001, "slam-in + hold")


func test_boss_line_bubble_reaches_its_reading_time() -> String:
	var line := "We are charging for\nparking on SUNDAYS!"
	var total: float = BossBanner.SAY_POP + BossBanner.TYPE_STEP * line.length() + BossBanner.say_hold(line, 0.8)
	return _T.assert_true(total >= R.seconds(line) - 0.001,
		"bubble up %.2f s, reading time %.2f s" % [total, R.seconds(line)])


func test_boss_line_keeps_a_longer_requested_hold() -> String:
	return _T.assert_float_eq(BossBanner.say_hold("HI", 9.5), 9.5, 0.001, "hold is a floor, not replaced")


func test_newspaper_holds_for_the_shared_rule() -> String:
	var script: GDScript = load("res://scripts/interactive_mailbox.gd")
	var t := "Robot Parade Scheduled for Friday!"
	return _T.assert_float_eq(script.min_read_seconds(t), R.seconds(t), 0.001, "same rule")
