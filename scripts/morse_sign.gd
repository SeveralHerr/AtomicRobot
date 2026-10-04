extends Node2D
## Secret: the shop sign's neon outline blinks `word` in International Morse.
## No prompt, no reward. Off = dimmed tube (sign stays legible); on = bright tube
## + additive halo with a faint buzz. Held lit while a cut scene plays.

const MORSE := preload("res://scripts/morse_code.gd")

@export var word := "ATOMIC"
@export var unit := 0.2               ## seconds per Morse unit
@export var lit_tube := Color(1.0, 0.93, 0.95)
@export var dim_tube := Color(0.66, 0.7, 0.8)
@export var lit_halo := Color(1.0, 0.3, 0.42, 0.8)
@export var buzz := 0.12              ## random halo flutter while lit (0 = steady)
@export var dim_glow := 0.15          ## halo fraction left on while "off" (dimmed, not dead)
@export var afterglow := 0.06         ## seconds the halo takes to die after a blink

@onready var tube: Sprite2D = $Tube
@onready var halo: Sprite2D = $Halo

var _timeline: Array
var _t := 0.0
var _glow := 1.0
## Own RNG: the global randf() stream is seeded for autoplay runs, and an ambient
## prop drawing from it every frame reshuffled every seeded fight.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_timeline = MORSE.timeline(word)
	_apply(true)


func _process(delta: float) -> void:
	if MicroCutscene.playing:
		_apply(true)
		return
	_t += delta
	_apply(MORSE.lit_at(_timeline, _t / unit), delta)


## Tube snaps (it is the Morse); the halo snaps on and fades over `afterglow`.
func _apply(lit: bool, delta: float = 0.0) -> void:
	tube.modulate = lit_tube if lit else dim_tube
	_glow = 1.0 - _rng.randf() * buzz if lit else maxf(dim_glow, _glow - delta / afterglow)
	var c := lit_halo
	c.a = lit_halo.a * _glow
	halo.modulate = c
