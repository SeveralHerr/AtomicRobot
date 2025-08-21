# Suggested Commands

## Development Commands

### Running the Game
```bash
# Primary method - Open in Godot editor and press F5
godot --editor

# Command line execution (from project directory)
godot --main-pack
```

### Exporting Builds
```bash
# Web export
godot --export-release "Web" bin/index.html

# Windows Desktop export  
godot --export-release "Windows Desktop" path/to/output.exe
```

### Project Management
```bash
# Open project in Godot editor
godot project.godot

# Run specific scene
godot --main-scene scenes/main.tscn
```

## System Commands (Linux/WSL)
```bash
# File operations
ls -la           # List files
find . -name "*.gd"  # Find GDScript files
grep -r "pattern" scripts/  # Search in scripts

# Git operations
git status
git add .
git commit -m "message"
git push
```

## No Formal Build Tools
- **No package manager** (npm, pip, etc.)
- **No testing framework** configured
- **No linting/formatting tools** available
- **No CI/CD** setup

## Key Project Files
- `project.godot` - Main project configuration
- `export_presets.cfg` - Export settings for different platforms
- `CLAUDE.md` - Development instructions and architecture notes
- `README.md` - Bug tracking and notes