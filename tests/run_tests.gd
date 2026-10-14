extends SceneTree

const EngineClass = preload("res://scripts/core/match_engine.gd")
const BotClass = preload("res://scripts/ai/heuristic_bot.gd")
const BridgeClass = preload("res://scripts/network/steam_bridge.gd")
var checks = 0
var failures: Array = []

class FakeSteam extends RefCounted:
	var sent: Array = []
	func getNumLobbyMembers(_lobby: int) -> int:
		return 2
	func getLobbyMemberByIndex(_lobby: int, index: int) -> int:
		return 1001 + index
	func sendMessageToUser(remote: int, data: PackedByteArray, flags: int, channel: int) -> int:
		sent.append({"remote": remote, "data": data, "flags": flags, "channel": channel})
		return 1
	func leaveLobby(_lobby: int) -> void:
		pass
	func closeSessionWithUser(_remote: int) -> bool:
		return true

func _initialize() -> void:
	_test_initial_state()
	_test_validation_and_colors()
	_test_initiative()
	_test_simultaneous_combat()
	_test_armor()
	_test_victory()
	_test_round_cycle()
	_test_effects_and_items()
	_test_hidden_information()
	_test_steam_boundary()
	_test_replays_and_bot_matches()
	if failures.is_empty():
		print("PASS: %d checks, including 24 complete seeded bot matches and replay round trips." % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("%d failures in %d checks." % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _new(seed_value: int = 7):
	var engine = EngineClass.new()
	engine.library = EngineClass.Library.new("original_training_fixtures")
	engine.start(seed_value)
	return engine

func _duel():
	var engine = _new()
	for lane in engine.state.lanes:
		lane.units = [[], []]
	for owner in engine.state.players:
		for hero in owner.roster:
			hero.lane = -1
	for player in range(2):
		var hero = engine.state.players[player].roster[0]
		hero.lane = 0
		hero.arrow = 0
		engine.state.lanes[0].units[player] = [hero]
	engine.state.active_player = 0
	engine.state.initiative = 0
	return engine

func _test_initial_state() -> void:
	var a = _new(10414)
	var b = _new(10414)
	_check(a.state_digest() == b.state_digest(), "Same seed creates exactly the same state")
	_check(a.state.lanes.size() == 3, "Three lanes")
	_check(a.library.training_deck().size() == 40, "Forty-card training deck")
	for player in range(2):
		_check(a.state.players[player].roster.size() == 5, "Five heroes per player")
		_check(a.state.players[player].hand.size() == 5, "Five-card opening hand")
		_check(a.state.players[player].deck.size() == 35, "Opening draw removes five cards")
		var deployed = 0
		for hero in a.state.players[player].roster:
			deployed += int(hero.lane != -1)
		_check(deployed == 3, "Three opening heroes")
		for lane in a.state.lanes:
			_check(lane.mana[player] == 3 and lane.structures[player].health == 40, "Independent opening mana and towers")

func _test_validation_and_colors() -> void:
	var engine = _duel()
	var before = engine.state_digest()
	var bad_commands = [{"type": "play", "hand": -1}, {"type": "play", "hand": 99},
		{"type": "pass", "injected": true}, {"type": "buy", "card": "training_sword"},
		{"type": "deploy", "unit": 1, "lane": 99}]
	for command in bad_commands:
		_check(not engine.apply_action(0, command).ok, "Malformed or out-of-phase command rejected")
		_check(engine.state_digest() == before, "Rejected command does not mutate state or RNG")
	_check(not engine.apply_action(1, {"type": "pass"}).ok, "Out-of-turn pass rejected")
	_check(not engine.apply_action(-1, {"type": "pass"}).ok, "Invalid player rejected")
	engine.state.players[0].hand = ["blue_bolt", "red_guard"]
	var actions = engine.legal_actions(0)
	_check({"type": "play", "hand": 1} in actions, "Matching red hero allows red creep")
	_check(actions.size() == 2, "No blue hero blocks blue spell")
	engine.state.lanes[0].mana[0] = 1
	_check(engine.legal_actions(0) == [{"type": "pass"}], "Insufficient mana blocks cards")
	engine.state.lanes[0].mana[0] = 3
	engine.state.lanes[0].units[0] = []
	_check(engine.legal_actions(0) == [{"type": "pass"}], "No hero blocks colored cards")

func _test_initiative() -> void:
	var engine = _duel()
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	_check(engine.state.lane == 1 and engine.state.active_player == 0, "First passer opens the next lane")
	engine = _duel()
	engine.state.players[0].hand = ["red_initiative"]
	engine.apply_action(0, {"type": "play", "hand": 0})
	_check(engine.state.active_player == 0 and engine.state.lanes[0].mana[0] == 2, "Get initiative keeps the action and pays mana")
	engine = _duel()
	engine.state.players[1].hand = ["red_guard"]
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "play", "hand": 0})
	_check(engine.state.first_pass == -1 and engine.state.active_player == 0, "A card resets consecutive passes")
	engine.apply_action(0, {"type": "pass"})
	_check(engine.state.lane == 0, "A pass separated by a card does not trigger combat")

func _test_simultaneous_combat() -> void:
	var engine = _duel()
	for player in range(2):
		var unit = engine.state.lanes[0].units[player][0]
		unit.attack = 7
		unit.armor = 0
		unit.health = 7
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	for player in range(2):
		_check(engine.state.lanes[0].units[player][0] == null, "Both lethal attackers die simultaneously")
		_check(engine.state.players[player].gold == 5, "Hero kill pays five gold")
		_check(engine.state.players[player].roster[0].ready_round == 3, "Dead hero skips the next round")
		_check(engine.state.players[player].roster[0].lane == -1, "Fallen hero leaves lane and stays in roster")

func _test_armor() -> void:
	var engine = _duel()
	var defender = engine.state.lanes[0].units[1][0]
	defender.armor = 2
	defender.health = 10
	var attacker = engine.state.lanes[0].units[0][0]
	attacker.attack = 1
	_check(engine.combat_preview(0).unit_damage[str(defender.uid)] == 0, "Positive armor cannot create healing")
	defender.armor = -2
	_check(engine.combat_preview(0).unit_damage[str(defender.uid)] == 3, "Negative armor amplifies damage")
	var neighbor = engine._make_unit({"id": "test", "name": "Test", "attack": 1, "health": 4}, 0, false)
	neighbor.arrow = -1
	neighbor.lane = 0
	engine.state.lanes[0].units[0].append(neighbor)
	_check(engine.combat_preview(0).unit_damage[str(defender.uid)] == 6, "Armor applies independently to each incoming attack")

func _test_victory() -> void:
	var engine = _duel()
	engine._damage_structure(0, 1, 100)
	_check(engine.state.lanes[0].structures[1].health == 80, "Tower overflow does not spill into a newly exposed ancient")
	engine._check_winner()
	_check(engine.state.winner == -1, "One tower alone does not win")
	engine._damage_structure(1, 1, 40)
	engine._check_winner()
	_check(engine.state.winner == 0, "Two enemy towers win")
	engine = _duel()
	engine._damage_structure(0, 1, 40)
	engine._damage_structure(0, 1, 80)
	engine._check_winner()
	_check(engine.state.winner == 0, "One tower plus its ancient wins")
	engine = _duel()
	for player in range(2):
		engine.state.lanes[0].structures[player] = {"health": 1, "ancient": true, "destroyed": false}
		engine.state.lanes[0].units[player][0].arrow = 1
	engine.apply_action(0, {"type": "pass"})
	engine.apply_action(1, {"type": "pass"})
	_check(engine.state.winner == 2, "Simultaneous ancient destruction produces a draw")

func _test_round_cycle() -> void:
	var engine = _new()
	for index in range(6):
		engine.apply_action(engine.state.active_player, {"type": "pass"})
	_check(engine.state.phase == "shop", "Right-lane combat enters shopping")
	engine.state.players[0].gold = 3
	engine.apply_action(0, {"type": "buy", "card": "training_sword"})
	_check(engine.state.players[0].gold == 0 and engine.state.players[0].hand.back() == "training_sword", "Shop spends gold and puts equipment in hand")
	_check(not engine.apply_action(0, {"type": "buy", "card": "training_sword"}).ok, "Cannot buy the same shop offering twice")
	engine.apply_action(0, {"type": "finish_shop"})
	engine.apply_action(1, {"type": "finish_shop"})
	_check(engine.state.phase == "deployment" and engine.state.round == 2, "Shopping advances to round-two deployment")
	var hero = engine.state.players[0].roster[3]
	engine.apply_action(0, {"type": "deploy", "unit": hero.uid, "lane": 2})
	_check(hero.lane == -1, "Deployment stays hidden until both players commit")
	_check(engine.player_view(1).players[0].plans.is_empty(), "Opponent cannot see planned lanes")
	for player in range(2):
		var safety = 0
		while not engine.state.players[player].finished and engine.state.phase == "deployment" and safety < 10:
			engine.apply_action(player, engine.legal_actions(player)[0])
			safety += 1
	_check(engine.state.phase == "action", "Both confirmations reveal deployment")
	_check(hero.lane == 2, "Chosen hero lane is respected")
	for lane in engine.state.lanes:
		_check(lane.mana == [4, 4] and lane.max_mana == [4, 4], "Each lane gains and refills mana independently")
	_check(engine.state.players[0].hand.size() == 8, "Round draws two cards plus the purchased item")

func _test_effects_and_items() -> void:
	var engine = _duel()
	var hero = engine.state.lanes[0].units[0][0]
	var enemy = engine.state.lanes[0].units[1][0]
	hero.color = "blue"
	engine.state.players[0].hand = ["blue_bolt"]
	var old_health = enemy.health
	engine.apply_action(0, {"type": "play", "hand": 0, "target": enemy.uid})
	_check(enemy.health == old_health - 2, "Damage spell respects target armor")
	engine = _duel()
	hero = engine.state.lanes[0].units[0][0]
	engine.state.players[0].hand = ["training_cloak"]
	engine.apply_action(0, {"type": "play", "hand": 0, "target": hero.uid})
	_check(hero.health == 15 and engine._max_health(hero) == 15, "Health equipment increases current and maximum health")
	engine.state.active_player = 0
	engine.state.players[0].hand = ["training_cloak"]
	engine.apply_action(0, {"type": "play", "hand": 0, "target": hero.uid})
	_check(hero.health == 15, "Replacing equipment in the same slot does not stack")
	engine = _duel()
	hero = engine.state.lanes[0].units[0][0]
	engine.state.players[0].hand = ["red_fury"]
	engine.apply_action(0, {"type": "play", "hand": 0, "target": hero.uid})
	_check(engine.attack_of(hero) == 11, "Round attack buff applies")
	engine._begin_deployment()
	_check(engine.attack_of(hero) == 7, "Round attack buff expires")
	engine = _duel()
	hero = engine.state.lanes[0].units[0][0]
	hero.color = "green"
	hero.health = 3
	engine.state.players[0].hand = ["green_heal"]
	engine.apply_action(0, {"type": "play", "hand": 0, "target": hero.uid})
	_check(hero.health == 9, "Healing restores health")
	engine = _duel()
	hero = engine.state.lanes[0].units[0][0]
	hero.color = "blue"
	engine.state.players[0].hand = ["blue_draw"]
	engine.apply_action(0, {"type": "play", "hand": 0})
	_check(engine.state.players[0].hand.size() == 2 and engine.state.players[0].deck.size() == 33, "Draw spell consumes itself and draws two")

func _test_hidden_information() -> void:
	var engine = _duel()
	var view = engine.player_view(0)
	_check(view.players[1].hand.is_empty() and view.players[1].hand_count == 5, "Observation exposes opponent hand count only")
	_check(view.players[0].deck.is_empty() and view.players[1].deck.is_empty(), "Observations never expose deck order")
	_check(not view.has("seed") and not view.has("rng"), "Observation has no future random state")
	var before = engine.state_digest()
	var bot = BotClass.new()
	var chosen = bot.choose_action(engine, 0)
	_check(chosen in engine.legal_actions(0), "Bot chooses a legal action")
	_check(engine.state_digest() == before, "Bot search does not mutate the live match")
	engine.state.players[1].hand = ["blue_bolt", "blue_bolt"]
	engine.state.players[1].deck.reverse()
	_check(bot.choose_action(engine, 0) == chosen, "Changing hidden opponent cards and deck order cannot influence bot choice")

func _test_steam_boundary() -> void:
	var bridge = BridgeClass.new()
	bridge.steam = FakeSteam.new()
	bridge.available = true
	bridge.is_host = true
	bridge.lobby_id = 9
	bridge.local_id = 1001
	bridge.peer_id = 1002
	var commands: Array = []
	bridge.command_received.connect(func(command, revision): commands.append([command, revision]))
	var packet = {"protocol": bridge.PROTOCOL, "game": bridge.GAME_TAG, "kind": "command", "command": {"type": "pass"}, "revision": 0}
	bridge._handle_packet(9999, packet)
	_check(commands.is_empty(), "Steam rejects a packet from outside the lobby")
	var wrong_protocol = packet.duplicate(true)
	wrong_protocol.protocol = 99
	bridge._handle_packet(1002, wrong_protocol)
	_check(commands.is_empty(), "Steam rejects incompatible protocol")
	bridge._handle_packet(1002, packet)
	_check(commands.size() == 1, "Steam accepts a command only from the bound opponent")
	var engine = _new()
	bridge.send_match(engine.player_view(1), engine.legal_actions(1))
	var envelope = JSON.parse_string(bridge.steam.sent[0].data.get_string_from_utf8())
	_check(envelope.view.players[0].hand.is_empty() and envelope.view.players[0].deck.is_empty(), "Guest snapshot hides host cards and deck order")
	_check(bridge.steam.sent[0].flags == 8 and bridge.steam.sent[0].channel == 71, "Steam uses reliable isolated-channel messages")
	bridge.free()

func _test_replays_and_bot_matches() -> void:
	var bot = BotClass.new()
	for seed_value in range(1, 25):
		var engine = _new(seed_value)
		var steps = 0
		while engine.state.winner == -1 and steps < 1200:
			var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
			var action = bot.choose_action(engine, player)
			if action.is_empty():
				failures.append("Bot stalled in seed %d, phase %s" % [seed_value, engine.state.phase])
				break
			_check(engine.apply_action(player, action).ok, "Bot action stays legal in seed %d" % seed_value)
			steps += 1
		_check(engine.state.winner != -1, "Bot match terminates in seed %d" % seed_value)
		var restored = EngineClass.new()
		var serialized = JSON.parse_string(JSON.stringify(engine.replay_data()))
		var replay_result = restored.load_replay(serialized)
		_check(replay_result.ok, "Serialized replay loads in seed %d: %s" % [seed_value, replay_result.get("error", "ok")])
		_check(restored.state_digest() == engine.state_digest(), "Replay reproduces state and RNG in seed %d" % seed_value)
	var replay = _new().replay_data()
	replay.actions.append({"player": 0, "command": {"type": "play", "hand": -1}})
	_check(not EngineClass.new().load_replay(replay).ok, "Corrupt replay action rejected")
