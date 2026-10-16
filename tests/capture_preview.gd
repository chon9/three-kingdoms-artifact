extends SceneTree
## Captures the main UI states as PNGs in res://.tools/shots/. Needs the real
## renderer, so run it without --headless:
##   godot --path . -s res://tests/capture_preview.gd [-- --only=lane_action,shop]
## Shots: main_menu, deployment_staging (round-two staging strips),
## deployment_staging_zh,
## deployment_reassign (a staged hero dragged toward another lane),
## deployment_reveal (mid-reveal), lane_action, lane_action_zh,
## drag_targeting, inspect, overview, hand_full (13 cards), combat
## (mid-animation), shop, shop_zh, deployment (a tray hero mid-drag),
## game_over, game_over_zh, hud_fountain (five heroes per fountain).
## On the rules fixture pack (EFFECT_SYSTEM_SPEC.md M2): m2_board (status and
## keyword icons, tower badges, both improvement rows, item ability buttons,
## hand marks and locked card backs), m2_board_zh, m2_overview (count chips),
## m2_stepper_lane, m2_stepper_position, m2_stepper_improvement,
## m2_item_ability (an item's lane step), m2_inspect, and two event
## animations mid-flight: m2_anim_status (a stun landing) and m2_anim_combat
## (combat strikes with cleave and retaliation); m2_chip_rows (the "+n" chip
## hovered open, a cooling chip in front), m2_hand_note and m2_hand_note_zh
## (a locked card's note beside the lifted card).
## M3 (red and green cards, the new presets): m3_lane (a mid-game lane of the
## Sun-Liu Alliance against A Gathering of Champions, new cards in hand and a
## Steel Reinforcement by your tower), m3_lane_zh, m3_lane_classic, m3_hand (a
## new card lifted), m3_hand_zh, m3_inspect (a new hero), m3_inspect_zh,
## m3_catalog (the catalog filtered to red / Shu), m3_catalog_zh (green / Wu),
## m3_decks (two of the new presets in the deck dialog) and m3_decks_zh.
## M4 (blue cards, the blue presets): m4_lane (Bronze Sparrow Terrace against
## Struggle for Longxi, new blue cards in hand), m4_lane_zh, m4_lane_classic,
## m4_lane_classic_zh, m4_hand (a new card lifted), m4_hand_zh, m4_hack_note
## (a card hacked by Self Sabotage, its note quoting the added text),
## m4_hack_note_zh, m4_inspect (a new blue hero), m4_inspect_zh, m4_catalog
## (the catalog filtered to blue / Wei), m4_catalog_zh, m4_catalog_classic,
## m4_decks (the new presets in the deck dialog) and m4_decks_zh.
## M5 (black cards, the black presets): m5_lane (Fengyi Pavilion against the
## Yellow Turban Rebellion, new black cards in hand), m5_lane_zh,
## m5_lane_classic, m5_lane_classic_zh, m5_hand (a new card lifted),
## m5_hand_zh, m5_inspect (a new black hero), m5_inspect_zh, m5_catalog (the
## catalog filtered to black / Qun), m5_catalog_zh, m5_catalog_classic,
## m5_catalog_classic_zh, m5_decks (the new presets in the deck dialog) and
## m5_decks_zh.
## M6 (items, the item presets): m6_lane (Five Tiger Generals against the
## Battle of Guandu: heroes with M6 equipment, one Stonehall item grown twice,
## M6 items in hand, a Shop Deed on each plate), m6_lane_zh, m6_lane_classic,
## m6_lane_classic_zh, m6_hand (an item lifted), m6_hand_zh, m6_item_inspect
## (a grown Stonehall item: its granted text with its count), m6_item_inspect_zh,
## m6_shop (a free Secret Shop offer under a Shop Deed), m6_shop_zh,
## m6_shop_paid (two deeds: the offer pays gold), m6_catalog (the catalog
## filtered to neutral: the items by slot and price), m6_catalog_zh,
## m6_catalog_classic, m6_catalog_classic_zh, m6_decks (the new presets in the
## deck dialog) and m6_decks_zh.
## M7 (improvements, the improvement presets): m7_lane (the Siege of Ye against
## the Struggle for Jing Province: M7 improvements by both towers of the shown
## lane, one with a ready active, M7 improvements in hand), m7_lane_zh,
## m7_lane_classic, m7_lane_classic_zh, m7_hand (an improvement lifted),
## m7_hand_zh, m7_oath (The Oath in the lane: a dimmed spell's note says it is
## forbidden), m7_oath_zh, m7_inspect (an improvement chip inspected),
## m7_inspect_zh, m7_catalog (the catalog filtered to black / Qun, its
## improvements among them), m7_catalog_zh, m7_catalog_classic,
## m7_catalog_classic_zh, m7_decks (the new presets in the deck dialog) and
## m7_decks_zh.
## Decks (the player's own decks): deck_list (My decks with a legal deck
## selected), deck_list_zh, deck_builder (an unfinished deck: an empty round 3
## slot, lamps red and green, the curve, a hovered row's card), deck_builder_zh,
## deck_builder_classic (the classic skin), deck_builder_drag (a card dragged
## onto the deck panel), deck_builder_valid (a legal deck: every lamp green,
## the item deck and the item filter) and deck_import (the import prompt);
## after review: deck_builder_four(_zh) (a four-faction deck with a message
## toast), deck_import_error(_zh) and deck_list_import_error (the import
## prompt with an error), deck_builder_slot (an empty slot clicked: the
## heroes shown, the slot marked) and deck_template (the question before a
## preset replaces a deck). With
## only deck shots requested (--only=deck_list,...) no match is played. The
## decks are written to res://.tools/scratch/capture_decks, never user://.
## v0.6.1: turn_cue (the your-action banner and rings), history, history_zh,
## history_hover (a tile's hover card), game_over_online(_zh) (Rematch,
## Change deck, Save, View board, Leave room; the opponent wants a rematch),
## room_waiting (the host's empty seat), room_ready(_zh) (both seats, both
## ready, the countdown), room_guest (the guest's side, its deck pending),
## room_deck (Change deck over the room: your own deck only),
## versus, versus_zh, versus_local (the match intro), settings(_zh). With
## only these shots requested no other capture runs. Review fixes (long
## Steam names, the guest's result after the host left): versus_online(_zh)
## (the online intro, a 32-character name and a long Chinese one),
## board_online(_zh) (the opponent's plate with a long name and the ping),
## room_long(_zh) (both seats with long names, the opponent ready for a
## rematch: the ready marks are labels, not buttons) and
## game_over_host_left(_zh) (the guest's win, the session over).
## v0.6.2: hud_hover(_zh) (a lane hero's hover card from the lane HUD, with
## its live stats), hud_hover_fallen(_zh) (an enemy hero that fell, waiting
## in the fountain) and hud_hover_classic (the classic skin). With only these
## shots requested no other capture runs.
## Pass --size=1280x720 to check the smaller window, --out=res://dir/ to save
## the shots elsewhere.

const MainScene = preload("res://scenes/main.tscn")
const Settings = preload("res://scripts/core/game_settings.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const MatchController = preload("res://scripts/game/match_controller.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const Library = preload("res://scripts/core/card_library.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Select = preload("res://scripts/core/rules/select.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const FIXTURES = "res://tests/fixtures/rules_fixtures.json"
const M2_SHOTS = ["m2_board", "m2_board_zh", "m2_overview", "m2_stepper_lane", "m2_stepper_position",
	"m2_stepper_improvement", "m2_item_ability", "m2_inspect", "m2_anim_status", "m2_anim_combat", "m2_chip_rows",
	"m2_hand_note", "m2_hand_note_zh"]
const M3_SHOTS = ["m3_lane", "m3_lane_zh", "m3_lane_classic", "m3_hand", "m3_hand_zh", "m3_inspect", "m3_inspect_zh",
	"m3_catalog", "m3_catalog_zh", "m3_decks", "m3_decks_zh"]
## New red and green cards for the M3 hand (EFFECT_SYSTEM_SPEC.md Appendix A).
const M3_HAND = ["duel", "gods_strength", "viper_strike", "hand_of_god", "stonehall_elite", "spring_the_trap", "steel_reinforcement"]
const M4_SHOTS = ["m4_lane", "m4_lane_zh", "m4_lane_classic", "m4_lane_classic_zh", "m4_hand", "m4_hand_zh", "m4_hack_note",
	"m4_hack_note_zh", "m4_inspect", "m4_inspect_zh", "m4_catalog", "m4_catalog_zh", "m4_catalog_classic", "m4_decks", "m4_decks_zh"]
## New blue cards for the M4 hand; the last one carries a Self Sabotage hack.
const M4_HAND = ["eclipse", "mystic_flare", "friendly_fire", "incarnation_of_selemene", "lost_in_time", "barracks", "echo_slam"]
const M5_SHOTS = ["m5_lane", "m5_lane_zh", "m5_lane_classic", "m5_lane_classic_zh", "m5_hand", "m5_hand_zh", "m5_inspect",
	"m5_inspect_zh", "m5_catalog", "m5_catalog_zh", "m5_catalog_classic", "m5_catalog_classic_zh", "m5_decks", "m5_decks_zh"]
## New black cards for the M5 hand (EFFECT_SYSTEM_SPEC.md Appendix A).
const M5_HAND = ["gank", "winters_curse", "coordinated_assault", "assassins_shadow", "the_cover_of_night", "march_of_the_machines", "heartstopper_aura"]
const M6_SHOTS = ["m6_lane", "m6_lane_zh", "m6_lane_classic", "m6_lane_classic_zh", "m6_hand", "m6_hand_zh", "m6_item_inspect",
	"m6_item_inspect_zh", "m6_shop", "m6_shop_zh", "m6_shop_paid", "m6_catalog", "m6_catalog_zh", "m6_catalog_classic",
	"m6_catalog_classic_zh", "m6_decks", "m6_decks_zh"]
const M7_SHOTS = ["m7_lane", "m7_lane_zh", "m7_lane_classic", "m7_lane_classic_zh", "m7_hand", "m7_hand_zh", "m7_oath",
	"m7_oath_zh", "m7_inspect", "m7_inspect_zh", "m7_catalog", "m7_catalog_zh", "m7_catalog_classic", "m7_catalog_classic_zh",
	"m7_decks", "m7_decks_zh"]
## M7 improvements for the hand, and by each tower of the shown lane (the first
## of player 0's has a ready active).
const M7_HAND = ["glyph_of_confusion", "the_oath", "steam_cannon", "path_of_the_wise", "selemenes_favor", "the_omexe_arena", "bitter_enemies"]
const M7_OWN = ["keenfolk_turret", "trebuchets", "aghanims_sanctum", "fractured_timeline"]
const M7_ENEMY = ["burning_oil", "grand_melee", "unearthed_secrets"]
## M6 items for the hand (EFFECT_SYSTEM_SPEC.md Appendix A).
const M6_HAND = ["golden_ticket", "obliterating_orb", "fountain_flask", "apotheosis_blade", "horn_of_the_alpha", "claszureme_hourglass", "shop_deed"]
## M6 equipment for player 0's heroes in the shown lane, by slot.
const M6_GEAR = [["stonehall_pike", "stonehall_plate", "stonehall_cloak"], ["blink_dagger", "vesture_of_the_tyrant", "phase_boots"],
	["wingfall_hammer", "seraphim_shield", "book_of_the_dead"]]
const DECK_SHOTS = ["deck_list", "deck_list_zh", "deck_builder", "deck_builder_zh", "deck_builder_classic", "deck_builder_drag", "deck_import",
	"deck_builder_valid", "deck_builder_four", "deck_builder_four_zh", "deck_import_error", "deck_import_error_zh", "deck_list_import_error",
	"deck_builder_slot", "deck_template"]
const DECK_STORE = "res://.tools/scratch/capture_decks"
## v0.6.1: the your-action cue, the card history, results, the room, the
## match intro and the settings' new toggles.
const V061_SHOTS = ["turn_cue", "history", "history_zh", "history_hover", "game_over_online", "game_over_online_zh",
	"room_waiting", "room_ready", "room_ready_zh", "room_guest", "room_deck", "versus", "versus_zh", "versus_local", "settings", "settings_zh",
	"versus_online", "versus_online_zh", "board_online", "board_online_zh", "room_long", "room_long_zh", "game_over_host_left",
	"game_over_host_left_zh"]
## v0.6.2: the lane HUD's hero hover cards.
const HUD_SHOTS = ["hud_hover", "hud_hover_zh", "hud_hover_fallen", "hud_hover_fallen_zh", "hud_hover_classic"]
## Steam names as long as Steam allows (32 characters) and a long Chinese one.
const LONG_NAMES = ["ThisIsAVeryLongSteamNameForTest!", "司马懿仲达不死之谋略大将军天下无双第一谋士"]
const DeckStore = preload("res://scripts/core/deck_store.gd")
const DeckCode = preload("res://scripts/core/deck_code.gd")
const DeckModel = preload("res://scripts/core/deck_model.gd")
const OUT = "res://.tools/shots/"
const SEED = 20482

var app
var bot = Bot.new()
var only: Array = []
var saved: Array = []
var window_size = Vector2i(1440, 900)
var suffix = ""
var out_dir = OUT

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",")
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
			if not out_dir.ends_with("/"):
				out_dir += "/"
		if argument.begins_with("--size="):
			var parts = argument.trim_prefix("--size=").split("x")
			window_size = Vector2i(int(parts[0]), int(parts[1]))
			suffix = "_%dx%d" % [window_size.x, window_size.y]
	call_deferred("_run")

func _frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame

func _wanted(shot_name: String) -> bool:
	return only.is_empty() or shot_name in only

func _shot(shot_name: String) -> void:
	if not _wanted(shot_name):
		return
	# The window has keyboard focus: undo panels a stray key press may open.
	if app.screen.log_panel.visible:
		app.screen.log_panel.toggle(false)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var result = image.save_png(out_dir + shot_name + suffix + ".png")
	saved.append("%s (%s)" % [shot_name + suffix, error_string(result)])

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

## Waits (up to 20 s of real time) until the presentation queue is idle.
func _idle() -> void:
	var queue = app.screen.queue
	var deadline = Time.get_ticks_msec() + 20000
	while queue.busy and Time.get_ticks_msec() < deadline:
		await process_frame

func _publish() -> void:
	app.controller.state_changed.emit(app.controller.view(), app.controller.actions())

## Plays both sides with the bot until `done` returns true.
func _advance(done: Callable, limit: int = 800) -> bool:
	var engine = app.controller.engine
	for step in range(limit):
		if done.call(engine.state):
			return true
		if engine.state.winner != -1:
			return false
		var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
		var action = bot.choose_action(engine, player)
		if action.is_empty():
			return false
		engine.apply_action(player, action)
		_publish()
	return done.call(engine.state)

func _busy_lane(state: Dictionary) -> bool:
	if state.phase != "action" or int(state.active_player) != 0 or int(state.round) < 3:
		return false
	var lane = state.lanes[int(state.lane)]
	var counts = [0, 0]
	for side in range(2):
		for unit in lane.units[side]:
			if unit != null:
				counts[side] += 1
	var targeted = false
	for action in app.engine.legal_actions(0):
		if action.get("type", "") == "play" and action.has("target") and not action.has("destination"):
			targeted = true
	return counts[0] >= 3 and counts[1] >= 3 and state.players[0].hand.size() >= 4 and targeted

## Real mouse input through the viewport (the same path as a player).
func _mouse(position: Vector2, button: int = 0, pressed: bool = false) -> void:
	var event: InputEventMouse
	if button == 0:
		event = InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
	event.position = position
	event.global_position = position
	root.push_input(event, true)

func _run() -> void:
	# The player's own decks and remembered choices never reach the shots.
	DeckStore.root = DECK_STORE
	if DirAccess.dir_exists_absolute(DECK_STORE):
		for file_name in DirAccess.get_files_at(DECK_STORE):
			DirAccess.remove_absolute("%s/%s" % [DECK_STORE, file_name])
	root.size = window_size
	# Ignore the real cursor: only the scripted events below may move the mouse.
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]))
	Settings.set_locale("en", false)
	Settings.set_skin("three_kingdoms", false)
	app = MainScene.instantiate()
	# The intro only shows in its own shots; the history strip shows on the board.
	Settings.match_intro = false
	Settings.show_history = true
	root.add_child(app)
	app.set_locale("en")
	app.set_skin("three_kingdoms")
	await _frames(4)
	await _wait(0.5)
	await _shot("main_menu")
	Settings.set_match_intro(false, false)
	Settings.set_show_history(true, false)
	if not only.is_empty() and only.all(func(shot_name): return shot_name in DECK_SHOTS):
		await _capture_decks()
		print("Shots: ", ", ".join(saved))
		app.queue_free()
		await process_frame
		quit(0)
		return
	if not only.is_empty() and only.all(func(shot_name): return shot_name in HUD_SHOTS):
		await _capture_hud_hover()
		print("Shots: ", ", ".join(saved))
		app.queue_free()
		await process_frame
		quit(0)
		return
	if not only.is_empty() and only.all(func(shot_name): return shot_name in V061_SHOTS):
		await _capture_v061()
		print("Shots: ", ", ".join(saved))
		app.queue_free()
		await process_frame
		quit(0)
		return
	app.controller.current_seed = SEED
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	await _capture_deployment_staging()
	AnimationQueue.instant = true
	var reached = _advance(_busy_lane)
	AnimationQueue.instant = false
	print("Mid-game state: ", reached, " round ", app.engine.state.round, " lane ", app.engine.state.lane)
	await _wait(0.5)
	await _shot("lane_action")
	if _wanted("lane_action_zh"):
		app.set_locale("zh_CN")
		await _wait(0.2)
		await _shot("lane_action_zh")
		app.set_locale("en")
		await _wait(0.2)
	await _capture_drag()
	if _wanted("inspect"):
		var hero_uid = -1
		for unit in app.engine.state.lanes[int(app.engine.state.lane)].units[0]:
			if unit != null and unit.hero:
				hero_uid = int(unit.uid)
		app.screen.inspect_unit(hero_uid)
		await _wait(0.4)
		await _shot("inspect")
		app.screen.inspect.close()
	if _wanted("overview"):
		app.screen.toggle_overview()
		await _wait(0.7)
		await _shot("overview")
		app.screen.toggle_overview()
		await _wait(0.6)
	if _wanted("hand_full"):
		var hand: Array = app.engine.state.players[0].hand
		var original = hand.duplicate()
		while hand.size() < 13:
			hand.append(original[hand.size() % original.size()])
		_publish()
		await _wait(0.6)
		await _shot("hand_full")
		app.engine.state.players[0].hand = original
		_publish()
		await _wait(0.4)
		await _idle()
	await _capture_combat()
	await _capture_shop_and_deployment()
	await _capture_game_over()
	await _capture_hud_fountain()
	await _capture_m2()
	await _capture_m3()
	await _capture_m4()
	await _capture_m5()
	await _capture_m6()
	await _capture_m7()
	await _capture_v061()
	await _capture_hud_hover()
	app.show_main_menu()
	await _capture_decks()
	print("Shots: ", ", ".join(saved))
	app.queue_free()
	await process_frame
	quit(0)

func _capture_drag() -> void:
	if not _wanted("drag_targeting"):
		return
	var screen = app.screen
	# Aim at the legal target farthest from the hand for a long arrow.
	var index = -1
	var target_uid = -1
	var best = -1.0
	for action in screen.actions:
		if action.get("type", "") == "play" and action.has("target") and not action.has("destination"):
			var distance = screen.hand_card_point(int(action.hand)).distance_to(screen.unit_point(int(action.target)))
			if distance > best:
				best = distance
				index = int(action.hand)
				target_uid = int(action.target)
	if index == -1:
		print("No targeted card for the drag shot")
		return
	var start = screen.hand_card_point(index)
	var finish = screen.unit_point(target_uid)
	_mouse(start)
	await _frames(2)
	_mouse(start, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	for step in range(1, 13):
		_mouse(start.lerp(finish + Vector2(-90, 40), step / 12.0), 0, true)
		await _frames(1)
	_mouse(finish + Vector2(0, 12), 0, true)
	await _wait(0.35)
	await _shot("drag_targeting")
	_mouse(finish, MOUSE_BUTTON_RIGHT, true)
	_mouse(finish, MOUSE_BUTTON_LEFT, false)
	await _wait(0.3)

func _capture_combat() -> void:
	if not _wanted("combat"):
		return
	var engine = app.engine
	# Both players pass: the second pass resolves combat in this lane.
	if engine.state.phase == "action" and int(engine.state.active_player) == 0:
		app.screen.press_coin()
		await _idle()
	if engine.state.phase == "action" and int(engine.state.active_player) == 1:
		engine.apply_action(1, {"type": "pass"})
		_publish()
	# Mid-animation: units lunging back, damage numbers popping.
	await _wait(0.8)
	await _shot("combat")
	await _idle()

func _capture_shop_and_deployment() -> void:
	if not (_wanted("shop") or _wanted("shop_zh") or _wanted("deployment")):
		return
	AnimationQueue.instant = true
	_advance(func(state): return state.phase == "shop")
	var engine = app.engine
	engine.state.players[0].gold = 12
	engine.state.players[0].held_secret = ""
	_publish()
	AnimationQueue.instant = false
	await _wait(0.6)
	await _shot("shop")
	if _wanted("shop_zh"):
		app.set_locale("zh_CN")
		await _wait(0.2)
		await _shot("shop_zh")
		app.set_locale("en")
		await _wait(0.2)
	if not _wanted("deployment"):
		return
	app.screen.press_coin()
	await _idle()
	AnimationQueue.instant = true
	_advance(func(state): return state.phase == "deployment")
	AnimationQueue.instant = false
	await _wait(0.8)
	# Drag the first ready hero over the middle lane, mid-drag.
	var deployment = app.screen.deployment
	if not deployment.hero_cards.is_empty():
		var card = deployment.hero_cards[0]
		var start = card.get_global_rect().get_center()
		var finish = app.screen.lane_point(1)
		_mouse(start)
		_mouse(start, MOUSE_BUTTON_LEFT, true)
		for step in range(1, 11):
			_mouse(start.lerp(finish, step / 10.0), 0, true)
			await _frames(1)
		await _wait(0.2)
	await _shot("deployment")
	if not deployment.hero_cards.is_empty():
		_mouse(app.screen.lane_point(1), MOUSE_BUTTON_LEFT, false)
		await _wait(0.4)

func _capture_game_over() -> void:
	if not _wanted("game_over"):
		return
	var engine = app.engine
	AnimationQueue.instant = true
	_advance(func(state): return state.phase == "action")
	engine.state.lanes[0].structures[1].ancient = true
	engine.state.lanes[0].structures[1].health = 80
	engine.state.lanes[2].structures[1].ancient = true
	engine.state.lanes[2].structures[1].health = 80
	engine.state.winner = 0
	engine.state.phase = "finished"
	engine._event("win", {"p": 0})
	_publish()
	AnimationQueue.instant = false
	await _wait(1.2)
	await _shot("game_over")
	if _wanted("game_over_zh"):
		app.set_locale("zh_CN")
		await _wait(0.2)
		await _shot("game_over_zh")
		app.set_locale("en")

## A press, a drag in `steps` moves and (optionally) the release.
func _drag(start: Vector2, finish: Vector2, release: bool, steps: int = 10) -> void:
	_mouse(start)
	await _frames(2)
	_mouse(start, MOUSE_BUTTON_LEFT, true)
	for step in range(1, steps + 1):
		_mouse(start.lerp(finish, step / float(steps)), 0, true)
		await _frames(1)
	if release:
		_mouse(finish, MOUSE_BUTTON_LEFT, false)

## Round-two deployment against the AI: heroes staged in the lanes, a staged
## hero dragged toward another lane, and the reveal mid-animation.
func _capture_deployment_staging() -> void:
	if not (_wanted("deployment_staging") or _wanted("deployment_staging_zh") or _wanted("deployment_reassign") or _wanted("deployment_reveal")):
		return
	var screen = app.screen
	var engine = app.engine
	AnimationQueue.instant = true
	_advance(func(state): return state.phase == "deployment")
	AnimationQueue.instant = false
	await _wait(0.8)
	await _idle()
	for lane_index in range(2):
		if screen.deployment.hero_cards.is_empty():
			break
		var card = screen.deployment.hero_cards[0]
		await _drag(card.get_global_rect().get_center(), screen.lane_point(lane_index), true)
		await _wait(0.4)
	_mouse(screen.size * 0.5)
	await _wait(0.6)
	await _shot("deployment_staging")
	if _wanted("deployment_staging_zh"):
		app.set_locale("zh_CN")
		await _wait(0.2)
		await _shot("deployment_staging_zh")
		app.set_locale("en")
		await _wait(0.2)
	var key = ""
	for entry in screen.board.lanes[0].staged[1]:
		if entry.kind == "hero":
			key = entry.key
	if not key.is_empty():
		var start = screen.board.lanes[0].staged_global_center(key)
		var middle = (screen.lane_point(1) + screen.lane_point(2)) * 0.5
		await _drag(start, middle, false)
		_mouse(screen.lane_point(2), 0, true)
		await _wait(0.2)
		await _shot("deployment_reassign")
		_mouse(screen.lane_point(2), MOUSE_BUTTON_LEFT, false)
		await _wait(0.5)
	# Confirm; the AI confirms too and the reveal plays in real time.
	screen.press_coin()
	await _idle()
	var started: Array = []
	var on_lane = func(lane: int) -> void:
		started.append(lane)
	screen.reveal_lane_started.connect(on_lane)
	while not engine.state.players[1].finished and engine.state.phase == "deployment":
		engine.apply_action(1, bot.choose_action(engine, 1))
	_publish()
	var deadline = Time.get_ticks_msec() + 15000
	while not started.any(func(lane): return lane >= 1) and screen.queue.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	await _wait(0.35)
	await _shot("deployment_reveal")
	screen.reveal_lane_started.disconnect(on_lane)
	await _idle()
	await _wait(0.3)

## Five heroes in each fountain (two ready, the rest one or two rounds out)
## during a deployment, with one of yours planned.
func _capture_hud_fountain() -> void:
	if not _wanted("hud_fountain"):
		return
	app.controller.current_seed = SEED + 7
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	AnimationQueue.instant = true
	_advance(func(state): return state.phase == "deployment")
	var engine = app.engine
	var round_now = int(engine.state.round)
	var waits = [0, 0, 1, 2, 1]
	for player in range(2):
		var roster: Array = engine.state.players[player].roster
		for index in range(roster.size()):
			engine._remove_from_lane(roster[index])
			roster[index].lane = -1
			roster[index].ready_round = round_now + waits[index % waits.size()]
	engine.apply_action(0, {"type": "deploy", "unit": int(engine.state.players[0].roster[0].uid), "lane": 1})
	_publish()
	AnimationQueue.instant = false
	_mouse(app.screen.size * 0.5)
	await _wait(0.8)
	await _shot("hud_fountain")

# --- M2 pieces on the rules fixture pack ------------------------------------------

## A unit of fixture card `card_id` for `player`, spawned in lane 0.
func _fixture_unit(card_id: String, player: int) -> Dictionary:
	var engine = app.controller.engine
	var unit = engine._make_unit(engine.library.get_card(card_id), player, false)
	engine._spawn(unit, 0)
	return unit

## Lane 0 rebuilt on the fixture pack: units with statuses, flags and
## keywords on both sides, items with ready and cooling abilities, both
## improvement rows (with charges, cooldowns and a "+n" chip), tower badges,
## marked cards in hand and locked card backs.
func _m2_board() -> Dictionary:
	var engine = app.controller.engine
	engine.library = Library.from_file(FIXTURES, "rules_fixtures")
	engine.state.phase = "action"
	engine.state.lane = 0
	engine.state.active_player = 0
	engine.state.first_pass = -1
	for player in range(2):
		for unit in engine.state.lanes[0].units[player].duplicate():
			if unit != null:
				engine._remove_from_lane(unit)
				if bool(unit.get("hero", false)):
					unit.lane = -1
	var own: Array = engine.state.players[0].roster
	var enemy: Array = engine.state.players[1].roster
	var ctx_own = {"controller": 0, "card": "fx_grant_spell"}
	var ctx_enemy = {"controller": 1, "card": "fx_stun_spell"}
	# Your side: heroes with items, creeps with keywords and statuses.
	var axe: Dictionary = own[0]
	var jmuy: Dictionary = own[1]
	for hero in [axe, jmuy, own[4]]:
		engine._remove_from_lane(hero)
		hero.health = int(hero.max_health)
		engine._spawn(hero, 0)
	Zones.equip(engine, jmuy, "fx_blink_item")
	var banner = Zones.equip(engine, axe, "fx_charge_item")
	banner.cd = 2
	Zones.equip(engine, axe, "fx_regen_armor")
	Kernel.modify(engine, jmuy, {}, {}, "fx_grant_spell#0", ctx_own)
	Kernel.give(engine, jmuy, {}, {"death_shield": 1}, "", "used", {"controller": 0, "card": "fx_shield_spell"})
	var cleaver = _fixture_unit("fx_cleave_3", 0)
	Kernel.give(engine, cleaver, {"attack": 2}, {"damage_immunity": 1}, "", "round", {"controller": 0, "card": "fx_immunity_spell"})
	var sieger = _fixture_unit("fx_siege_3", 0)
	Kernel.modify(engine, sieger, {}, {"rapid_deployment": 1, "pierce": 1}, "", ctx_own)
	_fixture_unit("fx_soulbound_creep", 0)
	_fixture_unit("fx_soulbound_creep", 0)
	# The enemy: a stunned hero, a silenced and disarmed hero, keyword creeps.
	for hero in [enemy[0], enemy[1]]:
		engine._remove_from_lane(hero)
		hero.health = int(hero.max_health)
		engine._spawn(hero, 0)
	Kernel.give(engine, enemy[0], {}, {"stun": 1}, "", "round", ctx_enemy)
	Kernel.give(engine, enemy[1], {}, {"silence": 1, "disarm": 1}, "", "round", ctx_enemy)
	var spiked = _fixture_unit("fx_retaliate_2", 1)
	Kernel.modify(engine, spiked, {}, {"regeneration": 2}, "", ctx_enemy)
	_fixture_unit("fx_lethal_creep", 1)
	_fixture_unit("fx_bounty_creep", 1)
	var mender = _fixture_unit("fx_regen_2", 1)
	mender.health = 2
	for player in range(2):
		for unit in engine.state.lanes[0].units[player]:
			if unit != null:
				engine._roll_arrow(unit)
	# Improvements: eight of yours (five shown, then "+3"), three of theirs.
	var ids = ["fx_tower_guard", "fx_improvement_ping", "fx_countdown", "fx_library", "fx_glyph", "fx_improvement_ping",
		"fx_oath", "fx_countdown"]
	var placed: Array = []
	for card_id in ids:
		placed.append(Zones.add_improvement(engine, card_id, 0, 0))
	placed[5].cd = 1
	for card_id in ["fx_countdown", "fx_glyph", "fx_improvement_ping"]:
		Zones.add_improvement(engine, card_id, 1, 0).cd = 1 if card_id == "fx_improvement_ping" else 0
	# Hands: lock, charges and hacked marks; locked enemy card backs.
	var hand = ["fx_stun_spell", "fx_counter_spell", "fx_swap", "fx_move_any", "fx_raze", "fx_shield_spell"]
	var marks = [{"lock": 2}, {"charges": 3}, {"hacks": ["fx_hack_spell#0"]}, {}, {}, {}]
	for player in range(2):
		var states: Array = []
		for index in range(hand.size()):
			var entry = {"iid": Kernel.next_oid(engine)}
			if player == 0:
				entry.merge(marks[index])
			elif index in [1, 3]:
				entry["lock"] = 1 if index == 1 else 2
			states.append(entry)
		engine.state.players[player].hand = hand.duplicate()
		engine.state.players[player].hand_state = states
	engine.state.lanes[0].mana[0] = 10
	engine.state.lanes[0].max_mana[0] = 10
	return {"jmuy": jmuy, "axe": axe, "mover": cleaver, "blink": int(jmuy.item_state.accessory.oid), "hidden": int(placed[5].oid)}

func _capture_m2() -> void:
	if not M2_SHOTS.any(func(shot): return _wanted(shot)):
		return
	var screen = app.screen
	app.controller.current_seed = SEED + 11
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	AnimationQueue.instant = true
	_advance(func(state): return state.phase == "action" and int(state.active_player) == 0)
	var found = _m2_board()
	_publish()
	await _idle()
	screen.view_lane(0)
	AnimationQueue.instant = false
	_mouse(screen.size * 0.5 + Vector2(0, 40))
	await _wait(0.7)
	await _shot("m2_board")
	if _wanted("m2_board_zh"):
		app.set_locale("zh_CN")
		await _wait(0.3)
		await _shot("m2_board_zh")
		app.set_locale("en")
		await _wait(0.2)
	if _wanted("m2_overview"):
		screen.toggle_overview()
		await _wait(0.7)
		await _shot("m2_overview")
		screen.toggle_overview()
		await _wait(0.6)
	if _wanted("m2_inspect"):
		screen.inspect_unit(int(found.jmuy.uid))
		await _wait(0.4)
		await _shot("m2_inspect")
		screen.inspect.close()
		await _wait(0.2)
	if _wanted("m2_chip_rows"):
		_mouse(screen.more_chip_point(0, true))
		await _wait(0.3)
		_mouse(screen.improvement_point(int(found.hidden)))
		await _wait(0.9)
		await _shot("m2_chip_rows")
		_mouse(screen.size * 0.5 + Vector2(0, 40))
		await _wait(0.3)
	if _wanted("m2_hand_note") or _wanted("m2_hand_note_zh"):
		_mouse(screen.hand_card_point(0))
		await _wait(0.9)
		await _shot("m2_hand_note")
		if _wanted("m2_hand_note_zh"):
			app.set_locale("zh_CN")
			await _wait(0.3)
			await _shot("m2_hand_note_zh")
			app.set_locale("en")
			await _wait(0.2)
		_mouse(screen.size * 0.5 + Vector2(0, 40))
		await _wait(0.4)
	# The stepper: Redeploy's unit, then lane (overview), then position.
	var move_index = app.engine.state.players[0].hand.find("fx_move_any")
	if screen.select_card(move_index):
		screen.target_unit(int(found.mover.uid))
		await _wait(0.5)
		_mouse(screen.lane_point(1))
		await _wait(0.4)
		await _shot("m2_stepper_lane")
		screen.choose_lane(1)
		await _wait(0.6)
		var ghosts: Array = screen.board.lanes[1].ghost_slots
		if not ghosts.is_empty():
			_mouse(screen.slot_point(int(ghosts[0].position)))
		await _wait(0.3)
		await _shot("m2_stepper_position")
		_mouse(screen.size * 0.5, MOUSE_BUTTON_RIGHT, true)
		await _wait(0.2)
		screen.view_lane(0)
		await _wait(0.6)
	var raze_index = app.engine.state.players[0].hand.find("fx_raze")
	if screen.select_card(raze_index):
		var target = app.engine.state.lanes[0].improvements[1][0]
		_mouse(screen.improvement_point(int(target.oid)))
		await _wait(0.4)
		await _shot("m2_stepper_improvement")
		_mouse(screen.size * 0.5, MOUSE_BUTTON_RIGHT, true)
		await _wait(0.3)
	if screen.use_ability(int(found.blink)):
		await _wait(0.5)
		_mouse(screen.lane_point(2))
		await _wait(0.4)
		await _shot("m2_item_ability")
		_mouse(screen.size * 0.5, MOUSE_BUTTON_RIGHT, true)
		await _wait(0.3)
	await _capture_m2_animations()

## Two event animations mid-flight: a stun landing on an enemy, then combat.
func _capture_m2_animations() -> void:
	if not (_wanted("m2_anim_status") or _wanted("m2_anim_combat")):
		return
	var engine = app.controller.engine
	var screen = app.screen
	await _idle()
	var stun_index = engine.state.players[0].hand.find("fx_stun_spell")
	engine.state.players[0].hand_state[stun_index].erase("lock")
	var enemy_uid = -1
	for unit in engine.state.lanes[0].units[1]:
		if unit != null and not bool(unit.get("hero", false)):
			enemy_uid = int(unit.uid)
	var command = {"type": "play", "hand": stun_index, "target": enemy_uid}
	if engine.apply_action(0, command).get("ok", false):
		engine.state.active_player = 0
		engine.state.first_pass = -1
		_publish()
		await _wait(1.05)
		await _shot("m2_anim_status")
		await _idle()
	if _wanted("m2_anim_combat"):
		engine.apply_action(0, {"type": "pass"})
		engine.apply_action(1, {"type": "pass"})
		_publish()
		await _wait(0.95)
		await _shot("m2_anim_combat")
		await _idle()

## M3: a mid-game lane between two of the new presets, with new cards in hand.
func _capture_m3() -> void:
	if not M3_SHOTS.any(func(shot): return _wanted(shot)):
		return
	var screen = app.screen
	app.set_locale("en")
	app.set_skin("three_kingdoms")
	app.deck_selections = ["sun_liu_alliance", "gathering_of_champions"]
	app.controller.current_seed = SEED + 23
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	AnimationQueue.instant = true
	var reached = _advance(_busy_lane, 1500)
	var engine = app.controller.engine
	print("M3 state: ", reached, " round ", engine.state.round, " lane ", engine.state.lane)
	engine.state.players[0].hand = M3_HAND.duplicate()
	Zones.sync(engine)
	var lane_index = int(engine.state.lane)
	if engine.state.lanes[lane_index].get("improvements", [[], []])[0].is_empty():
		Zones.add_improvement(engine, "steel_reinforcement", 0, lane_index)
	_publish()
	await _idle()
	AnimationQueue.instant = false
	screen.view_lane(lane_index)
	_mouse(screen.size * 0.5 + Vector2(0, 40))
	await _wait(0.8)
	await _shot("m3_lane")
	if _wanted("m3_lane_zh"):
		app.set_locale("zh_CN")
		await _wait(0.3)
		await _shot("m3_lane_zh")
		app.set_locale("en")
		await _wait(0.2)
	if _wanted("m3_lane_classic"):
		app.set_skin("classic")
		await _wait(0.4)
		await _shot("m3_lane_classic")
		app.set_skin("three_kingdoms")
		await _wait(0.3)
	if _wanted("m3_hand") or _wanted("m3_hand_zh"):
		_mouse(screen.hand_card_point(1))
		await _wait(0.9)
		await _shot("m3_hand")
		if _wanted("m3_hand_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m3_hand_zh")
			app.set_locale("en")
			await _wait(0.2)
		_mouse(screen.size * 0.5 + Vector2(0, 40))
		await _wait(0.4)
	if _wanted("m3_inspect") or _wanted("m3_inspect_zh"):
		var hero_uid = -1
		for unit in engine.state.lanes[lane_index].units[0] + engine.state.lanes[lane_index].units[1]:
			if unit != null and unit.hero and Library.has_active(str(unit.card)):
				hero_uid = int(unit.uid)
		if hero_uid == -1:
			for unit in engine.state.lanes[lane_index].units[0]:
				if unit != null and unit.hero:
					hero_uid = int(unit.uid)
		screen.inspect_unit(hero_uid)
		await _wait(0.5)
		await _shot("m3_inspect")
		if _wanted("m3_inspect_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m3_inspect_zh")
			app.set_locale("en")
			await _wait(0.2)
		screen.inspect.close()
		await _wait(0.2)
	if _wanted("m3_catalog") or _wanted("m3_catalog_zh"):
		var catalog = app.open_catalog()
		await _frames(3)
		catalog.apply_filter("red")
		await _wait(0.8)
		await _shot("m3_catalog")
		if _wanted("m3_catalog_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			catalog.apply_filter("green")
			await _wait(0.6)
			await _shot("m3_catalog_zh")
			app.set_locale("en")
		app.close_dialogs()
		await _wait(0.2)
	if _wanted("m3_decks") or _wanted("m3_decks_zh"):
		app.deck_selections = ["sun_liu_alliance", "ruxu_standoff"]
		app.open_decks()
		await _wait(0.8)
		await _shot("m3_decks")
		if _wanted("m3_decks_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			await _shot("m3_decks_zh")
			app.set_locale("en")
		app.close_dialogs()
		await _wait(0.2)

## M4: a mid-game lane between two of the blue presets, new blue cards in
## hand (one of them hacked by Self Sabotage), a new blue hero inspected, the
## catalog filtered to blue (Wei) and the new presets in the deck dialog.
func _capture_m4() -> void:
	if not M4_SHOTS.any(func(shot): return _wanted(shot)):
		return
	var screen = app.screen
	app.set_locale("en")
	app.set_skin("three_kingdoms")
	app.deck_selections = ["bronze_sparrow_terrace", "longxi_struggle"]
	app.controller.current_seed = SEED + 41
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	AnimationQueue.instant = true
	var reached = _advance(_busy_lane, 1500)
	var engine = app.controller.engine
	print("M4 state: ", reached, " round ", engine.state.round, " lane ", engine.state.lane)
	engine.state.players[0].hand = M4_HAND.duplicate()
	engine.state.players[0].hand_state = []
	Zones.sync(engine)
	engine.state.players[0].hand_state[M4_HAND.size() - 1]["hacks"] = ["self_sabotage#0"]
	var lane_index = int(engine.state.lane)
	_publish()
	await _idle()
	AnimationQueue.instant = false
	screen.view_lane(lane_index)
	_mouse(screen.size * 0.5 + Vector2(0, 40))
	await _wait(0.8)
	await _shot("m4_lane")
	if _wanted("m4_lane_zh"):
		app.set_locale("zh_CN")
		await _wait(0.3)
		await _shot("m4_lane_zh")
		app.set_locale("en")
		await _wait(0.2)
	if _wanted("m4_lane_classic") or _wanted("m4_lane_classic_zh"):
		app.set_skin("classic")
		await _wait(0.4)
		await _shot("m4_lane_classic")
		if _wanted("m4_lane_classic_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m4_lane_classic_zh")
			app.set_locale("en")
		app.set_skin("three_kingdoms")
		await _wait(0.3)
	if _wanted("m4_hand") or _wanted("m4_hand_zh"):
		_mouse(screen.hand_card_point(1))
		await _wait(0.9)
		await _shot("m4_hand")
		if _wanted("m4_hand_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m4_hand_zh")
			app.set_locale("en")
			await _wait(0.2)
		_mouse(screen.size * 0.5 + Vector2(0, 40))
		await _wait(0.4)
	if _wanted("m4_hack_note") or _wanted("m4_hack_note_zh"):
		_mouse(screen.hand_card_point(M4_HAND.size() - 1))
		await _wait(0.9)
		await _shot("m4_hack_note")
		if _wanted("m4_hack_note_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			_mouse(screen.size * 0.5 + Vector2(0, 40))
			await _wait(0.3)
			_mouse(screen.hand_card_point(M4_HAND.size() - 1))
			await _wait(0.9)
			await _shot("m4_hack_note_zh")
			app.set_locale("en")
			await _wait(0.2)
		_mouse(screen.size * 0.5 + Vector2(0, 40))
		await _wait(0.4)
	if _wanted("m4_inspect") or _wanted("m4_inspect_zh"):
		var hero_uid = -1
		var blue = ["luna", "crystal_maiden", "ogre_magi", "venomancer", "meepo", "skywrath_mage"]
		for lane in engine.state.lanes:
			for unit in lane.units[0] + lane.units[1]:
				if unit != null and unit.hero and str(unit.card) in blue and hero_uid == -1:
					hero_uid = int(unit.uid)
		if hero_uid == -1:
			for unit in engine.state.lanes[lane_index].units[0]:
				if unit != null and unit.hero:
					hero_uid = int(unit.uid)
		screen.inspect_unit(hero_uid)
		await _wait(0.5)
		await _shot("m4_inspect")
		if _wanted("m4_inspect_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m4_inspect_zh")
			app.set_locale("en")
			await _wait(0.2)
		screen.inspect.close()
		await _wait(0.2)
	if _wanted("m4_catalog") or _wanted("m4_catalog_zh") or _wanted("m4_catalog_classic"):
		var catalog = app.open_catalog()
		await _frames(3)
		catalog.apply_filter("blue")
		await _wait(0.8)
		await _shot("m4_catalog")
		if _wanted("m4_catalog_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			catalog.apply_filter("blue")
			await _wait(0.6)
			await _shot("m4_catalog_zh")
			app.set_locale("en")
			await _wait(0.3)
		if _wanted("m4_catalog_classic"):
			app.set_skin("classic")
			await _wait(0.6)
			catalog.apply_filter("blue")
			await _wait(0.6)
			await _shot("m4_catalog_classic")
			app.set_skin("three_kingdoms")
		app.close_dialogs()
		await _wait(0.2)
	if _wanted("m4_decks") or _wanted("m4_decks_zh"):
		app.deck_selections = ["bronze_sparrow_terrace", "siege_of_xiapi"]
		app.open_decks()
		await _wait(0.8)
		await _shot("m4_decks")
		if _wanted("m4_decks_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			await _shot("m4_decks_zh")
			app.set_locale("en")
		app.close_dialogs()
		await _wait(0.2)

## M5: a mid-game lane between two of the black presets, new black cards in
## hand, a new black hero inspected, the catalog filtered to black (Qun) in
## both skins and the new presets in the deck dialog.
func _capture_m5() -> void:
	if not M5_SHOTS.any(func(shot): return _wanted(shot)):
		return
	var screen = app.screen
	app.set_locale("en")
	app.set_skin("three_kingdoms")
	app.deck_selections = ["fengyi_pavilion", "yellow_turban_rebellion"]
	app.controller.current_seed = SEED + 53
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	AnimationQueue.instant = true
	var reached = _advance(_busy_lane, 1500)
	var engine = app.controller.engine
	print("M5 state: ", reached, " round ", engine.state.round, " lane ", engine.state.lane)
	engine.state.players[0].hand = M5_HAND.duplicate()
	engine.state.players[0].hand_state = []
	Zones.sync(engine)
	var lane_index = int(engine.state.lane)
	_publish()
	await _idle()
	AnimationQueue.instant = false
	screen.view_lane(lane_index)
	_mouse(screen.size * 0.5 + Vector2(0, 40))
	await _wait(0.8)
	await _shot("m5_lane")
	if _wanted("m5_lane_zh"):
		app.set_locale("zh_CN")
		await _wait(0.3)
		await _shot("m5_lane_zh")
		app.set_locale("en")
		await _wait(0.2)
	if _wanted("m5_lane_classic") or _wanted("m5_lane_classic_zh"):
		app.set_skin("classic")
		await _wait(0.4)
		await _shot("m5_lane_classic")
		if _wanted("m5_lane_classic_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m5_lane_classic_zh")
			app.set_locale("en")
		app.set_skin("three_kingdoms")
		await _wait(0.3)
	if _wanted("m5_hand") or _wanted("m5_hand_zh"):
		_mouse(screen.hand_card_point(0))
		await _wait(0.9)
		await _shot("m5_hand")
		if _wanted("m5_hand_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m5_hand_zh")
			app.set_locale("en")
			await _wait(0.2)
		_mouse(screen.size * 0.5 + Vector2(0, 40))
		await _wait(0.4)
	if _wanted("m5_inspect") or _wanted("m5_inspect_zh"):
		var hero_uid = -1
		var black = ["winter_wyvern", "bloodseeker", "storm_spirit", "tinker", "sniper", "lion", "necrophos"]
		for lane in engine.state.lanes:
			for unit in lane.units[0] + lane.units[1]:
				if unit != null and unit.hero and str(unit.card) in black and hero_uid == -1:
					hero_uid = int(unit.uid)
		if hero_uid == -1:
			for unit in engine.state.lanes[lane_index].units[0]:
				if unit != null and unit.hero:
					hero_uid = int(unit.uid)
		screen.inspect_unit(hero_uid)
		await _wait(0.5)
		await _shot("m5_inspect")
		if _wanted("m5_inspect_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m5_inspect_zh")
			app.set_locale("en")
			await _wait(0.2)
		screen.inspect.close()
		await _wait(0.2)
	if _wanted("m5_catalog") or _wanted("m5_catalog_zh") or _wanted("m5_catalog_classic") or _wanted("m5_catalog_classic_zh"):
		var catalog = app.open_catalog()
		await _frames(3)
		catalog.apply_filter("black")
		await _wait(0.8)
		await _shot("m5_catalog")
		if _wanted("m5_catalog_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			catalog.apply_filter("black")
			await _wait(0.6)
			await _shot("m5_catalog_zh")
			app.set_locale("en")
			await _wait(0.3)
		if _wanted("m5_catalog_classic") or _wanted("m5_catalog_classic_zh"):
			app.set_skin("classic")
			await _wait(0.6)
			catalog.apply_filter("black")
			await _wait(0.6)
			await _shot("m5_catalog_classic")
			if _wanted("m5_catalog_classic_zh"):
				app.set_locale("zh_CN")
				await _wait(0.6)
				catalog.apply_filter("black")
				await _wait(0.6)
				await _shot("m5_catalog_classic_zh")
				app.set_locale("en")
			app.set_skin("three_kingdoms")
		app.close_dialogs()
		await _wait(0.2)
	if _wanted("m5_decks") or _wanted("m5_decks_zh"):
		app.deck_selections = ["fengyi_pavilion", "hulao_pass"]
		app.open_decks()
		await _wait(0.8)
		await _shot("m5_decks")
		if _wanted("m5_decks_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			await _shot("m5_decks_zh")
			app.set_locale("en")
		app.close_dialogs()
		await _wait(0.2)


func _capture_m6() -> void:
	if not M6_SHOTS.any(func(shot): return _wanted(shot)):
		return
	var screen = app.screen
	app.set_locale("en")
	app.set_skin("three_kingdoms")
	app.deck_selections = ["five_tigers", "battle_of_guandu"]
	app.controller.current_seed = SEED + 61
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	AnimationQueue.instant = true
	var reached = _advance(_busy_lane, 1500)
	var engine = app.controller.engine
	print("M6 state: ", reached, " round ", engine.state.round, " lane ", engine.state.lane)
	var lane_index = int(engine.state.lane)
	# M6 equipment on player 0's heroes in this lane; the first one's
	# Stonehall items have grown twice (granted text on the item instances).
	var heroes: Array = engine.state.lanes[lane_index].units[0].filter(func(unit): return unit != null and unit.hero)
	var grown = -1
	for index in range(mini(heroes.size(), M6_GEAR.size())):
		for card_id in M6_GEAR[index]:
			Zones.equip(engine, heroes[index], card_id)
	if not heroes.is_empty():
		grown = int(heroes[0].uid)
		for slot in ["weapon", "armor", "accessory"]:
			var item_id = str(heroes[0].items.get(slot, ""))
			for count in range(2):
				Kernel.modify(engine, Select.item_handle(heroes[0], slot), {}, {}, item_id + "#0", {"controller": 0, "card": item_id})
	for side in range(2):
		engine.state.players[side].deeds = [{"oid": Kernel.next_oid(engine), "card": "shop_deed", "owner": side}]
	engine.state.players[0].hand = M6_HAND.duplicate()
	engine.state.players[0].hand_state = []
	Zones.sync(engine)
	engine._reset_transient()
	Stats.settle(engine)
	engine._settle_transient()
	_publish()
	await _idle()
	AnimationQueue.instant = false
	screen.view_lane(lane_index)
	_mouse(screen.size * 0.5 + Vector2(0, 40))
	await _wait(0.8)
	await _shot("m6_lane")
	if _wanted("m6_lane_zh"):
		app.set_locale("zh_CN")
		await _wait(0.3)
		await _shot("m6_lane_zh")
		app.set_locale("en")
		await _wait(0.2)
	if _wanted("m6_lane_classic") or _wanted("m6_lane_classic_zh"):
		app.set_skin("classic")
		await _wait(0.4)
		await _shot("m6_lane_classic")
		if _wanted("m6_lane_classic_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m6_lane_classic_zh")
			app.set_locale("en")
		app.set_skin("three_kingdoms")
		await _wait(0.3)
	if _wanted("m6_hand") or _wanted("m6_hand_zh"):
		_mouse(screen.hand_card_point(3))
		await _wait(0.9)
		await _shot("m6_hand")
		if _wanted("m6_hand_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m6_hand_zh")
			app.set_locale("en")
			await _wait(0.2)
		_mouse(screen.size * 0.5 + Vector2(0, 40))
		await _wait(0.4)
	if (_wanted("m6_item_inspect") or _wanted("m6_item_inspect_zh")) and grown != -1:
		screen.inspect_item(grown, "weapon")
		await _wait(0.5)
		await _shot("m6_item_inspect")
		if _wanted("m6_item_inspect_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m6_item_inspect_zh")
			app.set_locale("en")
			await _wait(0.2)
		screen.inspect.close()
		await _wait(0.2)
	if _wanted("m6_shop") or _wanted("m6_shop_zh") or _wanted("m6_shop_paid"):
		AnimationQueue.instant = true
		_advance(func(state): return state.phase == "shop")
		AnimationQueue.instant = false
		# One deed each (the bot may have played the Seal from its hand on the way).
		for side in range(2):
			engine.state.players[side].finished = false
			engine.state.players[side].deeds = [{"oid": Kernel.next_oid(engine), "card": "shop_deed", "owner": side}]
		engine.state.players[0].shop = {"secret": "apotheosis_blade", "item": str(engine.state.players[0].shop.get("item", "")),
			"consumable": "fountain_flask"}
		engine.state.players[0].gold = 6
		engine.state.players[0].held_secret = ""
		_publish()
		await _wait(0.8)
		await _shot("m6_shop")
		if _wanted("m6_shop_zh"):
			app.set_locale("zh_CN")
			await _wait(0.3)
			await _shot("m6_shop_zh")
			app.set_locale("en")
			await _wait(0.2)
		if _wanted("m6_shop_paid"):
			engine.state.players[0].deeds.append({"oid": Kernel.next_oid(engine), "card": "shop_deed", "owner": 0})
			_publish()
			await _wait(0.5)
			await _shot("m6_shop_paid")
	if _wanted("m6_catalog") or _wanted("m6_catalog_zh") or _wanted("m6_catalog_classic") or _wanted("m6_catalog_classic_zh"):
		var catalog = app.open_catalog()
		await _frames(3)
		catalog.apply_filter("neutral")
		await _wait(0.8)
		await _shot("m6_catalog")
		if _wanted("m6_catalog_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			catalog.apply_filter("neutral")
			await _wait(0.6)
			await _shot("m6_catalog_zh")
			app.set_locale("en")
			await _wait(0.3)
		if _wanted("m6_catalog_classic") or _wanted("m6_catalog_classic_zh"):
			app.set_skin("classic")
			await _wait(0.6)
			catalog.apply_filter("neutral")
			await _wait(0.6)
			await _shot("m6_catalog_classic")
			if _wanted("m6_catalog_classic_zh"):
				app.set_locale("zh_CN")
				await _wait(0.6)
				catalog.apply_filter("neutral")
				await _wait(0.6)
				await _shot("m6_catalog_classic_zh")
				app.set_locale("en")
			app.set_skin("three_kingdoms")
		app.close_dialogs()
		await _wait(0.2)
	if _wanted("m6_decks") or _wanted("m6_decks_zh"):
		app.deck_selections = ["five_tigers", "warlords_rise"]
		app.open_decks()
		await _wait(0.8)
		await _shot("m6_decks")
		if _wanted("m6_decks_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			await _shot("m6_decks_zh")
			app.set_locale("en")
		app.close_dialogs()
		await _wait(0.2)


func _capture_m7() -> void:
	if not M7_SHOTS.any(func(shot): return _wanted(shot)):
		return
	var screen = app.screen
	app.set_locale("en")
	app.set_skin("three_kingdoms")
	app.deck_selections = ["siege_of_ye", "jing_province"]
	app.controller.current_seed = SEED + 71
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	AnimationQueue.instant = true
	var reached = _advance(_busy_lane, 1500)
	var engine = app.controller.engine
	print("M7 state: ", reached, " round ", engine.state.round, " lane ", engine.state.lane)
	var lane_index = int(engine.state.lane)
	# M7 improvements by both towers of the shown lane (the bot may have played
	# some already: these come on top).
	var own: Array = []
	for card_id in M7_OWN:
		own.append(Zones.add_improvement(engine, card_id, 0, lane_index))
	for card_id in M7_ENEMY:
		Zones.add_improvement(engine, card_id, 1, lane_index)
	engine.state.players[0].hand = M7_HAND.duplicate()
	engine.state.players[0].hand_state = []
	# Seven Mana in every lane so the dearer improvements light up (settle
	# takes a maximum written directly as the new base).
	for lane in engine.state.lanes:
		lane.max_mana[0] = maxi(int(lane.max_mana[0]), 7)
	Zones.sync(engine)
	engine._reset_transient()
	Stats.settle(engine)
	engine._settle_transient()
	for lane in engine.state.lanes:
		lane.mana[0] = int(lane.max_mana[0])
	_publish()
	await _idle()
	AnimationQueue.instant = false
	screen.view_lane(lane_index)
	_mouse(screen.size * 0.5 + Vector2(0, 40))
	await _wait(0.8)
	await _shot("m7_lane")
	if _wanted("m7_lane_zh"):
		app.set_locale("zh_CN")
		await _wait(0.3)
		await _shot("m7_lane_zh")
		app.set_locale("en")
		await _wait(0.2)
	if _wanted("m7_lane_classic") or _wanted("m7_lane_classic_zh"):
		app.set_skin("classic")
		await _wait(0.4)
		await _shot("m7_lane_classic")
		if _wanted("m7_lane_classic_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m7_lane_classic_zh")
			app.set_locale("en")
		app.set_skin("three_kingdoms")
		await _wait(0.3)
	if _wanted("m7_hand") or _wanted("m7_hand_zh"):
		_mouse(screen.hand_card_point(0))
		await _wait(0.9)
		await _shot("m7_hand")
		if _wanted("m7_hand_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m7_hand_zh")
			app.set_locale("en")
			await _wait(0.2)
		_mouse(screen.size * 0.5 + Vector2(0, 40))
		await _wait(0.4)
	if (_wanted("m7_inspect") or _wanted("m7_inspect_zh")) and not own.is_empty():
		screen.inspect_improvement(int(own[0].oid))
		await _wait(0.5)
		await _shot("m7_inspect")
		if _wanted("m7_inspect_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m7_inspect_zh")
			app.set_locale("en")
			await _wait(0.2)
		screen.inspect.close()
		await _wait(0.2)
	if _wanted("m7_oath") or _wanted("m7_oath_zh"):
		# The Oath in this lane: player 0's spells and creeps are forbidden.
		Zones.add_improvement(engine, "the_oath", 0, lane_index)
		engine.state.players[0].hand = ["hip_fire", "lightning_strike", "relentless_zombie", "trebuchets"]
		engine.state.players[0].hand_state = []
		Zones.sync(engine)
		engine._reset_transient()
		Stats.settle(engine)
		engine._settle_transient()
		_publish()
		await _wait(0.6)
		_mouse(screen.hand_card_point(0))
		await _wait(0.9)
		await _shot("m7_oath")
		if _wanted("m7_oath_zh"):
			app.set_locale("zh_CN")
			await _wait(0.4)
			await _shot("m7_oath_zh")
			app.set_locale("en")
			await _wait(0.2)
		_mouse(screen.size * 0.5 + Vector2(0, 40))
		await _wait(0.4)
	if _wanted("m7_catalog") or _wanted("m7_catalog_zh") or _wanted("m7_catalog_classic") or _wanted("m7_catalog_classic_zh"):
		var catalog = app.open_catalog()
		await _frames(3)
		catalog.apply_filter("black")
		await _wait(0.6)
		_scroll_to_improvements(catalog)
		await _wait(0.6)
		await _shot("m7_catalog")
		if _wanted("m7_catalog_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			catalog.apply_filter("black")
			await _wait(0.4)
			_scroll_to_improvements(catalog)
			await _wait(0.6)
			await _shot("m7_catalog_zh")
			app.set_locale("en")
			await _wait(0.3)
		if _wanted("m7_catalog_classic") or _wanted("m7_catalog_classic_zh"):
			app.set_skin("classic")
			await _wait(0.6)
			catalog.apply_filter("black")
			await _wait(0.4)
			_scroll_to_improvements(catalog)
			await _wait(0.6)
			await _shot("m7_catalog_classic")
			if _wanted("m7_catalog_classic_zh"):
				app.set_locale("zh_CN")
				await _wait(0.6)
				catalog.apply_filter("black")
				await _wait(0.4)
				_scroll_to_improvements(catalog)
				await _wait(0.6)
				await _shot("m7_catalog_classic_zh")
				app.set_locale("en")
			app.set_skin("three_kingdoms")
		app.close_dialogs()
		await _wait(0.2)
	if _wanted("m7_decks") or _wanted("m7_decks_zh"):
		app.deck_selections = ["siege_of_ye", "dong_zhuo_tyranny"]
		app.open_decks()
		await _wait(0.8)
		await _shot("m7_decks")
		if _wanted("m7_decks_zh"):
			app.set_locale("zh_CN")
			await _wait(0.6)
			await _shot("m7_decks_zh")
			app.set_locale("en")
		app.close_dialogs()
		await _wait(0.2)

## Scrolls the catalog so its first visible improvement heads the view (the
## grid lists heroes, then creeps, spells and improvements by cost).
func _scroll_to_improvements(catalog) -> void:
	for card in catalog.cards:
		if card.visible and str(card.definition.get("kind", "")) == "improvement":
			var scroll = catalog.find_children("*", "ScrollContainer", true, false)
			if not scroll.is_empty():
				scroll[0].scroll_vertical = int(card.position.y)
			return

# --- Decks ---------------------------------------------------------------------------

## The deck screens on a scratch store: a legal deck and an unfinished one.
func _capture_decks() -> void:
	if not DECK_SHOTS.any(func(shot_name): return _wanted(shot_name)):
		return
	DeckStore.root = DECK_STORE
	if DirAccess.dir_exists_absolute(DECK_STORE):
		for file_name in DirAccess.get_files_at(DECK_STORE):
			DirAccess.remove_absolute("%s/%s" % [DECK_STORE, file_name])
	var library = Library.new()
	# A legal deck from Valve's Green/Black example code.
	var decoded = DeckCode.decode("ADCJWkTZX05uwGDCRV4XQGy3QGLmqUBg4GQJgGLGgO7AaABR3JlZW4vQmxhY2sgRXhhbXBsZQ__", library)
	var legal = DeckStore.blank("Green/Black Example")
	legal.heroes = decoded.deck.heroes
	legal.cards = decoded.deck.cards
	legal.items = decoded.deck.items
	DeckStore.save(legal)
	# An unfinished deck: four heroes, a short main deck, a few items.
	var draft = DeckStore.blank("Jiangdong Fleet")
	for hero_id in ["drow", "treant_protector", "lycan", "farvhan"]:
		DeckModel.add(draft, hero_id, library)
	DeckModel.move_hero(draft, 3, 4)
	DeckModel.move_hero(draft, 2, 3)
	for card_id in ["thunderhide_pack", "thunderhide_pack", "selemenes_favor", "selemenes_favor", "rampaging_hellbear", "rampaging_hellbear",
			"satyr_duelist", "vhoul_martyr", "vhoul_martyr", "rebel_decoy", "intimidation", "intimidation", "bellow", "bellow",
			"defend_the_weak", "mist_of_avernus", "stars_align", "stars_align", "juke", "rumusque_blessing", "avernus_blessing",
			"champion_of_the_ancient", "short_sword", "short_sword", "leather_armor", "travelers_cloak", "rumusque_vestments"]:
		DeckModel.add(draft, card_id, library)
	var saved_draft = DeckStore.save(draft)
	var stored = DeckStore.list()
	var legal_id = ""
	for deck in stored:
		if str(deck.name) == "Green/Black Example":
			legal_id = str(deck.id)
	for locale in ["en", "zh_CN"]:
		var shot_name = "deck_list" if locale == "en" else "deck_list_zh"
		if _wanted(shot_name):
			app.set_locale(locale)
			app.open_deck_list(legal_id)
			await _wait(0.5)
			await _shot(shot_name)
			app.close_dialogs()
			await _frames(2)
	for spec in [["deck_builder", "en", "three_kingdoms"], ["deck_builder_zh", "zh_CN", "three_kingdoms"], ["deck_builder_classic", "en", "classic"]]:
		if not _wanted(spec[0]):
			continue
		app.set_locale(spec[1])
		app.set_skin(spec[2])
		# The Chinese shot names the deck in traditional characters, beyond the
		# bundled font subsets (the system font fallback draws them).
		var shown_draft: Dictionary = (saved_draft.deck if saved_draft.ok else draft).duplicate(true)
		shown_draft.name = "江東艦隊" if spec[1] == "zh_CN" else "Jiangdong Fleet"
		var builder = app.open_deck_builder(shown_draft, false)
		await _wait(0.6)
		var row = builder.rows.get("thunderhide_pack")
		if row != null:
			_mouse(row.get_global_rect().get_center() + Vector2(-60, 0))
			await _wait(0.3)
		await _shot(spec[0])
		_mouse(Vector2(4, 4))
		app.close_dialogs()
		await _frames(2)
	app.set_locale("en")
	app.set_skin("three_kingdoms")
	if _wanted("deck_builder_drag"):
		var builder = app.open_deck_builder(saved_draft.deck if saved_draft.ok else draft, false)
		await _wait(0.6)
		builder.set_color_filter("green")
		await _wait(0.2)
		var card = builder.collection_card("revtel_convoy")
		if card == null:
			card = builder.collection[8]
		builder.collection_scroll.ensure_control_visible(card)
		await _wait(0.2)
		var start = card.get_global_rect().get_center()
		var finish = builder.deck_panel.get_global_rect().get_center() + Vector2(0, 60)
		_mouse(start)
		await _frames(2)
		_mouse(start, MOUSE_BUTTON_LEFT, true)
		await _frames(2)
		var last = start
		for step in range(1, 13):
			# Godot's drag and drop starts from the motion's relative movement.
			var point = start.lerp(finish, step / 12.0)
			_drag_motion(point, last)
			last = point
			await _frames(1)
		await _wait(0.3)
		await _shot("deck_builder_drag")
		_mouse(finish, MOUSE_BUTTON_LEFT, false)
		await _wait(0.2)
		app.close_dialogs()
		await _frames(2)
	if _wanted("deck_builder_valid"):
		# The legal deck: every lamp green, the item deck in view.
		var stored_legal = DeckStore.load_deck(legal_id)
		var builder = app.open_deck_builder(stored_legal, false)
		await _wait(0.5)
		builder.list_scroll.scroll_vertical = 100000
		builder.set_kind_filter("item")
		await _wait(0.4)
		await _shot("deck_builder_valid")
		app.close_dialogs()
		await _frames(2)
	if _wanted("deck_import"):
		var builder = app.open_deck_builder(DeckStore.blank("New deck"), true)
		await _wait(0.5)
		var box = builder.open_import()
		box.field.text = "https://playartifact.com/d/ADCJQUQI30zuwEYg2ABeF1Bu94BmWIBTEkLtAKlAZakAYmHh0JsdWUvUmVkIEV4YW1wbGU_"
		await _wait(0.3)
		await _shot("deck_import")
		app.close_dialogs()
		await _frames(2)
	for spec in [["deck_builder_four", "en"], ["deck_builder_four_zh", "zh_CN"]]:
		if not _wanted(spec[0]):
			continue
		app.set_locale(spec[1])
		var four = DeckStore.copy_of(library.preset("starter"), Library.preset_text("starter") + (" (copy)" if spec[1] == "en" else "（副本）"))
		var builder = app.open_deck_builder(four, false)
		await _wait(0.6)
		var outsider = ""
		for card_id in builder.eligible_cards():
			if outsider.is_empty() and str(Library.raw_definition(card_id).get("kind", "")) == "hero" and card_id not in builder.deck.heroes:
				outsider = card_id
		builder.add_card(outsider)
		await _wait(0.3)
		await _shot(spec[0])
		app.close_dialogs()
		await _frames(2)
	app.set_locale("en")
	for spec in [["deck_import_error", "en", "nonsense"], ["deck_import_error_zh", "zh_CN", "ADCJWkTZX05uwGDCRV4XQGy3QGLmqUBg4GQJgGLGgO7AaABR3JlZW4vQmxhY2sgRXhhbX"]]:
		if not _wanted(spec[0]):
			continue
		app.set_locale(spec[1])
		var builder = app.open_deck_builder(DeckStore.copy_of(library.preset("green_assault"), "Green Assault"), false)
		await _wait(0.5)
		var box = builder.open_import()
		box.field.text = spec[2]
		box.confirm_button.pressed.emit()
		await _wait(0.3)
		await _shot(spec[0])
		app.close_dialogs()
		await _frames(2)
	app.set_locale("en")
	if _wanted("deck_list_import_error"):
		var list = app.open_deck_list(legal_id)
		await _wait(0.5)
		var box = list.open_import()
		box.field.text = "ADCnotacode"
		box.confirm_button.pressed.emit()
		await _wait(0.3)
		await _shot("deck_list_import_error")
		app.close_dialogs()
		await _frames(2)
	if _wanted("deck_builder_slot"):
		var builder = app.open_deck_builder(saved_draft.deck if saved_draft.ok else draft, false)
		await _wait(0.6)
		var slot = builder.deck.heroes.find("")
		var point = builder.hero_slots[maxi(slot, 0)].get_global_rect().get_center()
		_mouse(point)
		_mouse(point, MOUSE_BUTTON_LEFT, true)
		_mouse(point, MOUSE_BUTTON_LEFT, false)
		await _wait(0.4)
		await _shot("deck_builder_slot")
		app.close_dialogs()
		await _frames(2)
	if _wanted("deck_template"):
		var builder = app.open_deck_builder(saved_draft.deck if saved_draft.ok else draft, false)
		await _wait(0.6)
		builder.template_button.item_selected.emit(2)
		await _wait(0.3)
		await _shot("deck_template")
		app.close_dialogs()
		await _frames(2)
	DeckStore.root = DeckStore.DEFAULT_ROOT

## A held-button mouse motion with its relative movement (Godot's drag and
## drop needs it to start a drag).
func _drag_motion(position: Vector2, last: Vector2) -> void:
	var event = InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = position
	event.global_position = position
	event.relative = position - last
	root.push_input(event, true)

# --- v0.6.1: the your-action cue, card history, results, the room, the match intro ---------

## Enough of GodotSteam for the room's screenshots: two avatars (card art) and
## no-op lobby calls. Nothing reaches the real Steam client.
class SteamStub:
	extends RefCounted
	var images: Dictionary = {}
	var handles: Dictionary = {}
	var persona: String = "Corosso"
	func getMediumFriendAvatar(steam_id: int) -> int:
		return int(handles.get(steam_id, 0))
	func getLargeFriendAvatar(steam_id: int) -> int:
		return int(handles.get(steam_id, 0))
	func getImageSize(image_handle: int) -> Dictionary:
		if not images.has(image_handle):
			return {"success": false, "width": 0, "height": 0}
		return {"success": true, "width": images[image_handle].get_width(), "height": images[image_handle].get_height()}
	func getImageRGBA(image_handle: int) -> Dictionary:
		if not images.has(image_handle):
			return {}
		return {"success": true, "buffer": images[image_handle].get_data()}
	func getPersonaName() -> String:
		return persona
	func run_callbacks() -> void:
		pass
	func receiveMessagesOnChannel(_channel: int, _max_messages: int) -> Array:
		return []
	func sendMessageToUser(_remote: int, _data: PackedByteArray, _flags: int, _channel: int) -> int:
		return 1
	func setLobbyData(_lobby: int, _key: String, _value: String) -> bool:
		return true
	func setLobbyMemberLimit(_lobby: int, _members: int) -> bool:
		return true
	func closeSessionWithUser(_remote: int) -> bool:
		return true
	func leaveLobby(_lobby: int) -> void:
		pass
	func clearRichPresence() -> void:
		pass

const HOST_STEAM_ID = 76561198000000101
const GUEST_STEAM_ID = 76561198000000202

## An avatar image (184 px) from a card's art.
func _avatar_image(card_id: String) -> Image:
	var texture: Texture2D = null
	for extension in ["jpg", "png", "webp"]:
		var path = "res://assets/art/cards/%s.%s" % [card_id, extension]
		if ResourceLoader.exists(path):
			texture = load(path)
			break
	var image: Image = texture.get_image() if texture != null else Image.create(184, 184, false, Image.FORMAT_RGBA8)
	if image.is_compressed():
		image.decompress()
	var side = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, int(image.get_height() * 0.08), side, side))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(184, 184, Image.INTERPOLATE_LANCZOS)
	return image

## Puts the controller in a room on the stub (no real Steam calls).
func _stub_room(host: bool, guest_here: bool) -> void:
	var bridge = app.controller.steam_bridge
	var stub = SteamStub.new()
	stub.images = {1: _avatar_image("zhang_fei" if ResourceLoader.exists("res://assets/art/cards/zhang_fei.jpg") else "axe"), 2: _avatar_image("drow")}
	stub.handles = {HOST_STEAM_ID: 1 if host else 2, GUEST_STEAM_ID: 2 if host else 1}
	bridge.steam = stub
	bridge.available = true
	bridge._avatars.clear()
	bridge.local_id = HOST_STEAM_ID if host else GUEST_STEAM_ID
	bridge.lobby_id = 109775241000000777
	bridge.is_host = host
	bridge.lobby_public = false
	bridge.handshake_done = guest_here
	bridge.opponent_present = guest_here
	bridge.peer_id = (GUEST_STEAM_ID if host else HOST_STEAM_ID) if guest_here else 0
	bridge.bound_opponent = bridge.peer_id if host else 0
	bridge.host_id = HOST_STEAM_ID
	bridge.peer_name = ("zucchini" if host else "zucchini") if guest_here else ""
	bridge.ping_ms = 48
	bridge.quality = 1.0
	app.controller.room_phase = "room" if guest_here else "waiting"
	app.controller.room_ready = [false, false]
	app.controller.room_starting = false
	app.controller.room_series = [0, 0]
	app.controller.guest_deck_state = "ok" if guest_here else ""
	app.controller.own_deck_result = {"ok": true}

## Leaves the stub room without a word to Steam.
func _leave_stub_room() -> void:
	var bridge = app.controller.steam_bridge
	bridge.leave_lobby()
	bridge.available = false
	bridge.steam = null
	app.controller._reset_room("none")
	app.controller.mode = MatchController.MODE_AI
	app.close_dialogs()

func _capture_v061() -> void:
	if not V061_SHOTS.any(func(shot_name): return _wanted(shot_name)):
		return
	var screen = app.screen
	Settings.set_show_history(true, false)
	Settings.set_turn_alert(true, false)
	# The card history in a busy lane, a tile hovered, and the your-action cue.
	if _wanted("history") or _wanted("history_zh") or _wanted("history_hover") or _wanted("turn_cue"):
		Settings.set_match_intro(false, false)
		app.controller.current_seed = SEED
		AnimationQueue.instant = true
		app.start_match(MatchController.MODE_AI)
		app.bot_timer.paused = true
		_advance(_busy_lane)
		AnimationQueue.instant = false
		_mouse(Vector2(screen.size.x * 0.5, screen.size.y * 0.45))
		await _wait(0.8)
		await _idle()
		await _wait(0.4)
		await _shot("history")
		if _wanted("history_zh"):
			app.set_locale("zh_CN")
			await _wait(0.3)
			await _shot("history_zh")
			app.set_locale("en")
			await _wait(0.2)
		if _wanted("history_hover"):
			var rail = screen.history
			# The newest drawn play (or ability) with effects listed under it.
			var spot = Vector2(-1, -1)
			for entry in rail._rects:
				var tile: Dictionary = rail._tile_by_id(int(entry[1]))
				if str(tile.get("kind", "")) in ["play", "ability"] and spot.x < 0.0:
					spot = rail.get_global_transform() * entry[0].get_center()
			if spot.x < 0.0 and not rail._rects.is_empty():
				spot = rail.get_global_transform() * rail._rects[0][0].get_center()
			_mouse(spot + Vector2(1, 0))
			await _frames(2)
			_mouse(spot)
			await _wait(0.4)
			await _shot("history_hover")
			_mouse(Vector2(screen.size.x * 0.5, screen.size.y * 0.45))
			await _wait(0.2)
		if _wanted("turn_cue"):
			var engine = app.engine
			if engine.state.phase == "action" and int(engine.state.active_player) == 0:
				screen.press_coin()
				await _idle()
			var guard = 0
			while engine.state.phase == "action" and int(engine.state.active_player) == 1 and guard < 4:
				engine.apply_action(1, bot.choose_action(engine, 1))
				_publish()
				guard += 1
			await _idle()
			await _wait(0.3 if not screen.fx.banners_showing() else 0.75)
			await _shot("turn_cue")
	# The results: online (the opponent wants a rematch).
	if _wanted("game_over_online") or _wanted("game_over_online_zh"):
		Settings.set_match_intro(false, false)
		AnimationQueue.instant = true
		app.start_match(MatchController.MODE_AI)
		app.bot_timer.paused = true
		_stub_room(true, true)
		app.controller.mode = MatchController.MODE_ONLINE
		app.controller.room_phase = "match"
		_advance(func(state): return int(state.round) >= 2 and state.phase == "action")
		var engine = app.engine
		engine.state.lanes[0].structures[1].ancient = true
		engine.state.lanes[0].structures[1].health = 80
		engine.state.lanes[1].structures[1].ancient = true
		engine.state.lanes[1].structures[1].health = 80
		engine.state.winner = 0
		engine.state.phase = "finished"
		engine._event("win", {"p": 0})
		_publish()
		app.controller._note_result()
		app.controller.room_ready = [false, true]
		app.controller.room_changed.emit()
		AnimationQueue.instant = false
		await _wait(1.2)
		await _shot("game_over_online")
		if _wanted("game_over_online_zh"):
			app.set_locale("zh_CN")
			await _wait(0.3)
			await _shot("game_over_online_zh")
			app.set_locale("en")
			await _wait(0.2)
		_leave_stub_room()
	# The room: the host waiting, both seats with a countdown, the guest's side.
	if _wanted("room_waiting") or _wanted("room_ready") or _wanted("room_ready_zh") or _wanted("room_guest") or _wanted("room_deck"):
		app.show_main_menu()
		_stub_room(true, false)
		app.show_room()
		await _wait(0.5)
		await _shot("room_waiting")
		_stub_room(true, true)
		app.controller.room_series = [1, 2]
		app.controller.room_phase = "result"
		app.controller.set_ready(true)
		app.controller._on_ready_received(true)
		app.room.refresh()
		await _wait(0.4)
		await _shot("room_ready")
		if _wanted("room_ready_zh"):
			app.set_locale("zh_CN")
			await _wait(0.3)
			await _shot("room_ready_zh")
			app.set_locale("en")
			await _wait(0.2)
		app.controller.set_ready(false)
		_stub_room(false, true)
		app.controller.own_deck_result = {}
		app.controller.room_ready = [true, false]
		app.controller.room_phase = "result"
		app.controller.room_series = [2, 1]
		app.room.refresh()
		await _wait(0.4)
		await _shot("room_guest")
		if _wanted("room_deck"):
			# Change deck in the room: your own deck only.
			app.room.buttons.deck.pressed.emit()
			await _wait(0.6)
			await _shot("room_deck")
			app.close_dialogs()
		_leave_stub_room()
	# The match intro: against the AI (en and zh) and in hot-seat play.
	if _wanted("versus") or _wanted("versus_zh") or _wanted("versus_local"):
		Settings.set_match_intro(true, false)
		AnimationQueue.instant = false
		for spec in [["versus", "en", MatchController.MODE_AI], ["versus_zh", "zh_CN", MatchController.MODE_AI], ["versus_local", "en", MatchController.MODE_LOCAL]]:
			if not _wanted(spec[0]):
				continue
			app.set_locale(spec[1])
			app.controller.current_seed = SEED + 3
			app.deck_selections = ["starter", "green_assault"]
			app.start_match(spec[2])
			app.bot_timer.paused = true
			await _wait(2.3)
			await _shot(spec[0])
			screen.versus.skip()
			await _idle()
			if screen.pass_screen.visible:
				screen.pass_screen.confirm()
		app.set_locale("en")
		Settings.set_match_intro(false, false)
	await _capture_review_fixes()
	# Settings: the new toggles.
	if _wanted("settings") or _wanted("settings_zh"):
		app.show_main_menu()
		app.open_settings()
		await _wait(0.4)
		await _shot("settings")
		if _wanted("settings_zh"):
			app.set_locale("zh_CN")
			await _wait(0.3)
			await _shot("settings_zh")
			app.set_locale("en")
		app.close_dialogs()
		await _wait(0.2)

## Review fixes: long Steam names in the online intro, on the opponent's
## plate and in the room; the guest's win after the host conceded and left.
func _capture_review_fixes() -> void:
	var screen = app.screen
	if _wanted("versus_online") or _wanted("versus_online_zh") or _wanted("board_online") or _wanted("board_online_zh"):
		Settings.set_match_intro(false, false)
		AnimationQueue.instant = true
		app.controller.current_seed = SEED + 3
		app.deck_selections = ["starter", "green_assault"]
		app.start_match(MatchController.MODE_AI)
		app.bot_timer.paused = true
		_stub_room(true, true)
		app.controller.steam_bridge.steam.persona = LONG_NAMES[0]
		app.controller.steam_bridge.peer_name = LONG_NAMES[1]
		app.controller.mode = MatchController.MODE_ONLINE
		app.controller.room_phase = "match"
		_advance(func(state): return state.phase == "action" and int(state.active_player) == 0)
		await _idle()
		AnimationQueue.instant = false
		for spec in [["versus_online", "en"], ["versus_online_zh", "zh_CN"]]:
			if not _wanted(spec[0]):
				continue
			app.set_locale(spec[1])
			Settings.set_match_intro(true, false)
			screen._play_intro(app.controller.view(), 0)
			Settings.set_match_intro(false, false)
			await _wait(2.3)
			await _shot(spec[0])
			screen.versus.skip()
			await _wait(0.4)
		for spec in [["board_online", "en"], ["board_online_zh", "zh_CN"]]:
			if not _wanted(spec[0]):
				continue
			app.set_locale(spec[1])
			screen._refresh_controls()
			await _wait(0.4)
			await _shot(spec[0])
		app.set_locale("en")
		_leave_stub_room()
	if _wanted("room_long") or _wanted("room_long_zh"):
		app.show_main_menu()
		_stub_room(true, true)
		app.controller.steam_bridge.steam.persona = LONG_NAMES[0]
		app.controller.steam_bridge.peer_name = LONG_NAMES[1]
		app.controller.room_phase = "result"
		app.controller.room_series = [1, 1]
		app.controller.room_ready = [false, true]
		app.show_room()
		await _wait(0.5)
		await _shot("room_long")
		if _wanted("room_long_zh"):
			app.set_locale("zh_CN")
			await _wait(0.3)
			await _shot("room_long_zh")
			app.set_locale("en")
			await _wait(0.2)
		_leave_stub_room()
	if _wanted("game_over_host_left") or _wanted("game_over_host_left_zh"):
		for spec in [["game_over_host_left", "en"], ["game_over_host_left_zh", "zh_CN"]]:
			if not _wanted(spec[0]):
				continue
			app.set_locale(spec[1])
			Settings.set_match_intro(false, false)
			AnimationQueue.instant = true
			app.controller.current_seed = SEED + 5
			app.start_match(MatchController.MODE_AI)
			app.bot_timer.paused = true
			_advance(func(state): return int(state.round) >= 2 and state.phase == "action")
			var engine = app.engine
			_stub_room(false, true)
			app.controller.steam_bridge.peer_name = "Sun Quan" if spec[1] == "en" else "孙权"
			app.controller.mode = MatchController.MODE_ONLINE
			app.controller.room_phase = "match"
			app.controller.match_serial = 0
			var publish = func() -> void:
				var view = engine.player_view(1)
				view.players[0]["preset"] = MatchController.HIDDEN_DECK
				app.controller._online_state(view, engine.legal_actions(1), 7)
			publish.call()
			await _idle()
			# The host concedes and leaves: result, room and goodbye in one poll.
			AnimationQueue.instant = false
			engine.state.lanes[0].structures[0].ancient = true
			engine.state.lanes[0].structures[0].health = 80
			engine.apply_action(0, {"type": "concede"})
			publish.call()
			app.controller.steam_bridge._end_session("host_left")
			await _idle()
			await _wait(1.2)
			await _shot(spec[0])
			_leave_stub_room()
		app.set_locale("en")

## The lane HUD's hover cards mid-game: an enemy hero in the shown lane (live
## stats) and an enemy hero that fell (in the fountain, two rounds out), in
## both languages and the classic skin.
func _capture_hud_hover() -> void:
	if not HUD_SHOTS.any(func(shot_name): return _wanted(shot_name)):
		return
	var screen = app.screen
	var hud = screen.hud
	Settings.set_match_intro(false, false)
	app.controller.current_seed = SEED
	app.deck_selections = ["starter", "green_assault"]
	AnimationQueue.instant = true
	app.start_match(MatchController.MODE_AI)
	app.bot_timer.paused = true
	_advance(_busy_lane)
	var engine = app.engine
	# An enemy hero outside the shown lane falls (as the kernel does it).
	var fallen: Dictionary = {}
	for unit in engine.state.players[1].roster:
		if int(unit.get("lane", -1)) != -1 and int(unit.lane) != int(engine.state.lane) and fallen.is_empty():
			fallen = unit
	if not fallen.is_empty():
		engine._remove_from_lane(fallen)
		engine._enter_fountain(fallen, int(engine.state.round) + 2)
		engine._event("death", {"p": 1, "uid": fallen.uid, "card": fallen.card, "gold": 0})
	_publish()
	await _idle()
	AnimationQueue.instant = false
	var lane_uid = -1
	for entry in hud.hero_chips():
		if int(entry.lane) == int(engine.state.lane) and int(entry.side) == 0 and lane_uid == -1:
			lane_uid = int(entry.hero.uid)
	if lane_uid == -1 and not hud.hero_chips().is_empty():
		lane_uid = int(hud.hero_chips()[0].hero.uid)
	var fallen_uid = int(fallen.get("uid", lane_uid))
	for spec in [["hud_hover", "en", "three_kingdoms", lane_uid], ["hud_hover_zh", "zh_CN", "three_kingdoms", lane_uid],
			["hud_hover_fallen", "en", "three_kingdoms", fallen_uid], ["hud_hover_fallen_zh", "zh_CN", "three_kingdoms", fallen_uid],
			["hud_hover_classic", "en", "classic", lane_uid]]:
		if not _wanted(spec[0]):
			continue
		app.set_locale(spec[1])
		app.set_skin(spec[2])
		_mouse(Vector2(screen.size.x * 0.5, screen.size.y * 0.45))
		await _wait(0.2)
		var point = hud.hero_chip_center(int(spec[3]))
		_mouse(point + Vector2(1, 0))
		await _frames(2)
		_mouse(point)
		await _wait(0.4)
		await _shot(spec[0])
	_mouse(Vector2(screen.size.x * 0.5, screen.size.y * 0.45))
	app.set_locale("en")
	app.set_skin("three_kingdoms")
	await _wait(0.2)
