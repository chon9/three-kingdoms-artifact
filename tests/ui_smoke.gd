extends SceneTree
## Exercises the real UI through its scene and, for play interactions, real
## mouse events pushed into the viewport: drag-play (untargeted, targeted,
## creep positions), Battlefield Control's two stages (click and drag), hero
## ability clicks, the initiative coin, shop hold/buy, deployment (staging
## strips, drags from the tray and between lanes, taking a hero back, the
## click fallback, the commit lock, privacy of the opponent's plans, the
## reveal and skipping it), the fountain HUD, inspect, dialogs, replays, live
## locale switching and both card skins, plus regressions found in review:
## drags surviving a state update, edge lane switching only for cross-lane
## cards, a readable and clickable 14-card hand, tooltips rebuilt on a
## language switch, and dialogs centred on their real size.
## Every check exits with code 1 on failure; a watchdog also exits with code 1
## if a script error stops the coroutine before it can finish.

const MainScene = preload("res://scenes/main.tscn")
const Settings = preload("res://scripts/core/game_settings.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const MatchController = preload("res://scripts/game/match_controller.gd")
const Library = preload("res://scripts/core/card_library.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const UnitCard = preload("res://scripts/ui/unit_card.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const WATCHDOG_SECONDS = 240.0
var app
var screen
var checks = 0
var errors = ErrorCatcher.new()
## The player's own settings file, restored on exit (dialogs persist choices).
var saved_settings = null

## Records engine and script errors so the run fails on any of them.
class ErrorCatcher:
	extends Logger
	var messages: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type != ERROR_TYPE_WARNING:
			messages.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass

func _initialize() -> void:
	OS.add_logger(errors)
	create_timer(WATCHDOG_SECONDS).timeout.connect(func():
		printerr("FAIL: UI smoke test did not finish within %d seconds." % WATCHDOG_SECONDS)
		quit(1))
	call_deferred("_run")

func _require(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		printerr("FAIL: " + message)
		_restore_settings()
		quit(1)
	return condition

func _restore_settings() -> void:
	if saved_settings is String:
		var file = FileAccess.open(Settings.PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(saved_settings)
	elif FileAccess.file_exists(Settings.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))

## Real mouse input through the viewport.
func _mouse(position: Vector2, button: int = 0, pressed: bool = false, held: bool = false) -> void:
	var event: InputEventMouse
	if button == 0:
		event = InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	event.position = position
	event.global_position = position
	root.push_input(event, true)

func _click(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	_mouse(point)
	_mouse(point, button, true)
	_mouse(point, button, false)

func _press_and_move(from: Vector2, to: Vector2) -> void:
	_mouse(from)
	_mouse(from, MOUSE_BUTTON_LEFT, true)
	for step in range(1, 7):
		_mouse(from.lerp(to, step / 6.0), 0, false, true)

## Confirms hot-seat hand-overs and waits for the presentation queue.
func _settle() -> void:
	for attempt in range(200):
		if screen.pass_screen.visible:
			screen.pass_screen.confirm()
		if not screen.queue.busy and not screen.pass_screen.visible:
			return
		await process_frame

func _engine():
	return app.engine

## Puts `unit` into lane 0 for its owner (test fixture).
func _place_in_lane(unit: Dictionary, health: int) -> void:
	var engine = _engine()
	engine._remove_from_lane(unit)
	unit.health = health
	engine._spawn(unit, 0)

func _focus_player_zero(hand: Array) -> void:
	var engine = _engine()
	engine.state.phase = "action"
	engine.state.lane = 0
	engine.state.active_player = 0
	engine.state.first_pass = -1
	engine.state.lanes[0].mana[0] = 10
	engine.state.players[0].hand = hand.duplicate()
	app.controller.refresh()

func _run() -> void:
	if FileAccess.file_exists(Settings.PATH):
		saved_settings = FileAccess.get_file_as_string(Settings.PATH)
	root.size = Vector2i(1440, 900)
	AnimationQueue.instant = true
	app = MainScene.instantiate()
	root.add_child(app)
	screen = app.screen
	await process_frame
	Settings.set_locale("zh_CN", false)
	Settings.set_skin("three_kingdoms", false)
	app.refresh_text()
	if not _require(app.menu.visible and not screen.visible, "The game opens on the main menu"):
		return
	if not _require(app.menu.buttons.has("ai") and app.menu.buttons.has("local") and app.menu.buttons.has("replays"), "Main menu offers the play modes and replays"):
		return
	if not _require(absf(screen.size.x - 1440.0) < 1.0 and absf(screen.size.y - 900.0) < 1.0, "Match screen fills the 1440x900 base view (got %s)" % screen.size):
		return
	# Every board and UI painting loads by name, whatever its format (the
	# optimizer turns opaque PNG masters into JPEGs).
	for file_name in DirAccess.get_files_at("res://assets/art/ui"):
		if file_name.get_extension() in ["png", "jpg", "webp"]:
			if not _require(UiKit.ui_art(file_name.get_basename()) != null, "UI art %s loads by name" % file_name):
				return
	# --- Hot-seat match through every phase -------------------------------------
	app.start_match(MatchController.MODE_LOCAL)
	app.bot_timer.stop()
	if not _require(screen.visible and not app.menu.visible, "Starting a match shows the board"):
		return
	if not _require(screen.pass_screen.visible, "Hot-seat starts behind the pass-device screen"):
		return
	await _settle()
	for index in range(6):
		await _settle()
		_click(screen.coin_point())
	await _settle()
	if not _require(_engine().state.phase == "shop", "Six coin passes reach the shop"):
		return
	if not _require(screen.shop.visible and screen.board.overview, "The shop chest opens over the overview"):
		return
	var shopper = app.local_player
	_engine().state.players[shopper].gold = 5
	app.controller.refresh()
	await _settle()
	screen.shop.hold_button.pressed.emit()
	await _settle()
	if not _require(_engine().state.players[shopper].gold == 4 and not str(_engine().state.players[shopper].held_secret).is_empty(), "HOLD spends one gold through the shop"):
		return
	if not _require(screen.shop.held_label.visible and not screen.shop.hold_button.visible, "The shop shows the held offer"):
		return
	var hand_before = _engine().state.players[shopper].hand.size()
	var affordable = ""
	for source in ["consumable", "item", "secret"]:
		var card_id = str(_engine().state.players[shopper].shop.get(source, ""))
		if not card_id.is_empty() and int(_engine().library.cards[card_id].price) <= 4:
			affordable = source
	if affordable != "":
		screen.shop.slots[affordable].buy.pressed.emit()
		await _settle()
		if not _require(_engine().state.players[shopper].hand.size() == hand_before + 1, "BUY adds the item to the hand"):
			return
	_click(screen.coin_point())
	await _settle()
	_click(screen.coin_point())
	await _settle()
	if not _require(_engine().state.phase == "deployment", "Both players finishing with the coin reaches deployment"):
		return
	if not _require(screen.deployment.visible and _engine().player_view(0).pending_creeps[1].size() == 2, "Deployment shows both players' lane creeps"):
		return
	if not await _check_staging():
		return
	for turn in range(2):
		await _settle()
		var deployer = app.local_player
		if turn == 0 and not await _check_replanning(deployer):
			return
		if turn == 1 and not _check_staging_privacy(deployer):
			return
		var tray: Array = screen.deployment.hero_cards.duplicate()
		for card_index in range(tray.size()):
			var cards = screen.deployment.hero_cards
			if cards.is_empty():
				break
			var card = cards[0]
			var uid = int(card.get_meta("uid"))
			var target_lane = card_index % 3
			var from = card.get_global_rect().get_center()
			var to = screen.lane_point(target_lane)
			_press_and_move(from, to)
			if not _require(screen.board.lanes[target_lane].drop_state == 2, "Dragging a hero lights up the lane under it"):
				return
			_mouse(to, MOUSE_BUTTON_LEFT, false)
			await _settle()
			if not _require(int(_engine().state.players[deployer].plans.get(str(uid), -1)) == target_lane, "Dropping a hero on a lane plans its deployment"):
				return
		_click(screen.coin_point())
		await _settle()
	if not _require(_engine().state.phase == "action", "Deployment reveal returns to the action phase"):
		return
	if not _check_reveal_result():
		return
	if not _require(not screen.deployment.visible and not screen.shop.visible and not screen.board.overview, "Overlays close and the camera returns to a lane"):
		return
	# --- Replays ---------------------------------------------------------------------
	var saved_path = "res://.tools/ui_test_replay.json"
	app.save_replay(saved_path)
	var previous_digest = _engine().state_digest()
	app.load_replay(saved_path)
	await _settle()
	if not _require(_engine().state_digest() == previous_digest, "Saved replay restores the same state"):
		return
	if not _require(app.mode == MatchController.MODE_LOCAL and screen.visible, "A loaded replay continues in local two-player mode"):
		return
	# --- Battlefield Control, click flow ------------------------------------------
	var jmuy = _engine().state.players[0].roster[1]
	_place_in_lane(jmuy, 8)
	_focus_player_zero(["battlefield_control"])
	await _settle()
	var revision_before = int(_engine().state.revision)
	if not _require(screen.select_card(0), "Battlefield Control can be picked up"):
		return
	screen.target_unit(jmuy.uid)
	if not _require(screen.selected_source() == jmuy.uid and int(_engine().state.revision) == revision_before, "Redirect waits for a destination"):
		return
	var destinations = _engine().combat_targets(jmuy)
	var destination = 0 if destinations.has(0) else int(destinations[0])
	screen.choose_destination(destination)
	await _settle()
	if not _require(int(jmuy.combat_target) == destination and int(_engine().state.revision) == revision_before + 1, "Redirect to a legal destination applies"):
		return
	if not _require(screen.selected_hand() == -1 and screen.selected_source() == -1, "Selection clears after the redirect"):
		return
	# --- Battlefield Control, drag flow (drop on unit, then click destination) ---
	_focus_player_zero(["battlefield_control"])
	await _settle()
	revision_before = int(_engine().state.revision)
	var card_point = screen.hand_card_point(0)
	_press_and_move(card_point, screen.unit_point(jmuy.uid))
	_mouse(screen.unit_point(jmuy.uid), MOUSE_BUTTON_LEFT, false)
	if not _require(screen.selected_source() == jmuy.uid, "Dropping Battlefield Control on a unit starts stage two"):
		return
	destinations = _engine().combat_targets(jmuy)
	var unit_destination = -1
	for value in destinations:
		if int(value) != 0:
			unit_destination = int(value)
	var target_point = screen.tower_point(0, false) if unit_destination == -1 else screen.unit_point(unit_destination)
	_click(target_point)
	await _settle()
	var expected = 0 if unit_destination == -1 else unit_destination
	if not _require(int(jmuy.combat_target) == expected and int(_engine().state.revision) == revision_before + 1, "Clicking the highlighted destination finishes the redirect"):
		return
	# --- Creep drag into a new left-end combat position ------------------------
	var axe = _engine().state.players[0].roster[0]
	_place_in_lane(axe, 10)
	_focus_player_zero(["bronze_legionnaire"])
	await _settle()
	revision_before = int(_engine().state.revision)
	card_point = screen.hand_card_point(0)
	_mouse(card_point)
	_mouse(card_point, MOUSE_BUTTON_LEFT, true)
	_mouse(card_point + Vector2(0, -40), 0, false, true)
	var slots: Array = screen.board.lanes[0].ghost_slots
	if not _require(not slots.is_empty() and slots[0].position == -1, "Holding a creep shows ghost combat positions"):
		return
	var slot_point = screen.slot_point(-1)
	for step in range(1, 7):
		_mouse(card_point.lerp(slot_point, step / 6.0), 0, false, true)
	_mouse(slot_point, MOUSE_BUTTON_LEFT, false)
	await _settle()
	var rows = _engine().state.lanes[0].units
	if not _require(int(_engine().state.revision) == revision_before + 1 and rows[0][0] != null and rows[0][0].card == "bronze_legionnaire", "Dropping a creep on the left ghost slot places it there"):
		return
	if not _require(rows[0].size() == rows[1].size() and screen.board.lanes[0].ghost_slots.is_empty(), "Rows stay aligned and ghost slots clear"):
		return
	# --- Targeted spell dragged onto an enemy unit ------------------------------
	var debbi = _engine().state.players[0].roster[4]
	_place_in_lane(debbi, 5)
	_focus_player_zero(["no_accident"])
	await _settle()
	var enemy_uid = -1
	for unit in _engine().state.lanes[0].units[1]:
		if unit != null:
			enemy_uid = int(unit.uid)
	var enemy_health = int(_engine().find_unit(enemy_uid).health)
	card_point = screen.hand_card_point(0)
	_press_and_move(card_point, screen.unit_point(enemy_uid))
	if not _require(screen.arrow.visible and screen.arrow.valid, "A target arrow follows the drag and lights up over a legal target"):
		return
	_mouse(screen.unit_point(enemy_uid), MOUSE_BUTTON_LEFT, false)
	await _settle()
	var after = _engine().find_unit(enemy_uid)
	if not _require(_engine().state.players[0].hand.is_empty() and (after.is_empty() or int(after.health) < enemy_health), "Dropping a damage spell on a unit resolves it"):
		return
	# --- Releasing away from any target cancels -----------------------------------
	_focus_player_zero(["no_accident"])
	await _settle()
	revision_before = int(_engine().state.revision)
	card_point = screen.hand_card_point(0)
	_press_and_move(card_point, Vector2(60, 300))
	_mouse(Vector2(60, 300), MOUSE_BUTTON_LEFT, false)
	await _settle()
	if not _require(int(_engine().state.revision) == revision_before and screen.selected_hand() == -1 and not screen.arrow.visible, "Dropping a targeted card on nothing cancels"):
		return
	_mouse(screen.hand_card_point(0))
	_mouse(screen.hand_card_point(0), MOUSE_BUTTON_LEFT, true)
	_mouse(screen.hand_card_point(0), MOUSE_BUTTON_LEFT, false)
	if not _require(screen.selected_hand() == 0, "A click picks a card up (click-to-play fallback)"):
		return
	_mouse(Vector2(700, 300), MOUSE_BUTTON_RIGHT, true)
	if not _require(screen.selected_hand() == -1, "Right-click cancels a held card"):
		return
	# --- Untargeted spell dropped on the board ------------------------------------
	_place_in_lane(jmuy, 8)
	_focus_player_zero(["foresight"])
	await _settle()
	var deck_before = int(_engine().state.players[0].deck.size())
	card_point = screen.hand_card_point(0)
	_press_and_move(card_point, screen.lane_point(0))
	_mouse(screen.lane_point(0), MOUSE_BUTTON_LEFT, false)
	await _settle()
	if not _require(int(_engine().state.players[0].deck.size()) == deck_before - 2, "Dropping an untargeted spell on the board casts it"):
		return
	# --- Hero ability by clicking its badge ------------------------------------------
	jmuy.cooldown = 0
	_focus_player_zero([])
	await _settle()
	var ability_point = screen.ability_point(jmuy.uid)
	if not _require(ability_point != Vector2.ZERO, "Active-ability heroes show an ability badge"):
		return
	_click(ability_point)
	await _settle()
	if not _require(int(jmuy.cooldown) > 0 and _engine().state.players[0].hand.size() == 1, "Clicking the ability badge uses the ability"):
		return
	# --- Edge hover: only cross-lane cards switch lanes, once per visit -----------
	_focus_player_zero(["no_accident"])
	await _settle()
	screen.view_lane(0)
	var edge_point = Vector2(screen.size.x - 20.0, screen.size.y * 0.62)
	if not _require(screen.select_card(0), "A lane-bound card can be picked up"):
		return
	_mouse(edge_point)
	await create_timer(1.3).timeout
	if not _require(screen.board.focus_lane == 0, "Holding a lane-bound card at the screen edge keeps the lane"):
		return
	_mouse(Vector2(700, 300), MOUSE_BUTTON_RIGHT, true)
	_place_in_lane(debbi, 5)
	var far_enemy = _engine().state.players[1].roster[2]
	_engine()._remove_from_lane(far_enemy)
	far_enemy.health = 5
	_engine()._spawn(far_enemy, 1)
	_focus_player_zero(["pick_off"])
	await _settle()
	screen.view_lane(0)
	if not _require(screen.select_card(0), "A cross-lane card can be picked up"):
		return
	_mouse(edge_point)
	await create_timer(1.6).timeout
	if not _require(screen.board.focus_lane == 1, "A cross-lane card at the edge switches one lane, not repeatedly (lane %d)" % screen.board.focus_lane):
		return
	_mouse(Vector2(700, 300), MOUSE_BUTTON_RIGHT, true)
	screen.view_lane(0)
	# --- A large hand stays readable and every card can be picked up -------------
	var big_hand: Array = []
	for index in range(14):
		big_hand.append("foresight")
	_mouse(Vector2(700, 300))
	_focus_player_zero(big_hand)
	await _settle()
	for index in range(14):
		if not _require(screen.hand.visible_height(index) >= 70.0, "Card %d of 14 keeps a readable spine (%.0f px)" % [index, screen.hand.visible_height(index)]):
			return
	var own_panel_left = screen.own_panel.get_global_rect().position.x
	var last_corner = screen.hand.get_global_transform() * screen.hand._slot_point(screen.hand.slot(13), screen.hand.CARD_SIZE)
	if not _require(last_corner.x <= own_panel_left + 1.0, "The hand stays clear of the player panel (%.0f > %.0f)" % [last_corner.x, own_panel_left]):
		return
	for index in range(14):
		_click(screen.hand_card_point(index))
		if not _require(screen.selected_hand() == index, "Clicking card %d of a 14-card hand picks up that card (got %d)" % [index, screen.selected_hand()]):
			return
		_mouse(Vector2(700, 300), MOUSE_BUTTON_RIGHT, true)
		_mouse(Vector2(700, 300))
	# --- Inspect -------------------------------------------------------------------
	app.inspect("foresight")
	if not _require(app.inspect_title() == "遗计" and "摸两张牌" in app.inspect_text(), "Inspector shows localized card text"):
		return
	screen.inspect.close()
	_click(screen.unit_point(jmuy.uid), MOUSE_BUTTON_RIGHT)
	if not _require(screen.inspect.visible and app.inspect_title() == Library.loc("jmuy"), "Right-clicking a unit inspects it"):
		return
	_click(Vector2(720, 450))
	if not _require(not screen.inspect.visible, "A click closes the inspector"):
		return
	_mouse(screen.unit_point(jmuy.uid))
	_mouse(screen.unit_point(jmuy.uid), MOUSE_BUTTON_LEFT, true)
	await create_timer(0.8).timeout
	_mouse(screen.unit_point(jmuy.uid), MOUSE_BUTTON_LEFT, false)
	if not _require(screen.inspect.visible, "Pressing and holding a unit inspects it"):
		return
	screen.inspect.close()
	# --- Locale and skin switch live -----------------------------------------------
	_focus_player_zero(["foresight"])
	_engine().state.lanes[0].mana[0] = 0
	app.controller.refresh()
	await _settle()
	app.set_locale("en")
	if not _require(screen.hand.cards[0].tooltip_text == EventText.t("REASON_NEED_MANA", {"n": 4}), "Hand tooltips are rebuilt in the new language (%s)" % screen.hand.cards[0].tooltip_text):
		return
	app.inspect("foresight")
	if not _require(app.inspect_title() == "Guo Jia's Legacy" and screen.coin.caption != "按兵不动", "Switching to English re-renders text live"):
		return
	app.set_skin("classic")
	app.inspect("foresight")
	if not _require(app.inspect_title() == "Foresight", "The classic skin shows the original names"):
		return
	app.set_skin("three_kingdoms")
	app.set_locale("zh_CN")
	app.inspect("foresight")
	if not _require(app.inspect_title() == "遗计", "Switching back restores the Three Kingdoms names in Chinese"):
		return
	screen.inspect.close()
	# --- Log ---------------------------------------------------------------------------
	app.open_log()
	var log_text = app.log_text()
	if not _require(not log_text.is_empty() and not log_text.begins_with("?") and "\n?\n" not in log_text, "Match log shows formatted event text"):
		return
	screen.toggle_log()
	# --- Dialogs ---------------------------------------------------------------------
	for opener in ["open_settings", "open_steam", "open_replays", "open_catalog", "open_menu"]:
		var dialog = app.call(opener)
		await process_frame
		if not _require(dialog != null and dialog.is_inside_tree() and dialog.panel.size.y <= 900.0, "%s opens a dialog that fits the screen" % opener):
			return
		app.close_dialogs()
		await process_frame
	app.open_menu()
	await process_frame
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	if not _require(app.dialogs().is_empty(), "Esc closes the in-match menu instead of reopening it"):
		return
	var settings = app.open_settings()
	await process_frame
	settings.language_buttons["en"].pressed.emit()
	if not _require(Settings.locale == "en" and settings.title_label.text == "Settings", "The settings language toggle applies immediately"):
		return
	settings.language_buttons["zh_CN"].pressed.emit()
	if not _require(settings.title_label.text == "设置", "Switching the language back re-renders the open dialog"):
		return
	app.close_dialogs()
	# The deck dialog fits and stays centred in English (longer text), and
	# refits when the language changes while it is open.
	app.set_locale("en")
	var english_decks = app.open_decks()
	await process_frame
	await process_frame
	var english_rect: Rect2 = english_decks.panel.get_global_rect()
	if not _require(english_rect.position.y >= 0.0 and english_rect.end.y <= 900.0 and absf(english_rect.get_center().y - 450.0) < 2.0,
			"Deck dialog fits and is centred in English (%s)" % english_rect):
		return
	# Content taller than the requested size: the panel grows and stays centred.
	english_decks.panel_size = Vector2(1180, 300)
	english_decks._place()
	var grown: Rect2 = english_decks.panel.get_global_rect()
	if not _require(grown.size.y > 300.0 and absf(grown.get_center().y - 450.0) < 2.0, "A dialog taller than requested is centred on its real size (%s)" % grown):
		return
	english_decks.panel_size = Vector2(1180, 790)
	app.set_locale("zh_CN")
	await process_frame
	await process_frame
	var chinese_rect: Rect2 = english_decks.panel.get_global_rect()
	if not _require(chinese_rect.end.y <= 900.0 and absf(chinese_rect.get_center().y - 450.0) < 2.0, "Deck dialog refits after a language switch (%s)" % chinese_rect):
		return
	app.close_dialogs()
	Settings.set_locale("zh_CN", false)
	var decks = app.open_decks()
	await process_frame
	await process_frame
	if not _require(decks != null and decks.selectors.size() == 2, "Deck dialog has two deck selectors"):
		return
	if not _require(decks.panel.get_global_rect().end.y <= 901.0 and decks.start_button.is_visible_in_tree(), "Deck dialog fits the screen with its start button visible"):
		return
	decks.selectors[0].item_selected.emit(1)
	decks.selectors[1].item_selected.emit(2)
	decks.start_button.pressed.emit()
	await _settle()
	if not _require(app.deck_selections == ["green_assault", "blue_black_control"], "Deck choices are stored"):
		return
	if not _require(_engine().state.players[0].roster[0].card == "drow" and _engine().state.players[1].roster[0].card == "zeus", "Starting from the deck dialog begins the chosen matchup"):
		return
	# --- Online pieces without Steam: lobby browser, pause overlay, link quality ----
	var steam_dialog = app.open_steam()
	await process_frame
	steam_dialog._on_lobbies([{"id": 1, "host": "孙权", "status": "waiting", "compatible": true},
		{"id": 2, "host": "", "status": "playing", "compatible": false},
		{"id": 3, "host": "吕布", "status": "reconnecting", "compatible": true}])
	await process_frame
	if not _require(steam_dialog.lobby_rows.size() == 3 and steam_dialog.lobby_rows[0].label.text.find("孙权") != -1
			and not steam_dialog.lobby_rows[0].button.disabled and steam_dialog.lobby_rows[1].button.disabled
			and steam_dialog.version_label.text.find("GodotSteam") != -1
			and steam_dialog.panel.get_global_rect().end.y <= 900.0, "The lobby browser lists hosts, disables other versions and fits"):
		return
	if not _require(steam_dialog.lobby_rows[2].button.disabled, "A lobby keeping its seat for a returning player offers no Join"):
		return
	app.close_dialogs()
	# The opponent may drop while the match screen is hidden (main menu): the
	# panel must still have its final height when the screen comes back.
	screen.visible = false
	screen.reconnect.set_waiting(true)
	await process_frame
	screen.visible = true
	await process_frame
	await process_frame
	var first_height = screen.reconnect.panel.size.y
	screen.reconnect.refresh_text()
	await process_frame
	await process_frame
	if not _require(absf(first_height - screen.reconnect.panel.size.y) < 2.0,
			"The reconnect panel has its final height on first show (%d then %d)" % [first_height, screen.reconnect.panel.size.y]):
		return
	if not _require(screen.reconnect.visible and not screen.can_play() and not screen.reconnect.waiting_label.text.is_empty()
			and screen.reconnect.panel.get_global_rect().end.y <= 900.0 and not screen.reconnect.buttons.claim.visible,
			"The reconnect overlay blocks play, fits, and offers no claim to a guest"):
		return
	screen.reconnect.buttons.wait.pressed.emit()
	if not _require(screen.reconnect.collapsed and screen.reconnect.bar.visible and not screen.reconnect.panel.visible, "Keep waiting collapses the overlay to a bar"):
		return
	screen.reconnect.set_waiting(false)
	screen.enemy_panel.set_connection({"level": "fair", "ping": 180, "quality": 0.9})
	if not _require(screen.enemy_panel.tooltip_text.find("180") != -1, "The opponent's plate shows the connection quality"):
		return
	screen.enemy_panel.set_connection({})
	# --- Concede through the in-match menu and its confirmation -----------------------
	var concede_menu = app.open_menu()
	await process_frame
	if not _require(not concede_menu.buttons.concede.disabled, "Concede is offered during a match"):
		return
	concede_menu.buttons.concede.pressed.emit()
	await process_frame
	await process_frame
	var confirm = app.dialogs().back() if not app.dialogs().is_empty() else null
	if not _require(confirm != null and confirm.has_method("build") and confirm.get("confirm_button") != null, "Conceding asks for confirmation"):
		return
	var conceder = app.controller.viewer()
	confirm.confirm_button.pressed.emit()
	await _settle()
	if not _require(int(_engine().state.winner) == 1 - conceder and screen.game_over.visible, "Confirming the concession ends the match"):
		return
	var after_menu = app.open_menu()
	await process_frame
	if not _require(after_menu.buttons.concede.disabled, "A finished match cannot be conceded"):
		return
	app.close_dialogs()
	# --- Against the AI: the bot acts after the animations --------------------------
	app.start_match(MatchController.MODE_AI)
	await _settle()
	var revision = int(_engine().state.revision)
	if int(_engine().state.active_player) == 0:
		_click(screen.coin_point())
	await create_timer(1.6).timeout
	await _settle()
	if not _require(int(_engine().state.revision) > revision and int(_engine().state.revision) >= revision + 1, "The AI responds once the board is idle"):
		return
	# --- Deployment against the AI: fountain HUD, commit lock, reveal skip ----------
	if not await _check_ai_deployment():
		return
	app.show_main_menu()
	if not _require(app.menu.visible and app.menu.buttons.resume.visible, "The main menu offers to resume the match"):
		return
	await process_frame
	if not _require(errors.messages.is_empty(), "No engine or script errors during the run: %s" % "; ".join(errors.messages)):
		return
	print("PASS: %d UI checks: hot-seat phases, coin, shop hold/buy, deployment staging, re-planning, take-back, commit lock, privacy and reveal (instant and skipped), the fountain HUD, drag-play (untargeted, targeted, creep positions), Battlefield Control (click and drag), edge lane switching, a 14-card hand, ability badge, inspect, locale and skin switching (incl. rebuilt tooltips), dialogs and their fit, deck selection, AI turn and replay restoration." % checks)
	app.queue_free()
	await process_frame
	_restore_settings()
	quit(0)

# --- Deployment staging, re-planning and the reveal -------------------------------

## Units entering a lane float in its staging strip (left side), never in a
## combat position, and no combat preview is shown while heroes are planned.
func _check_staging() -> bool:
	var creep = Library.raw_definition("melee_creep")
	var staged_creeps = 0
	var own_card: Control = null
	var own_lane: Control = null
	for lane in screen.board.lanes:
		var table: Rect2 = lane.get_global_transform() * lane.table_rect()
		var leftmost = INF
		for side in range(2):
			for uid in lane.columns[side]:
				if int(uid) != -1 and lane.cards.has(int(uid)):
					leftmost = minf(leftmost, lane.cards[int(uid)].get_global_rect().position.x)
		for card in lane.staged_cards():
			var bounds: Rect2 = card.get_global_transform() * Rect2(Vector2.ZERO, UnitCard.SIZE)
			if not _require(not lane.cards.values().has(card), "Staged cards are never board units"):
				return false
			if not _require(table.grow(2.0).encloses(bounds), "Staged cards stay inside their lane (%s in %s)" % [bounds, table]):
				return false
			if not _require(leftmost == INF or bounds.end.x <= leftmost + 2.0, "Staged cards float left of the unit rows (%.0f > %.0f)" % [bounds.end.x, leftmost]):
				return false
			if card.card_id == "melee_creep":
				staged_creeps += 1
				if not _require(int(card.model.attack) == int(creep.attack) and int(card.model.health) == int(creep.health),
						"Staged creeps show the creep's real stats (got %d/%d)" % [int(card.model.attack), int(card.model.health)]):
					return false
		for entry in lane.staged[1]:
			if own_card == null:
				own_card = entry.card
				own_lane = lane
		if not _require(lane._count == maxi(lane.columns[0].size(), lane.columns[1].size()), "Staging never takes a combat position"):
			return false
	if not _require(staged_creeps >= 4, "Both players' lane creeps are staged (%d)" % staged_creeps):
		return false
	for models in screen.board.lane_models:
		if not _require(models.get("tower_damage", [0, 0]) == [0, 0], "No tower damage is previewed while heroes are planned"):
			return false
		for uid in models:
			if uid is int and not _require(not models[uid].get("dies", false), "No death is previewed while heroes are planned"):
				return false
	if not _require(own_card != null, "Your lane creeps are staged"):
		return false
	if not _require(absf(own_card.rotation_degrees) >= 3.0 and own_card.scale.x > own_lane._scale and own_card.floating == 1.0,
			"Staged cards are tilted, larger than the row and lifted (%.1f deg, %.2f vs %.2f)" % [own_card.rotation_degrees, own_card.scale.x, own_lane._scale]):
		return false
	# The float bobs in real time only.
	AnimationQueue.instant = false
	own_lane._update_processing()
	var resting_y = own_card.position.y
	await create_timer(0.5).timeout
	var bobbed = absf(own_card.position.y - resting_y) > 0.01
	AnimationQueue.instant = true
	own_lane._update_processing()
	own_lane.layout()
	return _require(bobbed, "Staged cards bob gently")

## Tray to lane, re-planning by drag, taking back to the tray and the click
## fallback, with states published mid-drag.
func _check_replanning(deployer: int) -> bool:
	var deployment = screen.deployment
	var lanes: Array = screen.board.lanes
	if not _require(not deployment.hero_cards.is_empty(), "A ready hero waits in the tray"):
		return false
	var card: Control = deployment.hero_cards[0]
	var uid = int(card.get_meta("uid"))
	var key = "h%d" % uid
	_press_and_move(card.get_global_rect().get_center(), screen.lane_point(0))
	# A state published mid-drag (the opponent planning) keeps the dragged hero.
	app.controller.refresh()
	await _settle()
	if not _require(is_instance_valid(card) and card.is_inside_tree() and deployment.dragging == card, "A hero being dragged survives a state update"):
		return false
	_mouse(screen.lane_point(0), 0, false, true)
	_mouse(screen.lane_point(0), MOUSE_BUTTON_LEFT, false)
	await _settle()
	if not _require(_plan(deployer, uid) == 0 and deployment.hero_card(uid) == null and lanes[0].staged_entry(key).get("movable", false),
			"A dropped hero leaves the tray and floats, movable, in its lane's staging strip"):
		return false
	# Drag the staged hero on to the right lane; a state published mid-drag keeps it.
	_press_and_move(lanes[0].staged_global_center(key), screen.lane_point(1))
	app.controller.refresh()
	await _settle()
	if not _require(deployment.drag_proxy() != null and lanes[0].staged_entry(key).get("hidden", false), "A staged hero being dragged survives a state update"):
		return false
	_mouse(screen.lane_point(2), 0, false, true)
	if not _require(lanes[2].drop_state == 2 and lanes[1].drop_state == 1, "Dragging a staged hero lights up the lane under it"):
		return false
	_mouse(screen.lane_point(2), MOUSE_BUTTON_LEFT, false)
	await _settle()
	if not _require(_plan(deployer, uid) == 2 and not lanes[2].staged_entry(key).is_empty() and lanes[0].staged_entry(key).is_empty(),
			"Dropping a staged hero on another lane re-plans it there"):
		return false
	if not _require(deployment.drag_proxy() == null and not lanes[2].staged_entry(key).get("hidden", true), "The re-planned hero shows in its new lane"):
		return false
	# Back to the tray: the hero is unplanned and confirming is blocked.
	var tray_point = deployment.tray.get_global_rect().get_center()
	_press_and_move(lanes[2].staged_global_center(key), tray_point)
	if not _require(deployment.tray.drop_state == 2 and deployment.hint_label.text == UiKit.t("DEPLOY_UNASSIGN_HINT"), "The tray lights up to take a hero back"):
		return false
	_mouse(tray_point, MOUSE_BUTTON_LEFT, false)
	await _settle()
	if not _require(not _engine().state.players[deployer].plans.has(str(uid)) and deployment.hero_card(uid) != null and lanes[2].staged_entry(key).is_empty(),
			"Dropping a staged hero on the tray takes it back"):
		return false
	if not _require(not {"type": "finish_deployment"} in screen.actions and not screen.coin.enabled, "An unplanned hero keeps the coin from confirming"):
		return false
	# Click fallback: tray hero, then a lane; staged hero, then another lane.
	_click(deployment.hero_card(uid).get_global_rect().get_center())
	if not _require(deployment.selected_uid == uid and lanes[0].drop_state == 1, "Clicking a tray hero selects it"):
		return false
	_click(screen.lane_point(2))
	await _settle()
	if not _require(_plan(deployer, uid) == 2, "Clicking a lane plans the selected hero"):
		return false
	_click(lanes[2].staged_global_center(key))
	if not _require(deployment.selected_uid == uid and lanes[2].staged_entry(key).card.target_state == 3, "Clicking a staged hero selects it"):
		return false
	_click(screen.lane_point(1))
	await _settle()
	if not _require(_plan(deployer, uid) == 1 and not lanes[1].staged_entry(key).is_empty(), "Clicking another lane re-plans the selected staged hero"):
		return false
	return true

func _plan(player: int, uid: int) -> int:
	return int(_engine().state.players[player].plans.get(str(uid), -1))

## The opponent's planned heroes never appear before the reveal; its ready
## heroes are shown in the strip at the top.
func _check_staging_privacy(viewer: int) -> bool:
	for lane in screen.board.lanes:
		for entry in lane.staged[0]:
			if not _require(entry.kind == "creep", "Only the opponent's creeps are staged before the reveal"):
				return false
	var ready: Array = []
	for hero in _engine().state.players[1 - viewer].roster:
		if int(hero.lane) == -1 and int(hero.ready_round) <= int(_engine().state.round):
			ready.append(int(hero.uid))
	var shown: Array = screen.deployment.strip_uids()
	ready.sort()
	shown.sort()
	return _require(ready == shown and screen.deployment.opponent_strip.visible == not ready.is_empty(),
		"The opponent strip shows exactly the opponent's ready heroes (%s vs %s)" % [shown, ready])

## After the reveal every lane is settled and every placed unit sits in the
## column the engine chose.
func _check_reveal_result() -> bool:
	var placed: Dictionary = {}
	for event in _engine().state.events:
		if str(event.get("k", "")) == "deployment_placed":
			placed = event
	if not _require(not placed.is_empty(), "The reveal reports where every unit was placed"):
		return false
	for lane in screen.board.lanes:
		if not _require(lane.staged_cards().is_empty() and lane.staging == 0.0 and lane.slabs.is_empty() and not lane.preview_hidden,
				"The reveal leaves no staging, slabs or hidden previews"):
			return false
	var viewer = screen.shown_viewer
	for unit in placed.units:
		var column: Array = screen.board.lanes[int(unit.lane)].columns[1 if int(unit.p) == viewer else 0]
		if not _require(int(unit.slot) < column.size() and int(column[int(unit.slot)]) == int(unit.uid), "Revealed units land in their engine columns"):
			return false
	return true

## Every card rests in its slot at the lane's scale (a reveal finished or skipped).
func _board_settled() -> bool:
	var view: Dictionary = screen.shown_view
	var viewer = screen.shown_viewer
	for index in range(3):
		var lane = screen.board.lanes[index]
		var rows = [view.lanes[index].units[1 - viewer], view.lanes[index].units[viewer]]
		for side in range(2):
			if lane.columns[side].size() != rows[side].size():
				return false
			for column in range(rows[side].size()):
				var uid = int(lane.columns[side][column])
				if uid != (-1 if rows[side][column] == null else int(rows[side][column].uid)):
					return false
				if uid == -1:
					continue
				var card: Control = lane.cards[uid]
				var rest = lane.slot_center(column, side == 1) - UnitCard.SIZE * 0.5
				if card.position.distance_to(rest) > 0.5 or absf(card.rotation) > 0.001 or absf(card.scale.x - lane._scale) > 0.001 or card.modulate.a < 0.999:
					return false
		if lane.staging != 0.0 or not lane.staged_cards().is_empty():
			return false
	return true

## Fountain chips, their status lines and the opponent hand around the HUD.
func _check_fountain(label: String) -> bool:
	var hud = screen.hud
	var rects: Dictionary = hud.fountain_rects()
	var area = Rect2(0, 0, hud.FOUNTAIN_W, hud.HEIGHT)
	var chips: Array = rects.chips[0] + rects.chips[1]
	if not _require(rects.chips[0].size() == 5 and rects.chips[1].size() == 5, "%s: five chips per side in the fountain" % label):
		return false
	for index in range(chips.size()):
		if not _require(area.encloses(chips[index]), "%s: fountain chips stay inside the fountain" % label):
			return false
		for other in range(index + 1, chips.size()):
			if not _require(not chips[index].intersects(chips[other]), "%s: fountain chips never overlap" % label):
				return false
		for side in range(2):
			for status in rects.status[side]:
				if not _require(not status.intersects(chips[index]), "%s: fountain status marks never sit on a chip" % label):
					return false
	for status in rects.status[0]:
		if not _require(status.end.y <= rects.chips[0][0].position.y, "%s: the enemy's status line is above its chips" % label):
			return false
	for status in rects.status[1]:
		if not _require(status.position.y >= rects.chips[1][0].end.y, "%s: your status line is below your chips" % label):
			return false
	var enemy_hand: Rect2 = screen.enemy_hand.get_global_rect()
	return _require(enemy_hand.position.x >= hud.get_global_rect().end.x and enemy_hand.end.x <= screen.enemy_panel.get_global_rect().position.x,
		"%s: the opponent's hand fits between the HUD and its panel (%s)" % [label, enemy_hand])

## The tray's hero cards stay inside its frame with the opponent's spending
## line below it, and the coin's caption and two-line hint stay on screen and
## clear of the player panel.
func _check_deploy_layout(label: String) -> bool:
	var deployment = screen.deployment
	var tray: Rect2 = deployment.tray.get_global_rect()
	if not _require(not deployment.hero_cards.is_empty(), "%s: a hero waits in the tray" % label):
		return false
	for card in deployment.hero_cards:
		var bounds: Rect2 = card.get_global_rect()
		if not _require(bounds.end.y <= tray.end.y - 6.0 and bounds.position.y >= deployment.hint_label.get_global_rect().end.y - 1.0,
				"%s: tray heroes sit inside the frame, under the hint (%s in %s)" % [label, bounds, tray]):
			return false
	if not _require(deployment.info_label.get_global_rect().position.y >= tray.end.y, "%s: the opponent's spending line sits under the tray" % label):
		return false
	var coin = screen.coin
	var rects: Dictionary = coin.caption_rects()
	if not _require(rects.has("plate") and rects.has("hint"), "%s: the coin shows its caption and hint" % label):
		return false
	var panel_top = screen.own_panel.get_global_rect().position.y
	for part in ["plate", "hint"]:
		var bounds: Rect2 = coin.get_global_transform() * rects[part]
		if not _require(bounds.position.x >= 0.0 and bounds.end.x <= screen.size.x - 4.0 and bounds.end.y <= panel_top - 2.0,
				"%s: the coin's %s stays on screen and above the player panel (%s)" % [label, part, bounds]):
			return false
	return true

## Against the AI: five heroes per fountain, the commit lock, and a reveal
## in real time that a click skips to the settled board.
func _check_ai_deployment() -> bool:
	var engine = _engine()
	var bot = Bot.new()
	app.bot_timer.stop()
	app.bot_timer.paused = true
	var guard = 0
	while engine.state.phase != "deployment" and engine.state.winner == -1 and guard < 600:
		var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
		engine.apply_action(player, bot.choose_action(engine, player))
		guard += 1
	if not _require(engine.state.phase == "deployment", "The AI match reaches a deployment"):
		return false
	# Five heroes in each fountain: two ready, the rest one or two rounds out.
	var round_now = int(engine.state.round)
	var waits = [0, 0, 1, 2, 1]
	for player in range(2):
		var roster: Array = engine.state.players[player].roster
		for index in range(roster.size()):
			engine._remove_from_lane(roster[index])
			roster[index].lane = -1
			roster[index].ready_round = round_now + waits[index % waits.size()]
	var ready_uid = int(engine.state.players[0].roster[0].uid)
	engine.apply_action(0, {"type": "deploy", "unit": ready_uid, "lane": 1})
	app.controller.refresh()
	await _settle()
	if not _check_fountain("1440x900") or not _check_deploy_layout("1440x900"):
		return false
	var dots = screen.hud.fountain_layout()[1].filter(func(entry): return entry.status == "dots")
	if not _require(dots.size() == 1 and int(dots[0].lane) == 1, "Lane dots mark your planned hero's lane"):
		return false
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	var wide = absf(screen.size.x - 1600.0) < 1.0
	var fits = _check_fountain("1280x720") and _check_deploy_layout("1280x720")
	root.size = Vector2i(1440, 900)
	await process_frame
	await process_frame
	if not fits or not _require(wide, "A 1280x720 window gives a 1600x900 canvas (got %s)" % screen.size):
		return false
	# Plan the other ready hero, confirm, then try to move a staged hero.
	for card in screen.deployment.hero_cards.duplicate():
		screen.deploy_hero(int(card.get_meta("uid")), 0)
	await _settle()
	_click(screen.coin_point())
	await _settle()
	if not _require(engine.state.players[0].finished and not engine.state.players[1].finished, "The player confirmed before the AI"):
		return false
	var plans_before = engine.state.players[0].plans.duplicate()
	var key = "h%d" % ready_uid
	_press_and_move(screen.board.lanes[1].staged_global_center(key), screen.lane_point(2))
	_mouse(screen.lane_point(2), MOUSE_BUTTON_LEFT, false)
	await _settle()
	var glowing = false
	for lane in screen.board.lanes:
		for entry in lane.staged[1]:
			glowing = glowing or entry.card.target_state == 4
	if not _require(engine.state.players[0].plans == plans_before and not glowing and screen.deployment.drag_proxy() == null,
			"After confirming, staged heroes no longer move or glow"):
		return false
	# A zoom left open when the reveal starts must not hide it.
	_click(screen.board.lanes[1].staged_global_center(key), MOUSE_BUTTON_RIGHT)
	await _settle()
	if not _require(screen.inspect.visible, "Right-clicking a confirmed staged hero inspects it"):
		return false
	# The coin as it stands when you are the last to confirm (lit, inviting
	# changes): the reveal must turn it dark.
	screen.coin.set_state(true, true, UiKit.t("BTN_CONFIRM_DEPLOYMENT"), UiKit.t("DEPLOY_ALL_ASSIGNED"))
	# The AI confirms: the reveal plays in real time and a click skips it.
	AnimationQueue.instant = false
	while not engine.state.players[1].finished and engine.state.phase == "deployment":
		engine.apply_action(1, bot.choose_action(engine, 1))
	app.controller.refresh()
	await create_timer(0.3).timeout
	var was_revealing = screen._revealing
	var zoom_closed = not screen.inspect.visible
	var coin_dark = not screen.coin.lit and not screen.coin.enabled and screen.coin.sub_caption.is_empty()
	# The queue going idle mid-reveal refreshes the controls: still dark.
	screen._refresh_controls()
	coin_dark = coin_dark and not screen.coin.lit and not screen.coin.enabled and screen.coin.caption == UiKit.t("HUD_WAITING")
	_click(screen.size * 0.5)
	await process_frame
	await process_frame
	var skipped = not screen._revealing or screen._reveal_skip
	var waited = 0.0
	while screen.queue.busy and waited < 1.0:
		await process_frame
		waited += root.get_process_delta_time()
	var idle = not screen.queue.busy
	AnimationQueue.instant = true
	app.bot_timer.paused = false
	if not _require(was_revealing and zoom_closed, "The reveal closes an open card zoom (revealing %s, zoom closed %s)" % [was_revealing, zoom_closed]):
		return false
	if not _require(coin_dark, "The coin is dark and offers nothing while the reveal plays"):
		return false
	if not _require(was_revealing and skipped, "A click skips the reveal at once (revealing %s, skipped %s)" % [was_revealing, skipped]):
		return false
	if not _require(idle, "A skipped reveal hands control back within a second"):
		return false
	return _require(engine.state.phase == "action" and _board_settled() and _check_reveal_result(), "A skipped reveal leaves the board exactly settled")
