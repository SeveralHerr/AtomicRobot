extends RefCounted

# Headless tests for the orb-based health model: Player carries raw hit points and
# the HUD renders ceil(health / HITS_PER_ORB) orbs, each cycling through one texture
# per hit. Only static helpers are exercised, so no scene tree or Player node is needed.

var _T

var _P: GDScript = load("res://scripts/Player.gd")
var _HUD: GDScript = load("res://scripts/health_container.gd")


func test_hits_per_orb_matches_hud_texture_stages() -> String:
	# The HUD indexes ORB_TEXTURES with (hits left - 1); a mismatch would crash on a hit.
	return _T.assert_eq(_HUD.ORB_TEXTURES.size(), _P.HITS_PER_ORB, "damage-stage textures per orb")


func test_orb_textures_are_loadable_and_distinct() -> String:
	var seen := {}
	for tex in _HUD.ORB_TEXTURES:
		if tex == null:
			return "ORB_TEXTURES contains a null stage"
		var path: String = tex.resource_path
		if seen.has(path):
			return "ORB_TEXTURES reuses %s for two stages" % path
		seen[path] = true
	return ""


func test_orbs_for_rounds_partial_orbs_up() -> String:
	var cases := {0: 0, 1: 1, 2: 1, 3: 1, 4: 2, 6: 2, 7: 3, 9: 3}
	for hp in cases:
		var r: String = _T.assert_eq(_P.orbs_for(hp), cases[hp], "orbs_for(%d)" % hp)
		if r != "":
			return r
	return ""


func test_orbs_for_clamps_overkill_health() -> String:
	return _T.assert_eq(_P.orbs_for(-5), 0, "overkill health shows no orbs")


func test_orb_hits_left_walks_the_bar_left_to_right() -> String:
	# 7 hit points == two untouched orbs plus a third with a single hit left.
	var expected := [3, 3, 1, 0]
	for i in expected.size():
		var r: String = _T.assert_eq(_P.orb_hits_left(i, 7), expected[i], "orb %d of 7hp" % i)
		if r != "":
			return r
	return ""


func test_orb_hits_left_never_leaves_the_texture_range() -> String:
	for hp in range(-2, 40):
		for i in range(0, 12):
			var hits: int = _P.orb_hits_left(i, hp)
			if hits < 0 or hits > _P.HITS_PER_ORB:
				return "orb_hits_left(%d, %d) == %d is out of range" % [i, hp, hits]
	return ""


func test_each_hit_costs_exactly_one_stage_of_the_last_orb() -> String:
	# Walking a full bar down one hit at a time must lose a stage per hit and never
	# skip an orb.
	var hp: int = _P.max_health()
	var previous_orbs: int = _P.orbs_for(hp)
	while hp > 0:
		hp -= 1
		var orbs: int = _P.orbs_for(hp)
		if orbs != previous_orbs and orbs != previous_orbs - 1:
			return "health %d jumped from %d orbs to %d" % [hp, previous_orbs, orbs]
		previous_orbs = orbs
	return _T.assert_eq(previous_orbs, 0, "orbs at 0 health")


func test_max_health_is_a_whole_number_of_orbs() -> String:
	var r: String = _T.assert_eq(_P.max_health(), _P.MAX_ORBS * _P.HITS_PER_ORB, "max_health")
	if r != "":
		return r
	return _T.assert_eq(_P.orbs_for(_P.max_health()), _P.MAX_ORBS, "orbs at full health")


func test_character_starting_health_converts_to_whole_orbs() -> String:
	# Character configs are authored in orbs; Player._init() multiplies by HITS_PER_ORB.
	var globals = load("res://scripts/autoload/globals.gd").new()
	var result := ""
	for name in globals.character_dict:
		var orbs: int = globals.character_dict[name].get_starting_health()
		var hp: int = orbs * _P.HITS_PER_ORB
		if _P.orbs_for(hp) != orbs:
			result = "%s: %d orbs -> %d hp -> %d orbs" % [name, orbs, hp, _P.orbs_for(hp)]
			break
		if hp > _P.max_health():
			result = "%s starts at %d hp, above the %d cap" % [name, hp, _P.max_health()]
			break
	globals.free()
	return result
