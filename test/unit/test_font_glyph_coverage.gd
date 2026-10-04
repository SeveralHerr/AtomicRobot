extends RefCounted

# Every character the game puts on screen must exist in the font that draws it.
#
# On desktop, Godot quietly falls back to a system font for a missing glyph, so a
# character the project's font doesn't have looks perfectly fine in the editor. The
# exported WEB build has no system fonts to fall back on: the same text renders as
# blank boxes or drops out entirely. That is how the controls splash shipped with an
# em dash on every single line ("MOVE — A/D") and read as broken on the deployed
# mobile page while looking correct to everyone testing it locally.
#
# These tests scan the actual authored text rather than a hand-kept list, so new
# copy-pasted text (smart quotes out of a word processor are the usual culprit) is
# caught the first time the suite runs.

var _T

const BODY_FONT := "res://styles/AldotheApache.ttf"
const HEADER_FONT := "res://styles/KomikaTitlePaint-D3x.ttf"
## Scenes whose on-screen text is drawn in the fonts above.
const UI_SCENES: Array[String] = [
	"res://scenes/controls_splash.tscn",
	"res://scenes/pause_menu.tscn",
	"res://scenes/mobile_controls.tscn",
]


## Characters in `text` that `font` cannot draw. Whitespace is always fine.
func _missing_glyphs(font: Font, text: String) -> String:
	var missing := ""
	for i in text.length():
		var c := text[i]
		var code := c.unicode_at(0)
		if code <= 32:  # space, tab, newline
			continue
		if not font.has_char(code) and not missing.contains(c):
			missing += c
	return missing


## Raw `text = "..."` values authored in a scene file. Reading the .tscn source keeps
## this headless-safe (no instantiation, no @onready, no missing-node noise) and
## catches text on any node type, Label or Button alike.
func _scene_texts(path: String) -> Array[String]:
	var out: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var source := file.get_as_text()
	file.close()
	var re := RegEx.create_from_string('(?m)^text = "((?:[^"\\\\]|\\\\.)*)"')
	for m in re.search_all(source):
		out.append(m.get_string(1).replace("\\n", "\n"))
	return out


func test_ui_scene_text_is_drawable_in_the_body_font() -> String:
	var font: FontFile = load(BODY_FONT)
	if font == null:
		return "could not load %s" % BODY_FONT
	for scene in UI_SCENES:
		for text in _scene_texts(scene):
			var missing := _missing_glyphs(font, text)
			if missing != "":
				return "%s: text %s uses glyph(s) [%s] the body font has no character for" % [
					scene, JSON.stringify(text), missing]
	return ""


## The one that actually shipped: an em dash is the character a writer reaches for and
## the one this font does not have. Pinning it keeps the rule from being "fixed" by
## quietly re-adding a fallback font that only exists on desktop.
func test_the_glyphs_that_broke_the_web_build_are_still_absent() -> String:
	var font: FontFile = load(BODY_FONT)
	for c in ["—", "‘", "’", "“", "”"]:
		if font.has_char(c.unicode_at(0)):
			continue
		var r: String = _T.assert_false(font.has_char(c.unicode_at(0)),
			"U+%04X absent, so no authored text may use it" % c.unicode_at(0))
		if r != "":
			return r
	return ""


## Newspaper headlines are set from GDScript, not from a scene, so the scene scan
## above cannot see them - and they are long prose strings, the likeliest place for a
## pasted smart quote to hide.
func test_newspaper_headlines_are_drawable() -> String:
	# Drawn on the stand's NewsCard, in that card's headline font.
	var font: FontFile = NewsCard.HEADLINE_FONT
	var script: GDScript = load("res://scripts/interactive_mailbox.gd")
	var mailbox = script.new()
	var headlines: Array = mailbox.newspaper_texts
	var r: String = _T.assert_gt(float(headlines.size()), 0.0, "headlines exist to check")
	if r != "":
		return r
	for headline in headlines:
		var missing := _missing_glyphs(font, str(headline))
		if missing != "":
			return "headline %s uses glyph(s) [%s] the body font has no character for" % [
				JSON.stringify(headline), missing]
	return ""


## The controls page is the one screen a new player reads before touching anything, so
## it must name every control the game actually binds - including pause, which is the
## only way to reach volume and the CRT toggle.
func test_controls_page_covers_every_bound_action() -> String:
	var texts := _scene_texts("res://scenes/controls_splash.tscn")
	var page := "\n".join(texts).to_upper()
	for needle in ["MOVE", "JUMP", "ATTACK", "USE", "RUN", "CROUCH", "PAUSE"]:
		if not page.contains(needle):
			return "controls page never mentions %s" % needle
	# The pause menu's own buttons, so a player knows what pausing gets them.
	for needle in ["VOLUME", "CRT", "RESUME"]:
		if not page.contains(needle):
			return "controls page never mentions the pause menu's %s" % needle
	return ""
