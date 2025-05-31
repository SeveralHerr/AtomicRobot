extends State
class_name KnockbackState

var knockback_timer: float = 0.0
var knockback_duration: float = 0.3
var knockback_velocity: Vector2
var initial_knockback_strength: float

func enter(host: Player) -> void:
	#host.default_sprite.play("hurt")  # Assuming you have a hurt animation
	knockback_timer = knockback_duration
	
	# Store the initial knockback velocity
	knockback_velocity = host.velocity
	initial_knockback_strength = abs(knockback_velocity.x)

func exit(host: Player) -> void:
	# Reset any visual effects
	pass

func handle_input(host: Player, event: InputEvent) -> void:
	# Disable input during knockback
	pass

func update(host: Player, delta: float) -> void:
	knockback_timer -= delta
	
	# Gradually reduce the knockback velocity
	var decay_factor = knockback_timer / knockback_duration
	decay_factor = ease_out_quad(decay_factor)  # Smooth easing
	
	host.velocity.x = lerp(0.0, knockback_velocity.x, decay_factor)
	
	# Check if knockback is finished
	if knockback_timer <= 0:
		host.state_machine.change_state("IdleState")

func physics_update(host: Player, delta: float) -> void:
	# The main physics will be handled in update()
	pass

# Easing function for smooth deceleration
func ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t) 
