# Code Style and Conventions

## GDScript Conventions
Based on analysis of existing codebase:

### Naming Conventions
- **Classes**: PascalCase (e.g., `StateMachine`, `Player`)
- **Variables**: snake_case (e.g., `current_state`, `meter_maids_killed`)
- **Constants**: SCREAMING_SNAKE_CASE (e.g., `JUMP_VELOCITY`, `FRICTION`)
- **Functions**: snake_case (e.g., `change_state`, `handle_input`)
- **Signals**: snake_case (e.g., `player_health_updated`)

### File Organization
- Scripts organized by functionality in `scripts/` directory
- Autoload scripts in `scripts/autoload/`
- State machine scripts in `scripts/states/`
- Scene files (.tscn) in `scenes/` directory
- Sprites and assets in respective directories (`sprites/`, `sounds/`, etc.)

### Code Patterns
- Extensive use of `@onready` for node references
- Class_name declarations for reusable components
- Signal-based communication between systems
- State pattern implementation with enter/exit methods
- Preload for resource references

### Project Structure
```
├── addons/           # Third-party addons (virtual joystick)
├── scenes/           # .tscn scene files
├── scripts/          # All GDScript files
│   ├── autoload/     # Global singleton scripts
│   └── states/       # State machine implementations
├── sprites/          # Character and UI sprites
├── sounds/           # Audio files
├── tiles/            # Tileset resources
└── styles/           # UI themes and styles
```

### Documentation
- Minimal inline comments in existing code
- No formal documentation generation
- CLAUDE.md contains development instructions