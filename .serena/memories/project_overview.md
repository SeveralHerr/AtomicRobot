# AtomicRobot Project Overview

## Purpose
AtomicRobot is a 2D side-scrolling action game built in Godot 4.4. The game features a character named Atomic Robot navigating through an urban environment, fighting meter maids and other enemies. The game includes character switching mechanics, a state-based AI system, and boss fights.

## Tech Stack
- **Engine**: Godot 4.4
- **Language**: GDScript
- **Graphics**: 2D sprites with animation
- **Physics**: Godot's built-in 2D physics system
- **Audio**: Built-in AudioManager system
- **Target Platforms**: Web, Windows Desktop (with mobile/touch support via virtual joystick addon)

## Key Features
- Character switching system with unlockable characters (Robot, Cody, Ryan)
- State machine architecture for both player and enemy AI
- Global singleton pattern for game management
- Enemy spawning and management system
- Persistent world state tracking
- Boss fight mechanics
- Mobile/touch input support

## Architecture
The game uses a comprehensive singleton-based architecture with global state management and a robust state machine system for character and enemy behavior control.