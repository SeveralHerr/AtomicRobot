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

## 2026-07-26 — Juice the score/combo/power-up HUD and outline the HP label + logo

- Gap: **`get-state` silently omits transform properties for container children.** `scale` came back for `ComboLabel` (child of a plain `Control`) but was absent for `ScoreLabel` (child of a `VBoxContainer`) — Godot hides position/rotation/scale/pivot on container children, and the dump enumerates editor-visible properties. A scale animation on a container child is therefore invisible to the tool while working perfectly on screen. I had to assert the script's own `_score_pop_amount` instead.
  - Improvement: have `get-state` always append the raw `Node2D`/`Control` transform (`position`, `scale`, `rotation`, `pivot_offset`) in a `transform` sub-dictionary regardless of property usage flags, so container children can be asserted at all.
- Gap: **`get-state` has no `--property` flag** despite the cheat-sheet advising "prefer one property" for token cost. It dumps ~120 keys for a `Label`; every assertion this run had to be piped through an inline Python filter.
  - Improvement: add `get-state --node PATH --property NAME` (repeatable), which the cheat-sheet already implies exists.
- Gap: **`set_combo` produced an unreachable state** — it set the count but not the combo window, so `combo_fraction()` stayed 0. Harmless while the HUD drew the count unconditionally; it made the verb useless the moment the readout started fading on the timer. Fixed in `devtools_ext/commands.gd` this turn.
  - Improvement, generalised: a debug verb that writes one half of an invariant pair is a latent trap. Worth a note in the harness docs that setter verbs should leave the system in a state the game itself can reach.
- Recurring, still open: `orphan_max: 0` remains unreachable (47 orphans at HEAD, 50 with this change — I had to `git stash` and relaunch to establish that the delta was noise). The stale-player problem also bit again: the idle test player died to an enemy wave mid-session, which set `ScoreSystem.running = false` and froze the stage clock, so a fade test read a *constant* `combo_fraction` of exactly 1.0. The `status` field said `player: alive` because the player had already been revived — liveness of the *player* was not liveness of the *stage*.
  - Improvement: let the status provider carry stage/session liveness (here `ScoreSystem.running` + `stage_seconds`), not just player liveness, so a frozen subsystem announces itself the same way a dead player now does.

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

## 2026-08-01 — Pull main, resolve the log conflicts, commit the HUD work

- Gap: **the lint runner exits 1 on a clean project.** All 74 scenes reported OK and the
  only findings were pre-existing uid warnings, but the process still returned 1 because
  Godot reports leaked RIDs/ObjectDB instances at shutdown. Any CI gate or `/verify`
  step keying off the exit code is reading noise.
  - Improvement: have `lint_project.gd` call `quit(n)` with its own finding count so the
    exit code means "lint failed", not "Godot leaked at exit".
- Gap: **lint does not separate pre-existing findings from ones the current diff caused.**
  Nine `uid mismatch` warnings printed; deciding they were untouched repo debt meant
  hand-checking `git log`/`git diff` per file. This is the same "is this noise mine?"
  problem already logged for `orphan_max`, now on a second tool.
  - Improvement: a `--baseline` flag that records findings at the merge-base and prints
    only the delta — one mechanism would cover lint, orphans and UI warnings at once.
- Gap: **nothing validates a merge result specifically.** The risky failure here was two
  branches independently adding `[ext_resource]` ids to the same `.tscn`; a duplicate id
  loads without complaint and silently binds the wrong resource. I checked by listing
  ids by hand.
  - Improvement: have the scene lint assert `ext_resource`/`sub_resource` ids are unique
    within a file — cheap, and exactly the class of corruption a text-merged scene has.
- Environment note: the Godot binary on this machine writes nothing to a PowerShell
  console (it is the non-console build), so every headless run must redirect to a file
  and be read back. Worth stating in the harness docs; the first lint run looked like a
  silent success.

## 2026-08-01 — Upstream the log itself, then close what it recorded (harness 0.4.0)

This turn was harness work, not gameplay: `godot-selftest-harness` 0.4.0 makes this very
file a scaffolded feature and acts on the backlog above. Recording it here because
closures are entries too — an open gap that quietly got fixed is indistinguishable from
one nobody ever looked at.

**Closed upstream (re-run `/scaffold-godot-harness` to pick these up):**

- `get-state --property NAME` (repeatable) — logged twice, on 2026-07-25 and 2026-07-26.
- `get-state` now always returns a `transform` sub-dictionary read off the node. The
  container-child bug was reproduced on 4.7.1 before fixing: the same `Label` reports
  `scale` with usage `6` under a plain `Control` and `READ_ONLY|EDITOR` under a
  `VBoxContainer`, so the property dump legitimately omits it while the node scales.
- `step-time --seconds N`, with an honest caveat: it does **not** pause and step the
  tree (GDScript cannot tick the SceneTree). Physics time is exact; process time — what
  a default `Tween` runs on — lands within ~1 frame, and the verb reports the measured
  `process_seconds` so you can see the overshoot instead of assuming precision. Use
  `TWEEN_PROCESS_PHYSICS` when the sample point matters.
- Bridge liveness: a dead game now fails in ~2s with `game not running` instead of
  hanging for the full timeout. No extra ping needed — the autoload deletes the command
  file on pickup, so a file still sitting there *is* the signal.
- `orphan_max: 0` retired as a gate. `performance` reports `orphan_growth` vs a startup
  baseline, with `--reset-baseline` to re-baseline after the entry hook.
- `touch press|release|drag|clear|list` and `set-feature --touchscreen true` — both
  2026-07-31 mobile gaps. The latter verified empirically: `Input.set_emulate_touch_from_mouse()`
  really does flip `DisplayServer.is_touchscreen_available()`, so the touch UI stops
  hiding itself and the five manual `visible` overrides are gone.
- `await _T.instantiate_ui(scene, viewport_size)` / `_T.free_ui(node)` in the test
  runner, so headless Control tests resolve anchors and run `@onready`.
- `validate-ui` honours a configurable `safe_area_inset` — the CRT overlay eating ~50px
  of the edges is now expressible.
- Lint: real exit codes (`0`/`1`/`2` — `2` means the linter itself failed, so a broken
  gate can't read as clean), duplicate `ext_resource`/`sub_resource` id detection,
  `--baseline` splitting `NEW` from `PRE-EXISTING`, and `--find-orphans` for functions
  called only from `test/`. Same exit contract on `run_tests.gd`.
- Harness drift check in `/verify` Phase 0 (installed files vs plugin templates) —
  the 2026-07-25 gap where the local input patch had silently diverged.
- `entry_points` config + diff-aware selection in `/verify`, the mechanism the boss-room
  gap asked for. **Still needs configuring on this project** — see below.
- The non-console-Godot-on-Windows note is now in the harness docs, and both runners tell
  you to redirect to a file.

**Partially closed — do not read as fixed:**

- Bridge concurrency. Requests now carry an id the game echoes verbatim, so a crossed
  reply **errors** (`Crossed replies: ...`) instead of silently returning another
  request's data. That is detection, not concurrency: the bus is still one command file
  and one result file. The rule is unchanged — one in-flight command at a time.

**New gaps, found while building the above:**

- Gap: **each half of the bridge was tested against a fake counterpart and both passed,
  while three real request/response key mismatches sat between them.** `set_feature`
  returned the resulting state under `touchscreen_available` while the client read
  `touchscreen`; `touch_clear` returned `released` while the client read `cleared`;
  `step_time` returned `physics_seconds`/`frames_advanced` while the client read
  `advanced`/`frames`. The `touch_clear` one printed **"No active touches to clear"
  while successfully clearing two** — a tool lying about what it just did, which is the
  exact failure class this log exists for. Only running the real client against the real
  game exposed any of it.
  - Improvement: ship a contract test with the harness — a script that launches a
    scratch project and drives every generic verb over the real bus, asserting the keys
    each side promises. Cheap to run in `/verify` Phase 0 after a drift finding, and it
    would have caught all three before they shipped.
- Gap: **a test script with a parse error still `load()`s**, and `.new()` on it raised a
  runtime error that aborted the *calling* function — so `run_tests.gd` printed
  `Total: 0 | ALL TESTS PASSED` with **exit 0** while a real test file sat undiscovered
  beside it. Fixed upstream with a `can_instantiate()` guard, but it was live this whole
  time, which means any green test run before today is worth one skeptical look at the
  test *count*.
  - Improvement (still open): `/verify` should assert the test count is non-zero and
    ideally non-decreasing, not just that the suite said "passed".
- Gap: **a runtime error inside a test method is indistinguishable from a pass.**
  GDScript has no exception handling; the error aborts only that method and returns the
  declared type's default — `""` for a `-> String` test, i.e. success. A return-type
  heuristic was tried and backed out because the aborted call is genuinely identical to
  a clean one. **Unfixable from inside the runner.**
  - Improvement: `/verify` must capture and read **stderr** on the test step, not just
    the exit code — `[ERR]`/`[SCRIPT ERROR]` lines are the only evidence this happened.
- Gap: **`command -v python3` succeeds on Windows and then refuses to run.** Windows
  ships a Microsoft Store *App execution alias* stub at `python3.exe`; existence is not
  executability. Every `python3 tools/devtools.py` line in the docs assumes otherwise.
  - Improvement: probe interpreters by executing them (`"$c" -c "import sys"`). The
    scaffolder now does this; the docs now say so.

**Still open, unchanged:**

- No semantic scene diff (`tools/diff_scene.gd` / `--baseline <git-ref>` on
  `dump_level.gd`). The duplicate-id lint covers the *corruption* case from 2026-08-01,
  but proving a 246-line editor re-save dropped nothing still means dumping twice and
  diffing by hand.
- The boss fight is reachable *in principle* now via `entry_points`, but nothing is
  configured — this project still needs an entry naming the boss scene and whatever
  method actually starts the encounter (loading the room is not enough; the boss is
  hidden until the intro sequence runs).
- `pause-spawner` and `spawn_wave` staging verbs — project-side, still not written. The
  idle-test-player deaths that keep recurring in this log are the cost.

## 2026-08-01 — Re-scaffolding the harness onto an already-scaffolded project

- Gap: **the scaffolder overwrites `addons/godot_selftest/dev_tools.gd` with no backup**,
  while `tools/*` gets the `.bak` treatment. That asymmetry is only safe because this
  project happens to be under git — the local input-dispatch patch added on 2026-07-21
  would otherwise have been unrecoverable. (It survived: the patch is upstream now.)
  - Improvement: back up `dev_tools.gd` and `scene_validator.gd` on content mismatch
    exactly like the tool scripts, or refuse to overwrite when the file differs from the
    template *and* the project is not a clean git worktree.
- Gap: **no post-scaffold self-check of the bridge.** Step 12 lints, which proves the
  project still parses, but proves nothing about the thing that was actually installed.
  A refreshed `dev_tools.gd` could fail to register a single command and the smoke check
  would still print all-`OK`.
  - Improvement: add a step that launches muted, `ping`s, runs `list-commands`, asserts
    the project's own verbs are present, and quits. Roughly `/verify`'s first half.
- Gap: **the config patcher can't tell "customized" from "stale default".** It preserved
  `orphan_max: 0`, which this log has recorded as unreachable for months (a fresh launch
  reports 50–100 orphans). It's harmless now that `orphan_growth_max` is the real gate,
  but a dead key that reads like a threshold is a trap for the next reader.
  - Improvement: when a key is superseded, the patcher should drop or comment it rather
    than preserve it, and print which keys it added vs. kept.
- Confirmed fixed from earlier entries: the Windows `python3` App-execution-alias trap —
  probing by execution correctly picked `python` (`python3` fails here), and the Stop
  hook wired to it runs and exits 0.

**Still open, unchanged:** the boss-fight `entry_points` entry, `pause-spawner` /
`spawn_wave` staging verbs, and the semantic scene diff.

## 2026-08-01 — Anchor the lane baseline to street level (bug: lanes followed the player onto platforms)

- Gap: **No way to place the player on a specific piece of level geometry.** Reproducing
  "player stands on a platform" needed the platform's world Y, and the only route was
  reading it off a patrolling enemy in `lane_report`
  (`"node": "LaneSortLayer/MeterMaid", "foot_y": -63.5747375488281`), then
  `cmd teleport_player --args '{"x": 2401, "y": -140}'` + `wait-frames 60` and hoping
  something solid was under that column.
  - Improvement: a `surface_at --x N` verb (raycast down from a given x, return the
    first floor Y per collision layer), or `teleport_player --args '{"x": N, "snap": "floor"}'`.
- Gap: **`scene-tree` omits nodes, so a wrong node path reads as "the node is missing".**
  `run-method --node /root/Main/Player` returned `Failed: Node not found: /root/Main/Player`
  while `cmd player_state` happily reported the same player — the Player had been
  reparented into `LaneSortLayer`, and grepping the tree dump for `"Player"` found
  nothing until I searched for a child sprite name (`JumpingStreakSprite` →
  `/root/Main/LaneSortLayer/Player`).
  - Improvement: have the project verbs that already resolve a body (`player_state`,
    `lane_report`, `list_enemies`) include its `path` in `data`; `list_enemies` currently
    prints `"node": None` per enemy, which is the same gap.
- Gap: **A game launched with `&` from the Bash tool dies between calls.** `ping`,
  `run-method` and `validate-all` all worked, then `cmd lane_report` returned
  `game not running: 'lane_report' was never picked up` with a clean-exit tail in the
  log (`ERROR: 7 RID allocations ... leaked at exit`) and no script error — the process
  was reaped when its shell went away. Relaunching via the tool's own background mode
  survived the whole run.
  - Improvement: state in the `/verify` Phase 2 launch step that the game must be
    launched as a tracked background task, not with a trailing `&`.
- Gap (recurrence): **idle test players get killed by spawn waves.** Between discovery
  commands the player went to `"is_dead": true, "health": 0`; `revive_player` +
  `kill_enemies` fixed it, but every run pays this toll.
  - Improvement: a `pause_spawning` / `peace_mode` toggle so a diagnostic session can
    hold the level still (`god_mode` stops damage but not the swarm crowding the body).

## 2026-08-01 — Controls page rewrite (web-font glyph bug), README + screenshot

- Gap: **No way to reload a changed scene into a running game.** Editing
  `controls_splash.tscn` and re-issuing
  `cmd start_game --args '{"scene":"res://scenes/controls_splash.tscn"}'` produced a
  pixel-identical screenshot — the `PackedScene` was still cached from the first load.
  Every layout iteration cost a full quit + relaunch + re-enter (~10s each, 4 rounds).
  - Improvement: a `reload_scene` verb that calls
    `ResourceLoader.load(path, "", CACHE_MODE_IGNORE_DEEP)` before
    `change_scene_to_packed`, so a `.tscn` edit can be seen without relaunching.
- Gap: **`validate-ui`'s `ui_text_overflow` measures a multi-line Label as one line.**
  It reported `Label 'ActionsLabel' text 'MOVE\nJUMP\nATTACK...' exceeds width
  (text: 564px, label: 225px)` for a 9-line label whose every line fits comfortably —
  2 of 5 reported issues were this false positive, which trains you to skim the check.
  - Improvement: split on `\n` and compare the widest LINE against the label width
    (and skip the check entirely when `autowrap_mode != OFF`).
- Gap: **Nothing checks that on-screen text is drawable in the font that draws it.**
  The reported bug was em dashes on the controls page vanishing in the deployed web
  build; `has_char(0x2014)` is `false` for `AldotheApache.ttf`, but desktop Godot silently
  falls back to a system font, so lint, `validate-ui` and every local playtest passed.
  Added `test/unit/test_font_glyph_coverage.gd` for this project (mutation-checked: it
  fails with `uses glyph(s) [—] the body font has no character for`).
  - Improvement: promote it into the harness as a lint rule — scan every `.tscn` `text =`
    against the fonts actually assigned to those nodes. It is a whole class of
    "works locally, broken on web" that nothing else in the harness can see.
- Gap (recurrence, third time): **a game launched with a trailing `&` dies between
  calls** — mid-session `cmd teleport_player` and `cmd spawn_enemy` both returned
  `game not running: ... was never picked up` while `screenshot` in the same loop
  succeeded, so the failure is intermittent rather than a clean death.
  - Improvement: as logged last turn — `/verify` Phase 2 should say to launch the game
    as a tracked background task, not with `&`.

## 2026-08-01 — Committing the session's work

- No devtools/`/verify` gaps this turn: the work was git, and lint + tests were re-run
  against the committed tree (`Total: 133 | Passed: 133`, lint 6 pre-existing UID
  mismatches).
- Worth recording, though it is a repo effect rather than a harness gap:
  `godot --headless --path . --import` (run to register `docs/screenshot.png`) rewrote
  `uid://` refs in four files nobody had edited - `mobile_controls.tscn`,
  `hud_logo_outline_mat.tres`, `hud_orb_outline_mat.tres`, `hp_1.tscn` - and they
  surfaced as unexplained working-tree changes mid-commit.
  - Improvement: have `/verify` (or a small `tools/` helper) print
    `git status --short` before and after any `--import` it triggers, so import-authored
    edits are attributed at the moment they happen instead of being mistaken for
    someone else's in-editor work.
