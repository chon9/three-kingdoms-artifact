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
## Pass --size=1280x720 to check the smaller window.

const MainScene = preload("res://scenes/main.tscn")
const Settings = preload("res://scripts/core/game_settings.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const MatchController = preload("res://scripts/game/match_controller.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const Library = preload("res://scripts/core/card_library.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const FIXTURES = "res://tests/fixtures/rules_fixtures.json"
const M2_SHOTS = ["m2_board", "m2_board_zh", "m2_overview", "m2_stepper_lane", "m2_stepper_position",
	"m2_stepper_improvement", "m2_item_ability", "m2_inspect", "m2_anim_status", "m2_anim_combat", "m2_chip_rows",
	"m2_hand_note", "m2_hand_note_zh"]
const OUT = "res://.tools/shots/"
const SEED = 20482

var app
var bot = Bot.new()
var only: Array = []
var saved: Array = []
var window_size = Vector2i(1440, 900)
var suffix = ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",")
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var result = image.save_png(OUT + shot_name + suffix + ".png")
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
	root.size = window_size
	# Ignore the real cursor: only the scripted events below may move the mouse.
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]))
	Settings.set_locale("en", false)
	Settings.set_skin("three_kingdoms", false)
	app = MainScene.instantiate()
	root.add_child(app)
	app.set_locale("en")
	app.set_skin("three_kingdoms")
	await _frames(4)
	await _wait(0.5)
	await _shot("main_menu")
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
