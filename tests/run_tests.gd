extends SceneTree

const EngineClass = preload("res://scripts/core/match_engine.gd")
const BotClass = preload("res://scripts/ai/heuristic_bot.gd")
const EventFormatter = preload("res://scripts/core/event_text.gd")
const BridgeClass = preload("res://scripts/network/steam_bridge.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const Invariants = preload("res://tests/invariants.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	# Display text below is checked in English with the original card names.
	Settings.set_locale("en", false)
	Settings.set_skin("classic", false)
	_test_initial_state()
	_test_validation_and_colors()
	_test_initiative()
	_test_simultaneous_combat()
	_test_armor()
	_test_victory()
	_test_round_cycle()
	_test_effects_and_items()
	_test_hidden_information()
	_test_creep_positions()
	_test_no_lane_reroll()
	_test_arrow_resets()
	_test_deployment_creeps_visible()
	_test_deployment_replanning()
	_test_deployment_placed_event()
	_test_event_formatter_keys()
	_test_language_neutral_state()
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
	_check({"type": "play", "hand": 1, "position": -1} in actions and {"type": "play", "hand": 1, "position": 1} in actions, "Matching red hero allows red creep at either lane end")
	_check(actions.size() == 3, "No blue hero blocks blue spell")
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
	engine.apply_action(1, {"type": "play", "hand": 0, "position": 1})
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
		_check(engine.state.lanes[0].units[player].is_empty(), "Both lethal attackers die simultaneously and their position collapses")
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
	engine.state.lanes[0].units[1].append(null)
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
		# Blocked units attack forward; force the tower like Battlefield Control.
		engine.state.lanes[0].units[player][0].combat_target = 0
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

func _test_replays_and_bot_matches() -> void:
	var bot = BotClass.new()
	var emitted: Dictionary = {}
	for seed_value in range(1, 25):
		var engine = _new(seed_value)
		var steps = 0
		var aligned = Invariants.board(engine)
		var events_ok = _format_new_events(engine, 0, emitted)
		while engine.state.winner == -1 and steps < 1200:
			var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
			var action = bot.choose_action(engine, player)
			if action.is_empty():
				failures.append("Bot stalled in seed %d, phase %s" % [seed_value, engine.state.phase])
				break
			var seen = int(engine.state.event_seq)
			_check(engine.apply_action(player, action).ok, "Bot action stays legal in seed %d" % seed_value)
			aligned = aligned and Invariants.board(engine)
			events_ok = _format_new_events(engine, seen, emitted) and events_ok
			steps += 1
		_check(engine.state.winner != -1, "Bot match terminates in seed %d" % seed_value)
		_check(aligned, "Rows stay aligned, compacted and arrow-consistent after every bot action in seed %d" % seed_value)
		_check(events_ok, "Every emitted event formats to known non-empty text in seed %d" % seed_value)
		var restored = EngineClass.new()
		var serialized = JSON.parse_string(JSON.stringify(engine.replay_data()))
		var replay_result = restored.load_replay(serialized)
		_check(replay_result.ok, "Serialized replay loads in seed %d: %s" % [seed_value, replay_result.get("error", "ok")])
		_check(restored.state_digest() == engine.state_digest(), "Replay reproduces state and RNG in seed %d" % seed_value)
		_check(_bot_never_replans(engine.journal), "The bot never re-plans or takes back a hero in seed %d" % seed_value)
	for key in ["match_start", "pass", "lane_open", "play", "combat", "death", "shop_open", "deployment", "deployment_placed", "deployment_revealed"]:
		_check(emitted.has(key), "Bot matches emit and format event key " + key)
	_check(emitted.has("win") or emitted.has("draw"), "Bot matches emit a result event")
	var replay = _new().replay_data()
	_check(int(replay.protocol) == 7, "Replay format version is 7")
	replay.actions.append({"player": 0, "command": {"type": "play", "hand": -1}})
	_check(not EngineClass.new().load_replay(replay).ok, "Corrupt replay action rejected")
	var legacy = _new().replay_data()
	legacy.protocol = 3
	_check(not EngineClass.new().load_replay(legacy).ok, "Protocol 3 replays are rejected clearly")

func _format_new_events(engine, seen: int, emitted: Dictionary) -> bool:
	var events = engine.state.events
	var fresh = mini(int(engine.state.event_seq) - seen, events.size())
	var ok = true
	for event in events.slice(events.size() - fresh):
		var text = EventFormatter.format(event, engine.library)
		emitted[str(event.get("k", ""))] = true
		if text.is_empty() or text == "?" or str(event.get("k", "")) not in EventFormatter.KEYS:
			ok = false
	return ok

func _set_rows(engine, rows: Array) -> void:
	# rows = [[p0 unit or null, ...], [p1 unit or null, ...]] for lane 0.
	engine.state.lanes[0].units = rows
	for side in range(2):
		for unit in rows[side]:
			if unit != null:
				unit.lane = 0
	engine.state.lanes[0].mana = [20, 20]

func _test_creep_positions() -> void:
	var engine = _duel()
	var lane = engine.state.lanes[0]
	lane.mana = [20, 20]
	var enemy_creep = engine._make_unit({"id": "melee_creep", "name": "Melee Creep", "attack": 2, "health": 4}, 1, false)
	engine._place(enemy_creep, 0, 1)
	_check(lane.units[0].size() == 2 and lane.units[0][1] == null, "A new right-end position opens an empty slot opposite")
	engine.state.players[0].hand = ["red_guard"]
	var positions: Array = []
	for action in engine.legal_actions(0):
		if action.type == "play":
			positions.append(action.position)
	_check(positions == [-1, 1, 2], "Creep card offers the left end, each empty own slot and the right end")
	_check(engine.apply_action(0, {"type": "play", "hand": 0, "position": 1}).ok, "Creep can enter a chosen empty position")
	_check(lane.units[0][1] != null and lane.units[0][1].card == "red_guard" and lane.units[1][1] == enemy_creep, "Chosen position is opposite the enemy creep")
	engine.state.active_player = 0
	engine.state.players[0].hand = ["red_guard"]
	_check(not engine.apply_action(0, {"type": "play", "hand": 0, "position": 0}).ok, "An occupied position is not a legal choice")
	_check(not engine.apply_action(0, {"type": "play", "hand": 0}).ok, "A creep card requires a position")
	_check(engine.apply_action(0, {"type": "play", "hand": 0, "position": -1}).ok, "Creep can open a new left-end position")
	_check(lane.units[0][0].card == "red_guard" and lane.units[1][0] == null and lane.units[0].size() == 3 and lane.units[1].size() == 3, "Left-end insertion shifts both rows together")
	engine.state.active_player = 0
	engine.state.players[0].hand = ["red_guard"]
	_check(engine.apply_action(0, {"type": "play", "hand": 0, "position": 3}).ok, "Creep can open a new right-end position")
	_check(lane.units[0][3].card == "red_guard" and lane.units[1][3] == null, "Right-end insertion appends to both rows")
	_check(Invariants.board(engine), "Creep insertions keep the board aligned")
	engine.state.lanes[1].units = [[], []]
	_check(engine.creep_positions(1, 0) == [0], "An empty lane offers exactly one new position")

func _test_no_lane_reroll() -> void:
	var engine = _duel()
	var hero0 = engine.state.players[0].roster[0]
	var hero1 = engine.state.players[1].roster[0]
	var creep = engine._make_unit({"id": "melee_creep", "name": "Melee Creep", "attack": 2, "health": 4}, 0, false)
	_set_rows(engine, [[hero0, null, creep], [null, hero1, null]])
	hero0.arrow = 1
	hero1.arrow = -1
	creep.arrow = -1
	var watched = [hero0, hero1, creep]
	var before: Array = []
	for unit in watched:
		before.append([int(unit.arrow), int(engine.combat_target_of(unit).get("uid", 0))])
	for attempt in range(6):
		var player = attempt % 2
		engine.state.active_player = player
		engine.state.players[player].hand = ["red_guard"]
		var end = -1 if attempt < 3 else engine.state.lanes[0].units[player].size()
		_check(engine.apply_action(player, {"type": "play", "hand": 0, "position": end}).ok, "End-position creep play %d is legal" % attempt)
		var after: Array = []
		for unit in watched:
			after.append([int(unit.arrow), int(engine.combat_target_of(unit).get("uid", 0))])
		_check(after == before, "Playing a creep never rerolls or retargets other arrows (play %d)" % attempt)
	_check(Invariants.board(engine), "Repeated end insertions keep arrows consistent")

func _test_arrow_resets() -> void:
	var engine = _duel()
	var hero0 = engine.state.players[0].roster[0]
	var hero1 = engine.state.players[1].roster[0]
	_set_rows(engine, [[hero0, null], [null, hero1]])
	hero1.arrow = -1
	_check(engine.combat_target_of(hero1).uid == hero0.uid, "Diagonal arrow targets the left enemy neighbor")
	engine.state.players[0].hand = ["red_guard"]
	_check(engine.apply_action(0, {"type": "play", "hand": 0, "position": 1}).ok, "Creep placed opposite a diagonal attacker")
	_check(hero1.arrow == 0 and engine.combat_target_of(hero1).card == "red_guard", "Placing a unit directly opposite resets the attacker to face it")
	engine = _duel()
	hero0 = engine.state.players[0].roster[0]
	hero1 = engine.state.players[1].roster[0]
	_set_rows(engine, [[hero0, null], [null, hero1]])
	hero1.arrow = -1
	hero0.health = 0
	engine._clean_dead(0)
	_check(hero1.arrow == 0, "A diagonal target's death resets the attacker to forward")
	_check(engine.state.lanes[0].units[0] == [null] and engine.state.lanes[0].units[1].size() == 1, "The emptied position collapses after cleanup")
	_check(engine.combat_target_of(hero1).is_empty(), "With nothing opposite, forward means the tower")
	engine = _duel()
	hero0 = engine.state.players[0].roster[0]
	hero1 = engine.state.players[1].roster[0]
	_set_rows(engine, [[hero0, null], [null, hero1]])
	hero1.arrow = -1
	engine._remove_from_lane(hero0)
	_check(hero1.arrow == 0 and engine.state.lanes[0].units[0] == [null], "A target leaving play resets pathing and compacts the lane")
	engine = _duel()
	hero0 = engine.state.players[0].roster[0]
	hero1 = engine.state.players[1].roster[0]
	_set_rows(engine, [[hero0, null], [null, hero1]])
	hero1.combat_target = hero0.uid
	hero0.health = 0
	engine._clean_dead(0)
	_check(hero1.combat_target == -1 and hero1.arrow == 0, "A chosen combat target's death resets the redirect to forward")

func _creep_counts(engine) -> Array:
	var counts = [[0, 0, 0], [0, 0, 0]]
	for lane_index in range(3):
		for side in range(2):
			for unit in engine.state.lanes[lane_index].units[side]:
				if unit != null and not unit.hero:
					counts[side][lane_index] += 1
	return counts

func _test_deployment_creeps_visible() -> void:
	var engine = _new(5)
	for index in range(6):
		engine.apply_action(engine.state.active_player, {"type": "pass"})
	engine.apply_action(0, {"type": "finish_shop"})
	engine.apply_action(1, {"type": "finish_shop"})
	_check(engine.state.phase == "deployment", "Shopping leads to deployment")
	var pending = engine.state.pending_creeps.duplicate(true)
	var valid = pending.size() == 2
	for side in range(pending.size()):
		valid = valid and pending[side].size() == 2 and pending[side].all(func(lane_index): return lane_index >= 0 and lane_index <= 2)
	_check(valid, "Two lane creeps per player are assigned at the start of deployment")
	for viewer in range(2):
		_check(engine.player_view(viewer).pending_creeps == pending, "Both players see lane creep assignments before choosing heroes")
	_check(engine.legal_actions(0).any(func(action): return action.type == "deploy"), "Heroes are still unchosen while creeps are visible")
	var before = _creep_counts(engine)
	for player in range(2):
		var safety = 0
		while not engine.state.players[player].finished and engine.state.phase == "deployment" and safety < 10:
			engine.apply_action(player, engine.legal_actions(player)[0])
			safety += 1
	var after = _creep_counts(engine)
	var matched = true
	for side in range(2):
		for lane_index in range(3):
			matched = matched and after[side][lane_index] - before[side][lane_index] == pending[side].count(lane_index)
	_check(matched, "Revealed creeps enter exactly the announced lanes")
	_check(engine.state.pending_creeps == [[], []], "Pending creeps clear after placement")
	_check(Invariants.board(engine), "Deployment placement keeps lanes aligned and arrows consistent")

## Passes through round 1 and the shop into round-two deployment.
func _to_deployment(seed_value: int):
	var engine = _new(seed_value)
	for index in range(6):
		engine.apply_action(engine.state.active_player, {"type": "pass"})
	engine.apply_action(0, {"type": "finish_shop"})
	engine.apply_action(1, {"type": "finish_shop"})
	return engine

## Ready heroes of `player` still in the fountain.
func _ready_heroes(engine, player: int) -> Array:
	var heroes: Array = []
	for hero in engine.state.players[player].roster:
		if int(hero.lane) == -1 and int(hero.ready_round) <= int(engine.state.round):
			heroes.append(hero)
	return heroes

## Confirms `player`'s deployment by always taking the first legal action.
func _commit_first(engine, player: int) -> int:
	var steps = 0
	while not engine.state.players[player].finished and engine.state.phase == "deployment" and steps < 10:
		engine.apply_action(player, engine.legal_actions(player)[0])
		steps += 1
	return steps

func _test_deployment_replanning() -> void:
	var engine = _to_deployment(5)
	_check(engine.state.phase == "deployment", "Re-plan test reaches deployment")
	var ready = _ready_heroes(engine, 0)
	_check(not ready.is_empty(), "Player 1 has a ready hero in round two")
	if ready.is_empty():
		return
	var hero = ready[0]
	var uid = int(hero.uid)
	var digest_rng = engine.rng.state
	var event_count = engine.state.events.size()
	var event_seq = int(engine.state.event_seq)
	_check(engine.apply_action(0, {"type": "deploy", "unit": uid, "lane": 2}).ok, "A ready hero can be planned")
	var actions = engine.legal_actions(0)
	_check({"type": "deploy", "unit": uid, "lane": 0} in actions and {"type": "deploy", "unit": uid, "lane": 1} in actions
		and not {"type": "deploy", "unit": uid, "lane": 2} in actions, "A planned hero may move to the other two lanes only")
	_check({"type": "undeploy", "unit": uid} in actions, "A planned hero may be taken back")
	_check(engine.apply_action(0, {"type": "deploy", "unit": uid, "lane": 0}).ok and int(engine.state.players[0].plans[str(uid)]) == 0, "Re-planning moves the hero to the new lane")
	_check(engine.apply_action(0, {"type": "undeploy", "unit": uid}).ok and not engine.state.players[0].plans.has(str(uid)), "Undeploy removes the plan")
	_check(not {"type": "finish_deployment"} in engine.legal_actions(0), "An unplanned ready hero blocks confirming")
	_check(not engine.apply_action(0, {"type": "undeploy", "unit": uid}).ok, "An unplanned hero cannot be taken back")
	_check(engine.apply_action(0, {"type": "deploy", "unit": uid, "lane": 1}).ok, "A taken-back hero can be planned again")
	# Planning is private and draws no randomness.
	_check(engine.rng.state == digest_rng and engine.state.events.size() == event_count and int(engine.state.event_seq) == event_seq,
		"Planning, re-planning and undeploying emit no events and leave the random stream untouched")
	_check(engine.player_view(1).players[0].plans.is_empty() and not engine.player_view(0).players[0].plans.is_empty(), "Plans stay hidden from the opponent")
	engine.apply_action(0, {"type": "deploy", "unit": uid, "lane": 0})
	for other in _ready_heroes(engine, 0):
		if not engine.state.players[0].plans.has(str(other.uid)):
			engine.apply_action(0, {"type": "deploy", "unit": int(other.uid), "lane": 2})
	_check(engine.legal_actions(0)[0] == {"type": "finish_deployment"}, "With every hero planned, confirming is the first legal action")
	_check(_commit_first(engine, 0) == 1, "Taking the first action confirms at once")
	_check(engine.legal_actions(0).is_empty(), "After confirming there is no re-plan or undeploy")
	_check(not engine.apply_action(0, {"type": "undeploy", "unit": uid}).ok, "A confirmed plan cannot be taken back")
	_check(_commit_first(engine, 1) <= 10 and engine.state.phase == "action", "First-action loops still finish deployment")
	_check(int(hero.lane) == 0, "The hero deploys to its last planned lane")

func _test_deployment_placed_event() -> void:
	var commands: Array = []
	var engine = _to_deployment(11)
	var mirror = _to_deployment(11)
	for player in range(2):
		var heroes = _ready_heroes(engine, player)
		for index in range(heroes.size()):
			var uid = int(heroes[index].uid)
			commands.append([player, {"type": "deploy", "unit": uid, "lane": index % 3}])
			commands.append([player, {"type": "deploy", "unit": uid, "lane": (index + 1) % 3}])
			commands.append([player, {"type": "undeploy", "unit": uid}])
			commands.append([player, {"type": "deploy", "unit": uid, "lane": (index + 2) % 3}])
	var ok = true
	for entry in commands:
		ok = engine.apply_action(entry[0], entry[1]).ok and mirror.apply_action(entry[0], entry[1]).ok and ok
	_check(ok, "Scripted deploy, re-plan and undeploy commands are legal")
	var planned = [engine.state.players[0].plans.duplicate(), engine.state.players[1].plans.duplicate()]
	for player in range(2):
		engine.apply_action(player, {"type": "finish_deployment"})
		mirror.apply_action(player, {"type": "finish_deployment"})
	_check(engine.state.phase == "action", "Both confirmations reveal")
	var events: Array = engine.state.events
	var found: Array = []
	for index in range(events.size()):
		if str(events[index].k) == "deployment_placed":
			found.append(index)
	_check(found.size() == 1 and found[0] == events.size() - 2 and str(events.back().k) == "deployment_revealed",
		"deployment_placed is emitted once, directly before deployment_revealed")
	if found.is_empty():
		return
	var units: Array = events[found[0]].units
	_check(units.size() == planned[0].size() + planned[1].size() + 4, "The event lists every planned hero and the four lane creeps (%d)" % units.size())
	var uids: Dictionary = {}
	var placed_ok = true
	for unit in units:
		uids[int(unit.uid)] = true
		var live = engine.find_unit(int(unit.uid))
		placed_ok = placed_ok and not live.is_empty() and int(live.lane) == int(unit.lane) and engine.slot_of(live) == int(unit.slot) \
			and int(live.owner) == int(unit.p) and str(live.card) == str(unit.card) and bool(live.hero) == bool(unit.hero)
	_check(uids.size() == units.size(), "Placed uids are unique")
	_check(placed_ok, "Every placed entry matches the unit's final lane, column, owner and card")
	var heroes_ok = true
	for player in range(2):
		for uid_text in planned[player]:
			var match_entry = units.filter(func(unit): return int(unit.uid) == int(uid_text))
			heroes_ok = heroes_ok and match_entry.size() == 1 and bool(match_entry[0].hero) and int(match_entry[0].p) == player \
				and int(match_entry[0].lane) == int(planned[player][uid_text])
	_check(heroes_ok, "Every planned hero is placed in its planned lane")
	_check(mirror.state_digest() == engine.state_digest() and JSON.stringify(mirror.state.events.back()) == JSON.stringify(engine.state.events.back())
		and JSON.stringify(mirror.state.events[found[0]]) == JSON.stringify(events[found[0]]), "Same seed and commands give the same placement and digest")
	var restored = EngineClass.new()
	var replay_result = restored.load_replay(JSON.parse_string(JSON.stringify(engine.replay_data())))
	_check(replay_result.ok and restored.state_digest() == engine.state_digest(), "A replay with re-plans and undeploys reproduces the digest")

## True when no deployment phase in `journal` takes a hero back or plans the
## same hero twice.
func _bot_never_replans(journal: Array) -> bool:
	var seen: Dictionary = {}
	for entry in journal:
		var command: Dictionary = entry.command
		match str(command.type):
			"undeploy":
				return false
			"finish_shop":
				seen.clear()
			"deploy":
				var key = "%d:%d" % [int(entry.player), int(command.unit)]
				if seen.has(key):
					return false
				seen[key] = true
	return true

func _test_event_formatter_keys() -> void:
	var library = EngineClass.Library.new()
	var samples = {"match_start": {}, "pass": {"p": 0}, "lane_open": {"lane": 1, "p": 1},
		"shop_open": {}, "play": {"p": 0, "card": "foresight", "target": 3, "target_card": "axe"},
		"ability": {"p": 1, "uid": 4, "card": "jmuy"}, "buy": {"p": 0, "gold": 3},
		"hold": {"p": 1, "gold": 1}, "combat": {"lane": 2, "damage": [4, 7]},
		"death": {"p": 1, "uid": 9, "card": "melee_creep", "gold": 1}, "tower_fall": {"p": 0},
		"ancient_fall": {"p": 1}, "concede": {"p": 1}, "win": {"p": 0}, "draw": {},
		"deployment": {"round": 2, "creeps": [[0, 2], [1, 1]]},
		"deployment_placed": {"units": [{"uid": 4, "p": 0, "card": "axe", "hero": true, "lane": 1, "slot": 0},
			{"uid": 9, "p": 1, "card": "melee_creep", "hero": false, "lane": 2, "slot": 1}]},
		"deployment_revealed": {},
		"trigger": {"src": "u7", "card": "zeus", "ability": "static_field", "p": 0},
		"damage": {"src": "zeus", "p": 0, "hits": [[4, 1], [5, 1]], "pierce": true},
		"tower_damage": {"src": "lightning_strike", "p": 0, "hits": [[1, 1, 6]]},
		"heal": {"src": "healing_salve", "p": 1, "hits": [[4, 6]]},
		"mod": {"id": 4, "card": "axe", "st": {"attack": 1, "armor": 1}, "kw": {}, "perm": true, "src": "fighting_instinct"},
		"status": {"id": 4, "card": "axe", "st": {}, "kw": {"silence": 1}, "until": "round", "src": "gust"},
		"purge": {"id": "u4", "card": "axe", "n": 2},
		"condemn": {"id": 4, "card": "axe"},
		"summon": {"uid": 30, "card": "melee_creep", "p": 0, "lane": 1, "slot": 2},
		"move": {"uid": 4, "card": "axe", "from": 0, "to": 2, "slot": 1},
		"swap": {"a": 4, "b": 5},
		"retarget": {"uid": 4, "card": "axe", "target": 0},
		"control": {"uid": 9, "card": "melee_creep", "from": 1, "to": 0},
		"fountain": {"uid": 4, "card": "axe", "p": 0},
		"battle": {"a": 4, "card": "axe", "p": 0, "bs": [8, 9], "hits": [[4, 8, 6, "attack"]]},
		"shield": {"uid": 4, "card": "axe"},
		"charges": {"id": 1000040, "card": "foresight", "n": 2},
		"gold": {"p": 0, "n": -3},
		"mana": {"lane": 0, "p": 1, "n": 2},
		"draw_cards": {"p": 1, "n": 2},
		"discard": {"p": 0, "n": 1},
		"lock": {"p": 1, "n": 2},
		"gain_card": {"p": 0},
		"charged": {"p": 0, "n": 3},
		"hack": {"p": 1, "n": 2},
		"improvement": {"oid": 1000041, "card": "foresight", "p": 0, "lane": 2},
		"improvement_gone": {"oid": 1000041, "card": "foresight"},
		"item_gone": {"uid": 4, "slot": "weapon", "card": "short_sword"},
		"pulse": {}, "rules_overflow": {}}
	_check(samples.size() == EventFormatter.KEYS.size(), "Every documented event key has a formatter sample")
	for key in EventFormatter.KEYS:
		var event = {"k": key}
		event.merge(samples.get(key, {}))
		var text = EventFormatter.format(event, library)
		_check(not text.is_empty() and text != "?", "Formatter covers event key " + key)
	_check(EventFormatter.format({"k": "play", "p": 0, "card": "foresight", "target_card": "axe"}, library) == "Player 1 plays Foresight on Axe.", "Formatter names cards from the library")
	_check(EventFormatter.format({"k": "nonsense"}, library) == "?", "Unknown event keys are visible as ?")
	# Rules engine events (spec §6.5) name their source card and sum their hits.
	var keyed = func(key: String) -> Dictionary:
		var event = {"k": key}
		event.merge(samples[key])
		return event
	_check(EventFormatter.format(keyed.call("damage")) == "Zeus deals 2 piercing damage.", "Damage events sum their hits: " + EventFormatter.format(keyed.call("damage")))
	_check(EventFormatter.format(keyed.call("status")) == "Gust gives Axe Silence this round.", "Status events list the change and its duration: " + EventFormatter.format(keyed.call("status")))
	_check(EventFormatter.format(keyed.call("mod")) == "Fighting Instinct permanently gives Axe +1 Attack, +1 Armor.", "Modify events list the permanent stat changes: " + EventFormatter.format(keyed.call("mod")))
	_check(EventFormatter.format(keyed.call("gold")) == "Player 1 loses 3 gold." and EventFormatter.format({"k": "draw_cards", "p": 0, "n": 1}) == "Player 1 draws a card.",
		"Gold and draw events read naturally")
	_check(EventFormatter.format({"k": "ability", "p": 1, "uid": 4, "card": "jmuy", "ability": "wisdom_of_the_elders"}) == "J'Muy the Wise uses Wisdom of the Elders.", "Ability events name the ability")
	var placed = {"k": "deployment_placed", "units": [{"uid": 4, "p": 0, "card": "axe", "hero": true, "lane": 1, "slot": 0},
		{"uid": 5, "p": 0, "card": "keefe", "hero": true, "lane": 0, "slot": 2}, {"uid": 9, "p": 1, "card": "melee_creep", "hero": false, "lane": 2, "slot": 0}]}
	_check(EventFormatter.format(placed, library) == "Heroes deploy: Player 1: Axe (Middle lane), Keefe the Bold (Left lane)",
		"deployment_placed lists the heroes by player and lane: " + EventFormatter.format(placed, library))
	_check(EventFormatter.format({"k": "deployment_placed", "units": [{"uid": 9, "p": 1, "card": "melee_creep", "hero": false, "lane": 2, "slot": 0}]}, library)
		== "Only creeps deploy this round.", "A creep-only reveal says so")
	var play = {"k": "play", "p": 0, "card": "foresight", "target_card": "axe"}
	Settings.set_skin("three_kingdoms", false)
	_check(EventFormatter.format(play) == "Player 1 plays Guo Jia's Legacy on Zhang Fei.", "Formatter uses the Three Kingdoms skin")
	Settings.set_locale("zh_CN", false)
	_check(EventFormatter.format(play) == "玩家1对张飞打出遗计。", "Formatter uses zh_CN templates and names")
	_check(EventFormatter.format({"k": "lane_open", "lane": 1, "p": 1}) == "中路开战，玩家2持有先手。", "Lane names are translated")
	Settings.set_locale("en", false)
	Settings.set_skin("classic", false)

func _test_language_neutral_state() -> void:
	var engine = EngineClass.new()
	engine.start(5, ["starter", "green_assault"])
	var named: Array = []
	for owner in engine.state.players:
		if owner.has("deck_name"):
			named.append("deck_name")
		for hero in owner.roster:
			for field in ["name", "ability_name", "text"]:
				if hero.has(field):
					named.append(field)
	for lane in engine.state.lanes:
		for row in lane.units:
			for unit in row:
				if unit != null and (unit.has("name") or unit.has("ability_name")):
					named.append(unit.card)
	_check(named.is_empty(), "Match state holds ids and numbers, not display names: %s" % str(named))
	var illegal = engine.apply_action(1 - int(engine.state.active_player), {"type": "pass"})
	_check(not illegal.ok and illegal.get("code") == "illegal_action" and not str(illegal.get("error", "")).is_empty(), "Illegal commands return a code and an English fallback")
	var fraction = engine.apply_action(0, {"type": "play", "hand": 0.5})
	_check(fraction.get("code") == "bad_index", "Fractional indexes return bad_index")
	_check(engine.start(3, ["starter"]).get("code") == "deck_selection", "Bad deck selection returns deck_selection")
	_check(engine.library.validate_preset({"heroes": []}).get("code") == "deck_hero_count", "Deck validation returns codes")
	var replay = engine.replay_data()
	replay.protocol = 4
	var stale = EngineClass.new().load_replay(replay)
	_check(stale.get("code") == "replay_version", "Protocol 4 replays are rejected with replay_version")
	_check(EngineClass.PROTOCOL_VERSION == 7 and BridgeClass.PROTOCOL == 8, "Replay format 7; Steam network protocol 8 (tests/steam_test.gd covers the boundary)")
	_check(EventFormatter.error_text(illegal) == "That action is not legal in the current state.", "Error codes translate to English")
	Settings.set_locale("zh_CN", false)
	_check(EventFormatter.error_text(illegal) == "当前局面下不能执行该操作。", "Error codes translate to Chinese")
	_check(EventFormatter.steam_status("lobby_created", {"lobby": "42"}) == "房间 42 已创建。可邀请好友、发送房间号，或等待他人从房间列表加入。", "Steam status codes translate")
	Settings.set_locale("en", false)
	_check(EventFormatter.error_text({"ok": false, "error": "Raw fallback"}) == "Raw fallback", "Uncoded errors keep their fallback text")
	var bridge = BridgeClass.new()
	_check(bridge.status_code == "not_installed", "Steam bridge exposes a status code")
	bridge.free()
