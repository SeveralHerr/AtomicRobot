extends RefCounted

## Builds, writes and summarises the run report. The summary is the part an agent
## reads first: at most ~15 lines, one fact per line, then the JSON path for detail.

const RESULT_NAMES := {0: "PASS", 1: "FAIL", 2: "BROKEN"}


const Recorder := preload("res://tools/autoplay/recorder.gd")


static func build(name: String, code: int, reason: String, rec: Recorder, asserts: Array, tree: SceneTree) -> Dictionary:
	return sanitize({
		"name": name, "result": RESULT_NAMES.get(code, "FAIL"), "code": code, "reason": reason,
		"metrics": rec.metrics(tree), "asserts": asserts, "scenes": Array(rec.scenes),
		"stuck_spots": rec.stuck_spots, "step_failures": rec.step_failures,
		"errors": rec.top_errors(), "snaps": Array(rec.snaps), "snaps_skipped": rec.events.filter(func(e: Dictionary) -> bool: return e["ev"] == "snap" and e.has("skipped")).size(),
		"events": rec.events, "dropped_events": rec.dropped_events,
	})


## Returns the report path, or "" when it could not be written.
static func write(report: Dictionary, out_dir: String) -> String:
	if out_dir == "":
		return ""
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join("%s.json" % report["name"])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(report, "  "))
	return path


static func summary(r: Dictionary, path: String) -> String:
	var m: Dictionary = r["metrics"]
	var lines := PackedStringArray()
	lines.append("AUTOPLAY %s  %s  t=%ss frames=%d" % [r["name"], r["result"], m["t"], m["frames"]])
	if r["reason"] != "":
		lines.append("  reason: %s" % r["reason"])
	if r["result"] == "BROKEN":
		lines.append("RESULT: BROKEN")
		return "\n".join(lines)
	for f: Dictionary in r.get("step_failures", []).slice(0, 3):
		lines.append("  step failed: %s: %s" % [f["step"], f["reason"]])
	lines.append("  scenes: %s" % " > ".join(r["scenes"]))
	lines.append("  end: scene=%s x=%d lane=%s hp=%s/%s state=%s" % [m["scene"], m["x"], m["lane"], m["hp"], m["max_hp"], m["state"]])
	lines.append("  combat: kills=%d hits_taken=%d car_hits=%d damage=%d heals=%d deaths=%d won=%d score=%s%s" % [
		m["kills"], m["hits_taken"], m.get("car_hits", 0), m["damage_taken"], m["heals"], m["deaths"], m["won"], m["score"],
		"" if m.get("boss_hp", -1) < 0 else " boss_hp=%d" % m["boss_hp"]])
	for e: Dictionary in r.get("events", []):
		if e.get("ev") == "run":
			lines.append("  run: total=%s rank=%s street=%s boss=%s time=%s(+%s) health=+%s secrets=%s/%s(+%s)" % [
				e["total"], e["rank"], e["street_score"], e["boss_score"], snappedf(float(e["seconds"]), 0.1),
				e["time_bonus"], e["no_damage_bonus"], e["secrets"], e["secret_totals"], e["secret_bonus"]])
	lines.append("  stuck: max=%ss spots=%s" % [m["max_stuck_s"], _spots(r["stuck_spots"])])
	lines.append("  errors: script=%d engine=%d warnings=%d" % [m["errors"], m["engine_errors"], m["warnings"]])
	for e: Dictionary in r["errors"].slice(0, 3):
		lines.append("    %dx %s" % [e["count"], e["site"]])
	for a: Dictionary in r["asserts"]:
		lines.append("  %s %s (actual %s)" % ["ok  " if a["pass"] else "FAIL", a["text"], a["actual"]])
	if not r["snaps"].is_empty():
		lines.append("  snaps: %d in %s" % [r["snaps"].size(), str(r["snaps"][0]).get_base_dir()])
	elif r.get("snaps_skipped", 0) > 0:
		lines.append("  snaps: %d skipped (headless; rerun with --window for PNGs)" % r["snaps_skipped"])
	lines.append("  report: %s" % (path if path != "" else "(not written)"))
	lines.append("RESULT: %s" % r["result"])
	return "\n".join(lines)


static func _spots(spots: Array) -> String:
	if spots.is_empty():
		return "none"
	var parts := PackedStringArray()
	for s: Dictionary in spots.slice(0, 6):
		parts.append("%s@x%d/l%s" % [s["scene"], s["x"], s["lane"]])
	return ", ".join(parts) + (" (+%d)" % (spots.size() - 6) if spots.size() > 6 else "")


## JSON has no INF/NaN: replace them (and nested ones) with null.
static func sanitize(v: Variant) -> Variant:
	if v is float and not is_finite(v):
		return null
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = sanitize(v[k])
		return d
	if v is Array:
		var a := []
		for x in v:
			a.append(sanitize(x))
		return a
	return v
