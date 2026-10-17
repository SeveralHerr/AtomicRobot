extends RefCounted

## Which fighters the player has earned, on disk so an unlock survives quitting.
## Only earned unlocks are written; a fighter's starting lock state lives in its
## CharacterConfig (Globals.character_dict), so a fresh save means "as shipped".

const DEFAULT_PATH := "user://unlocks.cfg"
const SECTION := "unlocked"
## Fighters who have beaten the boss at least once.
const BEATEN := "beaten"
## Earned once every other fighter has beaten the boss.
const BOSS_REWARD := "Robot"


## Fighters marked unlocked in the save at `path` (empty when there's no save).
static func load_unlocked(path: String) -> PackedStringArray:
	return _load_flags(path, SECTION)


static func save_unlocked(path: String, character: String) -> void:
	_save_flag(path, SECTION, character)


## Fighters who have beaten the boss, per the save at `path`.
static func load_beaten(path: String) -> PackedStringArray:
	return _load_flags(path, BEATEN)


static func save_beaten(path: String, character: String) -> void:
	_save_flag(path, BEATEN, character)


static func _load_flags(path: String, section: String) -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section(section):
		return PackedStringArray()
	var out := PackedStringArray()
	for key in cfg.get_section_keys(section):
		# Strictly bool true: a hand-edited save can hold any Variant, Objects included.
		var v: Variant = cfg.get_value(section, key, false)
		if typeof(v) == TYPE_BOOL and v:
			out.append(key)
	return out


static func _save_flag(path: String, section: String, character: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)  # keep earlier flags; a missing file is fine
	cfg.set_value(section, character, true)
	cfg.save(path)
