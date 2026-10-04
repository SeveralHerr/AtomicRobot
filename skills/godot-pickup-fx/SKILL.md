---
name: godot-pickup-fx
description: Keep every collectible (hearts, dropped/placed power-ups, any new pickup) looking and popping the same — PowerupGlow halo+sparkles and PowerupGlow.collect_burst. Use when adding a pickup kind, spawning hearts at runtime, or when a player says "this one has no sparkles".
---

# Pickup FX consistency

- Look: every pickup owns ONE `PowerupGlow` child (`scripts/powerup_glow.gd`).
  - Scene-authored pickups (heart): put `Glow` in the pickup's own `.tscn`, never on one
    level instance — the roof heart once had the only heart glow; 4 other hearts + door/boss
    hearts were plain.
  - Script pickups: `add_child(PowerupGlow.new(color))` in `_ready`, unconditionally.
- Pop: collect via `await PowerupGlow.collect_burst(self, sprite).finished` then `queue_free()`.
- Blink/hide logic must toggle the glow too, or a "gone" pickup still sparkles.
- Gate: `test/unit/test_pickup_fx.gd` derives hearts from the levels (no hand list);
  add a new pickup scene to it.
- Look check: throwaway SceneTree script laying out one of each kind under a zoom-3 camera,
  windowed `--resolution 1200x400`, save `root.get_texture().get_image()`.
