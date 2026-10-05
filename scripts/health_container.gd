extends HBoxContainer

@onready var player: Player = $"../../../../Player"

# Dynamic heart management
const HEART_SCENE = preload("res://scenes/hp_1.tscn")
## Damage stages for a single orb, indexed by (hits left - 1): the atom sheds an
## orbit per hit. Player.HITS_PER_ORB must stay equal to this array's size.
const ORB_TEXTURES: Array[Texture2D] = [
	preload("res://images/Logo+Web-3_256.png"),  # 1 hit left
	preload("res://images/Logo+Web-2_256.png"),  # 2 hits left
	preload("res://images/Logo+Web_256.png"),  # 3 hits left (untouched)
]
## Rest pose of an orb. Effects always tween back to these rather than to whatever the
## node happened to read as mid-animation, so a hit landing during another hit (or a
## pickup) can't leave an orb stuck scaled or tinted.
const ORB_BASE_SCALE := Vector2.ONE
const ORB_BASE_MODULATE := Color.WHITE
## Red punch an orb flashes on the frame it loses a hit.
const ORB_DAMAGE_TINT := Color(1.0, 0.35, 0.3, 1.0)
var heart_instances: Array[Node] = []
var max_hearts: int = 0
var previous_health: int = 0
var is_initialized: bool = false
## Running effect per orb node, so a new one can cancel the old. Keyed by orb node.
var _orb_tweens: Dictionary = {}

func _ready() -> void:
	player.player_health_updated.connect(_update_health)
	# Initialize with player's starting health (no animation)
	_update_health(player.health)
	is_initialized = true  # Mark as initialized after first update

## `current_health` is raw hit points. Each orb soaks Player.HITS_PER_ORB of them, so
## a hit usually re-textures the rightmost orb rather than removing one.
func _update_health(current_health: int) -> void:
	var orbs := Player.orbs_for(current_health)
	print("Health updated to: ", current_health, " (", orbs, " orbs)")

	# Check if health increased (heart pickup) and we're past initialization
	var health_gained = current_health > previous_health and is_initialized
	# Same idea for damage: the orb that changed stage (or ran out) animates the swap.
	var health_lost = current_health < previous_health and is_initialized
	var previous_orbs := Player.orbs_for(previous_health)

	# Determine the maximum orbs we need (current orbs or existing max, whichever is higher)
	var needed_hearts = max(orbs, max_hearts)

	# Create additional heart instances if needed
	while heart_instances.size() < needed_hearts:
		_create_heart_instance()

	# Re-texture and show every orb that still has hits left; hide the spent ones
	for i in range(heart_instances.size()):
		var orb := heart_instances[i] as TextureRect
		var hits_left := Player.orb_hits_left(i, current_health)
		if hits_left <= 0:
			# A spent orb pops instead of blinking out; it hides when the tween ends.
			if health_lost and orb.visible:
				_play_orb_destroy_effect(orb)
			else:
				_cancel_orb_effect(orb)
				orb.hide()
			continue
		var was_visible := orb.visible
		var new_texture := ORB_TEXTURES[hits_left - 1]
		var damaged := health_lost and was_visible and orb.texture != new_texture
		if not was_visible:
			# Cancels a destroy pop still in flight, so a regained orb starts from rest.
			_cancel_orb_effect(orb)
		orb.texture = new_texture
		orb.show()
		if damaged:
			_play_orb_damage_effect(orb)
		# Apply pickup effect to newly gained orbs
		elif health_gained and i >= previous_orbs:
			_play_heart_pickup_effect(orb)

	# Update previous health for next comparison
	previous_health = current_health

func _create_heart_instance() -> void:
	var heart_instance = HEART_SCENE.instantiate()
	add_child(heart_instance)
	heart_instances.append(heart_instance)
	max_hearts = heart_instances.size()
	print("Created heart instance. Total hearts: ", max_hearts)

func _play_heart_pickup_effect(heart_node: Node) -> void:
	# Create a pickup effect tween
	var tween = _start_orb_tween(heart_node)
	tween.set_parallel(true)  # Allow multiple tween properties

	# Scale pulse effect
	tween.tween_property(heart_node, "scale", ORB_BASE_SCALE * 1.5, 0.2)
	tween.tween_property(heart_node, "scale", ORB_BASE_SCALE, 0.3).set_delay(0.2)

	# Color flash effect (bright white then back to normal)
	tween.tween_property(heart_node, "modulate", Color.WHITE, 0.1)
	tween.tween_property(heart_node, "modulate", ORB_BASE_MODULATE, 0.4).set_delay(0.1)

	# # Optional: Slight rotation wobble
	# tween.tween_property(heart_node, "rotation_degrees", 10.0, 0.1)
	# tween.tween_property(heart_node, "rotation_degrees", -10.0, 0.2).set_delay(0.1)
	# tween.tween_property(heart_node, "rotation_degrees", 0.0, 0.2).set_delay(0.3)


## Counterpart to the pickup pulse, for an orb that lost a hit but survived. The new
## damage-stage texture is already applied when this runs, so the punch-and-shake reads
## as the hit knocking an orbit off the atom.
func _play_orb_damage_effect(orb: Node) -> void:
	var tween = _start_orb_tween(orb)

	# Snap out and flash red on impact
	tween.tween_property(orb, "scale", ORB_BASE_SCALE * 1.35, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(orb, "modulate", ORB_DAMAGE_TINT, 0.06)

	# Recoil past rest, then wobble back down to it
	tween.tween_property(orb, "scale", ORB_BASE_SCALE * 0.85, 0.08)
	tween.parallel().tween_property(orb, "rotation_degrees", -12.0, 0.08)
	tween.tween_property(orb, "rotation_degrees", 8.0, 0.07)
	tween.tween_property(orb, "rotation_degrees", 0.0, 0.09)
	tween.parallel().tween_property(orb, "scale", ORB_BASE_SCALE, 0.09)
	tween.parallel().tween_property(orb, "modulate", ORB_BASE_MODULATE, 0.14)


## The last hit on an orb: it flares, then collapses and spins out before hiding. The
## node stays visible for the ~0.25s of the pop, so read the health int (not the HUD)
## when you need the settled state immediately.
func _play_orb_destroy_effect(orb: Node) -> void:
	var tween = _start_orb_tween(orb)

	tween.tween_property(orb, "scale", ORB_BASE_SCALE * 1.4, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(orb, "modulate", ORB_DAMAGE_TINT, 0.07)

	tween.tween_property(orb, "scale", ORB_BASE_SCALE * 0.1, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(orb, "rotation_degrees", 25.0, 0.18)
	tween.parallel().tween_property(orb, "modulate", Color(ORB_DAMAGE_TINT, 0.0), 0.18)

	tween.tween_callback(func() -> void:
		orb.hide()
		_reset_orb(orb))


## Fresh tween for `orb`, cancelling whatever effect it was running. Without this a
## second hit (or a pickup mid-pop) would fight the previous tween over the same
## properties and leave the orb tinted or shrunk.
func _start_orb_tween(orb: Node) -> Tween:
	_cancel_orb_effect(orb)
	var tween := create_tween()
	_orb_tweens[orb] = tween
	return tween


## Stop whatever effect `orb` is playing and snap it back to rest. Not safe to call
## from inside that orb's own tween callback — use `_reset_orb` there.
func _cancel_orb_effect(orb: Node) -> void:
	var running: Tween = _orb_tweens.get(orb)
	if running != null and running.is_valid():
		running.kill()
	_reset_orb(orb)


## Put the orb back in its rest pose and forget its effect. Safe to call from inside a
## tween callback — it never kills the tween that is running it.
func _reset_orb(orb: Node) -> void:
	_orb_tweens.erase(orb)
	orb.scale = ORB_BASE_SCALE
	orb.rotation_degrees = 0.0
	orb.modulate = ORB_BASE_MODULATE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
