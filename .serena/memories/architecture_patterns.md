# Architecture Patterns and Design

## State Machine Architecture
The game heavily relies on a state machine pattern for behavior control:

### Base Classes
- `scripts/states/state.gd` - Base state class
- `scripts/states/state_machine.gd` - State machine controller

### Player States
- idle, run, jump, fall, attack, crouch, climb, knockback, dead
- Located in `scripts/states/` directory

### Enemy States  
- patrol, chase_player, attack_player, find_meter, dead
- Separate state classes for different enemy types (melee, ranged, platform patrol)

## Global Singleton Pattern
Global singletons are autoloaded in project.godot:

- **Globals**: Core game state, character management, progress tracking
- **Utils**: Utility functions and screen effects
- **AudioManager**: Sound and music management
- **EnemySpawner**: Enemy lifecycle management
- **ScreenShake**: Screen shake effects
- **ChatBubble**: Dialog system
- **LeafSystem**: Environmental particle effects

## Character System
Character switching managed through `Globals.character_dict` with:
- Robot (default Atomic Robot mascot)
- Cody (Shop owner)
- Ryan (Employee)

Each character has associated sprite frames and unlock conditions.

## Signal System
Global event communication via signals:
- `player_death`, `meter_maid_death`, `meter_maid_boss_death`
- `unlocked(name, description)` for progression
- `boss_fight(status)`, `event(status)`, `newspaper(status)`

## Physics Configuration
- Viewport: 1280x800 with canvas item stretching
- Physics layers: Player (1), Ground (2), Enemy (3), Platforms (6), Wall (7)
- Input: WASD + Arrow keys, F (Attack), E (Interact), Shift (Run)