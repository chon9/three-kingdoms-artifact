extends "res://scripts/ui/modal_panel.gd"
## The in-match menu (top-right button or Esc): resume, log, save or load a
## replay, decks, settings, Steam, new match (offline) or leave the room
## (online), concede, main menu and quit.

signal selected(action: String)

const ITEMS = [["resume", "MENU_RESUME"], ["log", "MENU_LOG"], ["save", "MENU_SAVE_REPLAY"],
	["replays", "MENU_LOAD_REPLAY"], ["decks", "MENU_DECKS"], ["settings", "MENU_SETTINGS"],
	["steam", "MENU_STEAM"], ["new", "MENU_NEW_MATCH"], ["leave", "MENU_LEAVE_LOBBY"], ["concede", "MENU_CONCEDE"],
	["menu", "MENU_MAIN_MENU"], ["quit", "MENU_QUIT"]]

var buttons: Dictionary = {}
var disabled_actions: Array = []
## Actions not offered at all ("new" online, "leave" offline).
var hidden_actions: Array = []

func _init() -> void:
	super()
	title_key = "MENU_TITLE"
	panel_size = Vector2(420, 760)

func build() -> void:
	close_button.visible = false
	for item in ITEMS:
		var action = str(item[0])
		var entry = button(body, "", 21)
		entry.name = action.capitalize()
		entry.custom_minimum_size = Vector2(0, 46)
		entry.disabled = action in disabled_actions
		entry.visible = action not in hidden_actions
		entry.pressed.connect(func():
			selected.emit(action)
			close())
		buttons[action] = entry

func refresh_text() -> void:
	super()
	for item in ITEMS:
		buttons[item[0]].text = UiKit.t(item[1])
