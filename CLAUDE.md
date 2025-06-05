# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

**Running the Game:**
- Open project in Godot editor and press F5 to run
- For command line: `godot --main-pack` (from project directory)

**Exporting:**
- Web: `godot --export-release "Web" bin/index.html`
- Windows: `godot --export-release "Windows Desktop" path/to/output.exe`

**No formal build system, testing framework, or linting tools are configured.**

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
- Input: WASD + Arrow keys, F (Attack), E (Interact), Shift (Run)

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
- `Sprites/`: Character animations and UI elements
- `Tiles/`: Environment tilesets and backgrounds  
- `Sounds/`: Audio files with Godot import settings
- `scenes/`: Game objects and level scenes
- `scripts/`: All GDScript code organized by function