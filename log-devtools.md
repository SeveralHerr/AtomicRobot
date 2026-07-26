# Devtools/Verify Gaps Log

Log of gaps in the global /verify or devtools workflow, and suggested improvements.

## 2026-07-26 — Add logging sections to CLAUDE.md

- Gap: This change was a docs-only edit (CLAUDE.md), so `/verify` doesn't apply (it's scoped to gameplay/script/scene changes) — nothing caught that these new "log at the end of every response" instructions are prompt-level conventions with no enforcement.
- Improvement: A lightweight `Stop` hook (or a `/verify`-adjacent check) that fails/warns when a response touched code but `log.md`/`log-devtools.md` weren't updated in the same turn would make this logging convention self-enforcing instead of relying on the model remembering every time.

## 2026-07-26 — Add "enhance used skills" rule + merge to main

- Gap: none — no code/gameplay change this turn, just a CLAUDE.md wording tweak and a branch merge, so `/verify` and devtools don't apply.

## 2026-07-26 — Implement the logging Stop hook

- Gap: closed. Implemented the `Stop` hook suggested above: `tools/check_logging.sh` diffs this branch against `main` and, if code/gameplay files changed without `log.md`/`log-devtools.md` also changing, prints a `systemMessage` reminder (non-blocking — it warns, it doesn't fail the turn).
- Remaining gap: the check is scoped to code/gameplay file patterns (`.gd/.tscn/.tres/.import`, `scenes/scripts/sprites/Tiles/Sounds/addons`), so a non-code response still relies on the model remembering to log; and it's advisory only, so a model that ignores the warning isn't blocked. Could be tightened later to `decision: "block"` if warnings prove easy to ignore.

## 2026-07-26 — Retire enemies on death, not when the corpse frees

All three of these fired during one `/verify` run and together stopped the runtime tests
from finishing — only "`is_dead` flips on `die()`" was actually asserted at runtime.

- Gap: **the test player dies mid-run and takes the process with it.** An idle player is killed by ambient waves in ~30s (`hit player` → health 0), and the death flow exits the game, so the DevTools bridge vanishes and the next queued command hangs for its full 60s timeout. Workaround used: `cmd set_player_health --args '{"health":99}'` right after the entry hook.
  - Improvement: add a `god_mode` verb (or `set_player_health --lock`) that pins health, and have `/verify` Phase 2 call it automatically after the entry hook.
- Gap: **`kill_enemies` can't test death logic.** It calls `queue_free()` directly and never runs `Enemy.die()`, so the one verb for clearing enemies cannot exercise drops, score, `is_dead`, or event completion — exactly the pipeline this change touched.
  - Improvement: accept `{"method": "die"}` so it can route through the real death path. Cheapest of the three and the one that would have unblocked the unrun tests.
- Gap: **no liveness check on the bridge.** Every `devtools.py` call blocks on a response file, so a dead game is indistinguishable from a slow command until the timeout fires.
  - Improvement: a ~2s precheck that fails with `game not running`.

(These were first written into `README.md`; that section was removed so this file stays
the single source of truth.)

## 2026-07-26 — Log the harness gaps to README + memory

- Gap: none new — no gameplay/script/scene change this turn (README + memory only), so `/verify` and devtools don't apply. The three gaps above stay open.

## 2026-07-26 — Move the logs into log.md / log-devtools.md

- Gap: none new — docs-only turn.
- Process gap worth noting: `CLAUDE.md` was rewritten mid-session (PRs #4, #5), so the copy in context still had the old `## Other` rule and the first two turns wrote the gaps into the response body and `README.md` instead of these files. The `Stop` hook's reminder is the right mechanism, but it only fires on code changes — it didn't fire on those doc-only turns.
