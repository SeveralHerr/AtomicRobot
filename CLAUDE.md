# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment (this machine)

- Godot **4.7.1** is NOT on PATH. Use the full path:
  `C:\Users\gotmi\Downloads\Godot_v4.7.1_fixed\Godot_v4.7.1-stable_win64_console.exe`
  (use the `_console` build for `--headless` runs so output reaches the shell). Treat
  `godot` in any command below as an alias for that path. Older 4.5.1/4.6.1 builds
  also sit in `Downloads\` — don't use them, the project targets 4.7.
- Python 3.12 is installed user-scope (`python`, not `python3`). If a shell can't find
  it, it lives at `%LOCALAPPDATA%\Programs\Python\Python312\python.exe`.
- After pulling changes that touch images/resources, run
  `godot --headless --path . --import` once to refresh the import/UID cache.
- If lint reports `uid mismatch` errors (stale `uid://` refs after reimports), run
  `godot --headless --path . --script res://tools/fix_uids.gd` to rewrite them.

## Development Commands

**Running the Game:**

- Open project in Godot editor and press F5 to run
- Command line: `godot --path .` (add `--mute` for automated runs)

**Testing:**

- `godot --headless --path . --script res://tools/run_tests.gd` (add `-- --filter NAME`
  to run only matching test methods). Exit 0 pass, 1 fail, 2 broken test script.
- Tests live in `test/unit/test_*.gd`; see `test/unit/test_example.gd` for the contract.
- Gameplay: `python tools/run_sandbox_selftests.py` boots each `test/scenes/*.tscn`
  sandbox headless for ~5s of real physics and asserts on sampled enemy behaviour
  (see `test/scenes/README.md`). For a player feature, write a unit test that loads
  the real scene and steps frames with `Input.action_press` (`test_crouch_input.gd`).
- Self-test by playing: `python tools/autoplay.py` runs bot scenarios (`test/autoplay/*.json`)
  — `full_run` plays title screen to YOU WIN. Add `--window` for screenshots. Prints a
  short summary; detail in `autoplay_out/<name>.json`. See `skills/godot-autoplay-test/SKILL.md`.
- CI runs both before every itch.io deploy; a failure blocks the ship.

**Exporting:**

- Web: `godot --export-release "Web" bin/index.html`
- Windows: `godot --export-release "Windows Desktop" path/to/output.exe`


## Deep-dive docs (read these before non-trivial changes)

- `docs/ARCHITECTURE.md` — scene flow, autoloads, signals, player/enemy state machines,
  characters, physics layers, known quirks
- `docs/LEVELS.md` — how main.tscn/boss_room are structured, where ground collision
  actually lives (TileSet physics layers), how to inspect/edit tilemaps
- `docs/LANE_REFACTOR.md` — planned TMNT-style multi-lane movement: complete catalogue
  of single-ground-plane assumptions to change, plus pre-existing bugs to fix first
- `tools/dump_level.gd` — headless JSON dump of any scene's geometry:
  `godot --headless --path . --script res://tools/dump_level.gd -- --scene res://scenes/main.tscn --out dump.json`

## Architecture Overview

### State Machine Architecture

The game uses a comprehensive state machine pattern for both player and enemy behavior:

- **Base Classes**: `scripts/states/state.gd` and `scripts/states/state_machine.gd`
- **Player States**: idle, run, jump, fall, attack, crouch, climb, knockback, dead
- **Enemy States**: patrol, chase_player, attack_player, find_meter, dead

### Global Singletons (Autoloaded)

These are globally accessible throughout the game:

- **Globals**: Core game state, character management, global signals, progress tracking
- **Utils**: Utility functions and screen effects
- **AudioManager**: Sound and music management
- **EnemySpawner**: Enemy lifecycle management
- **ScreenShake**: Screen shake effects
- **ChatBubble**: Dialog system

### Character System

Character switching is managed through `Globals.character_dict` with unlockable characters:

- Robot (Atomic Robot mascot)
- Cody (Shop owner)
- Ryan (Employee)

Each character has associated sprite frames and unlock conditions.

### Game State Management

`Globals.gd` tracks:

- Current selected character
- Player position and health
- Meter maid kill counts
- Boss fight status
- Destroyed nodes persistence
- Global event states

### Signal System

Global signals for major game events:

- `player_death`, `meter_maid_death`, `meter_maid_boss_death`
- `unlocked(name, description)` for character/feature unlocks
- `boss_fight(status)`, `event(status)`, `newspaper(status)`

### Physics Configuration

- Viewport: 1280x800 with canvas item stretching
- Physics layers: Player (1), Ground (2), Enemy (3), Platforms (6), Wall (7)
- Input: WASD + Arrow keys, F (Attack), E (Interact), Shift (Run), C (Crouch)

## Key Development Notes

### State Transitions

When working with player/enemy behavior, states are managed through the StateMachine class. State changes are logged to console for debugging.

### Node Destruction Persistence

The game tracks destroyed objects via `Globals.destroyed_nodes` to maintain state across scene reloads.

### Bug Tracking

Current known issues are tracked in README.md including character highlighting bugs, collision issues, and health system problems.

### Mobile Support

Virtual joystick addon is included in `addons/virtual_joystick/` for mobile/web builds.

### Asset Organization

- `sprites/`: Character animations and UI elements
- `Tiles/`: Environment tilesets and backgrounds
- `Sounds/`: Audio files with Godot import settings
- `scenes/`: Game objects and level scenes
- `scripts/`: All GDScript code organized by function



## Logging

- **Skills log**: At the end of every response, append an entry to `log.md` (create it if missing) listing any skills — from the available skills list for that session — that might have been useful for the task or would have been useful had they existed, each with a short (few-word) reason why. If none would have helped, note that briefly instead of skipping the entry. If a skill was actually used, also note a simple-words enhancement idea for it.


# Agent Instructions

Always read @AGENTS.md

Always reply to me in information dense bullets.
Favor YAGNI.
Favor LEAN and Elimination of LEAN deadly wastes.
Always create the below checklist for every prompt:

## Checklist Manifesto

Always use your checklist or todo list tool to track items. Do not leave it to chance that you will remember later.
Immediately before implementing any prompts set up the following tasks as a checklist.

- Preparatory Unit Test Coverage
- Make it easy to change (which may be hard) (refactoring)
- Make the easy change
- Security Review
- Scout Rule
- Single Loop Learning
- Double Loop Learning
- Validation Loop
- Canary


## Preparatory Unit Test Coverage

Ensure the area that will be changed has approrpriate characterization tests making it safe to refactor.
Ensure characterization tests pass before starting any refactoring.
Prove a new bug test can fail: `git stash push <fixed file>`, run with `--filter`, `git stash pop`.

## Make it easy to change (which may be hard)

Refactor to common computer science grounded design patterns.
The resulting code should be easy to read, limited in file length, appropriately decoupled, and cohesive.

## Make the easy change

Complete the prompt considering YAGNI and DRY concepts in software development.

## Security Review

Evaluate for common OWASP pitfalls.
Run automated audits like pip audit, npm audit and correct package issues.
Evaluate for harder to detect problems with the system such as IDOR vulnerabilities.

## Scout Rule

Always leave the code better than you found it. Perform one of the following in priority order each time a prompt leads you to this area of the code.

- Evaluate Code Coverage and add more complete tests
- File length gate, reduce the file length of the files when over 500 lines by refactoring
- Mutation testing, use a analysis tool to perform mutant hunting on the modified files. For example Cosmic Ray in Python or Striker in Angular.

## Single Loop Learning

Learn from the tasks you complete:
Always end all of our chats with a list of skills that you used.
Always create new skills in this repo's skills folder that you wish you had before starting the prompt. Actually write the file now.
Always end all of our chats with a list of MCP servers that you used.
Always create new MCP servers that you wish you had before starting the prompt. Actually write the server now. Enable it when complete.

## Double Loop Learning

Learn from the process improvement opportunities:
Always evaluate the the process used here using a lens of Lean Software Development, Agile, Systems Thinking, Safety, Security, and Continuous Improvement.
Always make the changes to the AGENTS.md with these changes. Update this very list you are reading now.

## Validation Loop 

When doing an iteration or feature, take a screenshot and look for 3 things to improve. Do this 10 times. 
Batch it: one throwaway SceneTree script captures every state of the feature per round,
plus a `--resolution 1688x780` (landscape phone) round; review a PIL contact sheet.
Drive the REAL flow (emit the real signal, e.g. `Globals.boss_death`) — calling an inner
method directly skipped the Win overlay and hid a sequencing check.

## Sibling-game conventions

This game shares the arcade cabinet with `../atomic-pinball`. Before building any
menu/end screen, check how pinball does it and match it (look, flow, input rules).
Integrate new UI into the existing screen; never layer a second overlay over an old one.

## Input-driven features

Read `skills/godot-input-test/SKILL.md` before testing pad/key/touch UI. Mutation-check
new guards with a `(file, original, mutant, filter)` script; add a test per survivor.
The `godot-tests` MCP server (`.mcp.json`) runs the unit/sandbox suites with a short summary.

## Canary

Always end all of our chats with "# 🪁" Emoji. It should render as a markdown header so the Emoji will be large.
