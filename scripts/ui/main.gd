extends Control
## Application root: owns the match controller, switches between the main
## menu and the match screen, opens dialogs, applies settings live (language
## and card theme re-render everything) and exposes a small facade used by
## tests/ui_smoke.gd and tests/capture_preview.gd.

const MatchController = preload("res://scripts/game/match_controller.gd")
const MatchScreen = preload("res://scripts/ui/match_screen.gd")
const MainMenu = preload("res://scripts/ui/main_menu.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")
const SettingsDialog = preload("res://scripts/ui/settings_dialog.gd")
const DecksDialog = preload("res://scripts/ui/decks_dialog.gd")
const DeckListDialog = preload("res://scripts/ui/deck_list_dialog.gd")
const DeckBuilderDialog = preload("res://scripts/ui/deck_builder_dialog.gd")
const DeckStore = preload("res://scripts/core/deck_store.gd")
const CatalogDialog = preload("res://scripts/ui/catalog_dialog.gd")
const ReplaysDialog = preload("res://scripts/ui/replays_dialog.gd")
const SteamDialog = preload("res://scripts/ui/steam_dialog.gd")
const MatchMenu = preload("res://scripts/ui/match_menu.gd")
const ConfirmDialog = preload("res://scripts/ui/confirm_dialog.gd")

var controller: Node
var screen: Control
var menu: Control
var dialog_layer: Control
var sfx: Node

## Facade: the live engine, bot timer, mode and players of the controller.
var engine:
	get:
		return controller.engine
var bot_timer: Timer:
	get:
		return controller.bot_timer
var mode: int:
	get:
		return controller.mode
	set(value):
		controller.mode = value
var local_player: int:
	get:
		return controller.local_player
	set(value):
		controller.local_player = value
var deck_selections: Array:
	get:
		return controller.deck_selections
	set(value):
		controller.deck_selections = value

func _init() -> void:
	theme = UiKit.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	controller = MatchController.new()
	controller.name = "MatchController"
	add_child(controller)
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	screen = MatchScreen.new()
	screen.name = "MatchScreen"
	screen.visible = false
	screen.sfx = sfx
	add_child(screen)
	menu = MainMenu.new()
	menu.name = "MainMenu"
	add_child(menu)
	dialog_layer = Control.new()
	dialog_layer.name = "Dialogs"
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialog_layer)

func _ready() -> void:
	Settings.load_settings()
	UiKit.add_system_fallback()
	# The decks chosen last time (an own deck as it is stored now).
	controller.deck_selections = DeckStore.load_choices(controller.deck_selections, controller.library)
	AnimationQueue.speed = Settings.animation_speed
	for node in [screen, menu, dialog_layer]:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.bind(controller)
	screen.input_blocked = func() -> bool: return dialog_layer.get_child_count() > 0
	screen.menu_requested.connect(open_menu)
	screen.game_over_action.connect(_on_game_over_action)
	menu.action_requested.connect(_on_menu_action)
	controller.match_started.connect(_on_match_started)
	controller.online_ended.connect(_on_online_ended)
	controller.online_join_started.connect(_on_online_join_started)
	menu.set_can_resume(false)
	show_main_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_text()

# --- Screens -------------------------------------------------------------------

func show_main_menu() -> void:
	controller.bot_timer.stop()
	screen.visible = false
	menu.visible = true
	menu.set_can_resume(controller.started and not controller.is_finished())
	menu.refresh_text()

func show_match() -> void:
	menu.visible = false
	screen.visible = true
	controller.schedule_bot()

## Starts a match in `new_mode` (MatchController.MODE_*); returns the result.
func start_match(new_mode: int = MatchController.MODE_AI) -> Dictionary:
	close_dialogs()
	var result = controller.start_match(new_mode)
	if result.get("ok", false):
		show_match()
	return result

func _on_match_started() -> void:
	close_dialogs()
	screen.reset()
	show_match()

## The online session ended (host left, Steam closed, we left): back to the
## menu with the Steam dialog explaining what happened.
func _on_online_ended(_text: String) -> void:
	show_main_menu()
	open_steam()

## An overlay invite or "+connect_lobby" launch argument started a join.
func _on_online_join_started() -> void:
	if not dialogs().any(func(dialog): return dialog is SteamDialog):
		if not controller.started or controller.is_finished():
			show_main_menu()
		open_steam()

func _on_menu_action(action: String) -> void:
	sfx.play("tap-b")
	if action.begins_with("locale:"):
		set_locale(action.trim_prefix("locale:"))
		return
	match action:
		"resume":
			show_match()
		"ai":
			start_match(MatchController.MODE_AI)
		"local":
			start_match(MatchController.MODE_LOCAL)
		"online":
			open_steam()
		"decks":
			open_deck_list()
		"replays":
			open_replays()
		"settings":
			open_settings()
		"quit":
			get_tree().quit()

func _on_game_over_action(action: String) -> void:
	match action:
		"again":
			start_match(controller.mode)
		"save":
			save_replay()
		"menu":
			show_main_menu()

# --- Dialogs -------------------------------------------------------------------

func _open(dialog: Control) -> Control:
	close_dialogs()
	dialog_layer.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return dialog

func dialogs() -> Array:
	return dialog_layer.get_children().filter(func(node): return not node.is_queued_for_deletion())

func close_dialogs() -> void:
	for dialog in dialog_layer.get_children():
		UiKit.discard(dialog)

func open_settings() -> Control:
	var dialog = SettingsDialog.new()
	dialog.setting_changed.connect(_on_setting_changed)
	return _open(dialog)

## The matchup: a deck for each seat. An online guest picks only its own
## deck, which goes to the host (`back_to_steam` reopens the Steam dialog).
func open_decks(back_to_steam: bool = false) -> Control:
	var dialog = DecksDialog.new()
	var guest = controller.is_guest() or back_to_steam or (not controller.steam_bridge.is_host and controller.steam_bridge.handshake_done)
	var host_online = controller.mode == MatchController.MODE_ONLINE and controller.steam_bridge.is_host
	dialog.setup(controller.deck_selections, guest, controller.mode if host_online or controller.mode != MatchController.MODE_ONLINE else MatchController.MODE_AI)
	dialog.start_requested.connect(func(decks, play_mode):
		controller.deck_selections = decks.duplicate(true)
		_remember_decks()
		start_match(play_mode))
	dialog.own_deck_chosen.connect(func(entry):
		controller.set_own_deck(entry)
		_remember_decks()
		if back_to_steam:
			open_steam.call_deferred())
	dialog.catalog_requested.connect(open_catalog)
	dialog.manage_requested.connect(func(): open_deck_list.call_deferred())
	return _open(dialog)

## The chosen decks are remembered for the next session.
func _remember_decks() -> void:
	DeckStore.save_choices(controller.deck_selections)

## The player's own decks and the presets (main menu "Decks").
func open_deck_list(select_id: String = "") -> Control:
	var dialog = DeckListDialog.new()
	dialog.setup(select_id)
	dialog.edit_requested.connect(func(deck, new_deck): open_deck_builder.call_deferred(deck, new_deck))
	dialog.play_requested.connect(func(entry): _play_with.call_deferred(entry))
	return _open(dialog)

## The deck builder for `deck` (a stored deck, or a new one when `new_deck`).
func open_deck_builder(deck: Dictionary, new_deck: bool = false) -> Control:
	var dialog = DeckBuilderDialog.new()
	dialog.setup(deck, new_deck)
	dialog.back_requested.connect(func(deck_id): open_deck_list.call_deferred(deck_id))
	dialog.play_requested.connect(func(entry): _play_with.call_deferred(entry))
	return _open(dialog)

## "Play with this deck": it becomes this player's deck; offline the matchup
## opens to pick the opponent, online (as guest) it goes to the host.
func _play_with(entry) -> void:
	controller.set_own_deck(entry)
	_remember_decks()
	if not controller.steam_bridge.is_host and controller.steam_bridge.handshake_done:
		open_steam()
	else:
		open_decks()

func open_catalog() -> Control:
	return _open(CatalogDialog.new())

func open_replays() -> Control:
	var dialog = ReplaysDialog.new()
	dialog.load_requested.connect(load_replay)
	return _open(dialog)

func open_steam() -> Control:
	var dialog = SteamDialog.new()
	dialog.setup(controller)
	dialog.deck_change_requested.connect(func(): open_decks.call_deferred(true))
	return _open(dialog)

func open_menu() -> Control:
	var dialog = MatchMenu.new()
	if controller.is_guest():
		# A guest's Decks picks its own deck for the host's next match.
		dialog.disabled_actions = ["new", "save", "replays"]
	if not controller.can_concede():
		dialog.disabled_actions.append("concede")
	dialog.selected.connect(_on_match_menu)
	return _open(dialog)

func _on_match_menu(action: String) -> void:
	match action:
		"log":
			screen.toggle_log()
		"save":
			save_replay()
		"replays":
			open_replays.call_deferred()
		"decks":
			open_decks.call_deferred()
		"settings":
			open_settings.call_deferred()
		"steam":
			open_steam.call_deferred()
		"new":
			start_match(controller.mode)
		"concede":
			open_concede.call_deferred()
		"menu":
			show_main_menu()
		"quit":
			get_tree().quit()

## Asks before conceding; confirming ends the match in the opponent's favour.
func open_concede() -> Control:
	var dialog = ConfirmDialog.new()
	dialog.title_key = "MENU_CONCEDE_CONFIRM"
	dialog.message_key = "CONCEDE_CONFIRM_BODY"
	dialog.confirm_key = "MENU_CONCEDE"
	dialog.confirmed.connect(func(): controller.concede())
	return _open(dialog)

func _on_setting_changed(kind: String) -> void:
	match kind:
		"locale":
			refresh_text()
		"skin":
			CardArt.clear_cache()
			refresh_text()
		"speed":
			AnimationQueue.speed = Settings.animation_speed

## Re-renders every visible text and card after a language or skin change.
func refresh_text() -> void:
	UiKit.title_font()  # Re-points the shared heading font for the language.
	menu.refresh_text()
	screen.refresh_text()
	for dialog in dialog_layer.get_children():
		if dialog.has_method("refresh_text"):
			dialog.refresh_text()

# --- Facade ----------------------------------------------------------------------

func act(command: Dictionary) -> Dictionary:
	return controller.act(command)

## Play helpers (click flow; drag flows are driven with mouse events).
func select_card(index: int) -> bool:
	return screen.select_card(index)

func target_unit(uid: int) -> bool:
	return screen.target_unit(uid)

func choose_position(position: int) -> bool:
	return screen.choose_position(position)

func choose_destination(uid: int) -> bool:
	return screen.choose_destination(uid)

func choose_lane(index: int) -> bool:
	return screen.choose_lane(index)

func choose_improvement(oid: int) -> bool:
	return screen.choose_improvement(oid)

## Uses the active ability of a unit uid, or an item or improvement oid.
func use_ability(id: int) -> bool:
	return screen.use_ability(id)

func pass_turn() -> void:
	screen.press_coin()

func buy(source: String) -> void:
	screen.buy(source)

func hold() -> void:
	screen.hold_secret()

func finish_shop() -> void:
	screen.press_coin()

func deploy_hero(uid: int, lane: int) -> void:
	screen.deploy_hero(uid, lane)

func finish_deployment() -> void:
	screen.press_coin()

func concede() -> Dictionary:
	return controller.concede()

func set_locale(locale: String) -> void:
	Settings.set_locale(locale, false)
	refresh_text()

func set_skin(skin: String) -> void:
	Settings.set_skin(skin, false)
	CardArt.clear_cache()
	refresh_text()

func save_replay(path: String = "") -> Dictionary:
	return controller.save_replay(path)

func load_replay(path: String) -> Dictionary:
	close_dialogs()
	return controller.load_replay(path)

func inspect(card_id: String) -> void:
	screen.inspect_card(card_id)

func inspect_title() -> String:
	return screen.inspect.title_label.text

func inspect_text() -> String:
	return screen.inspect.text_label.text

func open_log() -> void:
	screen.log_panel.toggle(true)

func log_text() -> String:
	return screen.log_panel.plain_text()
