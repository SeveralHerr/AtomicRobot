extends RefCounted

# The damage scale: enemy HP vs every fighter's damage. Player feedback: with maids at
# 2 HP and fighters at 1-2 damage, the 2-damage fighters one-shot everything. Every
# table below is derived from Globals.character_dict / the scenes, never hand-listed.

var _T

const ATTACK_STATE := "res://scripts/states/attack_state.gd"
const Unlocks := preload("res://scripts/character_unlocks.gd")
const ENEMY_SCENES := ["res://scenes/meter_maid.tscn", "res://scenes/meter_maid_melee.tscn",
	"res://scenes/meter_maid_platform.tscn", "res://scenes/meter_maid_window.tscn"]

var _nodes: Array[Node] = []


func teardown() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	for n in _nodes:
		if is_instance_valid(n):
			Globals.release_attack_slot(n)
			n.free()
	_nodes.clear()


func _fighters(include_robot := false) -> Array:
	var out := []
	for c in Globals.character_dict:
		if include_robot or c != Unlocks.BOSS_REWARD:
			out.append(Globals.character_dict[c])
	return out


func _maid_hits(cfg: CharacterConfig) -> int:
	return DamageRules.hits_to_kill(DamageRules.MAID_HEALTH, cfg.get_starting_damage())


func test_no_fighter_one_shots_a_maid() -> String:
	for cfg: CharacterConfig in _fighters(true):
		if _maid_hits(cfg) < 2:
			return "%s kills a maid in one blow (%d dmg vs %d HP)" % [
				cfg.get_character_name(), cfg.get_starting_damage(), DamageRules.MAID_HEALTH]
	return ""


func test_regular_fighters_take_three_or_four_blows() -> String:
	for cfg: CharacterConfig in _fighters():
		var n := _maid_hits(cfg)
		if n < 3 or n > 4:
			return "%s needs %d blows per maid, want 3-4" % [cfg.get_character_name(), n]
	return ""


## Rage doubles damage; even then a regular fighter must not one-shot a maid.
func test_rage_still_takes_two_blows() -> String:
	var mult: float = PowerupRules.DEFS[PowerupRules.RAGE]["damage_multiplier"]
	for cfg: CharacterConfig in _fighters():
		var raged := roundi(cfg.get_starting_damage() * mult)
		if DamageRules.hits_to_kill(DamageRules.MAID_HEALTH, raged) < 2:
			return "%s one-shots under Rage (%d)" % [cfg.get_character_name(), raged]
	return ""


## The boss fight stays the length it was: 10-20 blows (old: Cody 10, Ryan 20).
func test_boss_takes_ten_to_twenty_blows_for_everyone() -> String:
	for cfg: CharacterConfig in _fighters():
		var n := DamageRules.hits_to_kill(BossRules.MAX_HEALTH, cfg.get_starting_damage())
		if n < 10 or n > 20:
			return "%s needs %d blows on the boss, want 10-20" % [cfg.get_character_name(), n]
	return ""


func test_window_maid_is_tougher_than_a_street_maid() -> String:
	return _T.assert_gt(DamageRules.WINDOW_MAID_HEALTH, DamageRules.MAID_HEALTH, "window maid HP")


func test_car_takes_half_a_maid() -> String:
	return _T.assert_eq(DamageRules.CAR_ENEMY_DAMAGE * 2, DamageRules.MAID_HEALTH, "car hit = half a maid")


## The fighters attack_state.gd fires a projectile for == the configs flagged ranged.
## Both directions: a new shooter without the flag, or a stale flag, fails.
func test_ranged_flag_matches_attack_state() -> String:
	var src := FileAccess.get_file_as_string(ATTACK_STATE)
	var re := RegEx.create_from_string("selected_character == \"(\\w+)\"")
	var shooters := {}
	for m in re.search_all(src):
		shooters[m.get_string(1)] = true
	if shooters.is_empty():
		return "found no projectile branches in attack_state.gd"
	for c in Globals.character_dict:
		var cfg: CharacterConfig = Globals.character_dict[c]
		if cfg.is_ranged() != shooters.has(c):
			return "%s: ranged=%s but attack_state fires=%s" % [c, cfg.is_ranged(), shooters.has(c)]
	return ""


## Every enemy scene spawns with its DamageRules health (what the pips divide by too).
func test_enemy_scenes_spawn_with_rule_health() -> String:
	for path in ENEMY_SCENES:
		var e: Enemy = (load(path) as PackedScene).instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(e)
		_nodes.append(e)
		e.set_process(false)
		e.set_physics_process(false)
		var want := DamageRules.WINDOW_MAID_HEALTH if e is MeterMaidWindow else DamageRules.MAID_HEALTH
		var r: String = _T.assert_eq(e.health, want, "%s health" % path)
		if r != "":
			return r
		r = _T.assert_eq(e.max_health, want, "%s max_health" % path)
		if r != "":
			return r
	return ""


## Every enemy scene in scenes/ is covered by ENEMY_SCENES (no new maid type slips past).
func test_enemy_scene_list_is_complete() -> String:
	var dir := DirAccess.open("res://scenes")
	for f in dir.get_files():
		if not f.ends_with(".tscn"):
			continue
		var path := "res://scenes/" + f
		var state := (load(path) as PackedScene).get_state()
		var script = null
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == "script":
				script = state.get_node_property_value(0, i)
		if script is Script and _extends_enemy(script) and not _extends_boss(script) \
				and not path in ENEMY_SCENES:
			return "%s is an Enemy scene missing from ENEMY_SCENES" % path
	return ""


func _extends_enemy(s: Script) -> bool:
	while s != null:
		if s.resource_path == "res://scripts/enemy.gd":
			return true
		s = s.get_base_script()
	return false


func _extends_boss(s: Script) -> bool:
	return s.resource_path == "res://scripts/city_council_boss.gd"


## A reflected coin is a swing's worth: within the roster's regular damage range.
func test_reflected_coin_is_one_regular_blow() -> String:
	var lo := 999
	var hi := 0
	for cfg: CharacterConfig in _fighters():
		lo = mini(lo, cfg.get_starting_damage())
		hi = maxi(hi, cfg.get_starting_damage())
	var d := DamageRules.REFLECTED_COIN_DAMAGE
	return _T.assert_true(d >= lo and d <= hi, "reflect %d within fighters' %d-%d" % [d, lo, hi])
