extends RefCounted
class_name EnemyTuning

## The crowd-pressure knobs in one place, for balance passes. If fights get too
## easy: raise the *_MOVE_SPEED values, raise WINDUP_SPEED (shorter wind-up), or
## lower the cooldowns. Related knobs that live with their owners:
##   * Globals.MAX_MELEE_ATTACKERS / MAX_RANGED_ATTACKERS — how many swing at once
##   * BuildingDoorEncounter.enemy_count (per door in main.tscn) — squad size
##   * EnemySpawner.spawn_wave(count) — ambient wave size

## Walk speed (px/s) while chasing.
const RANGED_MOVE_SPEED := 100.0
const MELEE_MOVE_SPEED := 150.0
const PLATFORM_MOVE_SPEED := 70.0

## Seconds between swings, counted from each release.
const RANGED_ATTACK_COOLDOWN := 4.0
const MELEE_ATTACK_COOLDOWN := 1.0
const WINDOW_ATTACK_COOLDOWN := 2.0
const PLATFORM_ATTACK_COOLDOWN := 1.0

## Playback-speed multiplier on every maid's attack clip. 1.0 = authored timing
## (coin throw ~1.9s from wind-up to release — its
## frames carry long durations — and the melee swing ~0.5s); 1.25 = 20% shorter.
const WINDUP_SPEED := 1.0
