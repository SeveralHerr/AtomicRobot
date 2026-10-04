extends RefCounted
class_name EnemyTuning

## The crowd-pressure knobs in one place, for balance passes. If fights get too
## easy: raise the *_MOVE_SPEED values, raise WINDUP_SPEED (shorter wind-up), or
## lower the cooldowns. Related knobs that live with their owners:
##   * Globals.MAX_MELEE_ATTACKERS / MAX_RANGED_ATTACKERS — how many swing at once
##   * BuildingDoorEncounter.enemy_count (per door in main.tscn) — squad size
##   * EnemySpawner.spawn_wave(count) — ambient wave size

## pf-balance (2026-10-04): the player's swings got ~1.6x faster (AttackChain), and
## the seeded route sweep went from 20/24 wins, 13.4 hits a run to 24/24 and 6.7.
## Raised per the player's own advice (faster enemies, slightly shorter wind-up, plus
## one more maid at each mid-street door) back to ~12.5 hits, ~5.5 of them on the
## street. Old values: speeds 100/150, cooldowns 4.0/1.0, WINDUP_SPEED 1.0.

## Walk speed (px/s) while chasing.
const RANGED_MOVE_SPEED := 150.0
const MELEE_MOVE_SPEED := 220.0
const PLATFORM_MOVE_SPEED := 70.0

## Seconds between swings, counted from each release.
const RANGED_ATTACK_COOLDOWN := 2.5
const MELEE_ATTACK_COOLDOWN := 0.6
const WINDOW_ATTACK_COOLDOWN := 2.0
const PLATFORM_ATTACK_COOLDOWN := 1.0

## Playback-speed multiplier on every maid's attack clip. 1.0 = authored timing
## (coin throw ~1.9s from wind-up to release — its
## frames carry long durations — and the melee swing ~0.5s); 1.4 = ~1.35 s throw,
## ~0.36 s swing. The gold EnemyTelegraph flash scales with it, so it still reads.
const WINDUP_SPEED := 1.4
