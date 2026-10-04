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
