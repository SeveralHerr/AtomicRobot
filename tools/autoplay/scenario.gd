extends RefCounted

## Autoplay scenario: parsing + validation. Pure (no scene tree), so it is unit
## tested directly (test/unit/test_autoplay_scenario.gd).
##
## A scenario is JSON. Every key is optional:
##   name       String  report/screenshot name                 (file stem / "inline")
##   scene      String  scene to start in                       ("res://scenes/main.tscn")
##   boot       bool    start from the title screen instead     (false)
##   character  String  Globals.selected_character              ("Ryan")
##   seed       int     seeds the global RNG                    (1)
##   timeout    float   game seconds before the run fails       (120)
##   snap_every float   windowed runs: screenshot every N s     (0 = off)
##   steps      Array   "verb args..." strings, run in order    ([])
##   expect     Array   "metric op value" checks at the end     ([])
## See skills/godot-autoplay-test/SKILL.md for the verb list.

const DEFAULTS := {
	"name": "inline",
	"scene": "res://scenes/main.tscn",
	"boot": false,
	"character": "Ryan",
	"seed": 1,
	"timeout": 120.0,
	"snap_every": 0.0,
	"steps": [],
	"expect": [],
}

## verb -> argument kinds, in order; a trailing "?" marks an optional argument.
## Kinds: num, int, action (InputMap name), lane (0-3), kind (melee|ranged),
## onoff, goal (BRAIN_GOALS), name (free text), check (assert: metric op value).
const VERBS := {
	"wait": ["num"],
	"hold": ["action", "num"],
	"tap": ["action"],
	"press": ["action"],
	"release": ["action"],
	"walk_to": ["num", "num?"],
	"lane": ["lane"],
	"teleport": ["num"],
	"spawn": ["kind", "num?", "lane?"],
	"god": ["onoff"],
	"hp": ["int"],
	"kill_all": [],
	"sink": ["num"],
	"brain": ["goal", "num?", "num?"],
	"menu": ["num?"],
	"snap": ["name?"],
	"dump": ["name?"],
	"assert": ["check"],
}

const OPS := ["==", "!=", ">=", "<=", ">", "<"]
const BRAIN_GOALS := ["advance", "clear", "monkey"]
## Every metric Recorder.metrics() reports. test_autoplay_scenario.gd pins the two
## lists equal in both directions, so a check can be validated before the run.
const METRICS := ["t", "frames", "scene", "x", "y", "lane", "hp", "max_hp", "state", "kills",
	"damage_taken", "hits_taken", "heals", "deaths", "won", "boss_reached", "enemies_near",
	"max_stuck_s", "stuck_spots", "step_failures", "errors", "engine_errors", "warnings", "score", "boss_hp",
	"secret_walls", "secret_news", "headlines"]
## Metrics compared as text (== / != only); every other metric needs a number.
const TEXT_METRICS := ["scene", "state"]


## Loads `source`: a path to a .json file, or an inline JSON object string.
## Returns {"ok": bool, "errors": PackedStringArray, "data": Dictionary}.
static func load_source(source: String) -> Dictionary:
	var text := source
	var name := "inline"
	if not source.strip_edges().begins_with("{"):
		if not FileAccess.file_exists(source):
			return _fail(["scenario file not found: %s" % source])
		text = FileAccess.get_file_as_string(source)
		name = source.get_file().get_basename()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return _fail(["scenario is not a JSON object"])
	var data: Dictionary = parsed
	if not data.has("name"):
		data["name"] = name
	# The name becomes report/screenshot file names: no path separators.
	data["name"] = str(data["name"]).validate_filename()
	return parse(data)


## Applies defaults and validates every step and expectation up front, so a typo
## fails the run before any game time is spent on it.
static func parse(raw: Dictionary) -> Dictionary:
	var data := DEFAULTS.duplicate(true)
	var errors := PackedStringArray()
	for key in raw:
		if not DEFAULTS.has(key):
			errors.append("unknown key '%s'" % key)
			continue
		data[key] = raw[key]
	if not (data["steps"] is Array):
		errors.append("steps must be an array of strings")
		data["steps"] = []
	if not (data["expect"] is Array):
		errors.append("expect must be an array of strings")
		data["expect"] = []
	var steps: Array = []
	for s in data["steps"]:
		var step := parse_step(str(s))
		if step.has("error"):
			errors.append(step["error"])
		steps.append(step)
	data["steps"] = steps
	var checks: Array = []
	for e in data["expect"]:
		var c := parse_check(str(e))
		if c.has("error"):
			errors.append(c["error"])
		checks.append(c)
	data["expect"] = checks
	for key in ["seed", "timeout", "snap_every"]:
		if not (data[key] is int or data[key] is float):
			errors.append("'%s' must be a number, got %s" % [key, JSON.stringify(data[key])])
			data[key] = DEFAULTS[key]
	if float(data["timeout"]) <= 0.0:
		errors.append("'timeout' must be > 0")
	for key in ["scene", "character", "name"]:
		if not (data[key] is String):
			errors.append("'%s' must be a string" % key)
			data[key] = DEFAULTS[key]
	if not ResourceLoader.exists(data["scene"]):
		errors.append("scene not found: %s" % data["scene"])
	if not Globals.character_dict.has(data["character"]):
		errors.append("unknown character '%s' (have %s)" % [data["character"], ", ".join(Globals.character_dict.keys())])
	data["seed"] = int(data["seed"])
	data["timeout"] = float(data["timeout"])
	data["snap_every"] = float(data["snap_every"])
	return {"ok": errors.is_empty(), "errors": errors, "data": data}


## "hold ui_right 0.5" -> {"verb": "hold", "args": ["ui_right", "0.5"], "text": ...}
static func parse_step(text: String) -> Dictionary:
	var parts := text.strip_edges().split(" ", false)
	if parts.is_empty():
		return {"text": text, "error": "empty step"}
	var verb := parts[0]
	var args := Array(parts.slice(1))
	var step := {"verb": verb, "args": args, "text": text}
	if not VERBS.has(verb):
		step["error"] = "unknown verb '%s' in '%s' (verbs: %s)" % [verb, text, ", ".join(VERBS.keys())]
		return step
	if verb == "assert":
		var c := parse_check(" ".join(args))
		if c.has("error"):
			step["error"] = c["error"]
		step["check"] = c
		return step
	var kinds: Array = VERBS[verb]
	var required := kinds.filter(func(k: String) -> bool: return not k.ends_with("?")).size()
	if args.size() < required or args.size() > kinds.size():
		step["error"] = "'%s' takes %s: '%s'" % [verb, " ".join(kinds), text]
		return step
	for i in args.size():
		var err := _arg_error(kinds[i].trim_suffix("?"), args[i])
		if err != "":
			step["error"] = "%s in '%s'" % [err, text]
			break
	return step


static func _arg_error(kind: String, arg: String) -> String:
	match kind:
		"num":
			return "" if arg.is_valid_float() else "'%s' is not a number" % arg
		"int":
			return "" if arg.is_valid_int() else "'%s' is not an integer" % arg
		"lane":
			return "" if arg.is_valid_int() and Lanes.is_valid_lane(int(arg)) else "lane '%s' not in %d-%d" % [arg, Lanes.BACK_LANE, Lanes.FRONT_LANE]
		"action":
			return "" if InputMap.has_action(arg) else "unknown input action '%s'" % arg
		"kind":
			return "" if arg in ["melee", "ranged"] else "spawn kind '%s' must be melee or ranged" % arg
		"onoff":
			return "" if arg in ["on", "off"] else "'%s' must be on or off" % arg
		"goal":
			return "" if arg in BRAIN_GOALS else "brain goal '%s' must be one of %s" % [arg, BRAIN_GOALS]
	return ""


## "kills >= 2" -> {"metric": "kills", "op": ">=", "value": "2", "text": ...}
static func parse_check(text: String) -> Dictionary:
	var parts := text.strip_edges().split(" ", false)
	if parts.size() != 3 or not (parts[1] in OPS):
		return {"text": text, "error": "check must be 'metric op value' with op in %s: '%s'" % [OPS, text]}
	var c := {"metric": parts[0], "op": parts[1], "value": parts[2], "text": text}
	if not (parts[0] in METRICS):
		c["error"] = "unknown metric '%s' in '%s' (metrics: %s)" % [parts[0], text, ", ".join(METRICS)]
	elif parts[0] in TEXT_METRICS and not (parts[1] in ["==", "!="]):
		c["error"] = "'%s' is text: use == or != in '%s'" % [parts[0], text]
	elif not (parts[0] in TEXT_METRICS) and not parts[2].is_valid_float():
		c["error"] = "'%s' needs a number, got '%s'" % [parts[0], parts[2]]
	return c


## Evaluates a parsed check against a metrics dictionary. Numbers compare
## numerically; anything else compares as a string (only == and != make sense).
## Returns {"pass": bool, "actual": Variant, "text": String}.
static func evaluate(check: Dictionary, metrics: Dictionary) -> Dictionary:
	var metric: String = check.get("metric", "")
	if not metrics.has(metric):
		return {"pass": false, "actual": null, "text": "%s (unknown metric)" % check.get("text", "")}
	var actual: Variant = metrics[metric]
	var want: String = check["value"]
	var ok := false
	if (actual is int or actual is float) and want.is_valid_float():
		ok = _compare(float(actual), float(want), check["op"])
	else:
		var a := str(actual)
		match check["op"]:
			"==": ok = a == want
			"!=": ok = a != want
			_: ok = false
	return {"pass": ok, "actual": actual, "text": check["text"]}


static func _compare(a: float, b: float, op: String) -> bool:
	match op:
		"==": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
		">=": return a >= b
		"<=": return a <= b
		">": return a > b
		"<": return a < b
	return false


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "errors": PackedStringArray(errors), "data": DEFAULTS.duplicate(true)}
