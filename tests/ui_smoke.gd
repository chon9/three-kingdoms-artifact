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
## animation played in real time (sped up) without a script error. The
## deck screens: the deck list from the main menu, the builder driven by
## clicks and drags (a hero clicked in, its locked signature cards, a hero
## dragged onto a round slot, slots swapped, copies added to the limit and
## removed with "-" and by dragging rows and heroes back), filters, inspect,
## code import (bad and good) and export, both sizes and languages, saving,
## and playing the saved deck against the AI; the guest's deck picker. For
## v0.6.1: hand cards repainted when they stop being playable, the
## your-action cue (exactly when the action becomes yours), the card history
## (tiles, privacy, placement, the log at a tile), the result's buttons
## offline and online, the online room and the match intro.
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
const DeckStore = preload("res://scripts/core/deck_store.gd")
const DeckListDialog = preload("res://scripts/ui/deck_list_dialog.gd")
const DeckBuilderDialog = preload("res://scripts/ui/deck_builder_dialog.gd")
const DecksDialog = preload("res://scripts/ui/decks_dialog.gd")
const CatalogDialog = preload("res://scripts/ui/catalog_dialog.gd")
const MatchScreen = preload("res://scripts/ui/match_screen.gd")
const HistoryRail = preload("res://scripts/ui/history_rail.gd")
const VersusIntro = preload("res://scripts/ui/versus_intro.gd")
const GameOverOverlay = preload("res://scripts/ui/game_over_overlay.gd")
const Music = preload("res://scripts/ui/music.gd")
## The test's own deck folder (never the player's user://decks).
const UI_DECKS = "res://.tools/scratch/ui_smoke_decks"
## Valve's README example code (Green/Black).
const VALVE_CODE = "ADCJWkTZX05uwGDCRV4XQGy3QGLmqUBg4GQJgGLGgO7AaABR3JlZW4vQmxhY2sgRXhhbXBsZQ__"
const WATCHDOG_SECONDS = 240.0
var app
var screen
var checks = 0
var errors = ErrorCatcher.new()
## The player's own settings file, restored on exit (dialogs persist choices).
var saved_settings = null
## What each tracked card last painted: [playable, dimmed, selected, hovered].
var painted: Dictionary = {}

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
	DeckStore.root = UI_DECKS
	_clear_decks()
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
	catalog.apply_filter("neutral")
	var neutral_ids = catalog.cards.filter(func(card): return card.visible).map(func(card): return card.card_id)
	catalog.apply_filter("red")
	var red_ids = catalog.cards.filter(func(card): return card.visible).map(func(card): return card.card_id)
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
	if not _require(["blink_dagger", "stonehall_pike", "apotheosis_blade", "book_of_the_dead", "shop_deed", "golden_ticket", "fountain_flask"].all(func(card_id): return card_id in neutral_ids)
			and "duel" not in neutral_ids and "gank" not in neutral_ids,
			"The neutral filter shows the M6 items (%d neutral)" % neutral_ids.size()):
		return
	# M7: every Classic card is in the catalog, the 39 improvements under their colours.
	if not _require(total == 303 and ["burning_oil", "grand_melee", "the_omexe_arena", "path_of_the_bold"].all(func(card_id): return card_id in red_ids)
			and ["cheating_death", "altar_of_the_mad_moon", "path_of_the_dreamer"].all(func(card_id): return card_id in green_ids)
			and ["glyph_of_confusion", "aghanims_sanctum", "watchtower"].all(func(card_id): return card_id in blue_ids)
			and ["the_oath", "steam_cannon", "bitter_enemies", "revtel_investments"].all(func(card_id): return card_id in black_ids)
			and "the_oath" not in red_ids and "burning_oil" not in neutral_ids,
			"The catalog holds all 303 Classic cards, each colour filter its M7 improvements (%d red)" % red_ids.size()):
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
	if not await _check_deck_builder():
		return
	if not await _check_deck_review():
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
	if not await _check_m6_ui():
		return
	if not await _check_m7_ui():
		return
	if not await _check_hand_repaint():
		return
	if not await _check_turn_cue():
		return
	if not await _check_history():
		return
	if not await _check_result_flows():
		return
	if not await _check_room_screen():
		return
	if not await _check_versus_intro():
		return
	if not await _check_long_names():
		return
	if not await _check_host_left_result():
		return
	if not await _check_music():
		return
	if not await _check_hud_hover():
		return
	app.show_main_menu()
	if not _require(app.menu.visible and app.menu.buttons.resume.visible, "The main menu offers to resume the match"):
		return
	await process_frame
	if not _require(errors.messages.is_empty(), "No engine or script errors during the run: %s" % "; ".join(errors.messages)):
		return
	print("PASS: %d UI checks: hot-seat phases, coin, shop hold/buy, deployment staging, re-planning, take-back, commit lock, privacy and reveal (instant and skipped), the fountain HUD, drag-play (untargeted, targeted, creep positions), Battlefield Control (click and drag), edge lane switching, a 14-card hand, ability badge, inspect, locale and skin switching (incl. rebuilt tooltips), dialogs and their fit, deck selection, AI turn, replay restoration, and the M2 pieces (status icons, tower badges, lock badges, the lane-then-position stepper, an improvement choice, chip and item ability clicks, the \"+n\" chip rows, hand notes, the lane-step hint, every event animation in real time), and the M3 pieces (Dark Seer's unit-then-lane ability, the full catalog and its colour filters), and the M4 pieces (Friendly Fire's unordered pair picked in either order, a hacked card's note quoting its text and kept clear of the coin, the blue catalog filter), and the M5 pieces (Winter Wyvern's position-only ability, the black catalog filter), and the M6 pieces (an item active aimed at a unit from its item slot, Secret Shop prices under Shop Deeds, deeds on the players' plates, a purchase that pays gold in the log, the items in the catalog), and the M7 pieces (The Oath's forbidden spells and creeps with their reason, an improvement active aimed at a unit from its chip, the improvements in the catalog), and the deck builder (deck list, click and drag edits, locked signature cards, round slots, filters, code import and export, saving, playing a saved deck against the AI, the guest's deck picker), and v0.6.1 (hand repaint, your-action cue, card history, result buttons, the room, the match intro), and v0.6.2 (the music states driven by real match events, crossfades, music and effect volumes, the lane HUD's hero hover cards and inspect)." % checks)
	app.queue_free()
	await process_frame
	# The audio thread releases the stopped music tracks on its next mixes.
	await create_timer(0.3).timeout
	_clear_decks()
	DeckStore.root = DeckStore.DEFAULT_ROOT
	_restore_settings()
	quit(0)

## The M6 UI (spec §12 M6): Keenfolk Musket's active clicked on its item slot
## and aimed at a unit; under a Shop Deed the Secret Shop offer is free and
## says so, with two it pays gold, and the purchase is logged as paid; both
## players' plates show the deeds zone (RQ-41).
func _check_m6_ui() -> bool:
	app.deck_selections = ["starter", "starter"]
	app.start_match(MatchController.MODE_LOCAL)
	await _settle()
	var engine = _engine()
	var hero: Dictionary = engine.state.players[0].roster[0]
	_place_in_lane(hero, 10)
	Zones.equip(engine, hero, "keenfolk_musket")
	var mark = engine._make_creep(1)
	engine._spawn(mark, 0)
	_act_in_lane_zero([])
	await _settle()
	var point = screen.item_ability_point(int(hero.uid), "weapon")
	if not _require(point != Vector2.ZERO, "Keenfolk Musket's item slot is an ability button"):
		return false
	_click(point)
	if not _require(screen.current_step_type() == "unit", "Clicking the Musket asks for a unit"):
		return false
	screen.target_unit(int(mark.uid))
	await _settle()
	if not _require(int(mark.health) == 2 and int(hero.item_state.weapon.cd) == 2,
			"The Musket deals 2 damage to the chosen unit and starts its own cooldown (health %d, cooldown %d)" % [int(mark.health), int(hero.item_state.weapon.cd)]):
		return false
	# Shop Deeds: the Secret Shop offer's price after the rules layer.
	app.local_player = 0
	engine.state.players[0].deeds = [{"oid": Kernel.next_oid(engine), "card": "shop_deed", "owner": 0}]
	engine.state.phase = "shop"
	for owner in engine.state.players:
		owner.finished = false
		owner.shop = {"secret": "claymore", "item": "", "consumable": "healing_salve"}
	engine.state.players[0].gold = 0
	app.controller.refresh()
	await _settle()
	var secret: Dictionary = screen.shop.slots.secret
	if not _require(screen.shop.visible and secret.card.price_override == 0 and secret.label.text.find(UiKit.t("SHOP_PRICE_FREE")) != -1
			and screen.shop.slots.consumable.card.price_override == 3 and not secret.buy.disabled,
			"Under a Shop Deed the Secret Shop offer is free, says so and can be bought with no gold (%s)" % secret.label.text):
		return false
	if not _require(screen.own_panel.deeds == ["shop_deed"] and screen.own_panel.tooltip_text.find(Library.loc("shop_deed")) != -1 and screen.enemy_panel.deeds.is_empty(),
			"The player's plate shows its deed, the opponent's none (%s)" % screen.own_panel.tooltip_text):
		return false
	engine.state.players[0].deeds.append({"oid": Kernel.next_oid(engine), "card": "shop_deed", "owner": 0})
	app.controller.refresh()
	await _settle()
	if not _require(secret.card.price_override == -14 and secret.label.text.find(UiKit.t("SHOP_PRICE_PAYS", {"gold": 14})) != -1,
			"With two deeds the Claymore offer pays 14 gold (%s)" % secret.label.text):
		return false
	secret.buy.pressed.emit()
	await _settle()
	var bought = engine.state.events.filter(func(event): return str(event.get("k", "")) == "buy")
	var line = EventText.format(bought.back()) if not bought.is_empty() else ""
	if not _require(int(engine.state.players[0].gold) == 14 and line.find("14") != -1 and line.find("-14") == -1,
			"Buying it pays 14 gold, and the log says so (%s)" % line):
		return false
	return true

## The M7 UI (spec §12 M7): with The Oath in the active lane your spells and
## creeps are dimmed and their note gives REASON_FORBIDDEN, while an
## improvement and an item stay playable; the opponent's hand is not
## restricted. An improvement's active with a choice (Keenfolk Turret, played
## this round, RQ-24) is used from its chip: the click asks for a unit, which
## takes 2 piercing damage, and the improvement starts its cooldown.
func _check_m7_ui() -> bool:
	app.deck_selections = ["starter", "starter"]
	app.start_match(MatchController.MODE_LOCAL)
	await _settle()
	var engine = _engine()
	var debbi: Dictionary = {}
	for hero in engine.state.players[0].roster:
		if str(hero.card) == "debbi":
			debbi = hero
	if not _require(not debbi.is_empty(), "The starter deck has Debbi, a black hero"):
		return false
	_place_in_lane(debbi, 5)
	Zones.add_improvement(engine, "the_oath", 0, 0)
	var mark = engine._make_creep(1)
	engine._spawn(mark, 0)
	_act_in_lane_zero(["hip_fire", "untested_grunt", "trebuchets", "short_sword"])
	await _settle()
	var forbidden = UiKit.t("REASON_FORBIDDEN")
	var cards: Array = screen.hand.cards
	var notes: Array = cards.map(func(card): return str(card.get_meta("note", "")))
	if not _require(cards.size() == 4 and not cards[0].playable and cards[0].dimmed and notes[0].find(forbidden) != -1
			and not cards[1].playable and notes[1].find(forbidden) != -1 and cards[2].playable and cards[3].playable,
			"The Oath dims your spells and creeps in its lane with \"%s\"; improvements and items stay playable (%s)" % [forbidden, notes]):
		return false
	if not _require(engine.rules_of(0).forbid_play.size() == 1 and engine.rules_of(1).forbid_play.is_empty(), "The Oath restricts only its owner"):
		return false
	var turret = Zones.add_improvement(engine, "keenfolk_turret", 0, 0)
	_act_in_lane_zero([])
	await _settle()
	var chip = screen.board.improvement_chip(int(turret.oid))
	if not _require(chip != null and chip.usable, "Keenfolk Turret's chip glows: an improvement played this round can use its active (RQ-24)"):
		return false
	var health = int(mark.health)
	_click(screen.improvement_point(int(turret.oid)))
	if not _require(screen.current_step_type() == "unit", "Clicking Keenfolk Turret's chip asks for a unit"):
		return false
	screen.target_unit(int(mark.uid))
	await _settle()
	if not _require(int(mark.health) == health - 2 and int(engine.find_object(int(turret.oid)).object.cd) == 1 and not screen.board.improvement_chip(int(turret.oid)).usable,
			"The Turret deals 2 piercing damage to the chosen unit and goes on cooldown (health %d of %d)" % [int(mark.health), health]):
		return false
	return true

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

# --- Decks: the deck list and the builder ---------------------------------------------------

func _clear_decks() -> void:
	if DirAccess.dir_exists_absolute(UI_DECKS):
		for file_name in DirAccess.get_files_at(UI_DECKS):
			DirAccess.remove_absolute("%s/%s" % [UI_DECKS, file_name])

## A real mouse drag: press, eight held motions with their relative movement
## (Godot's drag and drop starts from it), release.
func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from)
	_mouse(from, MOUSE_BUTTON_LEFT, true)
	var last = from
	for step in range(1, 9):
		var point = from.lerp(to, step / 8.0)
		var motion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = point
		motion.global_position = point
		motion.relative = point - last
		root.push_input(motion, true)
		last = point
	_mouse(to, MOUSE_BUTTON_LEFT, false)

func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func _top_dialog():
	var open: Array = app.dialogs()
	return open.back() if not open.is_empty() else null

## Scrolls a collection card into view and returns its centre.
func _card_point(builder, card_id: String) -> Vector2:
	var card = builder.collection_card(card_id)
	builder.collection_scroll.ensure_control_visible(card)
	await process_frame
	await process_frame
	return _center(card)

func _check_deck_builder() -> bool:
	var selections_before: Array = app.deck_selections.duplicate(true)
	app.show_main_menu()
	app.menu.action_requested.emit("decks")
	await process_frame
	await process_frame
	var list = _top_dialog()
	if not _require(list is DeckListDialog, "Main menu Decks opens the deck list"):
		return false
	if not _require(list.decks.is_empty() and list.entry_buttons.size() == 24 and list.panel.get_global_rect().end.y <= 900.0
			and list.actions.play.is_visible_in_tree(), "The deck list shows the 24 presets and no own decks yet, and fits"):
		return false
	# A preset is read-only: Edit a copy opens a new deck from it; leaving it
	# unsaved asks first.
	list.select("preset", "green_assault")
	if not _require(not list.actions.rename.visible and not list.actions.delete.visible and list.actions.edit.text == UiKit.t("DECKLIST_EDIT_COPY"),
			"A preset offers Edit a copy, not Rename or Delete"):
		return false
	list.actions.edit.pressed.emit()
	await process_frame
	await process_frame
	var copy = _top_dialog()
	if not _require(copy is DeckBuilderDialog and copy.is_new and copy.deck.heroes == Library.new().preset("green_assault").heroes and copy.issues.is_empty()
			and copy.deck.name.find(Library.preset_text("green_assault")) != -1, "Editing a preset opens a new copy of it (%s)" % copy.deck.get("name", "")):
		return false
	copy.close()
	if not _require(copy.prompt != null and copy.prompt.is_inside_tree() and copy.is_inside_tree(), "Leaving an unsaved deck asks first"):
		return false
	copy.prompt.confirm_button.pressed.emit()
	await process_frame
	await process_frame
	list = _top_dialog()
	if not _require(list is DeckListDialog and DeckStore.list().is_empty(), "Leaving without saving returns to the list and stores nothing"):
		return false
	list.new_button.pressed.emit()
	await process_frame
	await process_frame
	var builder = _top_dialog()
	if not _require(builder is DeckBuilderDialog and builder.is_new and builder.deck.heroes == ["", "", "", "", ""],
			"New deck opens an empty builder"):
		return false
	if not _require(builder.panel.get_global_rect().end.y <= 900.0 and builder.play_button.is_visible_in_tree() and builder.play_button.disabled
			and builder.collection.size() == builder.eligible_cards().size() and builder.collection.size() > 200,
			"The builder fits, lists every deckable card (%d), and Play waits for a legal deck" % builder.collection.size()):
		return false
	if not _check_collection_contents(builder):
		return false
	# A click adds a hero to the first slot, with its locked signature cards.
	_click(await _card_point(builder, "axe"))
	await process_frame
	var signature_row = builder.rows.get("berserkers_call")
	if not _require(builder.deck.heroes[0] == "axe" and signature_row != null and signature_row.locked and not signature_row.minus.visible
			and int(builder.deck.cards.get("berserkers_call", 0)) == 3, "Clicking a hero fills slot 1 and locks its three signature cards in the list"):
		return false
	if not _require(not builder.remove_card("berserkers_call") and int(builder.deck.cards.berserkers_call) == 3, "A signature card cannot be removed on its own"):
		return false
	# Drag a hero onto the round 3 slot, then move a hero by dragging its slot.
	_drag(await _card_point(builder, "debbi"), _center(builder.hero_slots[4]))
	await process_frame
	if not _require(builder.deck.heroes[4] == "debbi" and int(builder.deck.cards.get("no_accident", 0)) == 3,
			"Dragging a hero onto the round 3 slot puts it there (%s)" % [builder.deck.heroes]):
		return false
	_drag(_center(builder.hero_slots[0]), _center(builder.hero_slots[3]))
	await process_frame
	if not _require(builder.deck.heroes == ["", "", "", "axe", "debbi"], "Dragging a hero onto another slot moves it to that round (%s)" % [builder.deck.heroes]):
		return false
	# Copies: clicks add up to three, the fourth is refused.
	var payday = await _card_point(builder, "payday")
	for click in range(4):
		_click(payday)
		await process_frame
	if not _require(int(builder.deck.cards.get("payday", 0)) == 3 and builder.collection_card("payday").dimmed, "Clicks add copies up to three; the card dims at its limit"):
		return false
	_click(_center(builder.rows["payday"].minus))
	await process_frame
	if not _require(int(builder.deck.cards.get("payday", 0)) == 2, "The row's - removes a copy"):
		return false
	_drag(_center(builder.rows["payday"]) + Vector2(-80, 0), _center(builder.collection_scroll))
	await process_frame
	if not _require(int(builder.deck.cards.get("payday", 0)) == 1, "Dragging a row back to the collection removes a copy"):
		return false
	_drag(await _card_point(builder, "payday"), _center(builder.list_scroll))
	await process_frame
	if not _require(int(builder.deck.cards.get("payday", 0)) == 2, "Dragging a card onto the deck list adds a copy"):
		return false
	_drag(_center(builder.hero_slots[4]), _center(builder.collection_scroll))
	await process_frame
	if not _require(builder.deck.heroes[4] == "" and not builder.deck.cards.has("no_accident"), "Dragging a hero back to the collection removes it and its signature cards"):
		return false
	# Right-click inspects.
	_click(await _card_point(builder, "payday"), MOUSE_BUTTON_RIGHT)
	if not _require(builder.inspector.visible and builder.inspector.title_label.text == Library.loc("payday"), "Right-clicking a card inspects it"):
		return false
	_click(Vector2(720, 450))
	if not _require(not builder.inspector.visible, "A click closes the builder's inspector"):
		return false
	# Filters: kind, cost, slot, colour, search.
	builder.set_kind_filter("hero")
	var shown: Array = builder.shown_cards()
	if not _require(shown.size() == 48 and shown.all(func(card_id): return str(Library.raw_definition(card_id).get("kind", "")) == "hero"),
			"The hero filter shows all 48 heroes, Lich and Kanna included (%d)" % shown.size()):
		return false
	builder.set_kind_filter("hero")
	builder.set_cost_filter(8)
	shown = builder.shown_cards()
	var costly = func(card_id): return int(Library.raw_definition(card_id).get("cost", 0)) >= 8 and str(Library.raw_definition(card_id).get("kind", "")) in ["creep", "spell", "improvement"]
	if not _require(not shown.is_empty() and shown.all(costly), "The 8+ cost filter shows only main cards costing 8 or more"):
		return false
	builder.set_cost_filter(8)
	builder.set_kind_filter("weapon")
	shown = builder.shown_cards()
	if not _require(not shown.is_empty() and shown.all(func(card_id): return str(Library.raw_definition(card_id).get("slot", "")) == "weapon"), "The weapon filter shows weapons"):
		return false
	builder.set_kind_filter("weapon")
	builder.set_color_filter("blue")
	shown = builder.shown_cards()
	if not _require(not shown.is_empty() and shown.all(func(card_id): return CatalogDialog.filter_of(card_id) == "blue"), "The Wei (blue) filter"):
		return false
	builder.set_color_filter("all")
	builder.set_search(Library.loc("jmuy"))
	shown = builder.shown_cards()
	if not _require("jmuy" in shown and shown.size() < 10, "Search finds a hero by its name in the current language (%s)" % Library.loc("jmuy")):
		return false
	builder.set_search("")
	if not _require(builder.shown_cards().size() == builder.collection.size(), "Clearing the filters shows every card again"):
		return false
	# Import: a damaged code explains itself; Valve's example code fills the deck.
	var box = builder.open_import()
	await process_frame
	box.field.text = VALVE_CODE.substr(0, VALVE_CODE.length() - 12)
	box.confirm_button.pressed.emit()
	if not _require(box.is_inside_tree() and box.error_label.visible and box.error_label.text.find("{") == -1 and not box.error_label.text.begins_with("ERR_"),
			"A damaged code keeps the import box open with a localized reason (%s)" % box.error_label.text):
		return false
	box.field.text = "  https://playartifact.com/d/" + VALVE_CODE + "  "
	box.confirm_button.pressed.emit()
	await process_frame
	if not _require((not is_instance_valid(box) or not box.is_inside_tree()) and builder.deck.name == "Green/Black Example" and builder.issues.is_empty()
			and builder.lamps.states.all(func(met): return met) and not builder.play_button.disabled,
			"Importing Valve's example code gives a legal deck: every lamp green, Play enabled (%s)" % [builder.issues]):
		return false
	if not _require(builder.deck.heroes[3] == "debbi" and builder.deck.heroes[4] == "chen" and builder.name_field.text == "Green/Black Example",
			"The imported heroes keep their deploy rounds (%s)" % [builder.deck.heroes]):
		return false
	if not _require(builder.export_code() == VALVE_CODE and builder.prompt.field.text == VALVE_CODE, "Copy code gives back the same code"):
		return false
	builder.prompt.cancel()
	# Both languages and the smaller window.
	app.set_locale("en")
	if not _require(builder.title_label.text == "Deck builder" and builder.save_button.text.begins_with("Save"), "The builder re-renders in English"):
		return false
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	var small: Rect2 = builder.panel.get_global_rect()
	var fits_small = small.position.x >= 0.0 and small.position.y >= 0.0 and small.end.x <= screen.size.x + 1.0 and small.end.y <= screen.size.y + 1.0 \
		and builder.play_button.is_visible_in_tree() and builder.list_scroll.size.y > 120.0 and builder.collection_scroll.size.y > 200.0
	root.size = Vector2i(1440, 900)
	await process_frame
	await process_frame
	app.set_locale("zh_CN")
	if not _require(fits_small and builder.title_label.text == UiKit.t("DECKB_TITLE"), "The builder fits a 1280x720 window (%s) and switches back to Chinese" % small):
		return false
	# Save, back to the list, play it against the AI.
	builder.save_button.pressed.emit()
	var stored = DeckStore.list()
	if not _require(stored.size() == 1 and stored[0].name == "Green/Black Example" and builder.deck.id == stored[0].id and not builder.dirty()
			and FileAccess.file_exists("%s/%s.json" % [UI_DECKS, stored[0].id]), "Save writes the deck to the deck folder"):
		return false
	builder.close_button.pressed.emit()
	await process_frame
	await process_frame
	list = _top_dialog()
	if not _require(list is DeckListDialog and list.selected.get("id", "") == stored[0].id and list.entry_buttons.has("custom:" + stored[0].id)
			and not list.actions.play.disabled, "Back returns to the deck list with the saved deck selected and playable"):
		return false
	# Duplicate, rename and delete (through its confirmation).
	list.actions.duplicate.pressed.emit()
	var two = DeckStore.list()
	if not _require(two.size() == 2 and list.selected.get("id", "") != stored[0].id and list.selected_deck().heroes == stored[0].heroes,
			"Duplicate saves a copy and selects it"):
		return false
	var renamer = list.open_rename()
	renamer.field.text = "  Shu [Vanguard]  "
	renamer.confirm_button.pressed.emit()
	if not _require(list.selected_deck().get("name", "") == "Shu Vanguard" and list.name_label.text == "Shu Vanguard", "Rename stores a cleaned name"):
		return false
	var asker = list.open_delete()
	asker.confirm_button.pressed.emit()
	await process_frame
	if not _require(DeckStore.list().size() == 1 and list.decks.size() == 1, "Delete removes the deck after the confirmation"):
		return false
	list.select("custom", stored[0].id)
	list.actions.play.pressed.emit()
	await process_frame
	await process_frame
	var decks = _top_dialog()
	if not _require(decks is DecksDialog and decks.choices[0] is Dictionary and decks.choices[0].get("id", "") == stored[0].id
			and decks.selectors[0].get_item_text(decks.selectors[0].selected) == "Green/Black Example",
			"Play with this deck opens the matchup with the deck as yours"):
		return false
	decks.mode_buttons[MatchController.MODE_AI].pressed.emit()
	decks.start_button.pressed.emit()
	await _settle()
	app.bot_timer.stop()
	var roster = _engine().state.players[0].roster.map(func(hero): return hero.card)
	if not _require(app.mode == MatchController.MODE_AI and roster == stored[0].heroes and _engine().state.players[0].preset == "custom",
			"The AI match starts with the saved deck in its deploy order (%s)" % [roster]):
		return false
	if not _require(app.controller.deck_name_in(app.controller.view(), 0) == "Green/Black Example" and app.controller.view().players[1].preset != "custom",
			"The match names your deck"):
		return false
	# The guest's picker: one column, it sets this player's deck.
	var picker = app.open_decks("steam")
	await process_frame
	if not _require(picker.guest and picker.selectors.size() == 1 and picker.panel.get_global_rect().end.y <= 900.0, "The guest's deck picker has one column"):
		return false
	picker.selectors[0].item_selected.emit(2)
	picker.start_button.pressed.emit()
	await process_frame
	if not _require(app.deck_selections[0] is String and app.deck_selections[0] == "blue_black_control", "The guest's picker sets this player's deck (%s)" % [app.deck_selections[0]]):
		return false
	app.close_dialogs()
	app.deck_selections = selections_before
	app.start_match(MatchController.MODE_LOCAL)
	await _settle()
	return _require(_engine().state.players[0].preset == "green_assault", "The earlier matchup is restored for the checks that follow")

## True when `control` lies inside the visible part of its viewport.
func _on_screen(control: Control) -> bool:
	var view: Rect2 = control.get_viewport().get_visible_rect()
	var rect: Rect2 = control.get_global_rect()
	return rect.position.x >= view.position.x - 0.5 and rect.position.y >= view.position.y - 0.5 \
		and rect.end.x <= view.end.x + 0.5 and rect.end.y <= view.end.y + 0.5

## A code prompt showing an error stays a compact box inside the window.
func _prompt_fits(box, label: String) -> bool:
	var rect: Rect2 = box.panel.get_global_rect()
	var view: Rect2 = box.get_viewport().get_visible_rect()
	return _require(box.error_label.visible and _on_screen(box.panel) and rect.size.y < view.size.y * 0.6 and rect.position.y > 20.0
		and box.confirm_button.is_visible_in_tree() and _on_screen(box.confirm_button),
		"%s: the import prompt with an error fits the window (%s in %s)" % [label, rect, view.size])

## The deck screens after review: a four-faction deck fits every window in
## both languages, the code prompt with an error stays compact (builder and
## list), messages are a toast that never resizes the footer and clears
## after fading, a template asks before replacing a deck, copy badges stay
## off card names and emblems, and a click on an empty hero slot shows the
## heroes and fills that slot with the next hero clicked.
func _check_deck_review() -> bool:
	var locale_before = TranslationServer.get_locale()
	var library = Library.new()
	var four = DeckStore.copy_of(library.preset("starter"), "Contest of Warlords, a copy with a long name")
	var builder = app.open_deck_builder(four, false)
	await process_frame
	await process_frame
	if not _require(builder is DeckBuilderDialog and builder.color_counts.counts.size() == 4, "The review deck has four factions"):
		return false
	for locale in ["en", "zh_CN"]:
		app.set_locale(locale)
		for window in [Vector2i(1440, 900), Vector2i(1280, 800), Vector2i(1280, 720)]:
			root.size = window
			for frame in range(4):
				await process_frame
			var parts = [builder.panel, builder.export_button, builder.import_button, builder.close_button, builder.play_button, builder.save_button,
				builder.lamps, builder.issue_label, builder.deck_panel]
			var off: Array = parts.filter(func(part): return not _on_screen(part)).map(func(part): return part.name)
			if not _require(off.is_empty(), "A four-faction deck fits %s in %s (off screen: %s; panel %s)" % [window, locale, off, builder.panel.get_global_rect()]):
				return false
			if not _require(builder.footer.get_combined_minimum_size().x < builder.panel.size.x - 20.0 and builder.stats_holder.size.x > 200.0,
					"The footer's minimum width stays inside the panel (%s of %s)" % [builder.footer.get_combined_minimum_size().x, builder.panel.size.x]):
				return false
	root.size = Vector2i(1440, 900)
	for frame in range(3):
		await process_frame
	# The code prompt with an error: compact in both languages, builder and list.
	for locale in ["en", "zh_CN"]:
		app.set_locale(locale)
		for bad in ["nonsense", VALVE_CODE.substr(0, VALVE_CODE.length() - 12)]:
			var box = builder.open_import()
			box.field.text = bad
			box.confirm_button.pressed.emit()
			for frame in range(3):
				await process_frame
			if not _prompt_fits(box, "Builder, %s, %s" % [locale, bad.substr(0, 12)]):
				return false
			box.cancel()
	await process_frame
	# Messages: a toast over the collection; the footer and the lists keep their size.
	app.set_locale("en")
	for frame in range(3):
		await process_frame
	var footer_h = builder.footer.size.y
	var collection_h = builder.collection_scroll.size.y
	var list_h = builder.list_scroll.size.y
	var outsider = ""
	for card_id in builder.eligible_cards():
		if outsider.is_empty() and str(Library.raw_definition(card_id).get("kind", "")) == "hero" and card_id not in builder.deck.heroes:
			outsider = card_id
	_click(await _card_point(builder, outsider))
	for frame in range(3):
		await process_frame
	var toast: Control = builder.status_toast
	var zone: Rect2 = builder.collection_zone.get_global_rect()
	if not _require(builder.status_label.text == UiKit.t("DECKB_HEROES_FULL") and toast.visible and zone.encloses(toast.get_global_rect())
			and toast.size.y < 60.0, "A full set of heroes says so in a one-line toast over the collection (%s in %s)" % [toast.get_global_rect(), zone]):
		return false
	builder.show_status(UiKit.t("DECKB_SAVED", {"name": "A very long deck name that goes on and on ".repeat(4)}))
	for frame in range(3):
		await process_frame
	if not _require(zone.encloses(toast.get_global_rect()) and toast.size.y < 140.0, "A long message wraps inside the toast (%s)" % toast.get_global_rect()):
		return false
	if not _require(is_equal_approx(builder.footer.size.y, footer_h) and is_equal_approx(builder.collection_scroll.size.y, collection_h)
			and is_equal_approx(builder.list_scroll.size.y, list_h), "Messages leave the footer (%s -> %s), the collection and the deck list alone"
			% [footer_h, builder.footer.size.y]):
		return false
	builder._status_tween.custom_step(10.0)
	if not _require(builder.status_label.text.is_empty() and not toast.visible, "A faded message is cleared"):
		return false
	# Copy badges sit on the art, below the name strip and any emblem.
	var badged: Array = builder.deck.heroes.duplicate() + builder.deck.cards.keys().slice(0, 4) + builder.deck.items.keys().slice(0, 2)
	var drawn = 0
	for card_id in badged:
		var card = builder.collection_card(str(card_id))
		if card == null or card.count <= 0:
			continue
		drawn += 1
		var s = card.size.x / 180.0
		var layout = card._layout()
		var top = card.badge_center().y - maxf(11.0, 15.0 * s)
		var clear_below = layout.title_h + (27.0 * s if layout.stat_bar else 0.0)
		if not _require(top >= clear_below, "%s's copy badge clears its name strip and emblem (%s >= %s)" % [card_id, top, clear_below]):
			return false
	if not _require(drawn >= 6, "Heroes, cards and items of the deck show copy badges (%d checked)" % drawn):
		return false
	# Start from a preset: asks first; Cancel keeps the deck, Replace swaps it.
	var heroes_before: Array = builder.deck.heroes.duplicate()
	var main_before = builder.deck.cards.duplicate()
	var index = library.presets().map(func(preset): return str(preset.id)).find("green_assault") + 1
	builder.template_button.item_selected.emit(index)
	await process_frame
	if not _require(builder.prompt != null and is_instance_valid(builder.prompt) and builder.prompt.is_inside_tree() and builder.deck.heroes == heroes_before
			and builder.deck.cards == main_before, "Starting from a preset asks before replacing a deck with cards"):
		return false
	builder.prompt.cancel_button.pressed.emit()
	await process_frame
	if not _require(builder.deck.heroes == heroes_before and builder.deck.cards == main_before, "Cancel keeps the deck"):
		return false
	builder.template_button.item_selected.emit(index)
	await process_frame
	builder.prompt.confirm_button.pressed.emit()
	await process_frame
	if not _require(builder.deck.heroes == library.preset("green_assault").heroes and (builder.prompt == null or not is_instance_valid(builder.prompt)
			or not builder.prompt.is_inside_tree()), "Replace loads the preset"):
		return false
	# An empty hero slot: a click shows the heroes; the next hero fills that slot.
	builder.remove_hero(0)
	builder.remove_hero(3)
	builder.set_cost_filter(3)
	_click(_center(builder.hero_slots[3]))
	await process_frame
	if not _require(builder.filter_kind == "hero" and builder.filter_cost == 0 and builder.hero_slots[3].waiting and builder.pending_slot == 3
			and builder.shown_cards().size() > 40, "Clicking an empty slot shows the heroes and marks the slot"):
		return false
	var hero = ""
	for card_id in builder.eligible_cards():
		if hero.is_empty() and str(Library.raw_definition(card_id).get("kind", "")) == "hero" and card_id not in builder.deck.heroes:
			hero = card_id
	_click(await _card_point(builder, hero))
	await process_frame
	if not _require(builder.deck.heroes[3] == hero and builder.deck.heroes[0] == "" and not builder.hero_slots[3].waiting and builder.pending_slot == -1,
			"The next hero clicked fills the chosen round 2 slot, not the first free one (%s)" % [builder.deck.heroes]):
		return false
	_click(_center(builder.hero_slots[0]))
	await process_frame
	_click(_center(builder.hero_slots[0]))
	await process_frame
	if not _require(builder.pending_slot == -1 and not builder.hero_slots[0].waiting, "A second click on the slot cancels the choice"):
		return false
	app.close_dialogs()
	await process_frame
	# The deck list's import prompt with an error.
	var list = app.open_deck_list()
	await process_frame
	await process_frame
	for locale in ["zh_CN", "en"]:
		app.set_locale(locale)
		var box = list.open_import()
		box.field.text = "nonsense"
		box.confirm_button.pressed.emit()
		for frame in range(3):
			await process_frame
		if not _prompt_fits(box, "Deck list, %s" % locale):
			return false
		box.cancel()
	app.close_dialogs()
	app.set_locale(locale_before)
	await process_frame
	await process_frame
	return true

## The collection holds exactly the cards a deck may hold: no tokens,
## consumables, Deeds or signature cards (every shipped card is verified, so
## Lich, Kanna and Enough Magic! are offered).
func _check_collection_contents(builder) -> bool:
	var ids = builder.collection.map(func(card): return card.card_id)
	var library = Library.new()
	if not _require(not ("chain_frost" in ids or "melee_creep" in ids or "healing_salve" in ids or "shop_deed" in ids
			or "berserkers_call" in ids or "coup_de_grace" in ids), "The collection hides tokens, consumables, Deeds and signature cards"):
		return false
	if not _require("lich" in ids and "kanna" in ids and "enough_magic" in ids, "The collection offers Lich, Kanna and Enough Magic!"):
		return false
	return _require(ids.all(func(card_id): return library.deckable(card_id)), "Every collection card can enter a deck")

# --- v0.6.1: the hand repaints, the your-action cue, card history, the result's buttons,
# the online room and the match intro ------------------------------------------------------

func _frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame

## Records each card's look when it paints (its draw signal).
func _track_paint(cards: Array) -> void:
	for card in cards:
		if card.has_meta("paint_tracked"):
			continue
		card.set_meta("paint_tracked", true)
		var key = card.get_instance_id()
		card.draw.connect(func(): painted[key] = [card.playable, card.dimmed, card.selected, card.hovered])

## The cards whose last painted look differs from their state (stale paint).
func _stale_paint(cards: Array) -> Array:
	var stale: Array = []
	for card in cards:
		if painted.get(card.get_instance_id(), []) != [card.playable, card.dimmed, card.selected, card.hovered]:
			stale.append(str(card.card_id))
	return stale

## Issue 2: a hand card that stops (or starts) being playable is repainted:
## when the opponent gets the action, when the active lane moves to a lane
## without a hero of its colour, and a shop offer a purchase made
## unaffordable. Looking at another lane changes nothing.
func _check_hand_repaint() -> bool:
	app.deck_selections = ["starter", "starter"]
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _settle()
	var engine = _engine()
	var debbi: Dictionary = {}
	for hero in engine.state.players[0].roster:
		if str(hero.card) == "debbi":
			debbi = hero
	for lane_index in range(3):
		for unit in engine.state.lanes[lane_index].units[0].duplicate():
			if unit != null:
				engine._remove_from_lane(unit)
		engine.state.lanes[lane_index].mana[0] = 10
	debbi.health = 5
	engine._spawn(debbi, 0)
	var hand_cards = ["short_sword", "hip_fire", "untested_grunt"]
	_act_in_lane_zero(hand_cards)
	await _settle()
	_track_paint(screen.hand.cards)
	for card in screen.hand.cards:
		card.queue_redraw()
	await _frames()
	if not _require(screen.hand.cards.size() == 3 and screen.hand.cards.all(func(card): return card.playable) and _stale_paint(screen.hand.cards).is_empty(),
			"With Debbi in the active lane the three cards glow"):
		return false
	screen.view_lane(1)
	await _frames()
	var stale = _stale_paint(screen.hand.cards)
	if not _require(screen.hand.cards.all(func(card): return card.playable) and stale.is_empty(),
			"Looking at another lane keeps the hand playable and painted so (stale: %s)" % [stale]):
		return false
	screen.view_lane(0)
	engine.state.active_player = 1
	app.controller.refresh()
	await _settle()
	await _frames()
	stale = _stale_paint(screen.hand.cards)
	if not _require(screen.hand.cards.all(func(card): return not card.playable and card.dimmed) and stale.is_empty(),
			"The opponent's action repaints every card dimmed, none glowing (stale: %s)" % [stale]):
		return false
	_act_in_lane_zero(hand_cards)
	await _settle()
	await _frames()
	stale = _stale_paint(screen.hand.cards)
	if not _require(screen.hand.cards.all(func(card): return card.playable) and stale.is_empty(), "The action back: the cards glow again (stale: %s)" % [stale]):
		return false
	engine.state.lane = 1
	app.controller.refresh()
	await _settle()
	await _frames()
	stale = _stale_paint(screen.hand.cards)
	if not _require(screen.hand.cards.all(func(card): return not card.playable and card.dimmed) and stale.is_empty(),
			"The active lane moving on (no black hero there) repaints the cards dimmed (stale: %s)" % [stale]):
		return false
	screen.hand.set_hovered(1)
	await _frames(2)
	stale = _stale_paint(screen.hand.cards)
	screen.hand.set_hovered(-1)
	await _frames(2)
	if not _require(stale.is_empty() and _stale_paint(screen.hand.cards).is_empty(), "Hovering repaints just as before"):
		return false
	# The shop: buying one offer repaints the one it made unaffordable.
	engine.state.phase = "shop"
	for owner in engine.state.players:
		owner.finished = false
		owner.shop = {"secret": "barbed_mail", "item": "", "consumable": "healing_salve"}
	engine.state.players[0].gold = 7
	engine.state.players[0].held_secret = ""
	app.controller.refresh()
	await _settle()
	var offer: Control = screen.shop.slots.secret.card
	_track_paint([offer])
	offer.queue_redraw()
	await _frames()
	if not _require(offer.playable and _stale_paint([offer]).is_empty(), "Both shop offers are affordable at first"):
		return false
	screen.shop.slots.consumable.buy.pressed.emit()
	await _settle()
	await _frames()
	app.bot_timer.paused = false
	return _require(int(engine.state.players[0].gold) == 4 and not offer.playable and offer.dimmed and _stale_paint([offer]).is_empty(),
		"A purchase repaints the offer it made unaffordable dimmed")

## Issue 1: one cue (chime, rings, banner) exactly when the action becomes
## yours: not for the opponent's turns, not again when you keep the action,
## after combat when the next lane opens with you, after a hot-seat hand-over
## is confirmed, never for a reconnect or a restored replay, and silently
## when alerts are off.
func _check_turn_cue() -> bool:
	Settings.set_turn_alert(true, false)
	Settings.set_muted(false, false)
	Settings.set_volume(0.7, false)
	var sfx = app.sfx
	var acts = [{"type": "pass"}]
	var base = {"phase": "action", "winner": -1, "active_player": 1, "round": 2, "lane": 1, "first_pass": -1}
	if not _require(MatchScreen.action_key(base, 1, acts) == "2|1|1" and MatchScreen.action_key(base, 0, acts) == ""
			and MatchScreen.action_key(base, 1, []) == "" and MatchScreen.action_key(base.merged({"phase": "shop"}, true), 1, acts) == ""
			and MatchScreen.action_key(base.merged({"first_pass": 0}, true), 1, acts) == "2|1|1"
			and MatchScreen.action_key(base.merged({"winner": 1}, true), 1, acts) == "",
			"The action key: round, lane and player, only while it is your action (an online guest is player 2)"):
		return false
	app.deck_selections = ["starter", "starter"]
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _settle()
	var engine = _engine()
	engine.state.phase = "action"
	engine.state.lane = 0
	engine.state.active_player = 1
	engine.state.first_pass = -1
	app.controller.refresh()
	await _settle()
	var count = screen.turn_cue_count
	var chimes = int(sfx.counts.get("turn", 0))
	# (Cues of the checks before were moments ago: the chime's rate limit.)
	screen._last_cue_ms = -MatchScreen.CUE_MIN_MS * 10
	# The AI passes first: your action, and the coin says passing starts combat.
	engine.apply_action(1, {"type": "pass"})
	app.controller.refresh()
	await _settle()
	if not _require(screen.turn_cue_count == count + 1 and int(sfx.counts.get("turn", 0)) == chimes + 1 and screen.coin.pulsing()
			and screen.coin.sub_caption == UiKit.t("HUD_OPPONENT_PASSED"),
			"Your action after the AI's pass: one cue (chime and rings) and the coin's warning (%d cues, %d chimes, rings %s, %s)"
			% [screen.turn_cue_count - count, int(sfx.counts.get("turn", 0)) - chimes, screen.coin.pulsing(), screen.coin.sub_caption]):
		return false
	_act_in_lane_zero(["foresight"])
	await _settle()
	if not _require(screen.turn_cue_count == count + 1 and screen.coin.sub_caption == UiKit.t("HUD_INITIATIVE_YOU"),
			"Keeping the action (a quick card) is no new cue"):
		return false
	screen.press_coin()
	await _settle()
	if not _require(screen.turn_cue_count == count + 1 and int(engine.state.active_player) == 1, "Your pass gives the AI the action: no cue"):
		return false
	engine.apply_action(1, {"type": "pass"})
	app.controller.refresh()
	await _settle()
	if not _require(int(engine.state.lane) == 1 and int(engine.state.active_player) == 0 and screen.turn_cue_count == count + 2,
			"Combat, then the next lane opens with you: one cue once the board is idle (lane %d)" % int(engine.state.lane)):
		return false
	screen.press_coin()
	await _settle()
	engine.state.active_player = 0
	engine.state.first_pass = -1
	app.controller.refresh()
	await _settle()
	if not _require(screen.turn_cue_count == count + 3, "The action returning in the same lane is a new cue"):
		return false
	# A reconnect redraws the same turn: no cue.
	screen.reset()
	app.controller.refresh()
	await _settle()
	if not _require(screen.turn_cue_count == count + 3, "Seeing the same turn again (a reconnect) is no new cue"):
		return false
	# The AI's own turns never cue; alerts off: the cue shows, silently.
	engine.state.active_player = 1
	app.controller.refresh()
	await _settle()
	Settings.set_turn_alert(false, false)
	chimes = int(sfx.counts.get("turn", 0))
	engine.state.active_player = 0
	app.controller.refresh()
	await _settle()
	Settings.set_turn_alert(true, false)
	if not _require(screen.turn_cue_count == count + 4 and int(sfx.counts.get("turn", 0)) == chimes, "With the alert off the cue shows without a chime"):
		return false
	# Hot-seat: the cue waits for the hand-over screen.
	app.start_match(MatchController.MODE_LOCAL)
	while screen.queue.busy:
		await process_frame
	count = screen.turn_cue_count
	if not _require(screen.pass_screen.visible and count == screen.turn_cue_count, "Hot-seat: no cue behind the hand-over screen"):
		return false
	screen.pass_screen.confirm()
	await _frames()
	if not _require(screen.turn_cue_count == count + 1, "Hot-seat: the cue plays once the next player confirms"):
		return false
	# An online guest (player 2): host snapshots arrive; only its own action cues.
	if not await _check_guest_cue():
		return false
	# A restored replay is not a new turn.
	var saved_path = "res://.tools/ui_test_replay_cue.json"
	app.save_replay(saved_path)
	count = screen.turn_cue_count
	app.load_replay(saved_path)
	while screen.queue.busy:
		await process_frame
	if screen.pass_screen.visible:
		screen.pass_screen.confirm()
	await _frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
	app.bot_timer.paused = false
	return _require(screen.turn_cue_count == count, "A restored replay plays no cue")

## The guest's side of the cue: snapshots from the host (player 1 acting,
## then player 2) cue only when the action becomes player 2's.
func _check_guest_cue() -> bool:
	app.deck_selections = ["starter", "starter"]
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _settle()
	var engine = _engine()
	var controller = app.controller
	controller.steam_bridge.is_host = false
	controller.match_serial = 0
	var publish = func(serial: int) -> void:
		var view = engine.player_view(1)
		view.players[0]["preset"] = MatchController.HIDDEN_DECK
		controller._online_state(view, engine.legal_actions(1), serial)
	engine.state.phase = "action"
	engine.state.lane = 0
	engine.state.active_player = 0
	engine.state.first_pass = -1
	publish.call(41)
	await _settle()
	var count = screen.turn_cue_count
	var host_turn = screen.shown_viewer == 1 and count == screen.turn_cue_count
	engine.apply_action(0, {"type": "pass"})
	publish.call(41)
	await _settle()
	var guest_turn = screen.turn_cue_count == count + 1 and screen.coin.sub_caption == UiKit.t("HUD_OPPONENT_PASSED")
	engine.state.active_player = 0
	engine.state.first_pass = -1
	publish.call(41)
	await _settle()
	var quiet = screen.turn_cue_count == count + 1
	controller.mode = MatchController.MODE_AI
	controller.online_view.clear()
	controller.online_actions.clear()
	controller._reset_room("none")
	app.bot_timer.paused = false
	return _require(host_turn and guest_turn and quiet,
		"An online guest gets one cue when the host passes it the action, none for the host's turns (%s %s %s)" % [host_turn, guest_turn, quiet])

## Issue 3: the card history: lanes and rounds from the events, tiles for
## plays, abilities, combats, passes and purchases (the opponent's never
## name the item), tiles as plays animate, the full log at a tile's event,
## and the rail kept clear of the HUD, the opponent's hand, the chevrons,
## the deck pile and the enemy units at both window sizes.
func _check_history() -> bool:
	Settings.set_show_history(true, false)
	var events: Array = [{"k": "match_start"},
		{"k": "play", "p": 0, "card": "no_accident", "target": 5, "target_card": "axe"},
		{"k": "damage", "src": "no_accident", "p": 0, "hits": [[5, 3]]},
		{"k": "pass", "p": 1}, {"k": "pass", "p": 0},
		{"k": "combat", "lane": 0, "damage": [4, 2], "strikes": []}, {"k": "tower_fall", "p": 1},
		{"k": "lane_open", "lane": 1, "p": 0},
		{"k": "ability", "p": 1, "uid": 7, "card": "jmuy", "ability": "a"},
		{"k": "pass", "p": 0}, {"k": "pass", "p": 1},
		{"k": "combat", "lane": 1, "damage": [0, 0], "strikes": []},
		{"k": "lane_open", "lane": 2, "p": 0},
		{"k": "pass", "p": 0}, {"k": "pass", "p": 1},
		{"k": "combat", "lane": 2, "damage": [1, 1], "strikes": []},
		{"k": "shop_open"},
		{"k": "buy", "p": 1, "gold": 3}, {"k": "buy", "p": 1, "gold": 5},
		{"k": "buy", "p": 0, "gold": 4}, {"k": "hold", "p": 0, "gold": 1},
		{"k": "deployment", "round": 2, "creeps": [[0, 1], [2, 2]]},
		{"k": "deployment_placed", "units": []}, {"k": "deployment_revealed"},
		{"k": "play", "p": 1, "card": "hip_fire"}]
	var view = {"phase": "action", "lane": 0, "round": 2, "event_seq": 100 + events.size(), "events": events,
		"players": [{"bought": ["healing_salve"]}, {"bought": []}]}
	var lanes = HistoryRail.event_lanes(events, view)
	var rounds = HistoryRail.event_rounds(events, view)
	if not _require(lanes[1] == 0 and lanes[5] == 0 and lanes[8] == 1 and lanes[11] == 1 and lanes[15] == 2 and lanes[17] == -1 and lanes[19] == -1
			and lanes[24] == 0 and rounds[1] == 1 and rounds[20] == 1 and rounds[21] == 2 and rounds[24] == 2,
			"Each event's lane and round come from the events around it (%s)" % [lanes]):
		return false
	var rail = screen.history
	rail.refresh(view, 0)
	var kinds = rail.tiles.map(func(tile): return str(tile.kind))
	if not _require(kinds == ["play", "pass", "pass", "combat", "ability", "pass", "pass", "combat", "pass", "pass", "combat", "buy", "buy", "play"],
			"Tiles: plays, passes, combats, an ability and purchases (%s)" % [kinds]):
		return false
	var theirs: Dictionary = rail.tiles[11]
	var mine: Dictionary = rail.tiles[12]
	if not _require(int(theirs.p) == 1 and str(theirs.card) == "" and int(theirs.count) == 2 and int(theirs.gold) == 8 and str(mine.card) == "healing_salve"
			and str(rail.tiles[0].target_card) == "axe" and rail.tiles[0].lines == [2] and str(rail.tiles[3].fall) == "tower" and rail.tiles[3].damage == [4, 2]
			and int(rail.tiles[13].round) == 2 and int(rail.tiles[13].lane) == 0,
			"The opponent's two purchases share a tile without the items; yours shows its item; a play lists what it caused"):
		return false
	var hidden_text = rail.hover_text(int(theirs.id))
	if not _require(hidden_text.find(Library.loc("healing_salve")) == -1 and hidden_text.find("8") != -1,
			"The opponent's purchase tile names no item (%s)" % hidden_text):
		return false
	if not _require(rail.hover_text(int(mine.id)).find(Library.loc("healing_salve")) != -1, "Your purchase tile names your item"):
		return false
	# A real match: the tile appears with the play.
	app.deck_selections = ["starter", "starter"]
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _settle()
	var engine = _engine()
	var jmuy = engine.state.players[0].roster[1]
	_place_in_lane(jmuy, 8)
	_act_in_lane_zero(["foresight"])
	await _settle()
	var play: Dictionary = {}
	for action in engine.legal_actions(0):
		if str(action.get("type", "")) == "play":
			play = action
	if not _require(not play.is_empty(), "Foresight can be played"):
		return false
	app.act(play)
	await _settle()
	var newest: Dictionary = rail.tiles.back() if not rail.tiles.is_empty() else {}
	if not _require(rail.visible and str(newest.get("kind", "")) == "play" and str(newest.get("card", "")) == "foresight" and int(newest.p) == 0 and int(newest.lane) == 0,
			"Your play shows as the newest tile (%s)" % [newest]):
		return false
	screen._on_history_log(int(newest.id))
	var events_now: Array = screen.shown_view.events
	if not _require(screen.log_panel.visible and screen.log_panel.highlighted == int(newest.id) - (int(screen.shown_view.event_seq) - events_now.size()),
			"Clicking a tile opens the log at its event"):
		return false
	screen.toggle_log()
	for window in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		root.size = window
		await _frames()
		screen.view_lane(int(engine.state.lane))
		await _frames(3)
		var box: Rect2 = rail.get_global_rect()
		var blockers: Array = [screen.hud.get_global_rect(), screen.enemy_hand.get_global_rect(), screen.own_deck.get_global_rect(),
			screen.enemy_panel.get_global_rect()]
		for chevron in screen.board.chevrons:
			if chevron.visible:
				blockers.append(chevron.get_global_rect())
		var lane = screen.board.lanes[screen.board.focus_lane]
		for uid in lane.cards:
			if not lane.cards[uid].own:
				blockers.append(lane.cards[uid].get_global_rect())
		var hit: Array = blockers.filter(func(rect): return rect.intersects(box))
		if not _require(hit.is_empty() and box.end.x <= screen.size.x and box.position.y >= screen.hud.get_global_rect().end.y,
				"The history rail is clear of the HUD, the opponent's hand, the chevrons, the deck and the enemy units at %s (%s)" % [window, hit]):
			root.size = Vector2i(1440, 900)
			return false
	root.size = Vector2i(1440, 900)
	await _frames()
	# H hides and shows it; the overview fades it.
	var key = InputEventKey.new()
	key.keycode = KEY_H
	key.pressed = true
	root.push_input(key)
	await _frames(2)
	var hidden = not rail.visible and not Settings.show_history
	root.push_input(key)
	await _frames(2)
	if not _require(hidden and rail.visible and Settings.show_history, "H hides and shows the card history"):
		return false
	# The shop: the rail steps aside; the opponent's purchase stays unnamed.
	engine.state.phase = "shop"
	engine.state.events.append({"k": "shop_open"})
	engine.state.event_seq = int(engine.state.event_seq) + 1
	for owner in engine.state.players:
		owner.finished = false
		owner.bought = []
		owner.gold = 9
		owner.held_secret = ""
	engine.state.players[0].shop = {"secret": "", "item": "", "consumable": "town_portal_scroll"}
	engine.state.players[1].shop = {"secret": "", "item": "", "consumable": "healing_salve"}
	engine.apply_action(1, {"type": "buy", "card": "healing_salve", "source": "consumable"})
	engine.apply_action(0, {"type": "buy", "card": "town_portal_scroll", "source": "consumable"})
	app.controller.refresh()
	await _settle()
	var buys = rail.tiles.filter(func(tile): return str(tile.kind) == "buy")
	var opponent_buys = buys.filter(func(tile): return int(tile.p) == 1)
	var own_buys = buys.filter(func(tile): return int(tile.p) == 0)
	if not _require(not rail.visible and screen.shop.visible, "The card history steps aside for the shop"):
		return false
	app.bot_timer.paused = false
	return _require(opponent_buys.size() == 1 and str(opponent_buys[0].card) == "" and rail.hover_text(int(opponent_buys[0].id)).find(Library.loc("healing_salve")) == -1
		and own_buys.size() == 1 and str(own_buys[0].card) == "town_portal_scroll",
		"In a real match the opponent's purchase is unnamed and yours is named")

## Puts the controller in a room without Steam: only the bridge's fields
## are set, so nothing is sent (Steam is off in headless runs).
func _fake_room(host: bool, guest_here: bool = true) -> void:
	var bridge = app.controller.steam_bridge
	bridge.lobby_id = 109775241000000777
	bridge.is_host = host
	bridge.lobby_public = false
	bridge.handshake_done = guest_here
	bridge.opponent_present = guest_here
	bridge.peer_id = 76561198000000202 if guest_here else 0
	bridge.bound_opponent = bridge.peer_id if host else 0
	bridge.host_id = 0 if host else bridge.peer_id
	bridge.peer_name = "孙权" if guest_here else ""
	app.controller.room_phase = "room" if guest_here else "waiting"
	app.controller.room_ready = [false, false]
	app.controller.room_starting = false
	app.controller.guest_deck_state = "ok" if guest_here else ""
	app.controller.own_deck_result = {"ok": true}

## The engine's match ends with `winner` and the board catches up.
func _finish_match(winner: int) -> void:
	var engine = _engine()
	engine.state.winner = winner
	engine.state.phase = "finished"
	engine._event("win", {"p": winner})
	app.controller.refresh()
	await _settle()

## The overlay shows exactly `list` (in order).
func _result_actions_are(list: Array) -> bool:
	var over = screen.game_over
	var shown: Array = []
	for child in over._row.get_children():
		if child.visible:
			shown.append(over.buttons.find_key(child))
	return shown == list

## Issue 4: the result's buttons offline (Play again with the same decks,
## Change deck as the matchup, the result back from View board) and online
## (Rematch into the room, Change deck as your own deck, no Save for the
## guest, the opponent wanting a rematch or leaving, the session ending),
## the in-match menu's Leave room and its confirmation.
func _check_result_flows() -> bool:
	app.deck_selections = ["starter", "green_assault"]
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _settle()
	var engine = _engine()
	var rosters = [engine.state.players[0].roster.map(func(hero): return hero.card), engine.state.players[1].roster.map(func(hero): return hero.card)]
	await _finish_match(0)
	var over = screen.game_over
	if not _require(over.visible and _result_actions_are(GameOverOverlay.OFFLINE_ACTIONS), "Offline results offer Play again, Change deck, Save, View board and Main menu"):
		return false
	for window in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		root.size = window
		await _frames()
		var row: Rect2 = over._row.get_global_rect()
		if not _require(row.position.x >= 0.0 and row.end.x <= screen.size.x and row.end.y <= screen.size.y, "The result's buttons fit at %s (%s)" % [window, row]):
			root.size = Vector2i(1440, 900)
			return false
	root.size = Vector2i(1440, 900)
	await _frames()
	over.buttons.board.pressed.emit()
	await _frames()
	if not _require(not over.visible and screen.coin.enabled and screen.coin.caption == UiKit.t("RESULT_SHOW"), "View board: the coin brings the result back"):
		return false
	_click(screen.coin_point())
	await _frames()
	if not _require(over.visible, "Clicking the coin shows the result again"):
		return false
	over.buttons.decks.pressed.emit()
	await _frames()
	var dialog = _top_dialog()
	if not _require(dialog is DecksDialog and dialog.selectors.size() == 2, "Change deck after an offline match opens the matchup"):
		return false
	app.close_dialogs()
	over.buttons.again.pressed.emit()
	await _settle()
	if not _require(not over.visible and int(engine.state.winner) == -1 and engine.state.players[0].roster.map(func(hero): return hero.card) == rosters[0]
			and engine.state.players[1].roster.map(func(hero): return hero.card) == rosters[1], "Play again starts a new match with the same decks"):
		return false
	var menu_dialog = app.open_menu()
	await _frames(2)
	if not _require(menu_dialog.buttons.new.visible and not menu_dialog.buttons.leave.visible, "Offline the menu offers New match, not Leave room"):
		return false
	app.close_dialogs()
	# Online: a host in a room with a guest.
	_fake_room(true)
	app.controller.mode = MatchController.MODE_ONLINE
	app.controller.room_phase = "match"
	app.controller.refresh()
	await _settle()
	menu_dialog = app.open_menu()
	await _frames(2)
	if not _require(not menu_dialog.buttons.new.visible and menu_dialog.buttons.leave.visible and menu_dialog.panel.size.y <= 900.0,
			"Online the menu offers Leave room instead of New match"):
		return false
	app.close_dialogs()
	var confirm = app.open_leave()
	await _frames(2)
	if not _require(confirm.message_key == "LEAVE_CONFIRM_BODY_MATCH" and confirm.confirm_button.text == UiKit.t("LEAVE_CONFIRM_CONCEDE"),
			"Leaving during a match asks first and says it concedes"):
		return false
	app.close_dialogs()
	await _finish_match(0)
	app.controller.room_phase = "result"
	screen.refresh_result()
	if not _require(over.visible and _result_actions_are(GameOverOverlay.ONLINE_ACTIONS) and over.status.is_empty(),
			"Online results offer Rematch, Change deck, Save, View board and Leave room"):
		return false
	confirm = app.open_leave()
	await _frames(2)
	if not _require(confirm.message_key == "LEAVE_CONFIRM_BODY", "Leaving after the result only warns that no rematch follows"):
		return false
	app.close_dialogs()
	app.controller.room_ready = [false, true]
	app.controller.room_changed.emit()
	if not _require(over.status == UiKit.t("RESULT_OPPONENT_WANTS_REMATCH", {"name": "孙权"}) and over.status_alert,
			"The opponent's readiness: \"%s\"" % over.status):
		return false
	app.controller.steam_bridge.is_host = false
	screen.refresh_result()
	if not _require(not over.buttons.save.visible and over.buttons.rematch.visible, "A guest gets no Save replay"):
		return false
	app.controller.steam_bridge.is_host = true
	app.controller.room_ready = [false, false]
	screen.refresh_result()
	over.buttons.rematch.pressed.emit()
	await _frames()
	if not _require(app.room.visible and not screen.visible and app.controller.room_ready == [true, false], "Rematch gets you ready and shows the room"):
		return false
	app.show_match()
	app.controller.set_ready(false)
	over.buttons.decks.pressed.emit()
	await _frames()
	dialog = _top_dialog()
	if not _require(dialog is DecksDialog and dialog.single_column(), "Change deck online picks only your own deck"):
		return false
	app.close_dialogs()
	app.controller.steam_bridge.handshake_done = false
	app.controller.steam_bridge.opponent_present = false
	app.controller.opponent_left.emit("孙权")
	if not _require(over.buttons.room.visible and not over.buttons.rematch.visible and over.status == UiKit.t("RESULT_OPPONENT_LEFT", {"name": "孙权"}),
			"The opponent left: Back to room, and the status names them (%s)" % over.status):
		return false
	# A different player takes the freed seat while the result is up: they
	# never played this match, so no rematch with them (review fix), only
	# Back to room, and their readiness is not "wants a rematch".
	var bridge = app.controller.steam_bridge
	app.controller.last_opponent = 76561198000000202
	bridge.handshake_done = true
	bridge.opponent_present = true
	bridge.bound_opponent = 76561198000000303
	bridge.peer_id = bridge.bound_opponent
	bridge.peer_name = "吕布"
	app.controller.room_phase = "result"
	app.controller.room_ready = [false, true]
	app.controller.room_changed.emit()
	if not _require(over.buttons.room.visible and not over.buttons.rematch.visible
			and over.status == UiKit.t("RESULT_NEW_OPPONENT", {"name": "吕布"}) and not over.status_alert,
			"A new player in the freed seat: Back to room, no rematch (%s)" % over.status):
		return false
	over.buttons.room.pressed.emit()
	await _frames()
	if not _require(app.room.visible and not screen.visible, "Back to room shows the room with the new player"):
		return false
	app.show_match()
	# The original opponent back in its seat: Rematch again.
	bridge.bound_opponent = 76561198000000202
	bridge.peer_id = bridge.bound_opponent
	bridge.peer_name = "孙权"
	app.controller.room_changed.emit()
	if not _require(over.buttons.rematch.visible and over.status == UiKit.t("RESULT_OPPONENT_WANTS_REMATCH", {"name": "孙权"}),
			"The same opponent back: Rematch (%s)" % over.status):
		return false
	app.controller.room_ready = [false, false]
	bridge.handshake_done = false
	bridge.opponent_present = false
	app.controller.leave_online(false)
	await _frames()
	if not _require(over.visible and over.closed and _result_actions_are(GameOverOverlay.CLOSED_ACTIONS) and app.controller.steam_bridge.lobby_id == 0,
			"The session over: View board, Main menu and Find a lobby remain"):
		return false
	over.buttons.steam.pressed.emit()
	await _frames(2)
	var steam_open = _top_dialog() != null and _top_dialog().has_method("refresh_lobbies")
	app.close_dialogs()
	app.bot_timer.paused = false
	return _require(app.menu.visible and steam_open, "Find a lobby opens the Steam dialog from the main menu")

## Issue 5: the room: the host's empty seat, a guest arriving, getting
## ready, the countdown and cancelling it, the guest's deck answer, both
## languages and window sizes, Change deck, Main menu and back, and leaving.
func _check_room_screen() -> bool:
	app.show_main_menu()
	_fake_room(true, false)
	app.controller.mode = MatchController.MODE_AI
	app.controller.started = false
	app.menu.action_requested.emit("online")
	await _frames()
	var room = app.room
	if not _require(room.visible and not app.menu.visible and not screen.visible, "Online in a lobby opens the room"):
		return false
	room.show_notice("", 0.0)
	if not _require(room.status_text() == UiKit.t("ROOM_WAITING_OPPONENT") and room.buttons.ready.disabled and room.buttons.invite.visible
			and room.buttons.ready.tooltip_text == UiKit.t("ROOM_WAITING_SEAT"),
			"The host's empty seat waits and offers Invite (%s, %s, %s)" % [room.status_text(), room.buttons.ready.disabled, room.buttons.invite.visible]):
		return false
	_fake_room(true, true)
	app.controller.room_changed.emit()
	await _frames()
	if not _require(not room.buttons.ready.disabled and not room.buttons.invite.visible and room.opponent_deck_key(1) == "ROOM_DECK_CHOSEN"
			and room.status_text() == UiKit.t("ROOM_WAIT_YOU"), "A guest arrived: you may get ready"):
		return false
	room.buttons.ready.pressed.emit()
	if not _require(app.controller.room_ready == [true, false] and room.buttons.ready.text == UiKit.t("ROOM_BTN_UNREADY")
			and room.status_text() == UiKit.t("ROOM_WAIT_OPPONENT", {"name": "孙权"}), "Ready: the room waits for the opponent"):
		return false
	var chimes = int(app.sfx.counts.get("ready", 0))
	app.controller._on_ready_received(true)
	await _frames()
	if not _require(app.controller.room_starting and room.status_text() == UiKit.t("ROOM_STARTING", {"n": app.controller.countdown_left()})
			and int(app.sfx.counts.get("ready", 0)) == chimes + 1, "Both ready: the countdown shows and the opponent's readiness chimes"):
		return false
	for window in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for locale in ["en", "zh_CN"]:
			root.size = window
			app.set_locale(locale)
			await _frames()
			var seats: Array = room.seat_rects()
			var inside = Rect2(Vector2.ZERO, room.size)
			var fits = seats.all(func(rect): return inside.encloses(rect))
			for button in room.buttons.values():
				if button.visible:
					fits = fits and inside.encloses(button.get_global_rect())
			if not _require(fits, "The room fits at %s in %s" % [window, locale]):
				root.size = Vector2i(1440, 900)
				return false
	root.size = Vector2i(1440, 900)
	app.set_locale("zh_CN")
	await _frames()
	room.buttons.ready.pressed.emit()
	if not _require(not app.controller.room_starting and app.controller.room_ready == [false, true], "Cancelling ready stops the countdown"):
		return false
	# The guest's side: its deck must be accepted first.
	app.controller.steam_bridge.is_host = false
	app.controller.room_ready = [false, false]
	app.controller.own_deck_result = {}
	room.refresh()
	if not _require(room.buttons.ready.disabled and room.buttons.ready.tooltip_text == UiKit.t("ROOM_READY_NEEDS_DECK")
			and room.own_deck_answer() == UiKit.t("DECK_ONLINE_PENDING"), "A guest gets ready only once the host accepted its deck"):
		return false
	app.controller.own_deck_result = {"ok": true}
	room.refresh()
	if not _require(not room.buttons.ready.disabled and room.own_deck_answer() == UiKit.t("ROOM_DECK_ACCEPTED"), "An accepted deck lets the guest get ready"):
		return false
	room.buttons.deck.pressed.emit()
	await _frames()
	var dialog = _top_dialog()
	if not _require(dialog is DecksDialog and dialog.single_column(), "Change deck in the room picks your own deck"):
		return false
	dialog.start_button.pressed.emit()
	await _frames(3)
	if not _require(room.visible and app.dialogs().is_empty(), "Choosing the deck returns to the room"):
		return false
	room.buttons.menu.pressed.emit()
	await _frames()
	if not _require(app.menu.visible and not room.visible, "Main menu leaves the room on screen only"):
		return false
	app.menu.action_requested.emit("online")
	await _frames()
	if not _require(room.visible, "Online returns to the room"):
		return false
	room.buttons.leave.pressed.emit()
	await _frames(2)
	var left = not room.visible and app.menu.visible and app.controller.steam_bridge.lobby_id == 0 and app.controller.room_phase == "none"
	app.close_dialogs()
	return _require(left, "Leave room returns to the menu and leaves the lobby")

## Issue 5: the match intro: the two rows of heroes from the rosters, the
## board held back (and the AI waiting) until it ends or a click skips it,
## before the hot-seat hand-over, again for every new match, never in instant
## mode or with the setting off.
func _check_versus_intro() -> bool:
	Settings.set_match_intro(true, false)
	app.bot_timer.paused = false
	AnimationQueue.instant = false
	AnimationQueue.speed = 1.0
	var before = screen.intro_count
	app.deck_selections = ["starter", "green_assault"]
	app.start_match(MatchController.MODE_AI)
	await _frames(2)
	var engine = _engine()
	var revision = int(engine.state.revision)
	var info = VersusIntro.versus_info(app.controller.view(), 0, MatchController.MODE_AI, {})
	var bottom = engine.state.players[0].roster.slice(0, 5).map(func(hero): return str(hero.card))
	var top = engine.state.players[1].roster.slice(0, 5).map(func(hero): return str(hero.card))
	if not _require(screen.versus.visible and screen.queue.busy and screen.intro_count == before + 1 and info.bottom.heroes == bottom and info.top.heroes == top,
			"A new match opens with both armies' heroes, yours below"):
		AnimationQueue.instant = true
		return false
	await create_timer(1.6).timeout
	var cards: Array = screen.versus._cards[0] + screen.versus._cards[1]
	var inside = Rect2(Vector2.ZERO, screen.size)
	var on_screen = cards.size() == 10 and cards.all(func(card): return inside.encloses(card.get_global_rect()))
	var plates_clear = true
	for plate in screen.versus._plates:
		for card in cards:
			plates_clear = plates_clear and not plate.intersects(card.get_global_rect())
	var waited = int(engine.state.revision) == revision and screen.queue.busy
	_click(screen.size * 0.5)
	var deadline = Time.get_ticks_msec() + 2000
	while (screen.versus.visible or screen.queue.busy) and Time.get_ticks_msec() < deadline:
		await process_frame
	var skipped = not screen.versus.visible
	if not _require(on_screen and plates_clear and waited and skipped,
			"The intro's ten heroes fit, the plates are clear of them, the AI waits, and a click skips it (%s %s %s %s)" % [on_screen, plates_clear, waited, skipped]):
		AnimationQueue.instant = true
		return false
	# Hot-seat: the intro, then the hand-over screen.
	app.start_match(MatchController.MODE_LOCAL)
	await _frames(2)
	var first_intro = screen.versus.visible and not screen.pass_screen.visible
	var local_info = VersusIntro.versus_info(app.controller.view(), 1, MatchController.MODE_LOCAL, {})
	var space = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space)
	deadline = Time.get_ticks_msec() + 2000
	while screen.versus.visible and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames(2)
	var then_pass = not screen.versus.visible and screen.pass_screen.visible
	if not _require(first_intro and then_pass and int(local_info.bottom.seat) == 0, "Hot-seat: the intro plays (Player 1 below) before the hand-over; Space skips it"):
		AnimationQueue.instant = true
		return false
	screen.pass_screen.confirm()
	# A new match plays it again; instant mode and the setting skip it.
	before = screen.intro_count
	app.start_match(MatchController.MODE_AI)
	await _frames(2)
	var again = screen.intro_count == before + 1
	Settings.set_match_intro(false, false)
	app.start_match(MatchController.MODE_AI)
	await _frames(2)
	var off = screen.intro_count == before + 1 and not screen.versus.visible
	Settings.set_match_intro(true, false)
	AnimationQueue.instant = true
	app.start_match(MatchController.MODE_AI)
	await _settle()
	return _require(again and off and screen.intro_count == before + 1 and not screen.versus.visible,
		"Every new match has its intro; not with the setting off or in instant mode")

## Review fix: long Steam names (32 characters, wide glyphs) stay inside the
## intro's name plates and the in-match plate, cut with an ellipsis; the
## plate's tooltip then has the whole name.
func _check_long_names() -> bool:
	var long_names = ["ThisIsAVeryLongSteamNameForTest!", "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW", "司马懿仲达不死之谋略大将军天下无双第一谋士"]
	var font = UiKit.title_font()
	var versus = screen.versus
	app.show_match()
	for window in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		root.size = window
		await _frames()
		var info = {"top": {"name": long_names[2], "heroes": [], "caption": UiKit.t("VERSUS_OPPONENT")},
			"bottom": {"name": long_names[1], "heroes": [], "caption": UiKit.t("VERSUS_YOU")}}
		versus.play(info)
		await _frames(2)
		var inside = Rect2(Vector2.ZERO, versus.size)
		for row in range(2):
			var plate: Rect2 = versus._plates[row]
			var box: Rect2 = versus.name_box(row)
			for text in long_names:
				var drawn: Array = VersusIntro.plate_name(text, box.size.x)
				var width = font.get_string_size(str(drawn[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(drawn[1])).x
				if not _require(inside.encloses(plate) and plate.encloses(box) and width <= box.size.x and str(drawn[0]).ends_with("…"),
						"The intro's plate holds a long name at %s (row %d: %.0f of %.0f px, \"%s\")" % [window, row, width, box.size.x, drawn[0]]):
					versus.abort()
					root.size = Vector2i(1440, 900)
					return false
		versus.abort()
	root.size = Vector2i(1440, 900)
	await _frames()
	# The in-match plate: the name between the stats and the menu, the ping
	# giving way, the whole name in the tooltip.
	var panel = screen.enemy_panel
	panel.set_values(long_names[0], 12, 35, 5, false)
	panel.set_connection({"level": "good", "ping": 48})
	panel.set_deeds(["sun_quan"])
	await _frames()
	var room = panel.name_span.y - panel.name_span.x
	var size = UiKit.fit_size(font, long_names[0], room, 21, 12)
	var width = font.get_string_size(panel.shown_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var stats_end = 18.0 + 74.0 + 62.0 + 56.0 + 56.0
	if not _require(panel.name_cut and panel.shown_name.ends_with("…") and width <= room
			and panel.name_span.x >= stats_end and panel.tooltip_text.begins_with(long_names[0]),
			"The opponent's plate cuts a long name clear of its stats (\"%s\", %.0f px in %s)" % [panel.shown_name, width, panel.name_span]):
		return false
	panel.set_values("孙权", 12, 35, 5, false)
	await _frames()
	var short_ok = not panel.name_cut and panel.shown_name == "孙权" and not panel.tooltip_text.begins_with("孙权")
	panel.set_deeds([])
	panel.set_connection({})
	return _require(short_ok, "A short name is shown whole")

## Review fix: the host concedes and leaves in one burst (result, room and
## goodbye in one poll): the guest's screen keeps the match, shows its
## victory once the board has caught up, with only the ways out, and names
## the opponent (not the AI).
func _check_host_left_result() -> bool:
	AnimationQueue.instant = true
	app.deck_selections = ["starter", "starter"]
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _settle()
	var engine = _engine()
	var controller = app.controller
	_fake_room(false)
	controller.mode = MatchController.MODE_ONLINE
	controller.room_phase = "match"
	controller.match_serial = 0
	var publish = func(serial: int) -> void:
		var view = engine.player_view(1)
		view.players[0]["preset"] = MatchController.HIDDEN_DECK
		controller._online_state(view, engine.legal_actions(1), serial)
	engine.state.phase = "action"
	engine.state.lane = 0
	engine.state.active_player = 0
	engine.state.first_pass = -1
	publish.call(61)
	await _settle()
	if not _require(screen.visible and controller.online_match_running() and not screen.game_over.visible, "The guest plays an online match"):
		return false
	AnimationQueue.instant = false
	AnimationQueue.speed = 1.0
	engine.apply_action(0, {"type": "concede"})
	publish.call(61)
	controller.steam_bridge._end_session("host_left")
	await _frames(2)
	var kept = screen.visible and not app.menu.visible and app.dialogs().is_empty()
	await _settle_real(10.0)
	await _frames(2)
	var over = screen.game_over
	var shown = over.visible and over.closed and _result_actions_are(GameOverOverlay.CLOSED_ACTIONS) \
		and over.result_key == "RESULT_VICTORY" and over.status == controller.steam_status_text()
	var named = over.detail.contains("孙权") and not over.detail.contains(UiKit.t("PLAYER_AI"))
	AnimationQueue.instant = true
	if not _require(kept and shown and named, "The guest sees its win after the host left (kept %s, shown %s, named %s: %s / %s)"
			% [kept, shown, named, over.status, over.detail]):
		return false
	# View board, then the coin: the result returns with the ways out only.
	over.buttons.board.pressed.emit()
	await _frames()
	screen.press_coin()
	await _frames()
	if not _require(over.visible and over.closed and _result_actions_are(GameOverOverlay.CLOSED_ACTIONS),
			"After View board the result returns with only the ways out"):
		return false
	# Leaving a running match on purpose (it concedes) goes to the menu.
	app.start_match(MatchController.MODE_AI)
	await _settle()
	_fake_room(true)
	controller.mode = MatchController.MODE_ONLINE
	controller.room_phase = "match"
	controller.refresh()
	await _settle()
	var confirm = app.open_leave()
	await _frames(2)
	confirm.confirmed.emit()
	await _frames(2)
	var to_menu = app.menu.visible and not screen.visible and int(engine.state.winner) == 1
	app.close_dialogs()
	app.bot_timer.paused = false
	if not _require(to_menu, "Leaving a running match from the menu concedes it and goes to the main menu (menu %s, screen %s, winner %d)"
			% [app.menu.visible, screen.visible, int(engine.state.winner)]):
		return false
	# Back to a match against the AI for the checks after this one.
	app.start_match(MatchController.MODE_AI)
	await _settle()
	return true

# --- v0.6.2: music and the lane HUD's hover cards ------------------------------------------

## True when the bus `bus_name` plays at `level` (linear).
func _bus_at(bus_name: String, level: float) -> bool:
	var index = AudioServer.get_bus_index(bus_name)
	return index != -1 and absf(db_to_linear(AudioServer.get_bus_volume_db(index)) - level) < 0.01

## Waits `seconds` of real time (timers run while the tree is paused).
func _wait_real(seconds: float) -> void:
	await create_timer(seconds, true).timeout

## The music: buses and routing, the tracks (loops loop), the settings'
## music and effects sliders (persisted, localized, mute on Master), the
## states driven by real match events (menu, the fanfare as a match begins,
## battle, urgency once a tower falls and for the rest of that match, the
## menu after a result's pause, no fanfare for a restored replay, hot-seat),
## no restart for the state already playing, crossfades that never stack
## more than the two players and leave one, and fades while paused.
func _check_music() -> bool:
	var music = app.music
	var players: Array = music.players()
	var player_children = music.get_children().filter(func(node): return node is AudioStreamPlayer)
	if not _require(AudioServer.get_bus_index(Settings.MUSIC_BUS) != -1 and AudioServer.get_bus_index(Settings.SFX_BUS) != -1
			and players.size() == 2 and player_children.size() == 2 and players.all(func(player): return player.bus == Settings.MUSIC_BUS)
			and app.sfx.players().all(func(player): return player.bus == Settings.SFX_BUS)
			and music.process_mode == Node.PROCESS_MODE_ALWAYS,
			"Music plays on two players on the Music bus, effects on the SFX bus, and music runs while paused"):
		return false
	for state_name in Music.TRACKS:
		var stream = music.stream_for(state_name)
		if not _require(stream != null and stream.get_length() > 5.0 and bool(stream.loop) == (state_name != Music.STING),
				"Track %s loads, and loops unless it is the fanfare" % state_name):
			return false
	# Settings: master, music and effects sliders, persisted and localized.
	Settings.set_muted(false, false)
	var dialog = app.open_settings()
	await process_frame
	if not _require(dialog.level_labels.music.text == UiKit.t("SETTINGS_VOLUME_MUSIC") and dialog.level_labels.sfx.text == UiKit.t("SETTINGS_VOLUME_SFX")
			and dialog.level_labels.master.text == UiKit.t("SETTINGS_VOLUME_MASTER") and dialog.level_labels.music.text == "音乐",
			"The settings name the master, music and effects sliders in the current language"):
		return false
	dialog.music_slider.value = 0.35
	dialog.sfx_slider.value = 0.8
	dialog.volume_slider.value = 0.9
	if not _require(_bus_at(Settings.MUSIC_BUS, 0.35) and _bus_at(Settings.SFX_BUS, 0.8) and _bus_at("Master", 0.9)
			and dialog.level_values.music.text == "35%",
			"The sliders set the Music, SFX and Master buses at once"):
		return false
	var stored = ConfigFile.new()
	stored.load(Settings.PATH)
	Settings.music_volume = 0.6
	Settings.sfx_volume = 1.0
	Settings.load_settings()
	if not _require(is_equal_approx(float(stored.get_value("audio", "music_volume", -1.0)), 0.35) and is_equal_approx(Settings.music_volume, 0.35)
			and is_equal_approx(Settings.sfx_volume, 0.8) and _bus_at(Settings.MUSIC_BUS, 0.35),
			"The music and effects volumes persist and come back on load"):
		return false
	app.set_locale("en")
	if not _require(dialog.level_labels.music.text == "Music" and dialog.level_labels.sfx.text == "Sound effects", "The volume captions follow a language switch"):
		return false
	app.set_locale("zh_CN")
	dialog.toggles.mute.button_pressed = true
	var master = AudioServer.get_bus_index("Master")
	var muted_ok = AudioServer.is_bus_mute(master) and Settings.effective_sfx_volume() == 0.0
	dialog.toggles.mute.button_pressed = false
	if not _require(muted_ok and not AudioServer.is_bus_mute(master), "Mute silences Master: the music and the effects"):
		return false
	dialog.music_slider.value = 0.0
	var music_off = AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.MUSIC_BUS))
	dialog.music_slider.value = 0.6
	dialog.sfx_slider.value = 1.0
	dialog.volume_slider.value = 0.7
	if not _require(music_off and not AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.MUSIC_BUS)), "A music volume of 0 mutes only the music"):
		return false
	app.close_dialogs()
	# The states, from the menu through a match.
	music.fade_seconds = 0.2
	app.show_main_menu()
	var started = music.started_count
	app.open_settings()
	app.close_dialogs()
	app.open_deck_list()
	app.close_dialogs()
	app.show_main_menu()
	if not _require(music.state == "menu" and music.started_count == started, "The menu music plays on the menu and its dialogs without restarting"):
		return false
	app.deck_selections = ["starter", "starter"]
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _settle()
	if not _require(music.state == "battle_start" and music.history.back() == "battle_start" and screen.music_state() == "battle",
			"A new match opens with the fanfare (%s, screen %s)" % [music.state, screen.music_state()]):
		return false
	music.finish_sting()
	started = music.started_count
	var front = music.front_player()
	screen.sync_music()
	app.show_match()
	app.controller.refresh()
	await _settle()
	if not _require(music.state == "battle" and music.started_count == started and music.front_player() == front,
			"The battle loop follows the fanfare; asking for it again changes nothing"):
		return false
	var engine = _engine()
	Kernel.damage_structure(engine, 0, 1, 100)
	app.controller.refresh()
	await _settle()
	var fell = app.controller.view().events.any(func(event): return str(event.get("k", "")) == "tower_fall")
	if not _require(fell and music.state == "urgency" and screen.music_state() == "urgency", "A tower falling switches to the urgent music (%s)" % music.state):
		return false
	started = music.started_count
	engine.state.lanes[0].structures[1].ancient = false
	app.controller.refresh()
	await _settle()
	if not _require(music.state == "urgency" and music.started_count == started, "The urgent music stays for the rest of the match"):
		return false
	engine.state.lanes[0].structures[1].ancient = true
	app.show_main_menu()
	var to_menu = music.state == "menu"
	var before_resume = music.history.size()
	app.show_match()
	if not _require(to_menu and music.state == "urgency" and not music.history.slice(before_resume).has("battle_start"),
			"Leaving the match plays the menu music; resuming brings the urgent music back without the fanfare"):
		return false
	# A restored replay: no fanfare, its own battle state.
	var replay_path = "res://.tools/scratch/ui_music_replay.json"
	app.save_replay(replay_path)
	var before_replay = music.history.size()
	app.load_replay(replay_path)
	await _settle()
	var expected = "urgency" if MatchScreen.tower_fallen(app.controller.view()) else "battle"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(replay_path))
	if not _require(not music.history.slice(before_replay).has("battle_start") and music.state == expected,
			"A restored replay plays its battle music without the fanfare (%s)" % music.state):
		return false
	# The result: the music fades, the menu music follows after a pause.
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _settle()
	await _finish_match(0)
	if not _require(screen.game_over.visible and music.pending == "menu" and music.state == "", "A result fades the battle music out"):
		return false
	await _wait_real(Music.RESULT_PAUSE + 0.4)
	if not _require(music.state == "menu" and music.pending == "", "The menu music follows the result after a pause"):
		return false
	# Hot-seat: the fanfare again.
	app.start_match(MatchController.MODE_LOCAL)
	await _settle()
	if not _require(music.state == "battle_start", "A hot-seat match opens with the fanfare"):
		return false
	# Crossfades: quick changes never stack more than the two players, and a
	# finished fade leaves one at full level.
	music.fade_seconds = Music.FADE_SECONDS
	for state_name in ["menu", "battle", "urgency", "menu", "battle"]:
		music.request(state_name)
		if not _require(music.playing_players().size() <= 2 and music.get_children().filter(func(node): return node is AudioStreamPlayer).size() == 2,
				"A crossfade never stacks more than two players"):
			return false
	if not _require(music.state == "battle" and music.fading(), "The last state asked for fades in"):
		return false
	await _wait_real(Music.FADE_SECONDS + 0.3)
	var sounding: Array = music.playing_players()
	if not _require(sounding.size() == 1 and sounding[0] == music.front_player() and sounding[0].stream == music.stream_for("battle")
			and absf(sounding[0].volume_db) < 0.1 and not music.fading(),
			"A finished crossfade leaves one player at full level (%d playing)" % sounding.size()):
		return false
	started = music.started_count
	for repeat in range(3):
		music.request("battle")
	if not _require(music.started_count == started and not music.fading(), "Asking for the playing state again does not restart it"):
		return false
	# Paused: the fade still completes.
	paused = true
	music.request("urgency")
	await _wait_real(Music.FADE_SECONDS + 0.3)
	sounding = music.playing_players()
	var paused_ok = sounding.size() == 1 and sounding[0].stream == music.stream_for("urgency") and absf(sounding[0].volume_db) < 0.1
	paused = false
	if not _require(paused_ok, "Music crossfades while the game is paused"):
		return false
	music.fade_seconds = Music.FADE_SECONDS
	return true

## Hovers the hero chip `uid` with a real mouse move and returns the preview
## rect (global), or an empty rect when no preview shows.
func _hover_chip(uid: int) -> Rect2:
	var hud = screen.hud
	var point = hud.hero_chip_center(uid)
	_mouse(point + Vector2(0, 1))
	_mouse(point)
	await process_frame
	await process_frame
	if hud.hovered_uid != uid or not hud.preview.visible:
		return Rect2()
	return hud.preview.get_global_rect()

## The lane HUD's hover cards: every hero chip (fountain and lanes, both
## sides) shows its card with live stats and status (ready in N rounds, in a
## lane, fallen), stays on screen at 1440x900 and 1280x720, follows the
## language and the card theme, hides when the pointer leaves, and a
## right-click opens the inspector.
## Script files under `dir` (recursive) with a single-quoted or
## double-quoted string literal that runs over a raw line break, as
## "file:line" (triple-quoted strings and comments are skipped).
func _scripts_with_broken_strings(dir: String) -> Array:
	var found: Array = []
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_scripts_with_broken_strings(dir.path_join(sub)))
	for file_name in DirAccess.get_files_at(dir):
		if not file_name.ends_with(".gd"):
			continue
		var path = dir.path_join(file_name)
		var source = FileAccess.get_file_as_string(path)
		var line = 1
		var i = 0
		var quote = ""
		var start_line = 0
		while i < source.length():
			var ch = source[i]
			if quote.is_empty():
				if ch == "#":
					while i < source.length() and source[i] != "\n":
						i += 1
					continue
				if ch == "\"" or ch == "'":
					quote = source.substr(i, 3) if source.substr(i, 3) == ch.repeat(3) else ch
					start_line = line
					i += quote.length()
					continue
			elif ch == "\\":
				if i + 1 < source.length() and source[i + 1] == "\n":
					line += 1
				i += 2
				continue
			elif source.substr(i, quote.length()) == quote:
				i += quote.length()
				quote = ""
				continue
			elif ch == "\n" and quote.length() == 1:
				found.append("%s:%d" % [path, start_line])
				quote = ""
			if ch == "\n":
				line += 1
			i += 1
	return found

func _check_hud_hover() -> bool:
	var hud = screen.hud
	app.deck_selections = ["starter", "green_assault"]
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _settle()
	var engine = _engine()
	var bot = Bot.new()
	var guard = 0
	while not (engine.state.phase == "action" and int(engine.state.active_player) == 0 and int(engine.state.round) >= 1) and guard < 200:
		var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
		engine.apply_action(player, bot.choose_action(engine, player))
		guard += 1
	# An enemy hero falls (as the kernel does it): fountain, two rounds out.
	var fallen: Dictionary = {}
	for unit in engine.state.players[1].roster:
		if int(unit.get("lane", -1)) != -1 and fallen.is_empty():
			fallen = unit
	if not _require(not fallen.is_empty(), "An enemy hero stands in a lane"):
		return false
	engine._remove_from_lane(fallen)
	engine._enter_fountain(fallen, int(engine.state.round) + 2)
	engine._event("death", {"p": 1, "uid": fallen.uid, "card": fallen.card, "gold": 0})
	app.controller.refresh()
	await _settle()
	var chips: Array = hud.hero_chips()
	var kinds = {"lane_own": false, "lane_enemy": false, "fountain_own": false, "fountain_enemy": false}
	for entry in chips:
		kinds[("lane_" if int(entry.lane) >= 0 else "fountain_") + ("own" if int(entry.side) == 1 else "enemy")] = true
	if not _require(kinds.values().all(func(value): return value), "The HUD shows hero chips in the fountain and the lanes on both sides (%s)" % kinds):
		return false
	for size in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		root.size = size
		await process_frame
		await process_frame
		var inside = Rect2(Vector2.ZERO, screen.size)
		for entry in hud.hero_chips():
			var uid = int(entry.hero.uid)
			var rect: Rect2 = await _hover_chip(uid)
			if not _require(rect.size.x > 200.0 and inside.encloses(rect) and not rect.intersects(hud.get_global_rect()),
					"%dx%d: hovering hero %s shows its card on screen, under the HUD (%s)" % [size.x, size.y, entry.hero.card, rect]):
				root.size = Vector2i(1440, 900)
				return false
			var card = hud.preview.card
			var model = hud.hero_model(entry)
			if not _require(card.card_id == str(entry.hero.card) and int(card.live.get("health", -1)) == int(model.get("health", -2))
					and int(card.live.get("attack", -1)) == int(model.get("attack", -2)),
					"The hover card shows %s with its live stats" % entry.hero.card):
				root.size = Vector2i(1440, 900)
				return false
	root.size = Vector2i(1440, 900)
	await process_frame
	await process_frame
	# Status lines: a lane hero, a waiting hero, the fallen one; whose side.
	var lane_hero: Dictionary = {}
	var waiting: Dictionary = {}
	for entry in hud.hero_chips():
		if int(entry.lane) >= 0 and int(entry.side) == 1 and lane_hero.is_empty():
			lane_hero = entry
		if int(entry.lane) == -1 and int(entry.hero.get("ready_round", 1)) > int(engine.state.round) and int(entry.hero.uid) != int(fallen.uid) and waiting.is_empty():
			waiting = entry
	await _hover_chip(int(lane_hero.hero.uid))
	var lane_text = hud.preview.shown_text()
	var lane_ok = lane_text.find(UiKit.t("HUD_SIDE_OWN")) != -1 and lane_text.find(UiKit.t("FOUNTAIN_IN_LANE", {"lane": EventText.lane_name(int(lane_hero.lane))})) != -1
	var wait_ok = true
	if not waiting.is_empty():
		await _hover_chip(int(waiting.hero.uid))
		var rounds = int(waiting.hero.ready_round) - int(engine.state.round)
		wait_ok = hud.preview.shown_text().find(UiKit.t_n("HUD_HERO_DEPLOYS_IN", rounds)) != -1 and hud.preview.shown_text().find(UiKit.t("HUD_HERO_FALLEN")) == -1
	await _hover_chip(int(fallen.uid))
	var fallen_text = hud.preview.shown_text()
	var fallen_ok = fallen_text.find(UiKit.t("HUD_HERO_FALLEN")) != -1 and fallen_text.find(UiKit.t_n("HUD_HERO_DEPLOYS_IN", 2)) != -1 \
		and fallen_text.find(UiKit.t("HUD_SIDE_ENEMY")) != -1 and fallen_text.find("回合后可出阵") != -1
	if not _require(lane_ok and wait_ok and fallen_ok, "The hover card says whose hero it is, where, and when it is ready or that it fell (%s | %s)" % [lane_text, fallen_text]):
		return false
	# The deployment wait and the ability cooldown read differently (both
	# languages, singular and plural): the status line never says the
	# cooldown's "Ready in N rounds", and no line carries a carriage return.
	var distinct = true
	for locale in ["en", "zh_CN"]:
		app.set_locale(locale)
		for n in [1, 2, 3]:
			distinct = distinct and UiKit.t_n("HUD_HERO_DEPLOYS_IN", n) != UiKit.t_n("HUD_COOLDOWN", n) \
				and UiKit.t_n("HUD_HERO_DEPLOYS_IN", n).find(str(n)) != -1
		await process_frame
		var status_text: String = hud.preview.status_label.text
		distinct = distinct and status_text.find(UiKit.t_n("HUD_HERO_DEPLOYS_IN", 2)) != -1 and status_text.find(UiKit.t_n("HUD_COOLDOWN", 2)) == -1 \
			and hud.preview.shown_text().find("\r") == -1 and hud.preview.text_label.text.find("\r") == -1
	app.set_locale("zh_CN")
	await process_frame
	if not _require(distinct, "The hover card's deployment wait (\"Deploys in N rounds\") differs from the ability cooldown line, with no stray carriage returns"):
		return false
	var broken: Array = _scripts_with_broken_strings("res://scripts") + _scripts_with_broken_strings("res://tests")
	if not _require(broken.is_empty(), "No script string literal spans a raw line break (a CRLF checkout would add a stray \\r): %s" % [broken]):
		return false
	# Language and card theme: the open card follows.
	app.set_locale("en")
	app.set_skin("classic")
	await process_frame
	var classic_name = hud.preview.name_label.text == Library.loc(str(fallen.card)) and hud.preview.shown_text().find("Fallen in battle") != -1
	app.set_skin("three_kingdoms")
	app.set_locale("zh_CN")
	await process_frame
	var kingdoms_name = hud.preview.name_label.text == Library.loc(str(fallen.card)) and hud.preview.shown_text().find("已阵亡") != -1
	if not _require(classic_name and kingdoms_name and hud.preview.z_index > 0, "The hover card follows the language and the card theme, above the panels"):
		return false
	# Right-click inspects; leaving the HUD hides the card.
	var point = hud.hero_chip_center(int(lane_hero.hero.uid))
	_click(point, MOUSE_BUTTON_RIGHT)
	await process_frame
	var inspected = screen.inspect.visible and screen.inspect.card_id == str(lane_hero.hero.card) \
		and int(screen.inspect.live.get("unit", {}).get("uid", -1)) == int(lane_hero.hero.uid) and not hud.preview.visible
	screen.inspect.close()
	_click(hud.hero_chip_center(int(fallen.uid)), MOUSE_BUTTON_RIGHT)
	await process_frame
	var inspected_fountain = screen.inspect.visible and screen.inspect.card_id == str(fallen.card)
	screen.inspect.close()
	await process_frame
	await _hover_chip(int(fallen.uid))
	_mouse(screen.size * 0.5)
	await process_frame
	if not _require(inspected and inspected_fountain and not hud.preview.visible and hud.hovered_uid == -1,
			"Right-clicking a lane or fountain hero chip inspects it; moving away hides the hover card"):
		return false
	app.bot_timer.paused = false
	return true
