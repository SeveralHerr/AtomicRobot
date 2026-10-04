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

## 2026-10-03 — Robot/Cass can't clear door arenas (lane-based projectile hits + maid re-lane)
- Skills used: artifact-design (GIF report page). Enhancement idea: tell me up front that a 6-panel CRT-noise GIF blows past 16MB, and give a size budget per frame.
- Would have helped: godot-autoplay-test (used its CLI; it needs a "force a bad state" section and should say snaps are frame-numbered now); derive-the-list (not needed); a "godot-ab-worktree" skill that runs the same scenario on HEAD vs the working tree and prints a diff table (did this by hand).
- MCP: none used (godot-tests MCP available; used CLI directly for --filter + mutation loop).

- 2026-10-03 commit+merge: no skill needed; plain git branch -> 4 commits -> --no-ff merge.

## 2026-10-03 — Boss fight rework (worktree boss-fight-juice)
- Skills used: godot-autoplay-test (bot runs, snaps, balance). Enhancement: document GIF recipe + sweep tool (done).
- Would have helped: godot-boss-juice (created) — presentation checklist + fairness rules; somewhat-useful-claude-skills:godot-game-ui-juicy (motion patterns, container-scale gotcha); extract-a-testable-seam (pure `contact`/`link_fan`).
- MCP: none used (godot-tests MCP available; ran suites via shell for full output).

## 2026-10-03 — Speedrun self-test, crate invisible wall, human-style bot
- **godot-autoplay-test** (used): ran six full title-to-win runs. Idea: add a `--chars` flag to `autoplay.py` so one call runs every character; record ran in parallel via a background shell.
- **godot-lane-collision** (new): would have found the Wall-layer crate in one step. `tools/lane_wall_audit.py` plus the MCP `audit_lane_walls` tool.
- **godot-ab-worktree**: useful for comparing crate-fix runs before and after (used stash instead).
- **juicy-screen-review**: its judge-panel pattern was reused for the 3 code-audit agents.
- **mockup-on-screenshot**: would help turn the juice ideas into visual mockups next.
- **derive-the-list**: the lane-wall audit derives suspects from the dumped level instead of a hand-made list.
- MCP: added `run_autoplay` and `audit_lane_walls` to `godot-tests`. Merging branch `human-bot` was refused by the permission classifier because the working tree had uncommitted changes; commit first, then merge.

## 2026-10-03 — Combat feel sprint 1-4 (worktree juice-feel): shake fix, hurt shake, hitstop + sparks, same-frame reactions
- Skills used: godot-headful-screenshot (frame capture; enhancement: say autoplay snaps can't see hitstop, tag frames with time_scale), godot-autoplay-test (full_run/mortal/balance), godot-boss-juice (slow-mo ownership), juicy-screen-review (round shape).
- Would have helped: extract-a-testable-seam (ScreenShake.step / allow_headless_hit_pause seams), godot-ab-worktree (before/after; done by hand), godot-hit-feel (created).
- MCP: none used (godot-tests MCP available; CLI needed for --filter + mutation loop). No new MCP server (YAGNI).
- Process: shared scratchpad collided with the death-beat agent (shot.gd/sheet.py/shots/base) — rule added to CLAUDE.md.

## 2026-10-03 — Door encounters in 1–3 waves (worktree juice-waves)
- Skills used: godot-boss-juice (banner reuse; added a street-callout section), godot-headful-screenshot (round.sh + sheet.py), godot-ab-worktree (old-vs-new late-level sweep), godot-autoplay-test.
- Would have helped: a balance-sweep skill that A/Bs a teleport-start mortal scenario across seeds and prints a table (wrote sweep.py by hand); derive-the-list (encounter list derived from main.tscn in the ramp test, not hand-listed).
- Enhancement idea (godot-headful-screenshot): note that `--resolution` doesn't change the root texture size, so the phone round needs a window grab to judge aspect.
- MCP: none used (ran suites via shell for --filter + mutation loop).

## 2026-10-03 — Death beat + Transition fades (worktree juice-death)
- Skills used: godot-headful-screenshot (batched real-flow rounds), godot-autoplay-test (full_run/mortal), juicy-screen-review (round shape), godot-boss-juice (time-scale rules). Enhancement (headful-screenshot): print state beside each snap — load hitches shift timestamps (added).
- Would have helped: godot-time-scale-beat (created: beat/fade ownership rules + mutant-killing tests); somewhat-useful-claude-skills:derive-the-list (used its idea for the direct-scene-change grep test); extract-a-testable-seam (Transition.fade_through(swap)).
- MCP: none used (godot-tests MCP available; CLI needed for --filter mutation loop).

## 2026-10-03 — Juice sprint (items 1–6 + door waves), 3 parallel agents -> branch juice-sprint
- Fan-out: juice-feel / juice-death / juice-waves worktrees, disjoint file ownership; only conflict was log.md appends. Combined: 528/528 unit, 9/9 sandbox, 10/10 autoplay.
- Skills used: none directly by orchestrator; agents used godot-boss-juice, godot-headful-screenshot, juicy-screen-review, godot-autoplay-test. New: godot-hit-feel, godot-time-scale-beat.
- Would have helped: a "parallel-agent integration" skill (per-agent scratchpad subdir up front — feel agent clobbered death agent's shots/base); somewhat-useful-claude-skills:godot-game-ui-juicy (banner motion).
- Enhancement (godot-headful-screenshot): `--resolution` doesn't change capture size in --script runs; document the real phone-size recipe.
- MCP: none used.

## 2026-10-03 — Melee "hits maids behind" investigation (worktree fix-melee)
- Not reproduced: real-scene unit tests + autoplay probe (222 hits, all dx*facing >= 14px). Added test_melee_facing.gd as regression guard (6/6 mutants killed).
- Skills used: godot-input-test (InputEventAction for Attack; mutation loop), godot-headful-screenshot (front-hit/behind-miss sheet), godot-hit-feel, godot-ab-worktree (not needed: no game-code change). Enhancement (input-test): world-node fixture rule + probe-before-fix (added).
- Would have helped: a "combat-geometry probe" autoplay event (hit dx/facing/lane logged per hit) instead of a temp print.
- MCP: none used (CLI needed for --filter mutation loop).

## 2026-10-03 — Split enemy.gd under the 500-line gate (worktree fix-split)
- enemy.gd 654 -> 441; new scripts/enemy/: EnemyLaneMover, EnemySeparation, EnemyKnockback, EnemyLedgeProbe, FacingTransform. 23 characterization tests added first (test_enemy_lane_motion, test_enemy_body). Autoplay 11/11 summaries byte-identical to baseline.
- Skills used: none directly (followed godot-autoplay-test recipe by hand: baseline summary diff). Would have helped: somewhat-useful-claude-skills:extract-a-testable-seam (static helpers), a "refactor-autoplay-diff" skill (capture baseline summaries, diff after; seeded runs are deterministic).
- Note: test_end_card::test_card_draws_over_the_boss_hud failed once on baseline while autoplay ran concurrently, passed on every later run — flaky under load.
- MCP: none used.

## 2026-10-03 — Merge juice sprint to main + remaining fixes
- Committed prior crate/lane WIP (3 commits), merged juice-sprint, fix-melee (not a bug; 8 regression tests), fix-split (enemy.gd 654->441, autoplay identical).
- Own fixes: BUSTED! burst off combo line (BossBanner.burst_radii seam + clearance tests); autoplay keeps non-player steps after death -> death_restart.json covers card->RESTART; phone capture recipe documented; Player.gd under 500.
- Final: 567/567 unit, 9/9 sandbox, 12/12 autoplay, lane audit clean.
- Skills used: godot-autoplay-test (death_restart scenario), godot-headful-screenshot (enhancement: phone recipe now in it). Would have helped: somewhat-useful-claude-skills:godot-2d-placement-audit (pin HUD/banner clearance numerically sooner).
- MCP: none used.

## 2026-10-03 — Payoff renamed STREET CLEAR!, shipped to itch.io
- Clearance tests caught the longer word overlapping the combo line; burst scale 0.6 -> 0.5.
- First deploy blocked by CI: end card buried by boss letterbox bars added after it moved to front (slow CI frames). Fix: card re-fronts on sibling add; test_card_stays_on_top_of_later_ui. Second deploy green (568/568, 9/9) and shipped.
- Lesson: a test that "failed once under load" locally (split agent saw it) was a real race — chase it before shipping, not after.
- Skills: none used; itch-ci-deploy would have helped read the failed run faster. MCP: none.

## 2026-10-03 — 100% speedrun video + footage review artifact
- Route: completionist_run.json (all hearts, secret wall B, 5 newspapers, both power-ups, boss, Robot unlock). Mortal seed 1 recorded: 3:11 to YOU WIN, 0 deaths, ended 4/30 HP.
- Fixed: Movie Maker froze on first hitstop (time_scale 0 -> NaN unscaled delta); Utils.hit_pause_scale() gives recordings a 1% near-freeze. Added `brain advance S X`, recorder powerup/unlock events, `autoplay.py --record`, MCP record_autoplay. 571/571 unit, 9/9 sandbox, 14/14 autoplay; 2 stop-x mutants killed.
- Footage findings (artifact for approval): street HP + score wiped at boss room, cat crack unreachable, projectile chars can't open secrets, NEWS card over HUD, STREET CLEAR mid-door, Robot unlock hidden behind win card.
- Skills used: godot-autoplay-test (enhancement: say up front that the brain never presses Interact — now documented), artifact-capabilities. New: godot-speedrun-review.
- Would have helped: godot-speedrun-review (now exists); somewhat-useful-claude-skills:godot-2d-placement-audit (HUD overlap numerically); mockup-on-screenshot (proposal visuals on cards).
- MCP: godot-tests (extended with record_autoplay). AGENTS.md referenced by CLAUDE.md does not exist.

## 2026-10-03 sr-hud (HUD presentation: wave clear, timer duck, 2-hit combo, cinematic HUD)
- Useful: godot-boss-juice (banner/announcer layout; added HudFade gotchas), godot-headful-screenshot
  (SceneTree capture), godot-autoplay-test (`--resolution 1688x780` snaps), godot-speedrun-review (frames).
- Wished for: a reusable "capture HUD states" SceneTree script and a generic `(file, original, mutant,
  filter)` mutation runner checked into tools/ (rewrote both in scratch).
- Enhancement idea (godot-boss-juice): say up front which HUD rows each callout lands on.
## 2026-10-04 sr-run (boss HP carry, run score, secrets tally, unlock stamp)
- Done: street HP carries through the boss door; run score (street+boss) with STREET/BOSS/BONUS card; time bonus run-wide (420 s par, 15/s); ranks S18000/A13000/B9500/C6000 pinned to measured runs; SecretTally derives 2 walls/5 news from the level files; NEW FIGHTER stamp; card z above HUD orbs; autoplay no longer writes the real scores.cfg.
- Skills used: godot-headful-screenshot (enhancement: window_set_size works inside --script captures — added), godot-autoplay-test, derive-the-list idea (secret totals both directions).
- Would have helped: a SceneState-walk helper skill (instance nodes repeat their root's script — double counts); a "shared user:// across worktrees" warning (parallel agents race on settings.cfg/scores.cfg).
- MCP: none used (godot-tests MCP not needed; CLI direct).
## 2026-10-04 — Secret walls for every character, juicy reveal, news shuffle (sr-secrets)
- Robot/Cass shots chip cracks (LaneProjectile.find_crack); Crack.take_blow = one feel for melee + shots.
- Reveal: brick chunks, gold SECRET!, Unlock sting, painted hole + bobbing orb; claim flies orb to HP bar (heal on arrival) + chime; Globals.secret_found wall/news once per id.
- Bugs found: hitting a claimed wall re-armed the orb (infinite orbs); completionist never read stand 5028 (road lane).
- News: shared shuffle bag -> 5 stands, 5 headlines (seeded). Paper card moved below score/CRT edge.
- 598/598 unit, 9/9 sandbox, 15/15 autoplay; 13/13 guard mutants killed (1 survivor -> new test).
- Skills used: godot-hit-feel, godot-headful-screenshot, godot-autoplay-test, godot-speedrun-review, juicy-screen-review (enhancement: ship the round/sheet scripts in the skill instead of rewriting them). Would have helped: somewhat-useful-claude-skills:extract-a-testable-seam (prompt-delay mutant), a "python edits on Windows" note (cp1252 + CRLF mangled files: use PYTHONUTF8=1 and newline='').
- MCP: none used.
## 2026-10-04 sr-balance (difficulty cliff: street -> boss)
- Done: boss throws 1.7/1.35/1.2 -> 2.0/1.7/1.5 s + 1 s opening grace + per-phase dash count; street finale 6 -> 8 maids with a reward heart; power-ups carry through the boss door and hold during the intro; bot heart give-up + hearts group; completionist_mortal scenario; sweep `--base` route columns.
- Skills used: godot-autoplay-test (enhancement: say `--record` diverges from headless — added), godot-speedrun-review (frame sheets).
- Would have helped: a checked-in route-balance table (now `autoplay_sweep.py --base`); a frame-sheet script (rewrote PIL contact sheets in scratch again).
- MCP: none used. Merge of speedrun-fixes was blocked by the permission classifier — left for the user.

## 2026-10-04 — Round 2: 16 approved review items, fan-out + re-record
- Base (orchestrator): .import files tracked + 100 stale UIDs fixed, drop-rate doc, Globals.secret_found contract.
- Agents (worktrees): engerr (car kill -> deferred monitorable), hud (WAVE CLEAR!, HudFade ducking, 2+ combo, cinematic HUD), run (HP/score carry, run score card, time bonus, secret tally, Robot stamp), secrets (projectile cracks, wall payoff, news shuffle bag, infinite-orb exploit fixed), balance (boss pacing, last door 8 maids + heart, power-ups through boss door).
- Orchestrator: merged all, completionist_mortal drift test, round-2 footage found + fixed stale banner subtitle (overtaken slam). Final 679/679 unit, 9/9 sandbox, 17/17 autoplay, 0 engine errors, 0 UID warnings. Artifact v2: before/after video, 17 shipped cards, 9 to decide.
- Lessons: my round-1 "STREET CLEAR mid-door" was two doors back to back (check encounter identity); agents can't merge (classifier) — orchestrator merges; fresh worktree import churns .import files.
- Skills used: godot-speedrun-review (enhanced: fan-out + round-2 rules), godot-autoplay-test, artifact-capabilities. Would have helped: somewhat-useful-claude-skills:enumerate-the-pairs (callout-overtakes-callout matrix would have caught the stale tag).
- MCP: godot-tests (not called directly; CLI used for --filter/stash loops).

## 2026-10-04 pf-enemyai (lane-bound coins, point-blank maids, coin reflect)
- Root causes: coin re-aimed + re-tagged to the player's lane on the release frame (lane step was tracked); window/platform coins hit every lane; coins physically collided with a player body in the next lane. Point-blank: sight ray starts inside the player's box, a ray never reports its start shape -> maid idled forever.
- Fixes: coin lane = thrower's lane (lane-locked: your lane at release), lane+box contact (mid-step dodges), lane shadow, rest on lane floor; LineOfSight point-in-player check; gold wind-up tell via flash.gdshader buff_* (self_modulate is ignored by that shader); EnemyTuning constants; coin reflect (group `reflectable`, `reflect(by)`).
- Tests: 3 new sandboxes (coin_lane_dodge, point_blank_ranged/melee) fail on 015e514, pass now; 23 new unit tests; 17 mutants, 16 killed + 1 equivalent (redundant has_landed early-out).
- Skills used: godot-ab-worktree (enhancement: ship a reusable `cap_main.gd` capture + `gif.py`), godot-headful-screenshot, godot-autoplay-test.
- Would have helped: a "sprite shaders overwrite COLOR — modulate is dead on maids" note in ARCHITECTURE; a checked-in mutation runner (rewrote again).
- MCP: none used (CLI direct).
## 2026-10-04 pf-numbers (damage scale, Cass, hit pips)
- Skills used: godot-autoplay-test (sweep), godot-ab-worktree (HEAD vs tree GIFs), godot-headful-screenshot, derive-the-list (fighter/enemy-scene tables).
  - Enhancement: autoplay-test should say `full_run_mortal` boots via the menu, so a locked Robot silently plays as the first unlocked fighter in `autoplay_sweep.py --base` (Robot rows == Cody rows); use a non-boot base for sweeps.
  - Enhancement: autoplay.py has no `--autoplay-out`; snaps always land in autoplay_out/.
- Would have helped: a "balance-rescale" skill (checklist: enemy HP, boss, hazards, score tiers, select pips, scenario asserts in raw units); a GIF-from-scenario helper in tools/.
## 2026-10-04 pf-present (player feedback: camera lock, rank legibility, newspaper, pop-up time)
- Camera: CameraLimitBlend eases door-fight lock/release (590 -> 28 px max per-frame screen jump, unit-tested).
- Newspaper: screen-space comic card in the left column; holds while at the stand + ReadingTime after; Interact re-reads (no new credit).
- Rank: ladder chips with thresholds, "+gap FOR X · tip" line; boss-room death shows STREET/BOSS split (carry already worked since 5590195; the 470 report predates it).
- Pop-ups: ReadingTime (1.5 s + 0.06 s/char, 3-9 s) for newspaper, boss speech bubble, STREET CLEAR!, chat bubble, unlock toast; wave/phase slams + hit words left gameplay-timed.
- 724/724 unit, 9/9 sandbox, 17/17 autoplay; 27 mutants, 3 survivors -> 2 new tests (+1 mutant re-aimed), all killed.
- Skills used: godot-ab-worktree, godot-headful-screenshot (enhanced: camera-limit + capture-save lessons), godot-autoplay-test, godot-input-test, juicy-screen-review. Would have helped: somewhat-useful-claude-skills:godot-2d-placement-audit (card-vs-HUD rects), a checked-in gif/contact-sheet tool (rewrote gif.py/sheet.py again).
## 2026-10-04 pf-combat (air attack, air control, combo/cancel, SFX pitch, coin reflect hook)
- Root cause (air attack): AttackState zeroed velocity, then Player.apply_gravity forced FallState on the next frame (anim lost, hover); FallState.exit_state puffed landing fx on every exit.
- Fixes: AttackChain (1.4x anim, cancel/chain 2 anim frames after hit, 3-swing string, lunge), air swings keep gravity/steer, FallState.land only on touchdown, AIR_ACCELERATION 1800, SfxPitch (+0.06/step, +-0.025 jitter) on attack/voice/jump/hurt + enemy oof, melee reflects `reflectable` coins in lane, RunState stops clobbering Overclock speed_scale.
- Tests: 5 new files (~45 tests), all bug tests shown failing on old code; mutation 33/33 killed (7 first-pass survivors were filter misses or got new tests).
- Skills used: godot-hit-feel, godot-input-test, godot-ab-worktree, godot-headful-screenshot. Enhancement: input-test skill should note Area2D does not report StaticBody2D stubs (use CharacterBody2D), and that `--filter` substrings make mutation runs miss tests whose names lack the word.
- Would have helped: a checked-in `tools/mutate.py` (third agent to rewrite it) and a checked-in `tools/capture_timeline.gd` + `gif.py` for before/after GIFs.
- MCP: none used (CLI direct).
## 2026-10-04 pf-polish (comic hit words in fast strings, windowed-run warnings)
- Hit words: HitWords rank rule (hit < finisher < KO): re-punch the live card, finisher replaces, kill slams KO! (was no word); replaced card hidden at once (hitstop froze its retire shrink); words lean 10px away from the attacker, rise by size; pips at feet stay clear (pinned by a test). 4 capture rounds + 1688x780 round.
- Warnings root cause: hitstop sets time_scale 0; on a fixed clock (`--fixed-fps`, every autoplay --window run) that NaNs awake RigidBody2Ds (gust-kicked leaves, coins) -> one "Vector2 cannot be normalized" warning per body per frame. Pre-dates branch (main: 1298 in smoke_fight --window). Godot strips --fixed-fps from get_cmdline_args -> runner sets Utils.fixed_clock -> 0.01 near-freeze. smoke_fight --window 2350 -> 0. Recorder now groups warnings by site.
- Suites: unit 836/836, sandbox 12/12, autoplay 16/17 (boss_balance_ryan hits_taken 6 < 8 also fails on base eff72c5 — balance agent's floor).
- Mutation: 13 mutants, 12 killed first pass, survivor (finisher flag from AttackState) got a real-scene test. Added tools/mutate.py (fourth agent asking for it).
- Skills used: godot-hit-feel (enhanced: word ranks, fixed-clock hitstop), godot-headful-screenshot, godot-ab-worktree. Enhancement: headful-screenshot should warn Python on Windows writes cp1252 by default -> invalid UTF-8 .gd (whole suite broke).
- Would have helped: enumerate-the-pairs (used its idea for the rank matrix); a checked-in capture_timeline.gd + gif.py (rewrote again).
- MCP: none used (CLI direct).
## 2026-10-04 pf-balance (restore challenge after snappy combat; rank re-pin)
- Street: EnemyTuning melee 150->220, ranged 100->150 px/s, cooldowns 1.0->0.6 / 4.0->2.5, WINDUP_SPEED 1.0->1.4; +1 maid at the 5 mid-street doors.
- Boss: MAX_HEALTH 60->96, BossRules.WINDUP_SPEED 1.3 (new; was hardcoded 1.0), throws 2.0/1.7/1.5 -> 1.6/1.35/1.2. Boss HP alone barely moved the bot's hits (fight time is mostly intro/stagger); wind-up speed did.
- Pins restated in old-swing time (blows/1.6 in 10-20; throw gap >= 2.0|1.5 / AttackChain.ANIM_SPEED), not loosened.
- Route sweep (6 chars x 4 seeds, non-boot base): pre-combat 20/24, 13.4 hits (5.5 street / 7.9 boss); post-merge 24/24, 6.7; final 24/24, 13.1 (5.5 / 7.6).
- Ranks S20000/A15000/B8000/C5000 from measured runs (21.1k S, 16.1k A, 14.3k B, ~9.8k human B, 7.9k C).
- 838/838 unit, 12/12 sandbox, 17/17 autoplay.
- Skills used: godot-autoplay-test (sweep). Enhancement: ship a parallel `autoplay_sweep.py --jobs N` + mean-row summary (wrote sweep_all.sh/summ.py in scratch); note Sara and Caitlyn sweep rows are identical (check whether one is locked or same stats).
- Would have helped: godot-ab-worktree (old-build baseline sweep — used a detached worktree by hand); a boss-only sweep preset matching boss_balance_* steps (sweep default `advance 140` != scenario `advance 110`, gave different hit counts).
- MCP: none used (CLI direct).

## 2026-10-04 — Player playtest feedback (orchestrator, branch player-feedback)
- Fanned out 4 agents (combat, numbers, enemy AI, presentation) + balance + polish; merged all into `player-feedback`; 841 unit, 12 sandbox, 17/17 autoplay, lane audit clean, 0 warnings in the final recording.
- User mid-run: drop rank chip row (noise) → one hint line kept; record only at the end.
- Final footage found + fixed: last KO! drawn over STREET/WAVE CLEAR! burst (mutant killed).
- Page: https://claude.ai/artifact/4ZhZApXDVpMJT9EirmEHox (before/after GIFs + final video).
- Skills used: playthrough-video-review (enhancement: say "record at the END unless asked" — user stopped my up-front baseline), godot-speedrun-review. New: skills/godot-feedback-fanout.
- Would have helped: somewhat-useful-claude-skills:enumerate-the-pairs (callout × hit-word overlap matrix), derive-the-list (character stat tables).
- MCP: none used (godot-tests CLI equivalents). Open: autoplay_sweep `--base` with menu boot plays locked Robot as Cody; floating burst-hole decals in the park.

## 2026-10-04 — End card redo (presentation + juice through the CRT)
- CRT tunes in under the card (CRTOverlay.focus/FOCUS); breakdown cut to STREET/BOSS/BONUS, RANK tag gone, bigger type, 2-line ink rank hint, empty list places hidden, HUD fades out.
- Juice: rows drop in, ScoreTally count-up with rising coin ticks, stamp slam on last tick + card jolt + thud, hint fade, badge pop + power-up sound.
- 10 capture rounds (last at 1688x780); 851 unit, 12 sandbox, 17/17 autoplay; 12/12 mutants killed (+1 covered by exact-text test). Found: scanline moiré, empty-tween engine error (death card).
- Artifact: https://claude.ai/artifact/Asc6dfiNUQL2gGz52X8NoJ
- Skills used: juicy-screen-review (enhanced: CRT capture section), godot-headful-screenshot. Would have helped: somewhat-useful-claude-skills:godot-game-ui-juicy (count-up/stagger recipes), a checked-in end-card capture script (scratch again).
- MCP: none used.

## 2026-10-04 — Micro cut scenes (opening, The Arch + statue, City Council)
- New `scripts/cutscene/` (CutsceneShots table, MicroCutscene director, CaptionCard, StreetCutscenes trigger in main.tscn). Freeze fight not city; letterbox + comic caption; skip any button; once per session; only from the real front end.
- Street trigger waits for quiet (no enemy <700px, no door event) + 1s payoff beat; cut scene clears any banner (`BossBanner.GROUP`). User mid-run: arch must include the statue -> 3rd arch shot pushes in on it.
- Scout fix: door encounter `_is_alive(enemy: Node2D)` errored on freed enemies -> arena locked forever (test added). Autoplay waits through cut scenes, `cutscenes` metric, freeze not "stuck".
- 10 validation rounds (contact sheets, 1688x780 round, recorded natural run). 877 unit, 12 sandbox, 18/18 autoplay, 21/21 mutants killed.
- Artifact: https://claude.ai/artifact/FnL3wVVkynnXio8rwWJLJQ
- Skills used: none from the list invoked; followed repo skills godot-boss-juice, godot-time-scale-beat, godot-headful-screenshot, godot-autoplay-test (enhancement: autoplay-test should mention `contact_sheet.py` for snap review). New skill: skills/godot-micro-cutscene.
- Would have helped: playthrough-video-review (recording + reel), somewhat-useful-claude-skills:scope-vs-claim (the "grace" test passed on a skipped scene), derive-the-list (landmark positions from the scene, not hand-typed).
- MCP: none used directly (CLI equivalents); added `contact_sheet` tool to godot-tests MCP.

## 2026-10-04 — Cut scenes round 2 (story intro, floating fix, hold-to-skip)
- Floating: opening froze player + roof maid at spawn height (tree paused under the fade, then held before gravity). Now each body is held once landed; `Player.is_settled()` (grounded AND on spawn lane; `lanes_active()` is false on the landing frame — that hid a 48px drop at hand-back).
- Story screen retired: opening tells it in 4 captions over close-on-maids -> TICKET! popup on the car -> dolly to shop -> push-in. Character select -> controls splash; SKIP INTRO removed (user). Kicker "SIOUX FALLS, DOWNTOWN."; arch kicker "OVER THE BIG SIOUX..." (was "HALFWAY THERE", arch is ~80% along).
- Hold-to-skip (0.8s, ring prompt, armed after release) — user asked if scenes were too easy to skip.
- Validation: 4 intro rounds (one 1688x780) + skip prompt capture + recorded natural run. Mutants: landing 4/4 + settle (headless couldn't reproduce until the lanes_active bug was found), skip 6/6.
- Skills used: none via tool; repo skills godot-micro-cutscene (updated: hold-to-skip, settle rule, story captions), godot-autoplay-test. Would have helped: a "probe positions" helper (wrote 4 throwaway SceneTree probes — player from group, Player gets reparented so get_node("Player") is null).
- MCP: none used (CLI).
- Follow-up: opening's melee maids were authored 15-53px in the air (atomic_robot_area.tscn) -> authored at street level (y -28) right behind the red car (user: "like they're issuing a ticket"); enemies count as landed once their street baseline is captured (they rarely read is_on_floor()). New test: nothing in the opening's first shot falls (failed 53px on the old data). 883 unit, 18/18 autoplay, 12/12 sandbox. Merged to main via branch `cutscenes` (not pushed).

## 2026-10-04 — Jamcraft boot splash (branch lj-splash)
- `somewhat-useful-claude-skills:jamcraft-splash` pattern B (overlay on the title, like atomic-pinball's §11 splash): once per boot, any key/click/pad/tap skips and is swallowed, title anti-skip timer restarts at the reveal. Dropped the skill's `next_scene` mode (bypasses Transition; test_transition caught it); layer 99 under CRTOverlay (skill default 100 = CRT's layer).
- 10 new tests (test_title_splash.gd), 13/13 mutants killed (touch mutant survived until emulate_mouse_from_touch was turned off in the test). 893 unit, full_run + full_run_mortal PASS.
- Validation: --write-movie desktop round, 1688x780 window_set_size round, skip-at-0.35s round; no fixes needed.
- Skills used: jamcraft-splash (enhancement: warn that `next_scene` calls change_scene directly and layer 100 may collide with a post-process overlay; `--write-movie` ignores `--resolution`). Would have helped: none extra. MCP: none.
## 2026-10-04 — Static power-ups + roof heart (branch lj-pickups)
- PowerupPickup `placed` mode (no lifetime/blink, keeps parent, PowerupGlow halo + golden-angle twinkles, no global RNG). Placed in atomic_robot_building_group.tscn: Rage on the window building's upper ledge pier (590,-376), Overclock above the tall scaffold (1183,-112), RoofHeart over the AR Tattoo roof scaffold (-210,-306, glow so it doesn't read as a HUD orb).
- Autoplay: `powerups` metric, `teleport X [Y]`, snap step waits for its frame (same-frame teleport leaked into the picture), brain skips pickups beyond MAX_DY (ledge rewards could pin it). completionist routes collect all three; new placed_pickups.json.
- Balance (8 runs each): completionist 4.50 -> 6.25 power-ups/run, buff uptime 14.9% -> 20.2% (max 30%); bot full_run 4.5 -> 5.0 (no placed). Drop rate unchanged — far from the >50% "always buffed" failure; offsetting 2 optional rewards would need ~0.04 base chance (pity-driven).
- 10 validation rounds (one 1688x780). 901 unit, 19/19 autoplay, lane audit clean, 16/16 mutants killed.
- Skills used: none via tool; repo skills godot-autoplay-test (enhanced: powerups metric, teleport Y), godot-ab-worktree. New skill: skills/godot-level-pickups. Would have helped: somewhat-useful-claude-skills:godot-2d-placement-audit (numeric placement asserts), derive-the-list (placed pickup list from the scene).
- MCP: none used (CLI equivalents). No new MCP server (YAGNI: godot-tests already wraps autoplay).
## 2026-10-04 — Door cracks: wall breaches, bush bursts (branch lj-cracks)
- Every door mouth picks `mouth_style` per placement: 3 brick breaches (tinted rim + rubble, dust, chunk blast), 4 hedge mouths (shrub rustles, eyes peek, tears into halves over a dark hollow, leaf blast). 4721 moved off the window onto the brick pier at 0.75 scale. Secret walls get a chipped brick rim.
- Juice: shake ramps through the telegraph, 0.05s hitstop on burst, 0.18s beat before the first enemy, squad steps out of the mouth's shadow; arm_seconds 0.35 -> 0.6.
- 10 validation rounds (+1688x780), before/after crops + 2 GIFs. 896 unit, 12 sandbox, door_waves/secrets_cass/full_run/full_run_mortal pass, 24/24 mutants killed (3 survivors fixed with tests).
- Skills used: none via tool; repo skills godot-headful-screenshot, godot-hit-feel, godot-ab-worktree (enhancement: headful-screenshot should say "reimport after changing a PNG" — stale art cost a round). New skill: skills/godot-door-mouth.
- Would have helped: kenney-asset-kit (2D palette/measure for authoring into a set), derive-the-list (placement->style table derived from the scene), a "sample wall colour at x" probe.
- MCP: none used (CLI).
## 2026-10-04 — Ambient traffic (branch lj-cars)
- `Managers/AmbientTraffic`: one car per 15-30 s of open play, random road lane/direction/speed, 1.5 s edge-sign + off-screen engine telegraph, never two cars, paused in cut scenes / door-encounter locks, freed off screen, kept inside the end buildings. Car refactor: `launch()`, `road_y()`, direction, `rng`.
- Found: one extra global RNG draw alone flipped seeded full_run_mortal -> own RNG + `fixed_seed`. Touch buttons hid the world-space sign -> CanvasLayer 3.
- 905 unit, 2/2 mortal autoplay, 24-seed sweep, lane audit clean, 38/38 mutants killed (after 7 survivors -> new tests).
- Skills used: none via tool. Would have helped: somewhat-useful-claude-skills:extract-a-testable-seam (static rule funcs), derive-the-list (street bounds from the wall shapes), playthrough-video-review (natural-route video). New repo skill: skills/godot-rare-spawner. Enhancement idea for godot-autoplay-test: document `autoplay_sweep.py --base` for balance-noise checks.
- MCP: none used (CLI equivalents).
## 2026-10-04 — Orchestrator: level juice fan-out (branch level-juice)
- 5 worktree agents (pickups, cracks, bubble, cars, splash) merged into `level-juice`; conflicts only log.md + autoplay report/sweep metric columns (kept both).
- Post-merge bug: splash `await get_tree().process_frame` after leaving the tree -> 14/19 autoplay FAIL; fixed (hold tree ref + is_inside_tree) with a red-first test.
- "Meter maid talking over a tree" was the heart atom drawn behind a tree (z), not a speech bubble.
- Skills used: jamcraft-splash (via agent; enhancement: guard awaits for a node freed by a scene change on frame 1), godot-feedback-fanout (enhancement: say "agents run the whole autoplay suite"). New: tools/level_pan.py + MCP `level_pan` + skills/godot-level-map (screenshot -> world x). Would have helped: godot-level-map (now exists), derive-the-list.
- MCP: godot-tests (extended with level_pan).
- Follow-up (user screenshot images/image.png): ledge platform maid walked into Tree9's canopy (x 2287) — the real "maid over a tree" bug; the heart z fix was a second, separate issue. PlatformPatrolState turns at foliage (trees group); 4 tests incl. real-physics maid, 4/4 mutants killed. 954 unit, 19/19 autoplay, 12/12 sandbox.
- Lesson: an agent "explained" a player report with the first plausible match (heart z); ask for/locate the exact spot before closing a bug report.
## 2026-10-04 — Playthrough review round 3 (main cd9521b)
- Catalogue agent → route covers all reachable items; gaps: wall A unreachable, no cutscene/unlock/placed-pickup asserts, 7/9 heals (door 7775 heart never taken).
- Recorded completionist_mortal: take 1 died at 1:04 (scripted walk_to can't fight a late maid), take 2 won A 15,122, 4:21. Sweep 5 fighters × 4 seeds: 20/20 wins, Cody 7–14 hits vs 14–23, Sara == Caitlyn.
- Artifact https://claude.ai/artifact/ExkNpGwY4VsaokPtqvLfyr: 13 open cards (9 new, 4 carried), 2 shipped, R3/R2 video tabs, db `decisions`.
- Skills used: playthrough-video-review (enhancement: say "retry a died recording once before rerouting" and give the bitrate-from-length formula), artifact-capabilities, artifact-design. Repo skill godot-speedrun-review updated (bitrate formula, recorded-death gotcha, sweep command, server-side video copy).
- Would have helped: somewhat-useful-claude-skills:derive-the-list (route asserts from the catalogue), scope-vs-claim (completionist "100%" claim vs asserts).
- MCP: none used (CLI equivalents of godot-tests). No new MCP server (YAGNI: record_autoplay/contact_sheet exist).

## 2026-10-04 — pickup FX consistency
- Useful skills: none listed fit directly; `derive-the-list` (heart list from levels — applied by hand), `godot-level-pickups` (pickup placement context).
- Wished-for skill: `godot-pickup-fx` (written) — one glow/burst rule for every collectible.
- Gate: 958 unit, 19 autoplay, 12 sandbox, lane audit clean.
## 2026-10-04 — Review round 3 fixes (branch review3-fixes)
- Approved: intersection cars get the ambient edge sign (shared `CarWarning`, extracted from AmbientTraffic), drive in off screen, and use the player's lane (sidewalk -> lane 1). End card hint is one line ("FIND 4 MORE SECRETS FOR B" / "+3,857 FOR A (15,000)").
- Player report (images/image.png): BG1 ledge maid walked through Lamp2 (x 2572). `PlatformPatrolState` turns at `patrol_blockers` (trees + new lamp.gd). Real-level probe: x range 2354..2782 before, 2604..2782 after.
- Found: a typed `track(car: Car)` param errored on a freed car (34k script errors in 9 autoplay scenarios) -> untyped. Another session fast-forwarded newspaper-juice into this branch mid-task; reimport fixed its stale class cache.
- 970/970 unit, 19/19 autoplay, 12/12 sandbox, lane audit clean, 9 mutants: 8 killed + 1 equivalent; the 1 real survivor (parked car) got a test.
- Skills used: none via tool (repo skills godot-autoplay-test, godot-input-test patterns). Would have helped: somewhat-useful-claude-skills:derive-the-list (blockers from the dump), extract-a-testable-seam (track() seam). MCP: none (CLI). No new MCP/skill (YAGNI; CLAUDE.md note instead).
## 2026-10-04 - Modal newspaper (CRT readability)
- Used: artifact-capabilities (approval page with db picks) - idea: show a copy-approval template.
- Used: skills/godot-micro-cutscene (validation recipe), godot-input-test (polled input, mutants) - idea: input-test should warn that headless GUI clicks don't reach Controls; use `_input`.
- Would have helped: godot-modal-reader (written now) - pause/arm/CRT/autoplay rules for readable pop-ups.
- Would have helped: a "copy approval" skill - any player-facing text change goes to the user first.
## 2026-10-04 — Car over same-lane player; select "tap again" (branch review3-fixes)
- Car z was mid-band = player's z standing on the lane line -> tie -> tree order drew player over car. New `Lanes.vehicle_z` = top of lane band (+14 < stride 20). Before/after windowed autoplay, same seed.
- Select: Button `pressed` fires on release; viewport focuses on press, so the 2-frame `just_focused()` window expired on a normal tap -> first tap picked / tapping another card picked. Now arm = focus owner when the tap BEGAN (`_input`), plus a tap off the strip (prompt/big fighter) picks the preview.
- Old test faked taps with `pressed.emit()`; new `_tap` pushes ScreenTouch + emulated click via `root.push_input(ev, true)` (headless window 0x0 drops parse_input_event GUI touches).
- Skills: repo godot-input-test (fixed its bad "emit pressed" advice), godot-ab-worktree pattern (stash variant). Would have helped: somewhat-useful-claude-skills:enumerate-the-pairs (z vs every depth), extract-a-testable-seam. MCP: none used (CLI); no new MCP (YAGNI — autoplay covers it).
- Follow-up: secret wall prompt ("[interact] GRAB ORB", gold 12px, bobbing, code-built style + level override "[e]") now matches the newspaper stand: shared `styles/interact_prompt.tres`, plain "[interact]", static. `test_interact_prompt.gd` derives every InteractLabel from scenes/*.tscn (defs + overrides + live); 4/4 mutants killed.

## 2026-10-04 — itch store page refresh + first devlog draft
- Used: itch-store-page (screens replaced, description simplified w/ shop address + IG, gallery set to sidebar), itch-devlog (draft 1691562).
- Enhancement idea (itch-store-page): split the "poll until ids appear" loop into short evaluates — one 45s loop froze CDP though the upload landed.
- Enhancement idea (itch-devlog): note the "first devlog ever" case — no last-post date, so pick a 2-week window.
- Would have helped: a `store-shots` skill — run completionist bot with `snap_every`, contact sheet, pick 6.

## 2026-10-04 — YouTube Short style pilot (not committed)
- One god-mode Cody take (worktree wt-shorts @ e49e6af) -> 6 cuts, 5 review rounds; final `autoplay_out/shorts/v6.mp4` (21.9 s, 1080x1920).
- Would have helped: skills/godot-speedrun-review (recording recipe, used), playthrough-video-review (frame review). Enhancement idea (speedrun-review): note video time == game time so event `t` indexes footage.
- Written now: skills/godot-youtube-shorts (build_short.py, review_short.py, example_spec.py). MCP: none used/new (YAGNI — scripts suffice).
- Follow-up: copy rework v7 — user isn't the shop (no "we"), "hate this guy" too harsh -> feature-led lines. Skill/memory updated with the copy rule.
## 2026-10-04 — Ship (main d197687, itch deploy green)
- First push blocked by CI: 3 `res://Sounds/` preloads (folder is `sounds/`) — Windows-only green, 66 Linux fails. Fixed + `test_res_path_case.gd` guard.
- Would have helped: somewhat-useful-claude-skills:itch-ci-deploy (CI-only failure triage) — idea: list "case-sensitive res:// paths" as a top symptom.
- Follow-up 2: user: footage too "perfect run". Worktree-only patch (skills/godot-youtube-shorts/human_footage.patch): human-bot's human_style + whiffs/late reactions, god takes hits (HP floor 1). Re-recorded; v8-v10 (car hits, boss down to 1 HP comeback). Would have helped: human-bot merged to main (still unmerged, conflicts with heal logic).
- Follow-up 3: ending recut (v12) — no boss spoiler; Atomic Rage + Overclock clips with what-they-do captions, title-screen end card. Landscape-video skill delegated to a subagent.
- Follow-up 4: character select + intro cut scene short (uncropped, narration subtitles), 3 rounds; delivered as artifact https://claude.ai/artifact/2usPSFmGBcoJEv714tL6H2 (downloads capability).

## 2026-10-04 — Landscape YouTube video skill (not committed)
- New `skills/godot-youtube-video/` (build_video.py, review_video.py with YouTube safe zones + end-screen boxes, example_spec.py). Extracted shared `skills/godot-youtube-shorts/ffx.py` (review_short uses it; build_short refactor was MD5-identical but a parallel session overwrote it, so it is left as a TODO).
- 7 builds / 4 review rounds -> `autoplay_out/videos/highlight_sample.mp4` (38.2 s, 1920x1080 60 fps).
- Used: godot-youtube-shorts (reused scripts + copy rules). Enhancement idea: ship a `beats.py` that prints kill/hurt/powerup events from the report, so you don't have to rewrite the one-liner.
- Would have helped: playthrough-video-review (frame-review loop), godot-speedrun-review (footage recipe). MCP: none used or new (YAGNI: ffmpeg scripts are enough).

## 2026-10-04 — character select TAP AGAIN unclickable
- Used: none. Would help: `godot-input-test` (read earlier; now notes root hit-test gap), a "windowed input probe" MCP tool (push a real click/touch at a node in a 1280x800 window, report who ate it).
- Follow-up 5: fighters + Arch short (ch1-ch5, 3 rounds x 2 fixes); artifact https://claude.ai/artifact/UWX26fSWTyfA52GQSfuqXZ
- Follow-up 6: user: cut flashes look terrible -> removed all white flashes (ch6), artifact republished.

## 2026-10-04 — player on wall ledge drew over sidewalk tree (x~2287)
- Fix: `Lanes.RAISED_Z`/`on_raised_floor`; Player + enemy mover draw at z 0 when standing on raised ground. Test `test_raised_draw_order.gd`. Gate green (1039 unit, 19 autoplay, 12 sandbox, lane audit).
- Used: godot-level-map (spot lookup). Enhancement: note that `teleport` keeps the lane, so snap needs `lane 0` first.
- Would have helped: godot-draw-order (written now), godot-ab-worktree (A/B done by flipping a const instead). MCP: none new (godot-tests covers it).

## 2026-10-04 pi-game-deploy (Atomic Robot to Picade)
- pi-game-deploy (used): deploy + debug loop. Enhancement: warn that Godot games need cabinet keys in input defaults; reuse existing port name; pkill -f self-kill trap (added to Gotchas).
- derive-the-list: Picade test loops InputRemap.ACTIONS, not a hand list.
- Missing skill: none needed beyond the above gotchas.
- Follow-up: proof artifact https://claude.ai/artifact/BHTQSz5YKRyh485tMW5rH4 (before 788dc71 vs after 6e6a783, ledge + street GIFs). Used godot-ab-worktree (enhancement: say door waves must be cleared before recording, banners cover the subject). Ledge at x 2230-2430, y -83.

## 2026-10-04 — end card not joystick friendly (stuck after pause)
- Bug: Start/Esc pause on game-over/win card -> pause slider took focus, hid on resume -> focus none, stick dead. Fix: `EndCard._process` re-grabs RESTART when focus is off its buttons. Tests `test_*_stick_works_after_pause`.
- Used: none from list. Would have helped: godot-input-test (notes pause/resume focus theft now). MCP: godot-tests covers gate.
