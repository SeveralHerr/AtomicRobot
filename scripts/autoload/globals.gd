extends Node

const CharacterUnlocks := preload("res://scripts/character_unlocks.gd")

signal player_death
signal boss_death
signal meter_maid_death
signal meter_maid_boss_death
signal unlocked(name: String, description: String)
signal boss_fight(status: bool)
signal event(status: bool)
signal newspaper(status: bool)
signal gust(position: Vector2, range: float)
## A secret was claimed: kind "wall" (cracked wall's orb taken) or "news" (stand read).
## `id` is unique per secret in its level (node path) so repeats can be ignored.
signal secret_found(kind: String, id: String)

var selected_character: String = "Ryan"
var character_dict: Dictionary[String, CharacterConfig] = {
	"Cody": CharacterConfig.new(
		"Cody",
		"CODY IS NOW PLAYABLE",
		true, 
		"Artist at Atomic Robot Tattoo",
		preload("res://sprites/cody_sprite_frames.tres"),
		"",
		CharacterSounds.new(
			preload("res://sounds/Voice_Male_V2_Jump_Mono_05.wav"),
			preload("res://sounds/Voice_Male_V1_Hit_Short_Mono_07.wav"),
			preload("res://sounds/Voice_Male_V2_Jump_Mono_05.wav"),
			preload("res://sounds/Voice_Male_V2_Attack_Short_Mono_07.wav"),
			preload("res://sounds/lightsaber.wav")  # weapon sound
		),
		2,  # Attack frame,
		2, # hp
		4 # dmg: lightsaber, 3 blows a maid (DamageRules.MAID_HEALTH 12)
		
	),
	"Ryan": CharacterConfig.new(
		"Ryan",
		"RYAN IS NOW PLAYABLE",
		true,
		"Artist at Atomic Robot Tattoo",
		preload("res://sprites/ryan_sprite_frames.tres"),
		"",
		CharacterSounds.new(
			preload("res://sounds/Voice_Male_V2_Jump_Mono_05.wav"),
			preload("res://sounds/Voice_Male_V1_Hit_Short_Mono_07.wav"),
			preload("res://sounds/Voice_Male_V2_Jump_Mono_05.wav"),
			preload("res://sounds/Voice_Male_V2_Attack_Short_Mono_07.wav"),
			preload("res://sounds/sword_attack.wav")  # weapon sound
		),
		3,  # Attack frame
		4, # hp
		3 # dmg: 4 blows a maid; the fastest sword swing (8 frames) makes up for it
	),
	"Sara": CharacterConfig.new(
		"Sara",
		"SARA IS NOW PLAYABLE",
		true,
		"Artist at Atomic Robot Tattoo",
		preload("res://sprites/sarah_sprite_frames.tres"),
		"",
		CharacterSounds.new(
			preload("res://sounds/Voice_Female_V2_Jump_Mono_01.wav"),
			preload("res://sounds/Voice_Female_V1_Hit_Short_Mono_07.wav"),
			preload("res://sounds/Voice_Female_V2_Land_Mono_01.wav"),
			preload("res://sounds/Voice_Female_V2_Attack_Mono_01.wav"),
			preload("res://sounds/sword_attack.wav")  # weapon sound
		),
		5,  # Attack frame
		4, # hp
		4 # dmg: heavy axe, slow 10-frame swing, 3 blows a maid
	),
	"Cass": CharacterConfig.new(
		"Cass",
		"Cass IS NOW PLAYABLE",
		true,
		"Artist at Atomic Robot Tattoo",
		preload("res://sprites/cass_sprite_frames.tres"),
		"",
		CharacterSounds.new(
			preload("res://sounds/Voice_Female_V2_Jump_Mono_01.wav"),
			preload("res://sounds/Voice_Female_V1_Hit_Short_Mono_07.wav"),
			preload("res://sounds/Voice_Female_V2_Land_Mono_01.wav"),
			preload("res://sounds/Voice_Female_V2_Attack_Mono_01.wav"),
			preload("res://sounds/throw.wav")  # weapon sound
		),
		3,  # Attack frame: the flip-flop leaves the hand early (was 5, half the swing)
		3, # hp: ranged trades health, not power (was 2)
		4, # dmg: 3 shots a maid; FlipflopBullet's knockback holds her off
		true # ranged
	),
	"Caitlyn": CharacterConfig.new(
		"Caitlyn",
		"Caitlyn IS NOW PLAYABLE",
		true,
		"Artist at Atomic Robot Tattoo",
		preload("res://sprites/cait_sprite_frames.tres"),
		"",
		CharacterSounds.new(
			preload("res://sounds/Voice_Female_V2_Jump_Mono_01.wav"),
			preload("res://sounds/Voice_Female_V1_Hit_Short_Mono_07.wav"),
			preload("res://sounds/Voice_Female_V2_Land_Mono_01.wav"),
			preload("res://sounds/Voice_Female_V2_Attack_Mono_01.wav"),
			preload("res://sounds/sword_attack.wav")  # weapon sound
		),
		5,  # Attack frame
		4, # hp
		4 # dmg: heavy scythe, slow 10-frame swing, 3 blows a maid
	),
	# Locked until the player first beats the boss, and deliberately overpowered:
	# the reward run should feel like a victory lap. Unlock: CharacterUnlocks.
	"Robot": CharacterConfig.new(
		"Robot",
		"ROBOT IS NOW PLAYABLE",
		false,
		"Mascot of Atomic Robot Tattoo",
		preload("res://sprites/robot_sprite_frames.tres"),
		"Beat the boss to unlock!",
		CharacterSounds.new(
			preload("res://sounds/robot_noise.ogg"),
			preload("res://sounds/robot_noise.ogg"),
			preload("res://sounds/Retro FootStep Grass 01.wav"),
			preload("res://sounds/robot_noise.ogg"),
			preload("res://sounds/robot_attack.ogg")  # weapon sound
		),
		5,  # Attack frame
		8, # hp
		6, # dmg: 2 blows a maid, fewest on the roster (the victory lap)
		true # ranged
	)
}

var meters: Array
var meter_maids_killed: int = 0
var meter_maid_boss_killed: int = 0

## Save file for earned unlocks. Tests point it at a temp file.
var unlocks_path := CharacterUnlocks.DEFAULT_PATH
## Fighters unlocked this session that the select screen hasn't revealed yet.
var unseen_unlocks: PackedStringArray = []
## Lock states as shipped, before any save is applied.
var _shipped_unlocks := {}

func _ready() -> void:
	for c in character_dict:
		_shipped_unlocks[c] = character_dict[c].unlocked
	load_unlocks()
	boss_death.connect(_on_boss_death)


## Swap to another save (unit tests, the autoplay bot) so a bot beating the boss
## never unlocks Robot in the player's real save: back to shipped locks, then `path`.
func use_unlock_save(path: String) -> void:
	unlocks_path = path
	unseen_unlocks = PackedStringArray()
	for c in _shipped_unlocks:
		character_dict[c].unlocked = _shipped_unlocks[c]
	load_unlocks()


## Apply the save on top of the shipped lock states.
func load_unlocks() -> void:
	for character in CharacterUnlocks.load_unlocked(unlocks_path):
		if character_dict.has(character):
			character_dict[character].unlocked = true


## Earn `character`: unlock, save, announce. Repeat calls do nothing (boss_death can
## fire on every hit after the boss reaches 0 HP).
func unlock_character(character: String) -> void:
	var cfg: CharacterConfig = character_dict.get(character)
	if cfg == null or cfg.unlocked:
		return
	cfg.unlocked = true
	CharacterUnlocks.save_unlocked(unlocks_path, character)
	unseen_unlocks.append(character)
	unlocked.emit(cfg.get_unlock_text(), cfg.get_description().split("
")[0].strip_edges())


func _on_boss_death() -> void:
	unlock_character(CharacterUnlocks.BOSS_REWARD)


## Turn-taking attack slots (TMNT-style crowd combat): caps how many enemies can be
## actively attacking the player at once so a crowd queues up and takes turns
## instead of dogpiling. Keyed by Enemy.attack_category ("melee"/"ranged").
## See docs/LANE_REFACTOR.md; Enemy.can_attack gates on has_attack_slot_available,
## and AttackPlayerState.enter_state/exit_state claim and release the slot.
## Two melee, not one: with lane exclusivity gone a cap of 1 still reads on screen as
## a 1v1 with spectators. Two attackers is the classic beat-em-up feel and still
## leaves the rest of the crowd visibly queueing.
const MAX_MELEE_ATTACKERS := 2
const MAX_RANGED_ATTACKERS := 2
var _melee_attackers: Array = []
var _ranged_attackers: Array = []

func _attack_slot_array(category: String) -> Array:
	return _melee_attackers if category == "melee" else _ranged_attackers

func _attack_slot_max(category: String) -> int:
	return MAX_MELEE_ATTACKERS if category == "melee" else MAX_RANGED_ATTACKERS

func _prune_attack_slots(arr: Array) -> void:
	for i in range(arr.size() - 1, -1, -1):
		if not is_instance_valid(arr[i]):
			arr.remove_at(i)

## True if `enemy` already holds a slot in its category, or one is free. Pure —
## does not claim. Used to gate whether an enemy may start/continue attacking.
func has_attack_slot_available(category: String, enemy = null) -> bool:
	var arr := _attack_slot_array(category)
	_prune_attack_slots(arr)
	return (enemy != null and arr.has(enemy)) or arr.size() < _attack_slot_max(category)

## Claims a slot for `enemy` in its attack_category. Idempotent if already held.
## Returns false (no claim) if the category is full.
func request_attack_slot(enemy) -> bool:
	var arr := _attack_slot_array(enemy.attack_category)
	_prune_attack_slots(arr)
	if arr.has(enemy):
		return true
	if arr.size() < _attack_slot_max(enemy.attack_category):
		arr.append(enemy)
		return true
	return false

func release_attack_slot(enemy) -> void:
	_melee_attackers.erase(enemy)
	_ranged_attackers.erase(enemy)

## Hard reset of both pools. Setup/teardown only — NEVER wire this to a live gameplay
## signal.
##
## It used to run on `player_death`, which desynchronised the pool from the holders:
## AttackPlayerState tracks its own claim in `_slot_held`, so an enemy mid-swing kept
## believing it held a slot the pool had just forgotten. Two enemies would sit in
## AttackPlayerMeleeState while the pool reported 0/2, and because the cleared slots
## were immediately claimable, fresh attackers pushed the real count over the cap until
## the stale swings ended.
##
## Nothing needs the blunt reset: AttackPlayerState.exit_state releases on every route
## out of a swing, Enemy.die() releases explicitly, and _prune_attack_slots drops
## instances freed by a scene reload.
func reset_attack_slots() -> void:
	_melee_attackers.clear()
	_ranged_attackers.clear()

var destroyed_nodes = {}

func mark_node_destroyed(node_name: String) -> void:
	destroyed_nodes[node_name] = true

func is_node_destroyed(node_name: String) -> bool:
	return destroyed_nodes.get(node_name, false)

func reset() -> void:
	meters.clear()
	meter_maids_killed = 0
	_active_events = 0
	carried_health = -1


## Raw hit points the player walked through the boss door with; -1 = nothing carried.
## boss_room.tscn has its own Player, whose _init takes this once (take_carried_health)
## so the street's hearts survive the door but a later restart starts fresh.
var carried_health: int = -1


func carry_health(hp: int) -> void:
	carried_health = hp


## The carried health, or `fallback` when nothing (or nothing alive) was carried.
## Clears the carry: only the very next Player gets it.
func take_carried_health(fallback: int) -> int:
	var hp := carried_health
	carried_health = -1
	return hp if hp > 0 else fallback


## `event` is listened to by EnemyManager (pauses ambient waves), Player (slows on
## start) and the notification banner. Overlapping emitters used to fight over it —
## BuildingGroup3 has two EnemyEvent volumes, and whichever finished first emitted
## `event(false)` while the other was still running. Refcount so it only flips on
## the first push and the last pop.
var _active_events: int = 0

func push_event() -> void:
	_active_events += 1
	if _active_events == 1:
		event.emit(true)

func pop_event() -> void:
	_active_events = maxi(0, _active_events - 1)
	if _active_events == 0:
		event.emit(false)


# DevTools/testing entry hook: skip menus straight into a playable scene.
# Wired via addons/godot_selftest/devtools_config.json entry_hook and the
# devtools "start_game" verb. Not used by normal gameplay.
func debug_start_game(character: String = "Ryan", scene: String = "res://scenes/main.tscn") -> void:
	if character_dict.has(character):
		selected_character = character
	get_tree().change_scene_to_file.call_deferred(scene)


func nearest_meter(pos: Vector2) -> Node2D:
	var lowest_distance = 32323  
	var nearest_meter: Node2D = null 

	for meter in meters:
		if not is_instance_valid(meter):
			continue
		var dist = pos.distance_to(meter.global_position)
		if dist < lowest_distance:
			lowest_distance = dist
			nearest_meter = meter  

	return nearest_meter

# Character configuration helper methods
func get_current_character() -> CharacterConfig:
	return character_dict.get(selected_character)
	
func get_current_character_by_name(_name: String) -> CharacterConfig:
	return character_dict.get(_name)

func get_character_sound(character_name: String, sound_type: String) -> AudioStream:
	var character_config = character_dict.get(character_name)
	if not character_config:
		return null
		
	match sound_type:
		"jump":
			return character_config.get_jump_sound()
		"hit":
			return character_config.get_hit_sound()
		"land":
			return character_config.get_land_sound()
		"attack":
			return character_config.get_attack_sound()
		_:
			return null

func get_current_character_sound(sound_type: String) -> AudioStream:
	return get_character_sound(selected_character, sound_type)

func get_current_character_attack_frame() -> int:
	var character_config = get_current_character()
	if character_config:
		return character_config.get_attack_frame()
	return 0

func get_character_attack_frame(character_name: String) -> int:
	var character_config = character_dict.get(character_name)
	if character_config:
		return character_config.get_attack_frame()
	return 0
