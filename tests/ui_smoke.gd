extends SceneTree
## Exercises the actual UI, including phases, targets and replay controls.
## Every check exits with code 1 on failure; a watchdog also exits with code 1
## if a script error stops the coroutine before it can finish.

const MainScene = preload("res://scenes/main.tscn")
const WATCHDOG_SECONDS = 240.0
var app

func _initialize() -> void:
	create_timer(WATCHDOG_SECONDS).timeout.connect(func():
		printerr("FAIL: UI smoke test did not finish within %d seconds." % WATCHDOG_SECONDS)
		quit(1))
	call_deferred("_run")

func _require(condition: bool, message: String) -> bool:
	if not condition:
		printerr("FAIL: " + message)
		quit(1)
	return condition

func _run() -> void:
	app = MainScene.instantiate()
	root.add_child(app)
	app.bot_timer.stop()
	app.mode = 1
	app._render()
	for index in range(6):
		app._act({"type": "pass"})
	if not _require(app.engine.state.phase == "shop", "Six passes reach the shop"):
		return
	app._act({"type": "finish_shop"})
	app._act({"type": "finish_shop"})
	if not _require(app.engine.state.phase == "deployment", "Both players finishing reaches deployment"):
		return
	if not _require(app.engine.player_view(0).pending_creeps[1].size() == 2, "Deployment shows the enemy's lane creeps"):
		return
	var safety = 0
	while app.engine.state.phase == "deployment" and safety < 20:
		var player = app.local_player
		app._act(app.engine.legal_actions(player)[0])
		safety += 1
	if not _require(app.engine.state.phase == "action", "Deployment reveal returns to the action phase"):
		return
	app._open_steam()
	_close_popups()
	var saved_path = "res://.tools/ui_test_replay.json"
	app._save_replay(saved_path)
	var previous_digest = app.engine.state_digest()
	app._load_replay(saved_path)
	if not _require(app.engine.state_digest() == previous_digest, "Saved replay restores the same state"):
		return
	# Hold the Secret Shop offer through the shop controls (fixture shop phase).
	app.engine.state.phase = "shop"
	app.engine._prepare_shop()
	app.engine.state.players[0].gold = 3
	app.local_player = 0
	app._render()
	app._act({"type": "hold"})
	if not _require(app.engine.state.players[0].gold == 2 and not str(app.engine.state.players[0].held_secret).is_empty(), "Hold spends one gold in the UI"):
		return
	app.engine.state.phase = "action"
	# Exercise Battlefield Control's actual two-stage click flow.
	var jmuy = app.engine.state.players[0].roster[1]
	app.engine._remove_from_lane(jmuy)
	jmuy.health = 8
	app.engine._spawn(jmuy, 0)
	app.engine.state.lane = 0
	app.engine.state.active_player = 0
	app.engine.state.lanes[0].mana[0] = 10
	app.engine.state.players[0].hand = ["battlefield_control"]
	app.local_player = 0
	app._render()
	var revision_before = app.engine.state.revision
	app._select_card(0)
	app._target_unit(jmuy.uid)
	if not _require(app.selected_source == jmuy.uid and app.engine.state.revision == revision_before, "Redirect waits for a destination"):
		return
	# Destinations are limited to the three positions across; prefer the tower when open.
	var destinations = app.engine.combat_targets(jmuy)
	var destination = 0 if destinations.has(0) else int(destinations[0])
	app._choose_combat_destination(destination)
	if not _require(int(jmuy.combat_target) == destination and app.engine.state.revision == revision_before + 1, "Redirect to a legal destination applies"):
		return
	if not _require(app.selected_source == -1 and app.selected_hand == -1, "Selection clears after the redirect"):
		return
	# Creep cards wait for a combat position, then enter the chosen end.
	var axe = app.engine.state.players[0].roster[0]
	app.engine._remove_from_lane(axe)
	axe.health = 10
	app.engine._spawn(axe, 0)
	app.engine.state.active_player = 0
	app.engine.state.lanes[0].mana[0] = 10
	app.engine.state.players[0].hand = ["bronze_legionnaire"]
	app._render()
	revision_before = app.engine.state.revision
	app._select_card(0)
	if not _require(app.selected_hand == 0 and app.engine.state.revision == revision_before, "Creep card waits for a position choice"):
		return
	app._choose_position(-1)
	var rows = app.engine.state.lanes[0].units
	if not _require(app.engine.state.revision == revision_before + 1 and rows[0][0] != null and rows[0][0].card == "bronze_legionnaire", "Creep enters the chosen left-end position"):
		return
	if not _require(rows[0].size() == rows[1].size(), "Lane rows stay aligned after a UI creep play"):
		return
	app._inspect("foresight")
	if not _require(app.inspector_title.text == "Foresight" and "Draw two cards" in app.inspector_effect.text, "Inspector shows card text"):
		return
	app._open_card_preview()
	_close_popups()
	app._open_roster()
	_close_popups()
	app._open_log()
	var log_text = ""
	for child in app.get_children():
		if child is AcceptDialog and child.visible:
			for node in child.find_children("*", "RichTextLabel", true, false):
				log_text = node.text
	if not _require(not log_text.is_empty() and "\n\n?\n\n" not in log_text and not log_text.begins_with("?"), "Match log shows formatted event text"):
		return
	_close_popups()
	# Use the real deck-selection signals and confirmation path.
	app._open_decks()
	var deck_dialog
	for child in app.get_children():
		if child is AcceptDialog and child.visible:
			deck_dialog = child
	await process_frame
	await process_frame
	if not _require(deck_dialog != null, "Deck dialog opens"):
		return
	if not _require(deck_dialog.position.y + deck_dialog.size.y <= root.get_visible_rect().size.y + 1, "Deck dialog fits the viewport"):
		return
	if not _require(deck_dialog.get_ok_button().is_visible_in_tree(), "Deck dialog OK button is visible"):
		return
	var selectors: Array = []
	_find_selectors(deck_dialog, selectors)
	if not _require(selectors.size() == 2, "Deck dialog has two deck selectors"):
		return
	selectors[0].item_selected.emit(1)
	selectors[1].item_selected.emit(2)
	deck_dialog.confirmed.emit()
	if not _require(app.deck_selections == ["green_assault", "blue_black_control"], "Deck choices are stored"):
		return
	if not _require(app.engine.state.players[0].roster[0].card == "drow" and app.engine.state.players[1].roster[0].card == "zeus", "Confirmed decks start a new match"):
		return
	_close_popups()
	app._inspect("axe")
	app._inspect("gust")
	app._inspect("broadsword")
	app._inspect("axe")
	app._open_catalog()
	_close_popups()
	await process_frame
	print("PASS: UI combat/shop/hold/deployment, creep positions, targeting, patched cards, deck selection, catalog, log, Steam fallback and replay restoration.")
	app.queue_free()
	await process_frame
	quit(0)

func _close_popups() -> void:
	for child in app.get_children():
		if child is Window:
			child.hide()
			child.queue_free()

func _find_selectors(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is OptionButton:
			result.append(child)
		_find_selectors(child, result)
