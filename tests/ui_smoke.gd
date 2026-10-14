extends SceneTree
## Exercises the actual UI, including phases, targets and replay controls.

const MainScene = preload("res://scenes/main.tscn")
var app

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	app = MainScene.instantiate()
	root.add_child(app)
	app.bot_timer.stop()
	app.mode = 1
	app._render()
	for index in range(6):
		app._act({"type": "pass"})
	assert(app.engine.state.phase == "shop")
	app._act({"type": "finish_shop"})
	app._act({"type": "finish_shop"})
	assert(app.engine.state.phase == "deployment")
	var safety = 0
	while app.engine.state.phase == "deployment" and safety < 20:
		var player = app.local_player
		app._act(app.engine.legal_actions(player)[0])
		safety += 1
	assert(app.engine.state.phase == "action")
	app._open_steam()
	_close_popups()
	var saved_path = "res://.tools/ui_test_replay.json"
	app._save_replay(saved_path)
	var previous_digest = app.engine.state_digest()
	app._load_replay(saved_path)
	assert(app.engine.state_digest() == previous_digest)
	# Exercise Battlefield Control's actual two-stage click flow.
	var jmuy = app.engine.state.players[0].roster[1]
	if jmuy.lane != -1:
		var old_row = app.engine.state.lanes[jmuy.lane].units[0]
		old_row[old_row.find(jmuy)] = null
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
	assert(app.selected_source == jmuy.uid and app.engine.state.revision == revision_before)
	app._choose_combat_destination(0)
	assert(jmuy.combat_target == 0 and app.engine.state.revision == revision_before + 1)
	assert(app.selected_source == -1 and app.selected_hand == -1)
	app._inspect("foresight")
	assert(app.inspector_title.text == "Foresight" and "Draw two cards" in app.inspector_effect.text)
	app._open_card_preview()
	_close_popups()
	app._open_roster()
	_close_popups()
	app._open_log()
	_close_popups()
	# Use the real deck-selection signals and confirmation path.
	app._open_decks()
	var deck_dialog
	for child in app.get_children():
		if child is AcceptDialog and child.visible:
			deck_dialog = child
	await process_frame
	await process_frame
	assert(deck_dialog.position.y + deck_dialog.size.y <= root.get_visible_rect().size.y + 1)
	assert(deck_dialog.get_ok_button().is_visible_in_tree())
	var selectors: Array = []
	_find_selectors(deck_dialog, selectors)
	assert(selectors.size() == 2)
	selectors[0].item_selected.emit(1)
	selectors[1].item_selected.emit(2)
	deck_dialog.confirmed.emit()
	assert(app.deck_selections == ["green_assault", "blue_black_control"])
	assert(app.engine.state.players[0].roster[0].card == "drow")
	assert(app.engine.state.players[1].roster[0].card == "zeus")
	_close_popups()
	app._inspect("axe")
	app._inspect("gust")
	app._inspect("broadsword")
	app._inspect("axe")
	app._open_catalog()
	_close_popups()
	await process_frame
	print("PASS: UI combat/shop/deployment, targeting, patched cards, deck selection, catalog, Steam fallback and replay restoration.")
	app.queue_free()
	await process_frame
	quit()

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
