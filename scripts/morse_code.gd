extends RefCounted
## International Morse timing as data: a word becomes a looping list of
## [lit: bool, units: int] segments (dot 1, dash 3, intra-letter gap 1,
## letter gap 3, trailing word gap 7). Pure and static so tests drive it directly.

const DOT := 1
const DASH := 3
const INTRA_GAP := 1
const LETTER_GAP := 3
const WORD_GAP := 7

const TABLE := {
	"A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.",
	"G": "--.", "H": "....", "I": "..", "J": ".---", "K": "-.-", "L": ".-..",
	"M": "--", "N": "-.", "O": "---", "P": ".--.", "Q": "--.-", "R": ".-.",
	"S": "...", "T": "-", "U": "..-", "V": "...-", "W": ".--", "X": "-..-",
	"Y": "-.--", "Z": "--..",
}


static func timeline(word: String) -> Array:
	var out := []
	var letters := word.to_upper()
	for li in letters.length():
		if li > 0:
			out.append([false, LETTER_GAP])
		var code: String = TABLE[letters[li]]
		for si in code.length():
			if si > 0:
				out.append([false, INTRA_GAP])
			out.append([true, DOT if code[si] == "." else DASH])
	out.append([false, WORD_GAP])
	return out


static func total_units(tl: Array) -> int:
	var n := 0
	for seg in tl:
		n += seg[1]
	return n


## Whether the light is on `units` into the loop (wraps every total_units).
static func lit_at(tl: Array, units: float) -> bool:
	var t := fposmod(units, float(total_units(tl)))
	for seg in tl:
		if t < seg[1]:
			return seg[0]
		t -= seg[1]
	return false


## Inverse of timeline() for one word: lets tests prove the table round-trips.
static func decode(tl: Array) -> String:
	var by_code := {}
	for k in TABLE:
		by_code[TABLE[k]] = k
	var word := ""
	var code := ""
	for seg in tl:
		if seg[0]:
			code += "." if seg[1] == DOT else "-"
		elif seg[1] != INTRA_GAP:
			word += by_code.get(code, "?")
			code = ""
	return word
