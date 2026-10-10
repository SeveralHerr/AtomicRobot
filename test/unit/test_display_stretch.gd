extends RefCounted

## The cabinet is 4:3 and phones are ~19.5:9: "keep" letterboxed both. "expand" grows
## the 1280x800 design canvas along the free axis so every screen is filled; UI must
## anchor to the visible rect, not to 1280x800.

var _T


func test_stretch_fills_any_aspect() -> String:
	var r: String = _T.assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "stretch aspect")
	if r != "":
		return r
	return _T.assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch mode")


func test_design_size_unchanged() -> String:
	var size := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	return _T.assert_eq(size, Vector2i(1280, 800), "design canvas (16:10 must look as before)")
