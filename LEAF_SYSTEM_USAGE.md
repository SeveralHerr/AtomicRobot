# Leaf System Usage Guide

## Setup Instructions

1. **Add LeafSystem Autoload:**
   - Go to Project Settings → Autoload
   - Add `autoload/leaf_system.gd` with the name "LeafSystem"

2. **Replace Existing Leaves:**
   - Remove all existing leaf scenes from your level
   - The LeafManager will automatically spawn leaves around the player

3. **Configure LeafManager:**
   - Add the LeafManager scene to your main level scene
   - Adjust parameters in the inspector:
	 - `spawn_distance`: How far from player to spawn leaves (default: 600px)
	 - `despawn_distance`: When to remove leaves (default: 800px) 
	 - `leaf_density`: Leaves per pixel (default: 0.3)
	 - `leaf_pool_size`: Max total leaves (default: 100)
	 - `max_active_leaves`: Max active at once (default: 80)

## Integration with Player Attacks

### Option 1: Using Player Signal
If your Player class has an attack signal:

```gdscript
# In Player.gd
signal attacked(position: Vector2, range: float)

func attack():
	# Your attack code here
	attacked.emit(global_position, 100.0)  # Emit with attack range
```

### Option 2: Direct Call from Player
```gdscript
# In Player.gd attack function
func attack():
	# Your attack code here
	LeafSystem.trigger_sword_swing(global_position, 100.0)
```

### Option 3: Using Area2D Detection
```gdscript
# In your attack/sword Area2D script
func _on_area_entered(area):
	if area.has_method("do_gust"):  # Leaf detection
		LeafSystem.trigger_sword_swing(global_position, 100.0)
```

## Integration with Cars

```gdscript
# In car.gd
func _physics_process(delta):
	# Your car movement code
	
	# Trigger leaf gusts when moving
	if velocity.length() > 50:  # Only when moving fast enough
		LeafSystem.trigger_car_gust(global_position, velocity, 150.0)
```

## Other Effects

### Wind/Area Effects
```gdscript
# For explosions, wind zones, etc.
LeafSystem.trigger_area_gust(explosion_center, 200.0, 5.0)
```

### Custom Interactions
```gdscript
# Access the leaf manager directly for custom effects
var leaf_manager = LeafSystem.leaf_manager
if leaf_manager:
	# Custom leaf interactions
	for leaf in leaf_manager.active_leaves:
		# Do something with each leaf
```

## Performance Notes

- **Memory Usage:** ~100 leaf objects maximum vs hundreds/thousands before
- **Physics Processing:** Only active leaves (≤80) process physics vs all leaves before
- **Rendering:** Only visible leaves are rendered
- **Automatic Cleanup:** Leaves are recycled and cleaned up automatically

## Debug Information

```gdscript
# Get performance stats
var debug_info = LeafSystem.get_leaf_debug_info()
print("Active leaves: ", debug_info.active_leaves)
print("Pooled leaves: ", debug_info.pooled_leaves)
```

## Troubleshooting

1. **No leaves appearing:** Check that player is properly detected in LeafManager
2. **Leaves not responding to attacks:** Ensure attack integration is set up
3. **Performance still poor:** Reduce `max_active_leaves` and `leaf_pool_size`
4. **Ground detection issues:** Adjust ground collision layer detection in `get_ground_level()`
