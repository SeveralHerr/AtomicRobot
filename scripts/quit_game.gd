class_name QuitGame

## Shared "leave the game" logic for every screen with an EXIT/QUIT button (pause
## menu, Game Over, character select).

const EXIT_TEXT := "Exit Game"


## Desktop builds can always quit. On the web only the arcade kiosk can: its launcher
## opens the game with ?exit=1 in a one-tab window that window.close() is allowed to
## shut. An itch.io embed ignores window.close(), so the button stays hidden there.
static func can_quit(on_web: bool, query: String) -> bool:
	return not on_web or "exit=1" in query.trim_prefix("?").split("&")


static func available() -> bool:
	return can_quit(OS.has_feature("web"), web_query())


static func web_query() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("window.location.search"))


static func quit(tree: SceneTree) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.close()")
	else:
		tree.quit()


## Add an "Exit Game" button styled like `template`, right after it in its parent.
static func add_button_after(template: Button, on_press: Callable) -> Button:
	var button := template.duplicate(Node.DUPLICATE_GROUPS) as Button
	button.disabled = false
	template.add_sibling(button)
	return wire(button, on_press)


## Turn `button` into the exit button. `on_press` runs when pressed (screens pass a
## swappable Callable so tests can press it without ending the run). Hidden where
## quitting is impossible.
static func wire(button: Button, on_press: Callable) -> Button:
	button.name = "ExitButton"
	button.text = EXIT_TEXT
	button.pressed.connect(func() -> void: on_press.call())
	button.visible = available()
	return button
