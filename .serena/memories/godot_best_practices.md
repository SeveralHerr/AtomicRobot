# Godot Best Practices and Guidelines

## Development Principles

### Always Reference Godot Documentation
- **Official Docs**: https://docs.godotengine.org/
- **GDScript Style Guide**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- **Best Practices**: https://docs.godotengine.org/en/stable/tutorials/best_practices/
- Check documentation for current Godot 4.x best practices before implementing features

### Code Organization
- Use `class_name` for reusable components
- Prefer composition over inheritance
- Use signals for loose coupling between nodes
- Keep scripts focused and single-responsibility

### Performance Guidelines
- Use `@onready` for node references to avoid repeated `get_node()` calls
- Prefer `_ready()` over `_init()` for most initialization
- Use object pools for frequently instantiated objects (bullets, effects)
- Cache expensive calculations and node references

### Scene Structure
- Keep scenes modular and reusable
- Use groups for categorizing nodes
- Prefer scene instantiation over code-based node creation
- Use `PackedScene.instantiate()` for dynamic object creation

### State Management
- Use signals for global state changes
- Autoload singletons for truly global data only
- Consider using the Observer pattern for complex state dependencies
- Document state transitions clearly

### Input Handling
- Use Input Map for configurable controls
- Handle input in appropriate nodes (UI in Control nodes, gameplay in game nodes)
- Use `_unhandled_input()` for global inputs
- Consider mobile/touch input requirements

### Resource Management
- Use `preload()` for resources needed at compile time
- Use `load()` for dynamic resource loading
- Implement proper resource cleanup
- Use ResourceUID for stable resource references

### Debugging and Development
- Use print statements judiciously (remove in production)
- Leverage Godot's debugger and remote inspector
- Use breakpoints and step debugging
- Monitor performance with built-in profiler

### Version Control
- Include `.godot/` in .gitignore (already configured)
- Commit `.import` files for proper asset handling
- Use meaningful commit messages for scene and script changes

## Project-Specific Considerations
- This project uses Godot 4.4 - ensure compatibility with current version
- State machine pattern is well-implemented - follow existing patterns
- Global singletons are appropriately used - don't add unnecessary ones
- Physics layers are well-defined - respect existing collision setup