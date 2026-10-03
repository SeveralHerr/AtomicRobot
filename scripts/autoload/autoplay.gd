extends Node

## Test-only autoplay bot entry point (see skills/godot-autoplay-test/SKILL.md).
## Inert — frees itself on the first frame — unless the game is run from the
## project (editor binary, never an exported template) with:
##   -- --autoplay <scenario.json | inline JSON> [--autoplay-out <dir>]
## The bot itself lives in res://tools/autoplay/, which every export preset also
## excludes — two independent locks, so a new preset can't ship it by accident.

const RUNNER := "res://tools/autoplay/runner.gd"
const DEFAULT_OUT := "res://autoplay_out"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--autoplay")
	if OS.has_feature("template") or not OS.is_debug_build() or i == -1 or i + 1 >= args.size() or not ResourceLoader.exists(RUNNER):
		queue_free()
		return
	var o := args.find("--autoplay-out")
	var out := args[o + 1] if o != -1 and o + 1 < args.size() else ProjectSettings.globalize_path(DEFAULT_OUT)
	var runner: Node = load(RUNNER).new()
	runner.name = "AutoplayRunner"
	add_child(runner)
	runner.setup(args[i + 1], out)
