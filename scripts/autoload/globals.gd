extends Node

signal player_death
signal meter_maid_death
signal meter_maid_boss_death
signal unlocked(name: String, description: String)
signal boss_fight(status: bool)
signal event(status: bool)
signal newspaper(status: bool)
signal gust(position: Vector2, range: float)

var selected_character: String = "Ryan"
var character_dict: Dictionary[String, CharacterConfig] = {
	"Robot": CharacterConfig.new(
		"Robot",
		"ROBOT IS NOW PLAYABLE", 
		true,
		"Atomic Robot Tattoo Mascot",
		preload("res://sprites/cody_sprite_frames.tres"),
		"",
		CharacterSounds.new(
			preload("res://sounds/Voice_Male_V2_Jump_Mono_05.wav"),
			preload("res://sounds/Voice_Male_V1_Hit_Short_Mono_07.wav"),
			preload("res://sounds/Retro FootStep Grass 01.wav"),
			preload("res://sounds/Voice_Male_V2_Attack_Short_Mono_07.wav"),
			preload("res://sounds/sword_attack.wav")  # weapon sound
		),
		2  # Attack frame
	),
	"Cody": CharacterConfig.new(
		"Cody",
		"CODY IS NOW PLAYABLE",
		true, 
		"Owner of Atomic Robot Tattoo
		+2 hp    +2 dmg",
		preload("res://sprites/cody_sprite_frames.tres"),
		"",
		CharacterSounds.new(
			preload("res://sounds/Voice_Male_V2_Jump_Mono_05.wav"),
			preload("res://sounds/Voice_Male_V1_Hit_Short_Mono_07.wav"),
			preload("res://sounds/Retro FootStep Grass 01.wav"),
			preload("res://sounds/Voice_Male_V2_Attack_Short_Mono_07.wav"),
			preload("res://sounds/lightsaber.wav")  # weapon sound
		),
		2,  # Attack frame,
		2, # hp
		2 # dmg
		
	),
	"Ryan": CharacterConfig.new(
		"Ryan",
		"RYAN IS NOW PLAYABLE",
		true,
		"Employee of Atomic Robot Tattoo
		+3 hp    +1 dmg", 
		preload("res://sprites/ryan_sprite_frames.tres"),
		"",
		CharacterSounds.new(
			preload("res://sounds/Voice_Male_V2_Jump_Mono_05.wav"),
			preload("res://sounds/Voice_Male_V1_Hit_Short_Mono_07.wav"),
			preload("res://sounds/Retro FootStep Grass 01.wav"),
			preload("res://sounds/Voice_Male_V2_Attack_Short_Mono_07.wav"),
			preload("res://sounds/sword_attack.wav")  # weapon sound
		),
		3,  # Attack frame
		3, # hp
		1 # dmg
	),
	"Sara": CharacterConfig.new(
		"Sara",
		"SARA IS NOW PLAYABLE",
		true,
		"Employee of Atomic Robot Tattoo
		+3 hp    +1 dmg", 
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
		3, # hp
		1 # dmg
	)
}

var meters: Array
var meter_maids_killed: int = 0
var meter_maid_boss_killed: int = 0

var destroyed_nodes = {}

func mark_node_destroyed(node_name: String) -> void:
	destroyed_nodes[node_name] = true

func is_node_destroyed(node_name: String) -> bool:
	return destroyed_nodes.get(node_name, false)

func reset() -> void:
	meters.clear()
	meter_maids_killed = 0


func nearest_meter(pos: Vector2) -> Node2D:
	var lowest_distance = 32323  
	var nearest_meter: Node2D = null 

	for meter in meters:
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
