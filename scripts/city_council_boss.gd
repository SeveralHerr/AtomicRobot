extends Enemy
class_name FinalBoss

## The City Council boss. Three phases keyed off health (see BossRules); the room
## (boss_room.gd) listens to the signals below to run the waves, banner and HUD bar.
## He waits inert until the room's intro calls begin_fight().

signal health_changed(health: int, max_health: int)
signal phase_changed(phase: int)
## The killing blow landed. Globals.boss_death follows once the finale has played.
signal defeated

## Phase tints: he goes red in the face as the meeting runs long.
const PHASE_TINTS: Array[Color] = [Color.WHITE, Color(1.0, 0.82, 0.78), Color(1.0, 0.6, 0.55)]
## Finale: real seconds of slow motion after the last hit, then game seconds before
## the YOU WIN card — long enough to watch him fall over.
const FINALE_SLOW_MO := 1.1
const FINALE_HOLD := 1.6

var max_health: int = BossRules.MAX_HEALTH
var phase: int = 0
## Invulnerable, not attacking: the beat between phases.
var staggered: bool = false
var fighting: bool = false


func _ready() -> void:
	super._ready()
	health = max_health
	coins = 2999
	persist = true
	enemy_state_machine.add_state("BossAttackPlayerState", BossAttackPlayerState.new(self))
	enemy_state_machine.add_state("BossDashState", BossDashState.new(self))
	enemy_state_machine.add_state("DeadEnemyState", DeadEnemyState.new(self))
	set_physics_process(false)
	animated_sprite_2d.play("idle")


## Called by the room once the intro is over: from here he attacks.
func begin_fight() -> void:
	fighting = true
	set_physics_process(true)
	enemy_state_machine.change_state("BossAttackPlayerState")


func params() -> Dictionary:
	return BossRules.params(phase)


## The boss is a solo set-piece, not a member of the crowd the attack-slot pool
## paces — competing would mean holding a ranged slot until death and leaving the
## reinforcement maids to share the other one.
func competes_for_attack_slots() -> bool:
	return false


func receive_hit(damage: int, _knockback_strength: float = 200.0) -> void:
	# `fighting` also drops on the killing blow, so this guards the finale too.
	if not fighting or staggered or is_dead:
		return
	# He's planted: a small shove, not the maids' full knockback.
	super.receive_hit(damage, 60.0)
	health_changed.emit(maxi(health, 0), max_health)
	if health <= 0:
		_start_finale()
		return
	BossJuice.slow_mo(self, 0.08, 0.05)
	var p := BossRules.phase_for(health, max_health)
	if p > phase:
		_enter_phase(p)


func _enter_phase(p: int) -> void:
	phase = p
	staggered = true
	phase_changed.emit(p)
	create_tween().tween_property(self, "modulate", PHASE_TINTS[clampi(p, 0, PHASE_TINTS.size() - 1)], 0.4)
	Utils.shake_node2d(self, 5.0, 0.5)
	await get_tree().create_timer(BossRules.STAGGER_TIME).timeout
	staggered = false


func _start_finale() -> void:
	fighting = false
	defeated.emit()
	await BossJuice.slow_mo(self, 0.2, FINALE_SLOW_MO)
	await get_tree().create_timer(FINALE_HOLD).timeout
	Globals.boss_death.emit()


## The corpse stays on the floor under the YOU WIN card instead of blinking away.
func _play_death_blink() -> void:
	pass


func _on_death_blink_finished() -> void:
	pass
