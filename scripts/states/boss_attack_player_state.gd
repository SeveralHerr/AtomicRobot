extends AttackPlayerState
class_name BossAttackPlayerState

## The final boss's briefcase throw. Same swing machinery as the maids, but the
## boss never disengages: no chase or patrol state, so he re-arms in place. The beat
## between throws, the fan size and when he breaks off to charge all come from his
## current phase (BossRules), so the fight ramps without touching this file.

## Launch speed of a thrown briefcase (px/s). A coin flies at 600.
const THROW_SPEED := 420.0

var _throws_since_dash: int = 0
## Where the throw goes, locked at the wind-up tell: move after the shake and it
## misses. Without the lock the aim tracked you to the release frame — undodgeable.
var _aim: Vector2
var _aim_locked: bool = false
## False until the fight's first swing has been held back by OPENING_GRACE.
var _opened: bool = false


func _init(e: Enemy) -> void:
	super._init(e)
	release_frame_hint = 4
	telegraph_frame = 1  # wind-up shake: the tell that a throw is coming
	re_arm_delay = BossRules.params(0)["throw_delay"]


func _boss() -> FinalBoss:
	return enemy as FinalBoss


func _do_hit() -> void:
	var p := _boss().params()
	re_arm_delay = p["throw_delay"]
	var player := enemy.player
	if player == null:
		return
	var from: Vector2 = enemy.coin_spawn_point.global_position
	var aim := _aim if _aim_locked else _player_aim()
	_aim_locked = false
	# A fan of `burst` briefcases: one at the player, the rest stepped UPWARD by
	# `spread_deg` — they sail over a player who stands still and catch one who jumps.
	var up := 1.0 if aim.x < from.x else -1.0  # rotation sign that lifts the aim
	var fan: Array[Bullet] = []
	for i in int(p["burst"]):
		var target := from + (aim - from).rotated(deg_to_rad(i * float(p["spread_deg"]) * up))
		fan.append(Utils.throw_briefcase(from, target, player.get_parent(), false, 0.55, false, THROW_SPEED))
	link_fan(fan)
	_throws_since_dash += 1


## One fan, one hit: once any briefcase connects, its siblings are disarmed. Without
## this the knockback launched the player up into the higher ones — three hits in
## half a second from a single throw.
static func link_fan(fan: Array[Bullet]) -> void:
	for b in fan:
		b.tree_exiting.connect(func() -> void:
			if b.has_hit_player:
				for other in fan:
					if is_instance_valid(other):
						other.has_hit_player = true)


func _player_aim() -> Vector2:
	var aim: Vector2 = enemy.player.enemy_attack_position.global_position
	aim.y += 10 if _player_is_crouched() else 0
	return aim


func _begin_swing() -> void:
	_aim_locked = false
	if not _opened:
		# The opening beat: start "between throws", OPENING_GRACE short of a re-arm.
		_opened = true
		attack_finished = true
		_hold = re_arm_delay - BossRules.OPENING_GRACE
		return
	super._begin_swing()


func _telegraph(gen: int) -> void:
	if enemy.player:
		_aim = _player_aim()
		_aim_locked = true
	super._telegraph(gen)


## Silent while staggered between phases or after the killing blow.
func _should_re_arm() -> bool:
	return _boss().fighting and not _boss().staggered


func update(delta: float) -> void:
	var every: int = _boss().params()["dash_every"]
	if attack_finished and every > 0 and _throws_since_dash >= every and _should_re_arm():
		_throws_since_dash = 0
		enemy.enemy_state_machine.change_state("BossDashState")
		return
	super.update(delta)
