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
## language switch, and dialogs centred on their real size. On the rules
## fixture pack (EFFECT_SYSTEM_SPEC.md M2): status and keyword icons, tower
## badges, lock badges on an own card and an enemy card back, the
## lane-then-position stepper, an improvement choice, an improvement chip
## click and an item ability click (with its lane step), and every event
## animation played in real time (sped up) without a script error.
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
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const FIXTURES = "res://tests/fixtures/rules_fixtures.json"
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
	# --- Dark Seer's Surge: a hero ability with a unit step, then a lane step (M3) ---
	var seer = Zones.summon(_engine(), "dark_seer", 0, 0)
	var seer_ally = Zones.summon(_engine(), "melee_creep", 0, 0)
	_focus_player_zero([])
	await _settle()
	var seer_point = screen.ability_point(int(seer.uid))
	if not _require(seer_point != Vector2.ZERO, "Dark Seer shows an ability badge"):
		return
	_click(seer_point)
	if not _require(screen.current_step_type() == "unit", "Surge asks for another ally first"):
		return
	screen.target_unit(int(seer_ally.uid))
	if not _require(screen.current_step_type() == "lane", "Surge then asks for a lane"):
		return
	screen.choose_lane(2)
	await _settle()
	if not _require(int(seer_ally.lane) == 2 and int(seer.cooldown) > 0, "Surge moves the ally to the chosen lane and starts its cooldown"):
		return
	_engine()._remove_from_lane(seer)
	_engine()._remove_from_lane(seer_ally)
	# --- Winter Wyvern's Arctic Burn: an ability whose only step is a position (M5) ---
	var wyvern = Zones.summon(_engine(), "winter_wyvern", 0, 0)
	var wyvern_ally = Zones.summon(_engine(), "melee_creep", 0, 0)
	_focus_player_zero([])
	await _settle()
	var wyvern_point = screen.ability_point(int(wyvern.uid))
	if not _require(wyvern_point != Vector2.ZERO, "Winter Wyvern shows an ability badge"):
		return
	_click(wyvern_point)
	var wyvern_ghosts: Array = screen.board.lanes[0].ghost_slots
	if not _require(screen.current_step_type() == "position" and not wyvern_ghosts.is_empty(),
			"Arctic Burn asks for an empty combat position in Winter Wyvern's lane (%d ghost positions)" % wyvern_ghosts.size()):
		return
	_click(screen.slot_point(int(wyvern_ghosts.back().position)))
	await _settle()
	if not _require(int(wyvern.lane) == 0 and int(wyvern.cooldown) > 0 and _engine().attack_of(wyvern) == int(wyvern.attack) + 4,
			"Clicking a ghost position moves Winter Wyvern there, gives +4 Attack and starts the cooldown"):
		return
	_engine()._remove_from_lane(wyvern)
	_engine()._remove_from_lane(wyvern_ally)
	# --- Friendly Fire: an unordered pair, either unit picked first (M4) -----------
	var fodder: Array = []
	for count in range(3):
		fodder.append(Zones.summon(_engine(), "melee_creep", 1, 0))
	_focus_player_zero(["friendly_fire"])
	await _settle()
	fodder.sort_custom(func(a, b): return _engine().slot_of(a) < _engine().slot_of(b))
	var rightmost: Dictionary = fodder.back()
	var leftmost: Dictionary = fodder.front()
	if not _require(screen.select_card(0) and screen.current_step_type() == "unit", "Friendly Fire asks for an enemy"):
		return
	if not _require(screen.target_unit(int(rightmost.uid)) and screen.current_step_type() == "unit",
			"The rightmost enemy can be picked first (the pair is unordered), then Friendly Fire asks for the second enemy"):
		return
	screen.target_unit(int(leftmost.uid))
	await _settle()
	# The command sent is the canonical pair: the left enemy battles the right one.
	var battles: Array = []
	for event in _engine().state.events:
		if str(event.get("k", "")) == "battle" and int(event.get("a", -1)) == int(leftmost.uid) and event.get("bs", []).has(int(rightmost.uid)):
			battles.append(event)
	if not _require(_engine().state.players[0].hand.is_empty() and int(rightmost.health) < 4 and int(leftmost.health) < 4 and not battles.is_empty(),
			"The two picked enemies battle each other (health %d and %d)" % [int(rightmost.health), int(leftmost.health)]):
		return
	for unit in fodder:
		_engine()._remove_from_lane(unit)
	# M4: a hacked card at the right of the fan shows its (long) note beside
	# it, clear of the initiative coin, also in Chinese (a narrower note).
	var locale_before = Settings.locale
	app.set_locale("zh_CN")
	var hacked_hand = ["foresight", "foresight", "foresight", "foresight", "foresight", "foresight", "lightning_strike"]
	_act_in_lane_zero(hacked_hand, [{}, {}, {}, {}, {}, {}, {"hacks": ["self_sabotage#0"]}])
	await _settle()
	AnimationQueue.instant = false
	_mouse(screen.hand_card_point(hacked_hand.size() - 1))
	await create_timer(0.9).timeout
	var shown_note = screen.hand.shown_note()
	var note_box: Rect2 = screen.hand._note.get_global_rect()
	var coin_box: Rect2 = screen.coin.get_global_rect()
	AnimationQueue.instant = true
	_mouse(screen.lane_point(0))
	app.set_locale(locale_before)
	await _settle()
	if not _require(shown_note.find(EventText.t("EV_CHANGE_GRANT", {"text": Library.loc("self_sabotage", "grant_0")})) != -1 and not note_box.intersects(coin_box),
			"A long hand note stays clear of the initiative coin (%s vs %s)" % [note_box, coin_box]):
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
	if not _require(screen.hand.note_text(0) == EventText.t("REASON_NEED_MANA", {"n": 4}), "Hand notes are rebuilt in the new language (%s)" % screen.hand.note_text(0)):
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
	# The catalog lists every definition of the pack (M3: the red and green
	# cards too; M4: the blue ones), heroes first, and filters by colour (faction).
	var catalog = app.open_catalog()
	await process_frame
	var pack = Library.new()
	var total = catalog.cards.size()
	catalog.apply_filter("green")
	var greens = catalog.cards.filter(func(card): return card.visible).size()
	var green_ids = catalog.cards.filter(func(card): return card.visible).map(func(card): return card.card_id)
	catalog.apply_filter("blue")
	var blue_ids = catalog.cards.filter(func(card): return card.visible).map(func(card): return card.card_id)
	catalog.apply_filter("black")
	var black_ids = catalog.cards.filter(func(card): return card.visible).map(func(card): return card.card_id)
	catalog.apply_filter("all")
	if not _require(total == pack.heroes.size() + pack.cards.size() and total >= 190 and str(catalog.cards[0].definition.get("kind", "")) == "hero"
			and greens > 0 and greens < total and "treant_protector" in green_ids and "viper_strike" in green_ids and "duel" not in green_ids
			and catalog.cards.all(func(card): return card.visible),
			"The catalog lists every card (%d) and filters by colour (%d green)" % [total, greens]):
		return
	if not _require(["luna", "meepo", "eclipse", "barracks", "plague_ward", "self_sabotage"].all(func(card_id): return card_id in blue_ids)
			and "hound_of_war" not in blue_ids and "duel" not in blue_ids,
			"The blue (Wei) filter shows the M4 cards (%d blue)" % blue_ids.size()):
		return
	if not _require(["sorla_khan", "lich", "winter_wyvern", "chain_frost", "assault_ladders", "march_of_the_machines", "ravenous_mass", "gank"].all(func(card_id): return card_id in black_ids)
			and "eclipse" not in black_ids and "duel" not in black_ids,
			"The black (Qun) filter shows the M5 cards, the draft Chain Frost included (%d black)" % black_ids.size()):
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
	if not await _check_m2_ui():
		return
	app.show_main_menu()
	if not _require(app.menu.visible and app.menu.buttons.resume.visible, "The main menu offers to resume the match"):
		return
	await process_frame
	if not _require(errors.messages.is_empty(), "No engine or script errors during the run: %s" % "; ".join(errors.messages)):
		return
	print("PASS: %d UI checks: hot-seat phases, coin, shop hold/buy, deployment staging, re-planning, take-back, commit lock, privacy and reveal (instant and skipped), the fountain HUD, drag-play (untargeted, targeted, creep positions), Battlefield Control (click and drag), edge lane switching, a 14-card hand, ability badge, inspect, locale and skin switching (incl. rebuilt tooltips), dialogs and their fit, deck selection, AI turn, replay restoration, and the M2 pieces (status icons, tower badges, lock badges, the lane-then-position stepper, an improvement choice, chip and item ability clicks, the \"+n\" chip rows, hand notes, the lane-step hint, every event animation in real time), and the M3 pieces (Dark Seer's unit-then-lane ability, the full catalog and its colour filters), and the M4 pieces (Friendly Fire's unordered pair picked in either order, a hacked card's note quoting its text and kept clear of the coin, the blue catalog filter), and the M5 pieces (Winter Wyvern's position-only ability, the black catalog filter)." % checks)
	app.queue_free()
	await process_frame
	_restore_settings()
	quit(0)

# --- M2: statuses, hand marks, the target stepper and ability buttons ------------

## Sets `player`'s hand to `cards` with aligned hand states (fresh iids plus
## the given fields per card).
func _give_hand(player: int, cards: Array, fields: Array = []) -> void:
	var engine = _engine()
	var states: Array = []
	for index in range(cards.size()):
		var entry = {"iid": Kernel.next_oid(engine)}
		if index < fields.size():
			entry.merge(fields[index])
		states.append(entry)
	engine.state.players[player].hand = cards.duplicate()
	engine.state.players[player].hand_state = states

## Player 0 acts in lane 0 with mana to spare and `cards` in hand.
func _act_in_lane_zero(cards: Array, fields: Array = []) -> void:
	var engine = _engine()
	engine.state.phase = "action"
	engine.state.lane = 0
	engine.state.active_player = 0
	engine.state.first_pass = -1
	engine.state.lanes[0].mana[0] = 10
	_give_hand(0, cards, fields)
	app.controller.refresh()

## The M2 UI on the rules fixture pack (spec §12 M2, UI acceptance).
func _check_m2_ui() -> bool:
	app.deck_selections = ["starter", "starter"]
	app.start_match(MatchController.MODE_LOCAL)
	await _settle()
	var engine = _engine()
	var fixtures = Library.from_file(FIXTURES, "rules_fixtures")
	if not _require(fixtures != null and fixtures.cards.has("fx_move_any"), "The rules fixture pack loads"):
		return false
	engine.library = fixtures
	# Heroes of every colour in lane 0 for player 0: red, blue, green, black.
	var roster: Array = engine.state.players[0].roster
	for index in [0, 1, 2, 4]:
		_place_in_lane(roster[index], 10)
	var enemy = engine._make_unit(fixtures.get_card("fx_retaliate_2"), 1, false)
	engine._spawn(enemy, 0)
	Kernel.give(engine, enemy, {}, {"stun": 1}, "", "round", {"controller": 0, "card": "fx_stun_spell"})
	Zones.add_improvement(engine, "fx_tower_guard", 0, 0)
	# Status icons, tower badges and lock badges (own card, enemy card back).
	_give_hand(1, ["fx_swap", "fx_raze", "fx_swap"], [{}, {"lock": 1}, {}])
	_act_in_lane_zero(["fx_stun_spell", "fx_counter_spell", "fx_swap"], [{"lock": 2}, {}, {"hacks": ["fx_hack_spell#0"]}])
	await _settle()
	var enemy_card = screen.board.unit_card(int(enemy.uid))
	if not _require(enemy_card != null and enemy_card.badge_kinds().has("stun") and enemy_card.badge_kinds().has("retaliate"),
			"Status and keyword icons show on the unit (%s)" % str(enemy_card.badge_kinds() if enemy_card != null else [])):
		return false
	if not _require(screen.board.tower(0, true).badge_kinds() == ["armor", "retaliate", "regeneration"],
			"Tower badges show its derived armor, retaliate and regeneration (%s)" % str(screen.board.tower(0, true).badge_kinds())):
		return false
	var marks: Array = []
	for card in screen.hand.cards:
		marks.append(card.badges)
	if not _require(marks[0] == [{"k": "lock", "v": 2}] and screen.hand.cards[0].dimmed and marks[1] == [{"k": "charges", "v": 1}]
			and marks[2] == [{"k": "hacked", "v": 1}], "Hand cards show lock, charges and hacked badges (%s)" % [marks]):
		return false
	if not _require(screen.enemy_hand.locks == [0, 1, 0], "The opponent's locked card back shows its lock (%s)" % [screen.enemy_hand.locks]):
		return false
	if not _require(screen.inspect.granted_text("fx_hack_spell#0") == Library.loc("fx_hack_spell", "grant_0") and not Library.loc("fx_hack_spell", "grant_0").is_empty(),
			"Granted text reads from the card's grant text"):
		return false
	# The lane-then-position stepper: Redeploy (unit, lane, position).
	var mover = engine._make_unit(fixtures.get_card("fx_regen_2"), 0, false)
	engine._spawn(mover, 0)
	_act_in_lane_zero(["fx_move_any"])
	await _settle()
	var revision_before = int(engine.state.revision)
	if not _require(screen.select_card(0) and screen.current_step_type() == "unit", "Redeploy asks for a unit first"):
		return false
	screen.target_unit(int(mover.uid))
	if not _require(screen.current_step_type() == "lane" and screen.board.overview and screen.board.lanes[1].drop_state == 1,
			"The lane step opens the overview and lights the lanes"):
		return false
	_click(screen.lane_point(1))
	var ghosts: Array = screen.board.lanes[1].ghost_slots
	if not _require(screen.current_step_type() == "position" and not screen.board.overview and screen.board.focus_lane == 1 and not ghosts.is_empty(),
			"After the lane, ghost positions show in the chosen lane"):
		return false
	_click(screen.slot_point(int(ghosts[0].position)))
	await _settle()
	if not _require(int(engine.state.revision) == revision_before + 1 and int(engine.find_unit(int(mover.uid)).get("lane", -1)) == 1,
			"Choosing a position moves the unit to that lane"):
		return false
	# An improvement choice: Raze on the enemy's improvement.
	var target = Zones.add_improvement(engine, "fx_improvement_ping", 1, 0)
	_act_in_lane_zero(["fx_raze"])
	await _settle()
	screen.view_lane(0)
	if not _require(screen.select_card(0) and screen.current_step_type() == "improvement", "Raze asks for an improvement"):
		return false
	var chip = screen.board.improvement_chip(int(target.oid))
	if not _require(chip != null and chip.target_state == 1, "Candidate improvement chips light up"):
		return false
	_click(screen.improvement_point(int(target.oid)))
	await _settle()
	if not _require(engine.find_object(int(target.oid)).is_empty() and screen.board.improvement_chip(int(target.oid)) == null,
			"Clicking the chip condemns that improvement and its chip leaves"):
		return false
	# An improvement chip click: your Arrow Tower's Volley.
	var tower_piece = Zones.add_improvement(engine, "fx_improvement_ping", 0, 0)
	_act_in_lane_zero([])
	await _settle()
	chip = screen.board.improvement_chip(int(tower_piece.oid))
	if not _require(chip != null and chip.usable, "An own improvement with a ready ability glows"):
		return false
	revision_before = int(engine.state.revision)
	_click(screen.improvement_point(int(tower_piece.oid)))
	await _settle()
	if not _require(int(engine.state.revision) == revision_before + 1 and int(engine.find_object(int(tower_piece.oid)).object.cd) > 0,
			"Clicking the chip uses its ability"):
		return false
	# An item ability click: Swift Boots move their hero to a chosen lane.
	var hero: Dictionary = roster[1]
	Zones.equip(engine, hero, "fx_blink_item")
	_act_in_lane_zero([])
	await _settle()
	var point = screen.item_ability_point(int(hero.uid), "accessory")
	var hero_card = screen.board.unit_card(int(hero.uid))
	if not _require(point != Vector2.ZERO and hero_card.item_ability("accessory").get("ready", false), "An equipped item with a ready ability is a button"):
		return false
	_click(point)
	if not _require(screen.current_step_type() == "lane", "Clicking the item asks for its lane choice"):
		return false
	screen.choose_lane(2)
	await _settle()
	if not _require(int(hero.lane) == 2 and int(hero.item_state.accessory.cd) > 0, "The item ability moves its hero and starts its cooldown"):
		return false
	if not await _check_m2_animations():
		return false
	return await _check_m2_review()

## Regressions for the M2 UI review: the "+n" chip opens its lane's rows
## (click or hover) and glows for a ready hidden chip; hidden chips have no
## point; marks draw above every chip; hand notes (no repeated lock reason,
## singulars) show beside the lifted card; the lane-step hint stays clear of
## the units; a health status is not floated twice.
func _check_m2_review() -> bool:
	var engine = _engine()
	var roster: Array = engine.state.players[0].roster
	for index in [0, 1, 2, 4]:
		_place_in_lane(roster[index], 10)
	var added: Array = []
	for card_id in ["fx_countdown", "fx_library", "fx_glyph", "fx_library"]:
		added.append(Zones.add_improvement(engine, card_id, 0, 0))
	var hidden_ping = Zones.add_improvement(engine, "fx_improvement_ping", 0, 0)
	added.append(hidden_ping)
	var hand_cards = ["fx_stun_spell", "fx_counter_spell", "fx_swap", "fx_raze"]
	var hand_fields = [{"lock": 2}, {}, {"hacks": ["fx_hack_spell#0"]}, {"lock": 1}]
	_act_in_lane_zero(hand_cards, hand_fields)
	await _settle()
	screen.view_lane(0)
	await _settle()
	var lane = screen.board.lanes[0]
	var more: Control = lane.more_chips[1]
	if not _require(engine.state.lanes[0].improvements[0].size() > 6 and more.visible and more.count > 0 and more.usable,
			"The \"+n\" chip shows and glows while a hidden own chip is ready (count %d, usable %s)" % [more.count, more.usable]):
		return false
	if not _require(screen.improvement_point(int(hidden_ping.oid)) == Vector2.ZERO, "A hidden chip has no point (Vector2.ZERO)"):
		return false
	_mouse(Vector2(8, 8))
	_click(screen.more_chip_point(0, true))
	if not _require(screen.open_chip_lane() == 0 and lane.chip_expand and screen.improvement_point(int(hidden_ping.oid)) != Vector2.ZERO,
			"Clicking \"+n\" opens the lane's rows and shows the hidden chips"):
		return false
	var marks_index = lane.get_children().find(lane._chip_marks)
	if not _require(lane.improvement_rows[1].all(func(chip): return lane.get_children().find(chip) < marks_index),
			"Chip marks draw in a pass above every chip"):
		return false
	_mouse(screen.improvement_point(int(hidden_ping.oid)))
	if not _require(lane.hovered_chip == screen.board.improvement_chip(int(hidden_ping.oid)) and lane.improvement_at(screen.improvement_point(int(hidden_ping.oid))) == lane.hovered_chip,
			"The hovered chip of an open row is drawn in front and takes the click"):
		return false
	_click(screen.improvement_point(int(hidden_ping.oid)), MOUSE_BUTTON_RIGHT)
	if not _require(screen.inspect.visible, "A chip the \"+n\" chip hid can be inspected"):
		return false
	screen.inspect.close()
	var revision_before = int(engine.state.revision)
	_click(screen.improvement_point(int(hidden_ping.oid)))
	await _settle()
	if not _require(int(engine.state.revision) == revision_before + 1 and int(engine.find_object(int(hidden_ping.oid)).object.cd) > 0,
			"A chip the \"+n\" chip hid can be used"):
		return false
	_act_in_lane_zero(hand_cards, hand_fields)
	await _settle()
	screen.view_lane(0)
	await _settle()
	if not _require(screen.open_chip_lane() == 0 and lane.chip_expand, "The rows stay open while the pointer is on them"):
		return false
	_mouse(screen.lane_point(0))
	if not _require(screen.open_chip_lane() == -1 and not lane.chip_expand, "Leaving the open rows closes them"):
		return false
	_mouse(screen.more_chip_point(0, true))
	if not _require(screen.open_chip_lane() == 0 and lane.chip_expand, "Hovering \"+n\" opens the rows too"):
		return false
	_mouse(screen.lane_point(0))
	if not _require(screen.open_chip_lane() == -1, "and they close again"):
		return false
	# Hand notes: no repeated lock reason, singulars, beside the lifted card.
	var notes = [screen.hand.note_text(0), screen.hand.note_text(1), screen.hand.note_text(3)]
	if not _require(notes[0] == UiKit.t_n("BADGE_LOCK", 2) and notes[1].ends_with(EventText.t("BADGE_CHARGES_ONE")) and notes[2] == EventText.t("BADGE_LOCK_ONE"),
			"Hand notes skip the repeated lock reason and use singulars (%s)" % [notes]):
		return false
	if not _require(EventText.t("BADGE_LOCK_ONE") != "BADGE_LOCK_ONE" and UiKit.t_n("BADGE_CHARGES", 2) == EventText.t("BADGE_CHARGES", {"n": 2}),
			"Singular and plural mark strings exist"):
		return false
	# M4: a hacked card's note quotes the text the hack added (the holder's own information).
	var hack_text = Library.loc("fx_hack_spell", "grant_0")
	if not _require(not hack_text.is_empty() and screen.hand.note_text(2).find(EventText.t("EV_CHANGE_GRANT", {"text": hack_text})) != -1,
			"A hacked card's note shows the added text (%s)" % screen.hand.note_text(2)):
		return false
	AnimationQueue.instant = false
	_mouse(screen.hand_card_point(2))
	await create_timer(0.9).timeout
	var card_rect: Rect2 = screen.hand.cards[2].get_global_rect()
	var note_rect: Rect2 = screen.hand._note.get_global_rect()
	AnimationQueue.instant = true
	if not _require(screen.hand.shown_note() == screen.hand.note_text(2) and not screen.hand.note_text(2).is_empty() and not note_rect.intersects(card_rect),
			"The hovered card's note shows beside it, not over its text (%s vs %s)" % [note_rect, card_rect]):
		return false
	_mouse(screen.lane_point(0))
	await _settle()
	# The lane-step hint sits below the lane panels in the overview.
	var mover = engine._make_unit(engine.library.get_card("fx_regen_2"), 0, false)
	engine._spawn(mover, 0)
	_act_in_lane_zero(["fx_move_any"])
	await _settle()
	screen.view_lane(0)
	if not _require(screen.select_card(0) and screen.target_unit(int(mover.uid)) and screen.current_step_type() == "lane" and screen.board.overview,
			"Redeploy reaches its lane step"):
		return false
	_mouse(screen.lane_point(1))
	await _settle()
	var hint: Rect2 = screen.hint_label.get_global_rect()
	var covered: Array = []
	for each_lane in screen.board.lanes:
		for uid in each_lane.cards:
			if each_lane.cards[uid].get_global_rect().intersects(hint):
				covered.append(uid)
	if not _require(screen.hint_label.visible and covered.is_empty(), "The lane-step hint covers no unit (%s, %s)" % [hint, covered]):
		return false
	_click(Vector2(8, 8), MOUSE_BUTTON_RIGHT)
	await _settle()
	# A health status floats once: its unit is marked as animated for the sync.
	var context = {"hit": {}}
	var target = engine.state.lanes[0].units[0].filter(func(unit): return unit != null)[0]
	await screen._anim_status({"k": "status", "id": int(target.uid), "card": str(target.card), "st": {"max_health": 1}, "kw": {}, "until": "round"}, 0, context)
	if not _require(context.hit.has(int(target.uid)), "A health status marks its unit so the sync does not float it again"):
		return false
	return true

## Waits in real time (up to `limit` seconds) for the presentation queue,
## confirming hot-seat hand-overs.
func _settle_real(limit: float = 15.0) -> void:
	var deadline = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if screen.pass_screen.visible:
			screen.pass_screen.confirm()
		if not screen.queue.busy and not screen.pass_screen.visible:
			return
		await process_frame

## Player 0 acts and keeps the initiative (a test shortcut, so every event
## animates from player 0's side); the board then catches up in real time.
func _act_as_zero(command: Dictionary) -> bool:
	var engine = _engine()
	var result: Dictionary = engine.apply_action(0, command)
	if engine.state.phase == "action" and int(engine.state.winner) == -1:
		engine.state.active_player = 0
		engine.state.first_pass = -1
	app.controller.refresh()
	await _settle_real()
	return result.get("ok", false)

## Every M2 event animation (spec §8.7) plays in real time, sped up, without a
## script error: statuses, locks, hacks, charges, an improvement's ability and
## damage, condemn and an improvement leaving, a cross-lane move with the
## camera following, a swap, a control change, a summon, Pulses, gold, and a
## combat with cleave and retaliation followed by the next lane's triggers.
func _check_m2_animations() -> bool:
	var engine = _engine()
	var fixtures = engine.library
	var roster: Array = engine.state.players[0].roster
	for index in [0, 1, 2, 4]:
		_place_in_lane(roster[index], 10)
	for card_id in ["fx_cleave_3", "fx_quick_creep", "fx_soulbound_creep"]:
		engine._spawn(engine._make_unit(fixtures.get_card(card_id), 0, false), 0)
	for card_id in ["fx_retaliate_2", "fx_regen_2", "fx_bounty_creep"]:
		engine._spawn(engine._make_unit(fixtures.get_card(card_id), 1, false), 0)
	Zones.add_improvement(engine, "fx_improvement_ping", 1, 0)
	Zones.add_improvement(engine, "fx_glyph", 1, 1)
	var own_ping = Zones.add_improvement(engine, "fx_improvement_ping", 0, 0)
	Zones.add_improvement(engine, "fx_improvement_ping", 0, 1)
	_give_hand(1, ["fx_swap", "fx_raze", "fx_swap", "fx_stun_spell"])
	var plays = ["fx_stun_spell", "fx_lock_spell", "fx_hack_spell", "fx_counter_spell", "fx_charge_spell", "fx_raze", "fx_move_any",
		"fx_swap", "fx_control", "fx_summon_hero", "fx_shield_spell", "fx_purge_spell", "fx_curse_spell", "fx_next_combat_spell"]
	_act_in_lane_zero(plays + ["fx_counter_spell"])
	engine.state.lanes[0].mana[0] = 99
	AnimationQueue.instant = false
	AnimationQueue.speed = 6.0
	await _settle_real()
	var played = 0
	for card_id in plays:
		var index = engine.state.players[0].hand.find(card_id)
		var command: Dictionary = {}
		for action in engine.legal_actions(0):
			if action.get("type", "") == "play" and int(action.get("hand", -1)) == index:
				command = action
				break
		if not command.is_empty() and await _act_as_zero(command):
			played += 1
	var quick: Array = engine.state.lanes[0].units[0].filter(func(unit): return unit != null and str(unit.card) == "fx_quick_creep")
	for source in [int(own_ping.oid), int(roster[1].uid), int(quick[0].uid) if not quick.is_empty() else -1]:
		if {"type": "ability", "unit": source} in engine.legal_actions(0):
			await _act_as_zero({"type": "ability", "unit": source})
	# Both players pass: combat in lane 0, then lane 1 opens with its triggers.
	for turn in range(2):
		if engine.state.phase == "action":
			app.act({"type": "pass"})
			await _settle_real()
	AnimationQueue.speed = 1.0
	AnimationQueue.instant = true
	await _settle()
	if not _require(played >= 10, "The fixture cards play through the board (%d of %d)" % [played, plays.size()]):
		return false
	var kinds: Dictionary = {}
	for event in engine.state.events:
		kinds[str(event.get("k", ""))] = true
	for kind in ["status", "lock", "hack", "charged", "damage", "condemn", "improvement_gone", "move", "swap", "control",
			"summon", "pulse", "combat", "lane_open", "gold"]:
		if not _require(kinds.has(kind), "The animated sequence produced a %s event" % kind):
			return false
	return _require(screen.shown_seq == int(engine.state.event_seq) and not screen.queue.busy,
		"The board caught up with every animated event")

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
