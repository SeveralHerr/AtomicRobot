extends Node
class_name CharacterConfig

var character_name: String
var unlock_text: String
var unlocked: bool = false
var description: String
var sprite_frames: SpriteFrames
var unlock_hint: String
var sounds: CharacterSounds
var attack_frame: int = 0  # Which frame of attack animation triggers the attack
var starting_health: int = 3
var starting_damage: int = 2

func _init(_name: String, _unlock_text: String, _unlocked: bool, _description: String, _sprite_frames: SpriteFrames, _unlock_hint: String, _sounds: CharacterSounds, _attack_frame: int = 0, _starting_health: int = 2, _starting_damage: int = 1) -> void:
	character_name = _name
	unlock_text = _unlock_text
	unlocked = _unlocked
	description = _description
	sprite_frames = _sprite_frames
	unlock_hint = _unlock_hint
	sounds = _sounds
	attack_frame = _attack_frame
	starting_health = _starting_health
	starting_damage = _starting_damage

func get_character_name() -> String:
	return character_name

func get_unlock_text() -> String:
	return unlock_text

func get_unlocked() -> bool:
	return unlocked

func set_unlocked(value: bool) -> void:
	unlocked = value

func get_description() -> String:
	return description

func get_sprite_frames() -> SpriteFrames:
	return sprite_frames

func get_unlock_hint() -> String:
	return unlock_hint

func get_sounds() -> CharacterSounds:
	return sounds

func get_jump_sound() -> AudioStream:
	return sounds.jump_sound

func get_hit_sound() -> AudioStream:
	return sounds.hit_sound

func get_land_sound() -> AudioStream:
	return sounds.land_sound

func get_attack_sound() -> AudioStream:
	return sounds.attack_sound

func get_weapon_sound() -> AudioStream:
	return sounds.weapon_sound

func get_attack_frame() -> int:
	return attack_frame

func get_starting_health() -> int: 
	return starting_health
	
func get_starting_damage() -> int: 
	return starting_damage
