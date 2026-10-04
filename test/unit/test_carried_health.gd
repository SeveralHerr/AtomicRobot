extends RefCounted

# Health carried through the boss door (Globals.carried_health -> Player._init).
# boss_room.tscn has its own Player; without the carry it reset to the character's
# starting health and threw away every heart picked up on the street.
# Player.new() runs _init only (no scene, no _ready), which is all this needs.

var _T

var _saved_character: String


func setup() -> void:
	_saved_character = Globals.selected_character
	Globals.selected_character = "Ryan"
	Globals.set("carried_health", -1)


func teardown() -> void:
	Globals.set("carried_health", -1)
	Globals.selected_character = _saved_character


func _starting_hp() -> int:
	return Globals.get_current_character().get_starting_health() * Player.HITS_PER_ORB


func _new_player_hp() -> int:
	var p := Player.new()
	var hp := p.health
	p.free()
	return hp


func test_fresh_player_starts_at_character_health() -> String:
	return _T.assert_eq(_new_player_hp(), _starting_hp(), "no carry: starting health")


func test_next_player_takes_carried_health() -> String:
	Globals.set("carried_health", 20)
	return _T.assert_eq(_new_player_hp(), 20, "boss-room player keeps street health")


## Only the very next Player gets it: a restart after dying in the boss room must
## start fresh, not on the health the street ended with.
func test_carry_is_used_once() -> String:
	Globals.set("carried_health", 20)
	_new_player_hp()
	return _T.assert_eq(_new_player_hp(), _starting_hp(), "second player starts fresh")


func test_carry_clamps_to_max_health() -> String:
	Globals.set("carried_health", Player.max_health() + 50)
	return _T.assert_eq(_new_player_hp(), Player.max_health(), "never above the orb cap")


func test_carry_below_one_is_ignored() -> String:
	Globals.set("carried_health", 0)
	return _T.assert_eq(_new_player_hp(), _starting_hp(), "a 0 carry is no carry")


func test_reset_drops_the_carry() -> String:
	Globals.set("carried_health", 20)
	Globals.reset()
	return _T.assert_eq(_new_player_hp(), _starting_hp(), "RESTART starts on starting health")


func test_carry_health_records_hp() -> String:
	if not Globals.has_method("carry_health"):
		return "Globals.carry_health missing"
	Globals.call("carry_health", 17)
	return _T.assert_eq(_new_player_hp(), 17, "carry_health feeds the next player")
