extends RefCounted

# CRTOverlay focus: while the end card is up the tube "tunes in" (finer pixel grid,
# less fringing/scanlines/glare) so its text reads; the player's report was that the
# win / game over card was hard to read with CRT on. Focus 0 is the normal look.

var _T


func _param(name: String) -> Variant:
	return CRTOverlay._material.get_shader_parameter(name)


func teardown() -> void:
	CRTOverlay.focus = 0.0


func test_crt_focus_zero_is_the_normal_look() -> String:
	CRTOverlay.focus = 0.0
	var r: String = _T.assert_eq(_param("resolution"), CRTOverlay.resolution, "grid as exported")
	if r != "":
		return r
	return _T.assert_float_eq(float(_param("aberration")), CRTOverlay.aberration, 0.0001, "fringe as exported")


func test_crt_full_focus_reaches_the_focus_preset() -> String:
	CRTOverlay.focus = 1.0
	for key in CRTOverlay.FOCUS:
		var want: Variant = CRTOverlay.FOCUS[key]
		var got: Variant = _param(key)
		var r: String = _T.assert_true(is_equal_approx(float(got), float(want)) if not (want is Vector2)
			else (got as Vector2).is_equal_approx(want), "%s %s -> %s" % [key, got, want])
		if r != "":
			return r
	return ""


func test_crt_focus_preset_is_easier_to_read_than_the_normal_look() -> String:
	var f: Dictionary = CRTOverlay.FOCUS
	var r: String = _T.assert_gt(f["resolution"].x, CRTOverlay.resolution.x, "finer grid")
	if r != "":
		return r
	for key in ["aberration", "scanlines_opacity", "grille_opacity", "noise_opacity", "brightness"]:
		r = _T.assert_true(float(f[key]) < float(CRTOverlay.get(key)), "%s calmer" % key)
		if r != "":
			return r
	return ""


func test_crt_half_focus_blends() -> String:
	CRTOverlay.focus = 0.5
	var want := lerpf(CRTOverlay.scanlines_opacity, CRTOverlay.FOCUS["scanlines_opacity"], 0.5)
	return _T.assert_float_eq(float(_param("scanlines_opacity")), want, 0.0001, "halfway")


## Changing an exported knob while focused keeps the focus blend, and dropping the
## focus lands on the new knob.
func test_crt_unfocus_restores_a_retuned_knob() -> String:
	var old := CRTOverlay.scanlines_opacity
	CRTOverlay.focus = 1.0
	CRTOverlay.scanlines_opacity = 0.5
	var r: String = _T.assert_float_eq(float(_param("scanlines_opacity")), CRTOverlay.FOCUS["scanlines_opacity"], 0.0001, "focus wins")
	CRTOverlay.focus = 0.0
	var back := float(_param("scanlines_opacity"))
	CRTOverlay.scanlines_opacity = old
	if r != "":
		return r
	return _T.assert_float_eq(back, 0.5, 0.0001, "unfocused shows the retuned knob")
