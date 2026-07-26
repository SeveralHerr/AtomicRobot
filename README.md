# Bug list

# TODO: https://code.jason-storey.com/snippets?slug=statestack






# Cass, belt weapon 




# catch phrase
# is that my coke? 
# Hiyaa

# Test harness gaps (/verify + tools/devtools.py)

Hit while verifying the enemy-death timing fix (2026-07-25). Each one cost a re-run.

- **The test player dies mid-run and takes the game with it.** An idle player is
  killed by ambient waves in ~30s; the death flow exits the process, so the DevTools
  bridge vanishes and the next command hangs for its full timeout. Workaround today is
  `cmd set_player_health --args '{"health":99}'` right after the entry hook.
  *Fix:* a `god_mode` verb that pins health, called by `/verify` Phase 2 automatically.
- **`kill_enemies` can't test death logic.** It calls `queue_free()` directly and never
  runs `Enemy.die()`, so the one verb for clearing enemies can't exercise drops, score,
  `is_dead` or event completion. *Fix:* accept `{"method": "die"}` to route through the
  real death path.
- **No liveness check on the bridge.** Every `devtools.py` call blocks on a response
  file, so a dead game is indistinguishable from a slow command until the timeout fires.
  *Fix:* a ~2s precheck that fails with `game not running`.
