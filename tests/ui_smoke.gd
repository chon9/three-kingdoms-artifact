extends SceneTree
## Exercises the real UI through its scene and, for play interactions, real
## mouse events pushed into the viewport: drag-play (untargeted, targeted,
## creep positions), Battlefield Control's two stages (click and drag), hero
## ability clicks, the initiative coin, shop hold/buy, deployment drags,
## inspect, dialogs, replays, live locale switching and both card skins, plus
## regressions found in review: a deployment drag surviving a state update,
## incoming creep ghosts (real stats, inside the lane), edge lane switching
## only for cross-lane cards, a readable and clickable 14-card hand, tooltips
## rebuilt on a language switch, and dialogs centred on their real size.
## Every check exits with code 1 on failure; a watchdog also exits with code 1
## if a script error stops the coroutine before it can finish.

const MainScene = preload("res://scenes/main.tscn")
const Settings = preload("res://scripts/core/game_settings.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const MatchController = preload("res://scripts/game/match_controller.gd")
const Library = preload("res://scripts/core/card_library.gd")
const EventText = preload("res://scripts/core/event_text.gd")
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
	var ghosts = 0
	for lane in screen.board.lanes:
		ghosts += lane.incoming_cards.size()
	if not _require(ghosts >= 4, "Pending creeps appear as ghost cards in the lanes"):
		return
	var creep = Library.raw_definition("melee_creep")
	for lane in screen.board.lanes:
		var table: Rect2 = lane.get_global_transform() * lane.table_rect()
		for ghost in lane.incoming_cards:
			var unit: Dictionary = ghost.model.unit
			if ghost.card_id == "melee_creep" and not _require(int(unit.attack) == int(creep.attack) and int(unit.health) == int(creep.health),
					"Incoming creep ghosts show the creep's real stats (got %d/%d)" % [int(unit.attack), int(unit.health)]):
				return
			if not _require(table.grow(2.0).encloses(ghost.get_global_rect()), "Incoming ghost cards stay inside their lane (%s in %s)" % [ghost.get_global_rect(), table]):
				return
	for turn in range(2):
		await _settle()
		var deployer = app.local_player
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
			if card_index == 0:
				# A state published mid-drag (the opponent planning its own
				# deployment) must not destroy the dragged hero.
				app.controller.refresh()
				await _settle()
				if not _require(is_instance_valid(card) and card.is_inside_tree() and screen.deployment.dragging == card,
						"A hero being dragged survives a state update"):
					return
				_mouse(to, 0, false, true)
			_mouse(to, MOUSE_BUTTON_LEFT, false)
			await _settle()
			if not _require(int(_engine().state.players[deployer].plans.get(str(uid), -1)) == target_lane, "Dropping a hero on a lane plans its deployment"):
				return
		_click(screen.coin_point())
		await _settle()
	if not _require(_engine().state.phase == "action", "Deployment reveal returns to the action phase"):
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
	app.show_main_menu()
	if not _require(app.menu.visible and app.menu.buttons.resume.visible, "The main menu offers to resume the match"):
		return
	await process_frame
	if not _require(errors.messages.is_empty(), "No engine or script errors during the run: %s" % "; ".join(errors.messages)):
		return
	print("PASS: %d UI checks: hot-seat phases, coin, shop hold/buy, deployment drag (incl. a state update mid-drag) and incoming creep ghosts, drag-play (untargeted, targeted, creep positions), Battlefield Control (click and drag), edge lane switching, a 14-card hand, ability badge, inspect, locale and skin switching (incl. rebuilt tooltips), dialogs and their fit, deck selection, AI turn and replay restoration." % checks)
	app.queue_free()
	await process_frame
	_restore_settings()
	quit(0)
