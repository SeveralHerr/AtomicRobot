extends RefCounted
class_name DamageRules

## The enemy side of the damage scale, in one table. Pure and static — pinned by
## test_damage_scale.gd against every fighter in Globals.character_dict.
##
## Scale: enemies have 12 HP and fighters hit for 3-6, so a street maid takes 3-4
## blows (Robot, the unlockable, 2). The old scale (2 HP, fighters 1-4) only had
## "one hit" and "two hits", so the 2-damage fighters one-shot everything. Player
## health is a separate unit (raw hits, Player.HITS_PER_ORB) and is not on this scale.
## Boss HP lives in BossRules.MAX_HEALTH on the same scale.

## Street maids: ranged, melee and platform.
const MAID_HEALTH := 12
## Window maids sit out of reach and pelt the street, so they take one blow more
## (the old 3 HP vs 2, rounded to the nearest blow on this scale).
const WINDOW_MAID_HEALTH := 15
## A car clipping an enemy takes half her health, as it always did (1 of 2).
const CAR_ENEMY_DAMAGE := MAID_HEALTH / 2

## A coin the player knocks back into a maid: one ordinary fighter's blow (the
## roster's 3-4), so a reflect is worth a swing, not a kill. For coin_bullet.gd.
const REFLECTED_COIN_DAMAGE := 4


## Blows of `damage` needed to drop `health` HP.
static func hits_to_kill(health: int, damage: int) -> int:
	return ceili(float(health) / float(maxi(damage, 1)))
