extends RefCounted

# The enemy hurt "oof" (ReceiveHitAudio) was too loud. Enemy._ready trims it by
# Enemy.HIT_SOUND_TRIM_DB on top of each scene's authored volume_db, so every maid
# variant drops by the same amount and nothing else (coin sfx, player hurt) moves.

var _T

const SCENES := [
	"res://scenes/meter_maid.tscn",
	"res://scenes/meter_maid_melee.tscn",
	"res://scenes/meter_maid_platform.tscn",
	"res://scenes/meter_maid_window.tscn",
	"res://scenes/final_boss.tscn",
]

var _nodes: Array[Node] = []


func teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func test_trim_is_about_half_amplitude() -> String:
	return _T.assert_float_eq(Enemy.HIT_SOUND_TRIM_DB, -6.0, 0.01, "hurt trim is -6 dB")


func test_every_enemy_hit_sound_is_trimmed_and_coin_sound_is_not() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	for path in SCENES:
		var e: Enemy = (load(path) as PackedScene).instantiate()
		var hit_authored: float = (e.get_node("ReceiveHitAudio") as AudioStreamPlayer).volume_db
		var coin_authored: float = (e.get_node("CoinAudioPlayer") as AudioStreamPlayer2D).volume_db
		tree.root.add_child(e)
		e.set_physics_process(false)
		_nodes.append(e)
		var r: String = _T.assert_float_eq(e.receive_hit_audio.volume_db,
			hit_authored + Enemy.HIT_SOUND_TRIM_DB, 0.001, path + " hurt sound trimmed")
		if r != "":
			return r
		r = _T.assert_float_eq(e.coin_audio_player.volume_db, coin_authored, 0.001,
			path + " coin sound untouched")
		if r != "":
			return r
	return ""
