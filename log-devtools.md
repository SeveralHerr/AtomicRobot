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

## 2026-07-25 — Animate the HUD orb losing a hit point

- Gap: **`get-state` has no `--property` filter**, despite the CLAUDE.md cheat-sheet listing `get-state --node PATH --property N`. `devtools.py: error: unrecognized arguments: --property scale` — so every read dumped ~200 properties and had to be grepped.
  - Improvement: add `--property` (repeatable) to `get-state`; until then, fix the cheat-sheet line so it doesn't advertise a flag that doesn't exist.
- Gap: **no way to observe an animation at a chosen moment.** The only lever is `set-game-speed 0.05` plus real-time sleeps, so whether a read lands in the flash, the recoil, or after the tween finished is luck — two reads of the same effect came back "tinted" and "already settled".
  - Improvement: a `step-time --seconds N` verb that pauses the tree and advances it by exactly N game-seconds, so a tween can be sampled deterministically (t=0.05s, t=0.3s, …).
- Gap: **the previously-logged "test player dies mid-run" gap bit again, twice** — ambient waves killed the idle player between setup and assertion (`health 12 → 9` with no call of mine), forcing two relaunches. `kill_enemies` only clears the current wave; the spawner refills it.
  - Improvement: the already-proposed god-mode/health-pin verb, plus a `pause-spawner` toggle so a HUD test isn't racing the enemy AI.
- Gap: **`get-state` on a `Control` omits `scale`/`rotation`** (Godot 4.7 reports `offset_transform_scale` instead, which stayed 1.0 while the node was visibly scaling), so the scale half of the effect could only be confirmed from a screenshot.
  - Improvement: have `get_state` include a node's real transform (`scale`, `rotation`, `pivot_offset`) for `Control`s rather than only the serialized property list.

## 2026-07-25 — Commit the HUD damage animation and the leftover working-tree changes

- Gap: **nothing compares two versions of a scene.** A 246-line editor re-save of `main.tscn` looked like it had dropped `groups=["player"]`, building positions, and script overrides; proving it hadn't meant writing HEAD's copy to a temp `.tscn`, running `tools/dump_level.gd` twice, and diffing the JSON by hand.
  - Improvement: a `tools/diff_scene.gd` (or a `--baseline <git-ref>` flag on `dump_level.gd`) that instantiates a scene at two revisions and reports only the semantic differences — and have `/verify` run it automatically when the diff touches a `.tscn`.

## 2026-07-25 — Diagnose the one-attacker wave bug, fan out approach A

- Gap: **nothing verifies that a registered system is actually reachable from gameplay.** `Globals.request_attack_slot` and friends had six passing unit tests and not one caller; lint checks UIDs and scenes, `run_tests.gd` happily green-lights orphaned code. The bug survived because both gates said "clean".
  - Improvement: a lint rule (or a `tools/find_orphans.gd`) that flags script functions and autoload APIs referenced only from `test/`, and have `/verify` surface them as warnings.
- Gap: **no way to assert "how many enemies are attacking right now".** The whole bug is a crowd-behaviour property, and the devtools vocabulary is per-node (`get-state`, `node-bounds`) — confirming it means reading each maid's state one call at a time and inferring.
  - Improvement: a project verb in `devtools_ext/commands.gd` like `cmd enemy_summary` returning one row per enemy (lane, current state, holds-a-slot, distance to player), so a wave can be asserted in a single call. That is the natural runtime check for this change.
- Gap: **no deterministic way to stage a wave.** Verifying multi-attacker combat needs N maids placed at known lanes and offsets around the player; today that means letting the ambient spawner do it and hoping, which is the same nondeterminism that has killed idle test players in earlier runs.
  - Improvement: a `cmd spawn_wave --args '{"count":4,"lanes":[0,1,2,3],"around":"player"}'` setup verb, paired with the already-proposed `pause-spawner` toggle so the staged wave isn't polluted by ambient spawns.

## 2026-07-25 — Exempt the boss from the attack-slot pool

- Gap: **no runtime read of who holds an attack slot.** The boss-holds-a-slot-forever bug was found by reading code, not by observing the game; there is no verb that would have shown `_melee_attackers` / `_ranged_attackers` occupancy during a fight.
  - Improvement: a `cmd attack_slots` verb dumping both pools (holder name, category, how long held). Paired with the `enemy_summary` verb proposed above, that makes crowd pacing directly assertable.
- Gap: **`/verify` cannot exercise the boss room.** Its `entry_hook` advances into `main_scene` only, so a change touching `city_council_boss.gd` has no runtime path at all — the boss fight has to be reached by hand.
  - Improvement: let `devtools_config.json` declare additional named entry points (e.g. `scenes: {boss: {path, hook}}`) and have `/verify` pick the one matching the diff, so touching a boss script actually launches the boss room.

## 2026-07-25 — Verify approach A at runtime

- Gap: **a dead test player silently zeroes every reading.** Three separate runs returned `melee=0 ranged=0 swinging=0` across 20-40 identical samples; the cause was `is_dead=true`, not a broken fix. `set_player_health` restores the number but NOT the `is_dead` flag or the DeadState, so the player is unrevivable once killed.
  - Improvement: a `revive_player` verb (clear `is_dead`, force the state machine out of `DeadState`) and a `god_mode` toggle; and have every `cmd` response carry a `player_alive` field so a frozen run is self-diagnosing instead of looking like a passing test.
- Gap: **the devtools bridge is not concurrency-safe.** Pinning health from a background thread while sampling on the main thread corrupted responses (`KeyError: 'enemies'` — a reply arrived for the wrong request). Nothing in the docs warns about this.
  - Improvement: sequence-number or lock the file bridge so interleaved requests can't cross; failing that, document "one in-flight command at a time" in the cheat-sheet.
- Gap: **no runtime read of attack-slot occupancy, and no crowd-level aggregation.** The whole change is a crowd property, so every measurement went through `get-state //root/Globals` plus a hand-written Python parser over `list_enemies`. `list_enemies` also omits the state-machine state, so "who is attacking" had to be inferred from the animation name.
  - Improvement: add `current_state` to `list_enemies`, and a `cmd attack_slots` verb dumping both pools. Both are small additions to `devtools_ext/commands.gd` and would have replaced four throwaway sampler scripts.
- Gap: **the boss fight is unreachable from devtools**, so the boss-exemption fix could not be verified at runtime. `start_game --scene res://scenes/boss_room.tscn` loads the room with `CityCouncilBoss.visible=false`; walking the player onto `Triggers/EntranceTrigger` does not start the fight, and `list_encounters` returns 0.
  - Improvement: a `start_boss_fight` verb that runs whatever the intro sequence does, so boss-side changes have any runtime path at all.
- Gap: **`orphan_max: 0` is unreachable and therefore ignored.** A fresh launch into `main.tscn` reports 53 orphan nodes before any test action; after scene swaps it reached 178. A threshold nothing can ever satisfy trains you to skip the check.
  - Improvement: retune `orphan_max` to a real baseline (or make `performance` report orphan *growth* across a run rather than an absolute), so the number means something.
- Gap: **Git Bash mangles `/root/...` node paths into Windows paths** (`Node not found: C:/Program Files/Git/root/Globals`). Workaround found: a leading double slash (`//root/Globals`) survives. Cheat-sheet does not mention it.
  - Improvement: have `devtools.py` normalise a leading `C:/.../Git/root/` back to `/root/`, and document the `//root` form.

## 2026-07-25 — Add revive/god_mode/attack_slots devtools verbs

- Closed (project, `devtools_ext/commands.gd`): `revive_player` (clears `is_dead`, leaves `DeadState`, hides the game-over panel), `god_mode` (exposes the flag `Player.take_damage` already honours), `attack_slots` (both pools + caps + holder paths), and `state` on every `list_enemies` row.
- Closed (harness core, generic): `register_status_provider()` — one project-supplied callable whose Dictionary rides on EVERY response as `status`. A dead player now announces itself on every reply instead of silently returning well-formed zeros.
- Closed (harness, `devtools.py`): `normalize_node_path()` undoes Git Bash rewriting `/root/Globals` into `C:/Program Files/Git/root/Globals`, and accepts the `//root/...` workaround form.
- Proof the `state` field was needed: the first call returned an enemy with `"animation": "idle"` whose real state was `attack_player_melee_state.gd`. Inferring attacks from animation names was wrong, not merely awkward.
- Still open: the bridge is not concurrency-safe (one in-flight command at a time — a background health-pinning thread corrupted replies); `orphan_max: 0` is unreachable (53 orphans on a fresh launch); and there is no path into the boss fight.
- New, found while testing: `Globals.reset_attack_slots()` on `player_death` clears both pools without telling the holders, so an enemy mid-swing keeps `AttackPlayerState._slot_held = true` while the pool forgets it. Measured as 2 enemies in `attack_player_melee_state` with `attack_slots` reporting `0/2`. A clean run with no death tracks 1:1 (`melee 2/2`, `in_attack_state=2`, 12/12 samples), so the desync is death-triggered and self-heals within one swing.

## 2026-07-25 — Fix the slot desync and upstream the input patch

- The verbs added last turn paid for themselves immediately: confirming the desync fix took one `attack_slots` call per sample, and the `status` field showed `player=dead` inline, so the death case could be verified deliberately instead of being mistaken for a frozen run.
- Closed (harness 0.3.1): the input-injection patch that had been living only in this project is upstreamed, so `/scaffold-godot-harness` can no longer silently overwrite it. `templates/addons/godot_selftest/dev_tools.gd` and the installed copy are now byte-identical.
- Gap: **nothing keeps the installed harness and the upstream template in sync.** This divergence survived unnoticed until a diff happened to be run for another reason, and the only thing at risk was a fix the project depended on.
  - Improvement: have `/verify` (or the scaffolder) diff the installed `addons/godot_selftest/` and `tools/` against the plugin's templates and report drift, naming which side is ahead.
- Still open from previous runs: bridge concurrency, unreachable `orphan_max: 0`, and no path into the boss fight.

## 2026-07-31 — Mobile controls relayout

- No way to simulate touch: `devtools.py input` only presses input *actions*, so the
  multi-touch path (`InputEventScreenTouch` with two indexes) can't be exercised on the
  running game at all. Suggestion: add `touch <press|release|drag> --index N --pos X,Y`.
- No way to fake a touchscreen: touch UI hides itself when
  `DisplayServer.is_touchscreen_available()` is false, so every screenshot needed five
  manual `set-state --property visible` calls. Suggestion: a `--force-touch-ui` /
  `set-feature touchscreen true` verb, or a config flag the harness applies at boot.
- Headless unit tests get no frames, so Control anchors never resolve (`size` stays 0)
  and `@onready` vars never initialize — the test has to call
  `propagate_notification(NOTIFICATION_READY)` and recompute rects by hand. Suggestion:
  a runner helper like `_T.instantiate_ui(scene, viewport_size)` that does both.
- `node-bounds` reports rects fine but there's no "assert this control is inside the
  viewport / doesn't overlap that one" verb; the CRT overlay also eats ~50px of the
  edges, which no validator knows about. Suggestion: `validate-ui` should flag controls
  outside a configurable safe-area inset.

## 2026-07-31 — Lane baseline vs multiple ground layers

- No way to hold state while probing: `set-state --property current_lane --value 0`
  is overwritten by the player's own `_physics_process` on the next frame, and
  `teleport_player` drops you wherever gravity takes you. Every probe reported a lane
  I hadn't asked for. Suggestion: `pin-state --node P --property N --value V` that
  re-applies each frame until cleared, and `teleport_player --settle N` that steps N
  frames and reports where the body actually came to rest.
- `lane_report` shows each body's `lane_floor_y` but nothing says what the *authored*
  walkway line is, so a rebased baseline looks identical to a correct one. Suggestion:
  report an `expected_floor_y` (from config or the level dump) alongside, and flag
  bodies whose baseline differs — `foot_spread_by_lane` already spotted 175.5px of
  spread on lane 0 and called it 0 violations.
- Physics repros have no home: `run_tests.gd` can't step frames, so I had to copy an
  `extends SceneTree` script into `tools/`, run it, and delete it. Suggestion: a
  `test/integration/` dir the runner executes in a separate frame-stepping pass.
- Running the editor/game rewrote `scripts/enemy.gd` (stripped a trailing newline) and
  emitted an untracked `test/unit/test_mobile_controls.gd.uid`, so `git status` was
  dirty for reasons unrelated to my work. Suggestion: `/verify` should call out
  Godot-authored churn separately from the user's diff.

## 2026-07-31 — Lane baseline fix

- `lane_report` reported `violations: []` while lane 0 showed `foot_spread_by_lane`
  of 175.5px and three bodies held baselines of -63/-193/-239 against the player's -1.
  It only checks road lanes for mismatch. Suggestion: also flag any non-`lane_locked`
  body whose baseline differs from the scene baseline, now that
  `Lanes.baseline_on_root()` makes "the scene baseline" a real, queryable number.
- No verb exposes the new registry. Suggestion: `lane_baseline` (read the scene's
  resolved value + where it came from: authored marker vs seeded by whom), which would
  have replaced the whole headless repro script I wrote.
- `get-state --property lane_locked` returned unparseable output for three nodes and I
  had to identify them via `list_enemies` `script` fields instead. Suggestion: make
  `get-state` always emit valid JSON, with an explicit error object for a missing
  property.
- Unit tests can't step physics AND can't use the tree at all (`is_inside_tree()` is
  false inside `_initialize`). Suggestion: document that in the harness README, and add
  a frame-stepping integration pass so a repro like this one lives in the repo instead
  of a scratchpad file that gets copied into `tools/` and deleted.
