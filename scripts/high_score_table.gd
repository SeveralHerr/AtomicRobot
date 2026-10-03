class_name HighScoreTable
extends RefCounted

## The arcade high-score list: top SIZE runs, each tagged with three initials.
##
## Static and side-effect free, like ScoreRules, so the ordering and the input checks
## are unit-testable headless (test/unit/test_high_score_table.gd). Persistence lives
## in ScoreSystem; the entry and board screens are scripts/ui/initials_entry.gd and
## scripts/ui/high_score_board.gd.
##
## An entry is {"initials": String, "score": int, "rank": String}. Plain Dictionaries
## rather than a Resource so a ConfigFile can store the list as-is.

const SIZE := 10
const INITIALS_LENGTH := 3
## Letters an arcade player can dial in: A-Z, the same set atomic-pinball uses on the
## same cabinet, so the initials wheel behaves identically in both games.
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DEFAULT_INITIALS := "AAA"


## Whether `score` earns a place on `entries`. A tie with the last place does NOT
## qualify: the incumbent got there first, which is the arcade convention.
static func qualifies(entries: Array, score: int) -> bool:
	if score <= 0:
		return false
	if entries.size() < SIZE:
		return true
	return score > int(entries[SIZE - 1]["score"])


## The row `score` would land on, or -1 if it does not qualify. Ties go BELOW the
## existing entry, for the same reason as qualifies().
static func slot_for(entries: Array, score: int) -> int:
	if not qualifies(entries, score):
		return -1
	for i in entries.size():
		if score > int(entries[i]["score"]):
			return i
	return entries.size()


## Insert `entry` in place and trim to SIZE. Returns the row it landed on, or -1.
static func insert(entries: Array, entry: Dictionary) -> int:
	var slot := slot_for(entries, int(entry.get("score", 0)))
	if slot < 0:
		return -1
	entries.insert(slot, make_entry(String(entry.get("initials", "")), int(entry["score"]), String(entry.get("rank", ""))))
	entries.resize(mini(entries.size(), SIZE))
	return slot


static func make_entry(initials: String, score: int, rank: String = "") -> Dictionary:
	return {"initials": sanitize_initials(initials), "score": maxi(0, score), "rank": sanitize_rank(rank)}


## Uppercase, drop anything outside ALPHABET, then cut, or pad with "A" (the wheel's
## start letter), to INITIALS_LENGTH.
## Everything that reaches the save file or the screen goes through here, including
## whatever was read back from disk — the save is a user-editable file.
static func sanitize_initials(raw: String) -> String:
	var out := ""
	for c in raw.to_upper():
		if c in ALPHABET:
			out += c
		if out.length() == INITIALS_LENGTH:
			break
	while out.length() < INITIALS_LENGTH:
		out += ALPHABET[0]
	return out


## A rank is a single letter from ScoreRules.RANK_THRESHOLDS, or "" for a run that
## ended in death (no rank card, so no letter).
static func sanitize_rank(raw: String) -> String:
	for entry in ScoreRules.RANK_THRESHOLDS:
		if raw == String(entry[0]):
			return raw
	return ""


## Rebuild a table from untrusted storage: wrong types, junk rows, an over-long list
## and an unsorted one all come back as a valid table.
static func from_variant(data: Variant) -> Array:
	var entries: Array = []
	if not data is Array:
		return entries
	for row in data:
		if row is Dictionary and row.has("score"):
			insert(entries, {
				"initials": str(row.get("initials", "")),
				"score": int(str(row.get("score", 0)).to_int()),
				"rank": str(row.get("rank", "")),
			})
	return entries


## Step one initials letter through ALPHABET, wrapping at both ends.
static func cycle_letter(letter: String, step: int) -> String:
	var i := ALPHABET.find(letter)
	if i < 0:
		i = 0
	return ALPHABET[posmod(i + step, ALPHABET.length())]
