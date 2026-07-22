extends RefCounted

## Example unit test — delete or replace once you add real tests.
##
## The headless runner (tools/run_tests.gd) auto-discovers every test_*.gd file
## under the configured test_dir, instantiates it, calls setup() before each
## test (and teardown() after, if present), and runs every method whose name
## begins with "test_". It injects the runner as `_T`, giving you the assertion
## helpers below. A test method returns "" on success, or a non-empty failure
## message (produced by the _T.assert_* helpers) on failure.
##
## Available assertions (all return "" on pass, a message on fail):
##   _T.assert_eq(actual, expected, context)
##   _T.assert_true(condition, context)
##   _T.assert_false(condition, context)
##   _T.assert_gt(actual, threshold, context)
##   _T.assert_gte(actual, threshold, context)
##   _T.assert_float_eq(actual, expected, tolerance, context)

var _T  # assertion helper injected by run_tests.gd

func setup() -> void:
	# Runs before each test method. Build fresh fixtures here.
	pass

func test_arithmetic_sanity() -> String:
	return _T.assert_eq(2 + 2, 4, "basic arithmetic")

func test_boolean_sanity() -> String:
	return _T.assert_true(true, "true should be true")
