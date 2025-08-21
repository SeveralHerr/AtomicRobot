# Task Completion Checklist

## When a Task is Completed

### Testing
- **Manual Testing**: Test in Godot editor by pressing F5
- **No automated tests** are configured in this project
- Verify functionality works as expected in-game
- Test on different characters if character-specific changes were made

### Code Quality
- **No linting tools** available - rely on Godot editor error checking
- **No formatting tools** configured
- Ensure code follows existing patterns and conventions
- Check Godot editor for any errors/warnings (shows in bottom panel)

### Build Verification  
- **No formal build process** required for development
- For release testing:
  ```bash
  # Test web export
  godot --export-release "Web" bin/index.html
  ```

### Documentation
- Update CLAUDE.md if architecture changes were made
- No other documentation requirements

### Git Workflow
- Commit changes with descriptive messages
- No specific branch requirements (uses main branch)
- Current status shows modified sprite and scene files

### Deployment
- **No CI/CD pipeline** configured  
- Manual export required for releases
- Web builds export to `bin/` directory

## Important Notes
- This project has minimal tooling - most verification is manual
- Primary verification is running the game in Godot editor
- Focus on ensuring code follows existing patterns and doesn't break game functionality
- Check console output for state machine transitions and errors during gameplay