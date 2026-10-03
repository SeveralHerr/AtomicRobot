# Skills Log

Log of skills that might have been useful for a given response, and why (short form).

## 2026-07-26 — Add logging sections to CLAUDE.md

- `update-config` — flags that "do X at the end of every response" behaviors are memory/prompt conventions, not enforced hooks; relevant caveat, but not used since the user explicitly wanted a CLAUDE.md instruction, not a settings.json hook.

## 2026-07-26 — Add "enhance used skills" rule + merge to main

- No skills were used this turn (plain doc edit + git/GitHub operations); none of the available skills fit small text edits or merging a branch.

## 2026-07-26 — Implement the logging Stop hook

- `update-config` — used to add the Stop hook to `.claude/settings.json` (hooks are the right primitive for a per-turn automated check, not a CLAUDE.md instruction). Enhancement idea, in simple words: give the skill a few ready-made hook recipes (like "warn if file A changed but file B didn't") so it doesn't have to hand-write the shell script from scratch every time.

## 2026-07-26 — Retire enemies on death, not when the corpse frees

- `godot-selftest-harness:verify` — used. It caught nothing wrong, but its Phase 2 launch is where the run fell over: the test player was killed by ambient waves and the game exited, taking the bridge down mid-test. Enhancement idea, in simple words: after the entry hook, have `/verify` make the test player unkillable, and check the game is still alive before each command so a dead game says "game not running" instead of hanging for a minute.
- `simplify` — would have been useful and wasn't run. The fix added the same `_is_alive()` helper to both `enemy_event.gd` and `building_door_encounter.gd`; a reuse pass would likely have pulled it up to a shared static on `Enemy` instead of copy-pasting it.
- `fewer-permission-prompts` — marginal. Several read-only `python tools/devtools.py ...` calls prompted, and one got denied mid-test; an allowlist for the devtools CLI would smooth out future runtime verification.

## 2026-07-26 — Log the harness gaps to README + memory

- No skills used or needed — a README edit, a memory-file update, and git operations. None of the available skills cover small doc edits or committing.

## 2026-07-26 — Move the logs into log.md / log-devtools.md

- No skills used or needed — reading the updated CLAUDE.md and appending to two log files. No available skill covers "follow a repo's own logging convention".

## 2026-07-25 — Animate the HUD orb losing a hit point

- `godot-selftest-harness:verify` — used. Lint/tests were clean; the runtime phase is what proved the change (mid-tween `modulate` reads + a screenshot of the flare) and also exposed that the orb shader was throwing `modulate` away. Enhancement idea, in simple words: let `/verify` freeze the game clock and step it by a fixed amount, so an animation can be checked at an exact moment instead of guessing with slow-motion and sleeps.
- `simplify` — not run; would have been a reasonable pass over `health_container.gd`, which still carries an empty `_process` and a mix of typed/untyped locals from before this change.
- A skill that doesn't exist and would have helped: something like "godot-tween-effects" — a small library of reusable UI juice tweens (punch, shake, pop-out) so damage/pickup effects don't get hand-written per project.

## 2026-07-25 — Commit the HUD damage animation and the leftover working-tree changes

- No skills fit — branching, reviewing three diffs I hadn't written, and committing. `/verify` was already run on the code change in the previous turn and nothing gameplay-related changed here.
- A skill that doesn't exist and would have helped: something like "godot-scene-diff" — tell whether a re-saved `.tscn` actually changed behaviour or just churned format. Doing it by hand meant dumping both versions through `tools/dump_level.gd` and diffing the JSON.

## 2026-07-25 — Diagnose the one-attacker wave bug, fan out approach A

- No skill was invoked this turn — the work was reading `enemy.gd` / `lane_system.gd` / `globals.gd` to find why only one enemy attacks, then splitting the fix across three subagents by file ownership. No available skill covers "partition an edit so parallel agents can't collide".
- `godot-selftest-harness:verify` — not yet run; it is the gate for the next turn, once all three agents have landed their edits. Enhancement idea, in simple words: let `/verify` take a list of files and check only what those files affect, so a three-way parallel change can be verified per-part instead of only at the end.
- `simplify` — worth queueing after the agents finish. The change deletes `_lane_is_claimed` and shrinks `_pick_chase_lane` to a one-liner, which is exactly the kind of leftover a reuse/altitude pass should collapse.
- A skill that doesn't exist and would have helped: something like "godot-dead-code" — find autoload APIs that are fully written and unit-tested but never called from gameplay. The whole bug was that `Globals`' attack-slot manager had passing tests and zero callers, and nothing surfaced that; its own docstring pointed at a function (`_chase_toward_player`) that never existed.

## 2026-07-25 — Exempt the boss from the attack-slot pool

- No skill invoked — a three-file follow-up fix surfaced by a subagent's report (the boss holding a ranged slot for the whole fight), plus a lint run.
- `godot-selftest-harness:verify` — still pending until the test agent lands; the `test/scenes/melee_cluster.tscn` / `ranged_cluster.tscn` / `mixed_cluster.tscn` sandboxes are the right runtime targets for this change.
- A skill that doesn't exist and would have helped: something like "godot-state-reachability" — given a state machine, report which states have no exit transition. The boss bug was exactly that (`BossAttackPlayerState` is entered in `_ready()` and never left), and it only came to light because an agent read the file by hand.

## 2026-07-25 — Verify approach A at runtime

- `godot-selftest-harness:verify` — used, and it was the only thing that could prove this change (lint + 114 unit tests passed on the broken version too). Enhancement idea, in simple words: let `/verify` keep the test player alive by itself, because the fight killed the player three times before a single measurement succeeded, and each death silently froze every reading at zero instead of saying "your player is dead".
- `simplify` — still queued and now clearly worth running: the change left `_pick_chase_lane` inlined and `_lane_is_claimed` deleted, and I added a `competes_for_attack_slots()` predicate that replaced a duplicated `lane_locked` check in two files.
- A skill that doesn't exist and would have helped: something like "godot-crowd-assert" — sample a running fight over time and report peaks (how many attacking at once, who is on which lane). I hand-wrote four throwaway Python samplers to get numbers that should be one command.

## 2026-07-25 — Add revive/god_mode/attack_slots devtools verbs

- No skill invoked — adding project verbs to `devtools_ext/commands.gd`, a generic status hook to the harness core, and a path fix to `devtools.py`, then committing to two repos.
- `godot-selftest-harness:verify` — not re-run in full; this turn changed only debug tooling, and the gameplay change it gates was already verified and committed. Lint + 114 tests were re-run clean, and each new verb was exercised live.
- A skill that doesn't exist and would have helped: something like "plugin-release" — bump the version, update the changelog, and push a Claude marketplace plugin in one step. Doing it by hand means remembering which of `plugin.json` / `marketplace.json` carries the version.

## 2026-07-25 — Fix the slot desync and upstream the input patch

- No skill invoked — a one-line root-cause fix, two regression tests, and a file sync between two repos.
- `godot-selftest-harness:verify` — not run in full; lint + 116 tests are clean and the fix was confirmed live with the new `attack_slots` verb across a player death. The verbs added last turn are what made that a single command instead of a hand-written sampler.
- A skill that doesn't exist and would have helped: something like "mutation-check" — reintroduce a fix's root cause, confirm the new test fails, then restore. I did that by hand this turn and my restore path was wrong, so the bug briefly stayed reintroduced; a skill that owns the backup/restore step would not have slipped.

## 2026-07-26 — Juice the score/combo/power-up HUD and outline the HP label + logo

- `godot-selftest-harness:verify` — used, and it earned its keep twice. Lint caught a shader-compiler error I had just introduced (Godot cannot take the built-in `TEXTURE` as a user function argument), and `validate-ui` caught the combo label sitting visible-but-fully-transparent when no combo is running. Neither is visible in a screenshot. Enhancement idea, in simple words: let `/verify` take a "before" reading of the noisy numbers (orphan nodes, UI warnings) on the unchanged code automatically, so it can say "these 3 warnings were already here" instead of leaving me to stash my work and relaunch the game twice to find that out by hand.
- `simplify` — not run; the change is additive and the one helper I wrote badly (a `_tint()` that looked its cache up by string name) I replaced by hand before committing.
- A skill that doesn't exist and would have helped: something like "godot-uv-shader-preflight" — given a shader and the nodes it is assigned to, report the drawn pixel size and aspect of each one, and warn when a UV-space radius will come out anisotropic or will be clipped by the art's own margin. Both problems were real here (a 794x500 logo would have got a rim 1.6x fatter top-and-bottom, and only ~1.4% of vertical margin to draw it in), and I only caught them by measuring the PNG's alpha bounding box in Python first.

## 2026-07-31 — Mobile controls relayout (joystick left, actions right)

- `run` — would have helped: launching + screenshotting the game to confirm the touch
  layout; I drove it by hand through the devtools bridge instead. Enhancement idea:
  teach it to auto-run the project's `entry_hook` so the first screenshot is of the
  playable scene, not the start screen.
- `simplify` — not used, but a good follow-up on `scripts/mobile_ui.gd` now that the
  per-finger tracking replaced the copy-pasted per-button branches.
- A "godot-scene-layout" skill would have helped had it existed: editing anchors and
  offsets in `.tscn` text by hand is error prone, and there is no headless way to ask
  Godot "what rect would this control get at 1280x800" without running the game.

## 2026-08-01 — Pull main, resolve the log conflicts, commit the HUD work

- No skill invoked — committing a working tree, merging one commit, and resolving two
  append-only log conflicts. `godot-selftest-harness:verify` was deliberately not run in
  full: nothing was authored this turn, and the merge was non-overlapping (theirs moved
  `MobileUI` anchors, mine added a HUD material), so headless lint + the 125 unit tests
  were the proportionate gate. Both passed.
- A skill that doesn't exist and would have helped: something like "append-log-merge" —
  auto-resolve conflicts in files that are only ever appended to (changelogs, these two
  logs) by keeping both sides in date order. Git conflicts on every one of these merges
  and the resolution is mechanical every time.
- A second one worth having: "godot-post-pull" — run `--import`, then diff which
  generated `.uid` files are newly untracked. The incoming commit shipped
  `test/unit/test_mobile_controls.gd` without its `.gd.uid`, which the other 122 scripts
  all have; only a reimport surfaced it.

## 2026-08-01 — Re-scaffold the godot-selftest-harness

- Used `godot-selftest-harness:scaffold-godot-harness`. It was a refresh, not a first
  install: the addon core, all four tool scripts, the example extension, and the
  CLAUDE.md section were updated in place; `devtools_ext/commands.gd`, `test/unit/`,
  and `log-devtools.md` were correctly left alone; `devtools_config.json` was patched
  to add the six new keys while keeping this project's `hud_layer_name: "UI"`,
  `main_scene`, and `entry_hook`.
  - Enhancement idea, in simple words: the scaffolder should **say what changed** at the
    end — a short list of "refreshed / created / left alone / backed up" per file. Right
    now you only learn `dev_tools.gd` gained 714 lines by running `git diff` yourself,
    and the three `.bak` files it leaves behind look like junk unless you go diff them.
  - Second idea: it should **check the DevTools autoload is last** in `project.godot`,
    not just present. Here it sits above five game autoloads that the project's own
    debug verbs call into. Nothing broke (the verbs run later, not at registration),
    but the ordering rule the command itself states is silently violated.
- `godot-selftest-harness:verify` was not run: nothing about gameplay changed, so
  headless lint + the 125 unit tests were the right-sized gate for a tooling refresh.
- A skill that would have helped had it existed: "godot-fix-uids" — the lint smoke check
  surfaced 9 pre-existing stale-UID errors and the remedy is a documented one-liner in
  CLAUDE.md, but deciding whether rewriting nine `.tscn` files counts as in-scope for a
  scaffold is a judgment call a small dedicated skill could just own.

## 2026-08-01 — Lane baseline anchored to street level

- `godot-selftest-harness:verify` — used. Caught nothing new here (lint/tests were
  already green before it), but it is what forced the runtime check of the platform
  case rather than trusting the unit tests. Enhancement idea: let it print, per changed
  file, which runtime test covered it — so a script that got no runtime coverage is
  named out loud instead of blending into a green summary.
- A skill that would have helped, had it existed: **"repro a reported gameplay bug"** —
  take a screenshot/description, find the geometry involved, drive the game into that
  exact situation, and confirm the misbehaviour BEFORE the fix. Most of the runtime time
  this turn went into locating a platform and standing on it.
- `simplify` / `/code-review` — not used; the change is small and self-contained.

## 2026-08-01 — README, controls page, web-font glyph fix

- No skill was invoked this turn (the work was scene/doc editing plus runtime screenshots).
- Would have helped, had it existed: **"capture a game screenshot for docs"** — launch,
  reach a representative moment, compose it (spread enemies, full health, good backdrop),
  save into the repo and reference it from a doc. Doing it by hand took 5 candidate shots
  and 3 relaunches.
- `godot-selftest-harness:verify` — not run as a whole this turn; its Phase 1 (lint,
  tests) and Phase 3 (validate-ui, performance) steps were run individually because the
  work was UI layout that needed a screenshot loop, not a diff assertion. Enhancement
  idea: a lighter `/verify ui <scene>` entry point that loads one scene, validates it and
  screenshots it, without the full launch-and-assert-the-diff pass.

## 2026-08-01 — Commit split

- No skill invoked; this was git work. No skill in the list would have helped, and none
  is obviously missing - `/code-review` would have been the one to reach for had the
  request been "check this before committing" rather than "commit it".

## 2026-08-01 — Pause menu CRT + readability

- No skill invoked. `godot-selftest-harness:verify` would have been the natural fit but
  its Phase 2 launch/entry flow cannot reach a PAUSED frame at all (see log-devtools.md
  this date), so the check was done by hand.
- Would have helped, had it existed: a **"compare a UI state before/after a shader or
  layer change"** skill — capture the same screen twice and diff, rather than eyeballing
  two screenshots taken minutes apart.

## 2026-08-01 — Public-repo push-permission audit

- `security-review`: closest fit, but it reviews pending code changes on the branch, not repository hosting configuration — did not invoke.
  - Enhancement idea: let it also look at the repo's GitHub settings, not just the diff — is the main branch locked, do the build robots hand secrets to strangers.
- Would have been useful had it existed: a **repo-hardening** skill that answers "is my public repo safe" — checks branch protection, workflow triggers vs. secrets, collaborator list, and committed keys, then offers the fixes.
- `update-config`: not applicable; the settings at issue are GitHub's, not `settings.json`.

## 2026-08-04 — Controls splash text unreadable (overlapping lines)

- No skill invoked; this was a scene-resource fix verified with the project's own
  headless runners. `/run` was the closest listed fit — it launches the app to confirm a
  change works — but it does not know how to reach the controls splash specifically, so
  the scene was instantiated directly instead.
  - Enhancement idea for `/run`: let it take a scene path and just show that one screen,
    so checking a single menu does not mean playing through the start screens.
- Would have helped, had it existed: a **text-layout sanity** skill that flags label
  settings whose line spacing is smaller than the font's own height — the whole bug was
  one negative `line_spacing` value, and nothing in the repo could see it.

## 2026-10-02 — Crouch off S/Down: mobile button, controls screen, docs

- No skill invoked. `derive-the-list` was the nearest fit: the controls-screen needle
  list and the mobile button->action map are both hand-written lists that drift.
- Would have helped, had it existed: a **unit-test runner** — `tools/run_tests.gd` was
  removed in 06e113f, so running two test files meant restoring it from git into a
  scratch copy. Also CLAUDE.md's Godot path is stale (exe is under
  `Downloads\Godot_v4.7.1_fixed\`).

## 2026-10-02 — Commit + ship crouch button

- No skill invoked. `itch-ci-deploy` was the nearest fit: confirming the push-triggered
  itch deploy went green (it did: run 37077555115).

## 2026-10-02 — New lean test runner

- No skill invoked. `extract-a-testable-seam` / `scope-vs-claim` fit: old runner counted
  a test that hit a runtime error as a pass; new `tools/run_tests.gd` hooks Godot's
  `Logger` so script errors fail the test.
- `itch-ci-deploy` would have helped wiring the CI test gate before export.

## 2026-10-02 — Does the suite play the game? Wire gameplay selftests into CI

- No skill invoked. `cycle` fit (gate → commit → push loop); sandbox selftests already
  existed but nothing ran them and their Godot default path was stale.

## 2026-10-02 — Arcade button remapping in the pause menu

- Fanned out 2 subagents on disjoint files against a fixed `InputRemap` API contract
  (logic+tests / UI+tests); both landed green first try (166/166).
- No skill invoked. `godot-game-ui` fit (pause sub-screen); `extract-a-testable-seam` fit
  (panel exposes `_capture` so listen mode is testable without real input).
- Missing skill written: `skills/godot-headful-screenshot` (validation-loop screenshots).

## 2026-10-02 — Arcade joypad navigation audit (all UIs)

- Fanned out 3 agents by UI area on disjoint files (front-end / overlays / pause+input map);
  42 new pad-driven tests; 208/208 unit + 9/9 sandbox green.
- Big finds: title/story/controls screens were key+mouse only (pad could not start the game);
  all ui_* pad binds pinned to device 0 (2nd encoder pad dead); Game Over RESTART unfocused.
- No skill invoked. `godot-game-ui` fit (focus styles); `extract-a-testable-seam` fit (stub
  scene-change methods so tests don't boot main). `pi-game-deploy` appeared late — next step
  for putting the build on the cabinet.
- Skill used last time `godot-headful-screenshot` (repo skills/) worked again; enhancement:
  include a pad-event helper for driving focus before the shot.
- Follow-up: RESTART mash guard (`GameOver.arm`, 0.6s disabled), `[e]` prompts -> `[interact]`,
  deleted dead ui_container/restart_ui/scene_transition/fade_utility.

## 2026-10-02 — Window maid death no longer blinks/removes the window

- Cause: `Enemy.die()` tweened `self.modulate` + `queue_free()`; window frame sprites are children of MeterMaidWindow.
- Fix: hooks `_death_blink_target()` / `_on_death_blink_finished()`; window maid blinks + hides only AnimatedSprite2D.
- Skill used: `godot-headful-screenshot` (repo) — enhancement written: gameplay timed-sequence section + class_name compile gotcha.
- Would have fit: `extract-a-testable-seam` (blink split out of die() for tests), `scope-vs-claim` (test proven to fail w/o fix).
- 212/212 unit, 9/9 sandbox green.

## 2026-10-02 — /pi-game-deploy Atomic Robot to Picade
- pi-game-deploy (used): deploy worked first try. Enhancement: check that Godot export templates are installed before exporting, and warn when the game's keys don't land on Picade buttons.
- itch-ci-deploy: would have shown the CI template-download step to copy locally.
- Wished-for skill: "godot-export-templates" — fetch only the web template zips from the 1.2 GB tpz.
- Follow-up "Aw snap": Chromium was OOM-killed (1 GB Pi). Fixed by excluding 66 MB of unused WAVs from export, and the launcher now uses its own empty labwc config so the Pi desktop doesn't autostart. pi-game-deploy enhancement: check dmesg for OOM in the debug loop, and warn when the pck is large.
- Follow-up "error code 9": renderer still OOM. Measured with a headless-Chrome memory probe on the PC (a headless probe ON the Pi froze it — never do that). Music WAV set to stream playback (885→514 MB), big backgrounds VRAM-compressed + ETC2 (gpu 420→297 MB). Wished-for skill: "web-game-memory-budget" (measure tab+GPU memory before deploying to a low-RAM device).
- Follow-up Ryan black square + exit button: Ryan2.png 170x4712 exceeded Pi GPU's 4096 px limit, so it was repacked to a 4-column grid (pixel-identical, guard test added). Pause menu got a QUIT GAME button (desktop quit, cabinet window.close via ?exit=1, hidden on itch). pi-game-deploy enhancement: done — added the OOM/4096/launcher gotchas to SKILL.md. godot-headful-screenshot (used): worked as written; idea: show how to push ui_down to screenshot a focused button.
- "Thoroughly test": broadened 4096-px test to every image a scene references; mutation-tested the quit logic (7 mutants: 6 killed, 1 survivor = web-only window.close branch, untestable headless). Built picade_keys.py (uinput key injection, no evdev) + memlog.sh, left on the Pi. Found separate bug: Pinball GPU process crash (exit_code=8704) → labwc abort 134 → user had to power-cycle. Wished-for skill: "cabinet-e2e" (launch port remotely + grim + uinput drive). Local Chrome E2E blocked: background tab throttled to 1 FPS.

## 2026-10-02 — Investigate Pi lag (advice only, no code changed)
- pi-game-deploy: would have helped — has the Pi launcher/Chromium context. Enhancement idea: add a "perf checklist" (screen-texture mipmaps, full-res canvas, physics bodies) to SKILL.md.
- webgl-antialiasing: near-fit (WebGL canvas cost), not directly needed.
- Wished-for skill: "web-game-perf-budget" — headless Chrome frame-time probe on PC with CPU throttling to mimic a Pi, before shipping.
- Follow-up: removed unused shaders/water.gdshader (+.uid). 219/219 unit green. Spotted orphans water.gd + splash_particles.tscn + stale LEVELS.md WaterHandler line — left for user decision. Would have fit: derive-the-list (orphan-asset finder from references, not memory).
- Follow-up: removed debug/settings/stdout/print_fps from project.godot (no on-screen FPS label existed). Tests re-run.
- Follow-up leaf perf: pooled leaves now PROCESS_MODE_DISABLED (were still falling in physics — test proved 11px drop), sleeping leaves skip raycast, LeafManager rescans only after player moves 32px. New test/unit/test_leaf_perf.gd (4). Runner now awaits process_frame before each test (physics_frame-ending test broke remap test order). 223/223 unit, 9/9 sandbox. Would have fit: extract-a-testable-seam (should_rescan pure seam) — enhancement idea: mention "test ended on physics_frame poisons the next test" gotcha.

## Jump reach tune (subagent)
- No skill used. Would help: a "godot-platformer-tuning" skill (measure jump arc headless, baseline-then-tune).

## Door-burst spawn grace (subagent)
- No skill used. Would have helped: `extract-a-testable-seam` (gate can_attack headless), a "godot-enemy-fixture" skill (real maid+player in tree for AI gate tests).

## 2026-10-02 — Picade menu btn, jump reach, door-burst grace, enemy oof -6dB (orchestrator)
- Skills used: none (fanned out 4 general-purpose subagents).
- Would help: `pi-game-deploy` — push the build to the Picade to feel-check; a "godot-feel-tuning" skill — playtest timing/jump values with screenshots.

## 2026-10-02 — Cat easter egg, comic popups, car once-hit, stoplight column, Exit Game (orchestrator)
- Skills used: artifact-design (artifact page); godot-headful-screenshot (repo skill, exit-button shots). Enhancement: added GIF recipe + "--import after new class_name" gotcha to it.
- Fanned out 2 general-purpose subagents (comic popups; cat + GIF). Cat building was ambiguous → 2 corrections from user; a screenshot up front would have saved a loop.
- Would have helped: `mockup-on-screenshot` (confirm target building against a real screenshot before building), `extract-a-testable-seam` (used the idea: `Streetlight.player_in_range()`), wished-for "godot-level-landmarks" skill — name→world-coords map of buildings so "the first skyscraper" resolves without guessing.

## 2026-10-02 — No popup on enemy death, ship, Pi deploy, Pi shutdown
- Skills used: pi-game-deploy (deploy + verify). Enhancement idea: add a `pi_shutdown` helper (sudo -S fed from .env; pie has no passwordless sudo) and note that the `.env` lives in atomic-pinball, not each game repo.
- Would have helped: itch-ci-deploy (watch the run; done by hand with gh run watch).

## 2026-10-03 — Q: do we have a play-test method?
- Answer only, no code. Skills used: none. Would have helped: `run` (launch/screenshot game), repo `godot-headful-screenshot`; wished-for "playtest-bot" skill (scripted input replay through full run + assertions).

## 2026-10-03 — High-score list + arcade initials entry (pad / keys / touch)
- Skills used: repo `godot-headful-screenshot` (10 validation rounds). Enhancement: add a contact-sheet + `--resolution` phone recipe (now in CLAUDE.md / new skill).
- Would have helped: `godot-game-ui` / `godot-game-ui-juicy` (menu kit; skipped to match the existing Bangers/rank-card look), `extract-a-testable-seam` (hint_text(touch) seam), `derive-the-list` (glyph test derived from ALPHABET), `scope-vs-claim` (mutation survivors exposed 2 over-claiming tests).
- New skill written: `skills/godot-input-test` (frame-start input injection, just_pressed-first polling, WASD-vs-typing, mutation script).
- New MCP server: `tools/mcp/godot_tests_mcp.py` (`godot-tests`, enabled in `.mcp.json`).
- 311/311 unit (45 new), 9/9 sandbox, 16/16 mutants killed.

## 2026-10-03 — Integrate end screens into one pinball-style EndCard (+ GIF artifact)
- User feedback: new UIs were "slapped on top"; Game Over sat behind the high-score menus. Fixed: one `UI/EndCard` (rank stamp, score, badge, initials → list, RESTART/EXIT) replaces Game Over/Win containers, HUD rank card and overlays; styled after atomic-pinball.
- Skills used: none from the list (repo `godot-headful-screenshot` + `godot-input-test` recipes). Enhancement for godot-input-test: added flush-on-record, precondition asserts, tilt/stamp/touch-control gotchas.
- Would have helped: `mockup-on-screenshot` (mock the card on a real frame before coding), `godot-game-ui` (comic re-skin kit), wished-for "sibling-game-style" skill (extract tokens/flow from a related repo into a Godot theme).
- 320/320 unit, 9/9 sandbox, 19/19 mutants killed (3 after tightening). Artifact: https://claude.ai/artifact/BXTHrWgYfZo3BetDA3nH9z

## 2026-10-03 — Autoplay bot for self-testing, judge panel, full playthrough report
- Skills used: godot-headful-screenshot (windowed snaps), artifact-design via quickstart (report page). Enhancement idea for godot-headful-screenshot: point to `tools/autoplay.py --window` + `snap`/`snap_every` instead of throwaway SceneTree scripts.
- Created: `skills/godot-autoplay-test/SKILL.md`.
- Would have helped: `extract-a-testable-seam` (brain kept pure for tests), `derive-the-list` (used the idea: METRICS pinned to recorder both ways), `scope-vs-claim` (judges caught `max_stuck_s` that could never fail), `godot-2d-placement-audit` (crate collider walls off road lanes).
- Process lessons: worktree under the OneDrive path failed on long filenames — fixed with `core.longpaths` + short worktree path; a bot that "passes" needs a metric that can fail (prove it red first, as with the boss soft lock).
- Report: https://claude.ai/artifact/G2ieWdXVsPtTuYCbu64AhH. Merged to main; 373/373 unit, 6/6 autoplay scenarios.

## 2026-10-03 — Character select redo (worktree char-select-juice)
- Used: none of the listed skills directly. Followed repo skills godot-input-test + godot-headful-screenshot by hand.
- Would have helped: somewhat-useful-claude-skills:godot-game-ui-juicy (tween/Container gotchas pre-solved); godot-2d-placement-audit (cursor/feet placement asserted numerically); a judge-panel skill (written: skills/juicy-screen-review in the worktree).
- Enhancement idea (godot-headful-screenshot): ship the round.sh + sheet.py pair so each validation round is one command.

## 2026-10-03 — Robot unlock (locked → first boss win, overpowered); merged to main
- Used: godot-autoplay-test (repo skill) — caught the wall-clock grace bug that unit tests missed.
- Would have helped: somewhat-useful-claude-skills:derive-the-list (OP badge/gold pips derived from roster, not hand-listed).
- Enhancement idea (godot-autoplay-test): note that any boss-winning scenario hits persistent saves; isolate them like the runner now does.
