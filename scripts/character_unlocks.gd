extends RefCounted

## Which fighters the player has earned, on disk so an unlock survives quitting.
## Only earned unlocks are written; a fighter's starting lock state lives in its
## CharacterConfig (Globals.character_dict), so a fresh save means "as shipped".

const DEFAULT_PATH := "user://unlocks.cfg"
const SECTION := "unlocked"
## Which story beat earns which fighter. The boss is the only one so far.
const BOSS_REWARD := "Robot"


## Fighters marked unlocked in the save at `path` (empty when there's no save).
static func load_unlocked(path: String) -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section(SECTION):
		return PackedStringArray()
	var out := PackedStringArray()
	for key in cfg.get_section_keys(SECTION):
		# Strictly bool true: a hand-edited save can hold any Variant, Objects included.
		var v: Variant = cfg.get_value(SECTION, key, false)
		if typeof(v) == TYPE_BOOL and v:
			out.append(key)
	return out


static func save_unlocked(path: String, character: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)  # keep earlier unlocks; a missing file is fine
	cfg.set_value(SECTION, character, true)
	cfg.save(path)
