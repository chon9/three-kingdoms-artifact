extends SceneTree
## Captures the main UI states as PNGs in res://.tools/shots/. Needs the real
## renderer, so run it without --headless:
##   godot --path . -s res://tests/capture_preview.gd [-- --only=lane_action,shop]
## Shots: main_menu, lane_action, lane_action_zh, drag_targeting, inspect,
## overview, hand_full (13 cards), combat (mid-animation), shop, shop_zh,
## deployment, game_over, game_over_zh.
## Pass --size=1280x720 to check the smaller window.

const MainScene = preload("res://scenes/main.tscn")
const Settings = preload("res://scripts/core/game_settings.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const MatchController = preload("res://scripts/game/match_controller.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
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

func _idle() -> void:
	var queue = app.screen.queue
	var guard = 0
	while queue.busy and guard < 600:
		await process_frame
		guard += 1

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
