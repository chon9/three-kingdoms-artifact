extends SceneTree
## Fuzz (EFFECT_SYSTEM_SPEC.md §13.4, M2): seeded matches on the rules
## fixture pack (tests/fixtures/rules_fixtures.json) with random legal decks
## drawn from every verified card (the Classic cards and the M2 fixtures),
## plus the shipped presets.
##
## Agents: the bot against a seeded random-legal agent, and the bot against
## itself (every third seed). For every match:
## * the global invariants (tests/invariants.gd) after every step, the deep
##   ones (privacy, purity, bounds) every few steps, and no rules_overflow;
## * mutated illegal commands are rejected and change nothing;
## * the hidden swap: the other player's hidden hand, hand state (hacks,
##   counters), deck and deck state never change a view, a legal action or a
##   bot choice;
## * a replay round trip with an equal state_digest, and a second run of the
##   same seed giving the same digest after every step.
## Torture mode then applies every legal action of every card on random
## boards with statuses, items and improvements, each to a copy.
##
## Options (after --): --seeds N (default 50; --nightly is 2000), --first S,
## --steps N (per match, default 500), --torture N (boards, default 24),
## --out <dir> for failing journals (default res://.tools/fuzz_failures,
## outside the user data folder), --timing.

const EngineClass = preload("res://scripts/core/match_engine.gd")
const Library = preload("res://scripts/core/card_library.gd")
const BotClass = preload("res://scripts/ai/heuristic_bot.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Invariants = preload("res://tests/invariants.gd")
const Bridge = preload("res://scripts/network/steam_bridge.gd")
const FIXTURES = "res://tests/fixtures/rules_fixtures.json"
const DEEP_EVERY = 12
const SWAP_EVERY = 40
const MUTATE_EVERY = 6
var checks = 0
var failures: Array = []
var library
var bot = BotClass.new()
var out_dir = "res://.tools/fuzz_failures"
var saved: Array = []

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	var seeds = 2000 if args.has("--nightly") else int(_option(args, "--seeds", "50"))
	var first = int(_option(args, "--first", "1"))
	var max_steps = int(_option(args, "--steps", "500"))
	var torture_boards = int(_option(args, "--torture", "24"))
	out_dir = _option(args, "--out", out_dir)
	library = Library.from_file(FIXTURES, "rules_fixtures")
	_check(library.errors.is_empty(), "The fixture pack compiles: %s" % [library.errors.slice(0, 3)])
	var started = Time.get_ticks_msec()
	var stats = {"matches": 0, "steps": 0, "finished": 0, "plays": {}, "largest_packet": 0, "most_actions": 0}
	for seed_value in range(first, first + seeds):
		_fuzz_match(seed_value, max_steps, stats)
	var match_ms = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	_torture(torture_boards)
	if args.has("--timing"):
		print("matches %d ms, torture %d ms" % [match_ms, Time.get_ticks_msec() - started])
	var played: Array = stats.plays.keys().filter(func(card_id): return str(card_id).begins_with("fx_"))
	_check(stats.matches == seeds, "Every seed ran a match (%d)" % stats.matches)
	_check(seeds < 10 or played.size() >= 20, "The fuzz played many fixture cards (%d: %s)" % [played.size(), played.slice(0, 8)])
	_check(stats.largest_packet < Invariants.PACKET_LIMIT and stats.most_actions <= Invariants.LEGAL_ACTIONS_LIMIT,
		"I14: the largest guest packet %d bytes (< %d), the most legal actions %d (<= %d)" % [stats.largest_packet,
			Invariants.PACKET_LIMIT, stats.most_actions, Invariants.LEGAL_ACTIONS_LIMIT])
	for failure in failures:
		printerr("FAIL: " + failure)
	if not saved.is_empty():
		printerr("Failing journals: " + ", ".join(saved))
	print("%s: %d fuzz checks over %d seeded matches (%d steps, %d finished, %d fixture cards played) and %d torture boards." % [
		"PASS" if failures.is_empty() else "FAIL", checks, stats.matches, stats.steps, stats.finished, played.size(), torture_boards])
	quit(0 if failures.is_empty() else 1)

func _option(args: PackedStringArray, name: String, fallback: String) -> String:
	var index = args.find(name)
	return args[index + 1] if index != -1 and index + 1 < args.size() else fallback

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

# --- Random legal decks ------------------------------------------------------------

## Verified, playable, non-token cards of `kinds` (cards) in sorted id order.
func _pool(kinds: Array, equipment: bool = false) -> Array:
	var ids: Array = []
	for card_id in library.cards:
		var card: Dictionary = library.cards[card_id]
		if str(card.get("kind", "")) not in kinds or not library._deckable(str(card_id)):
			continue
		# Item decks hold equipment only (validate_preset, wiki Item Shop).
		if equipment and (card.get("consumable", false) or str(card.get("slot", "")) not in Library.EQUIPMENT_SLOTS):
			continue
		ids.append(str(card_id))
	ids.sort()
	return ids

## A random legal preset (5 heroes, their signatures, 40+ main cards, 9+
## items) registered in the fixture library under `preset_id`.
func _random_deck(rng: RandomNumberGenerator, preset_id: String) -> String:
	var heroes: Array = []
	for hero in library.heroes:
		# A hero needs a deckable signature card of the pack to fill a legal
		# deck (Lich's Chain Frost is a draft, RQ-16).
		var signature = str(hero.get("signature", ""))
		if str(hero.get("kind", "hero")) == "hero" and library._deckable(str(hero.id)) and library.cards.has(signature) and library._deckable(signature):
			heroes.append(str(hero.id))
	heroes.sort()
	var chosen: Array = []
	while chosen.size() < 5:
		var hero_id = heroes[rng.randi_range(0, heroes.size() - 1)]
		if hero_id not in chosen:
			chosen.append(hero_id)
	var cards: Dictionary = {}
	for hero_id in chosen:
		cards[str(library.definition(hero_id).signature)] = 3
	var main = _pool(["creep", "spell", "improvement"])
	var total = 15
	while total < 40:
		var card_id = main[rng.randi_range(0, main.size() - 1)]
		if int(cards.get(card_id, 0)) < 3:
			cards[card_id] = int(cards.get(card_id, 0)) + 1
			total += 1
	var items: Dictionary = {}
	var equipment = _pool(["item"], true)
	for count in range(rng.randi_range(9, 12)):
		var item_id = equipment[rng.randi_range(0, equipment.size() - 1)]
		items[item_id] = int(items.get(item_id, 0)) + 1
	var preset = {"id": preset_id, "name": preset_id, "heroes": chosen, "cards": cards, "items": items}
	var validation = library.validate_preset(preset)
	_check(validation.ok, "A generated deck is legal: %s" % [validation])
	library.catalog.presets.append(preset)
	return preset_id

# --- Matches -------------------------------------------------------------------------

func _next_player(engine) -> int:
	return int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)

## One seeded match; returns the per-step digests.
func _run(seed_value: int, decks: Array, max_steps: int, stats: Dictionary, checking: bool) -> Dictionary:
	var engine = EngineClass.new()
	engine.library = library
	var started = engine.start(seed_value, decks)
	if not started.ok:
		failures.append("seed %d: the match does not start: %s" % [seed_value, started])
		return {"engine": engine, "digests": [], "problems": ["start"]}
	var agent = RandomNumberGenerator.new()
	agent.seed = seed_value * 7919 + 13
	var mutator = RandomNumberGenerator.new()
	mutator.seed = seed_value * 104729 + 7
	var bots = [true, true] if seed_value % 3 == 0 else [seed_value % 2 == 0, seed_value % 2 == 1]
	var digests: Array = [engine.state_digest()]
	var problems: Array = []
	var steps = 0
	while engine.state.winner == -1 and steps < max_steps and problems.size() < 3:
		var player = _next_player(engine)
		var legal: Array = engine.legal_actions(player)
		if legal.is_empty():
			problems.append("step %d: no legal action in phase %s" % [steps, engine.state.phase])
			break
		if checking:
			stats.most_actions = maxi(stats.most_actions, legal.size())
			if steps % MUTATE_EVERY == 0:
				_check_mutations(engine, player, legal, mutator, problems, steps)
			if steps % DEEP_EVERY == 0:
				var deep = Invariants.deep_violations(engine)
				stats.largest_packet = maxi(stats.largest_packet, Invariants.packet_size(engine))
				if not deep.is_empty():
					problems.append("step %d: %s" % [steps, deep])
			if steps % SWAP_EVERY == 0:
				var swap = _hidden_swap(engine)
				if swap != "":
					problems.append("step %d: hidden swap: %s" % [steps, swap])
		var command: Dictionary = bot.choose_action(engine, player) if bots[player] else legal[agent.randi_range(0, legal.size() - 1)]
		if checking and str(command.get("type", "")) == "play":
			var card_id = str(engine.state.players[player].hand[int(command.hand)])
			stats.plays[card_id] = int(stats.plays.get(card_id, 0)) + 1
		var raw = JSON.parse_string(JSON.stringify(command))
		var result = engine.apply_action(player, raw)
		if not result.ok:
			problems.append("step %d: a legal command %s was rejected after a JSON round trip: %s" % [steps, JSON.stringify(command), result])
			break
		digests.append(engine.state_digest())
		if checking:
			var broken = Invariants.violations(engine) + Invariants.write_through(engine)
			if not broken.is_empty():
				problems.append("step %d after %s: %s" % [steps, JSON.stringify(command), broken])
		steps += 1
	if checking:
		stats.steps += steps
		if engine.state.winner != -1:
			stats.finished += 1
	return {"engine": engine, "digests": digests, "problems": problems}

func _fuzz_match(seed_value: int, max_steps: int, stats: Dictionary) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 5
	var decks: Array
	if seed_value % 5 == 0:
		var presets: Array = ["starter", "green_assault", "blue_black_control"]
		decks = [presets[seed_value % 3], presets[(seed_value / 3) % 3]]
	else:
		decks = [_random_deck(rng, "fuzz_%d_a" % seed_value), _random_deck(rng, "fuzz_%d_b" % seed_value)]
	stats.matches += 1
	var first = _run(seed_value, decks, max_steps, stats, true)
	var problems: Array = first.problems
	var engine = first.engine
	# A replay round trip (plain JSON and the network number normalization).
	var text = JSON.stringify(engine.replay_data())
	for normalize in [false, true]:
		var data = JSON.parse_string(text)
		var restored = EngineClass.new()
		restored.library = library
		var loaded = restored.load_replay(Bridge.normalize_numbers(data) if normalize else data)
		if not loaded.ok or restored.state_digest() != engine.state_digest():
			problems.append("replay round trip (normalized %s): %s" % [normalize, loaded])
	# The same seed again gives the same digest after every step.
	var second = _run(seed_value, decks, max_steps, stats, false)
	if second.digests != first.digests:
		problems.append("a second run of the same seed diverged at step %d" % _diverged(first.digests, second.digests))
	_check(problems.is_empty(), "Fuzz seed %d (%s): %s" % [seed_value, decks, problems.slice(0, 3)])
	if not problems.is_empty():
		_save_failure(seed_value, decks, engine, problems)

func _diverged(a: Array, b: Array) -> int:
	for index in range(mini(a.size(), b.size())):
		if a[index] != b[index]:
			return index
	return mini(a.size(), b.size())

## Mutated variants of legal commands are rejected and change nothing.
func _check_mutations(engine, player: int, legal: Array, rng: RandomNumberGenerator, problems: Array, step: int) -> void:
	var digest = engine.state_digest()
	var rng_state = engine.rng.state
	var ids: Array = [0, -1, 1, 999999, 1000000, 2000000]
	for unit in Stats.all_units(engine):
		ids.append(int(unit.uid))
	for lane in engine.state.lanes:
		for row in lane.get("improvements", [[], []]):
			for improvement in row:
				ids.append(int(improvement.oid))
	for command in legal.slice(0, 30):
		var forged: Dictionary = command.duplicate()
		match rng.randi_range(0, 5):
			0:
				forged["target"] = ids[rng.randi_range(0, ids.size() - 1)]
			1:
				forged["injected"] = true
			2:
				forged["lane"] = int(forged.get("lane", 0)) + rng.randi_range(1, 3)
			3:
				forged["position"] = int(forged.get("position", 0)) + rng.randi_range(-3, 3)
			4:
				forged["unit"] = ids[rng.randi_range(0, ids.size() - 1)]
			5:
				for key in ["target", "destination", "position", "unit", "lane"]:
					forged.erase(key)
		if forged in legal:
			continue
		if engine.apply_action(player, forged).ok:
			problems.append("step %d: forged %s was accepted" % [step, JSON.stringify(forged)])
		if engine.state_digest() != digest or engine.rng.state != rng_state:
			problems.append("step %d: a rejected command changed the state" % step)
			return

## The other player's hidden state (hand cards, hand state with hacks and
## counters, deck and deck state with counters) changes no view, legal action
## or bot choice of either viewer. "" when it holds.
func _hidden_swap(engine) -> String:
	for viewer in range(2):
		var swapped = _swapped(engine, 1 - viewer)
		if JSON.stringify(engine.player_view(viewer)) != JSON.stringify(swapped.player_view(viewer)):
			return "view of %d" % viewer
		if engine.legal_actions(viewer) != swapped.legal_actions(viewer):
			return "legal actions of %d" % viewer
		if engine.state.winner == -1 and _next_player(engine) == viewer:
			if bot.choose_action(engine, viewer) != bot.choose_action(swapped, viewer):
				return "bot choice of %d" % viewer
	return ""

func _swapped(engine, hidden_owner: int):
	var swapped = EngineClass.new()
	swapped.library = engine.library
	swapped.state = engine.state.duplicate(true)
	swapped.rng.state = engine.rng.state
	swapped.next_id = engine.next_id
	swapped.match_seed = engine.match_seed
	swapped.deck_ids = engine.deck_ids.duplicate()
	var owner: Dictionary = swapped.state.players[hidden_owner]
	for index in range(owner.hand.size()):
		owner.hand[index] = "fx_counter_spell" if str(owner.hand[index]) != "fx_counter_spell" else "foresight"
	for index in range(owner.get("hand_state", []).size()):
		var entry: Dictionary = owner.hand_state[index]
		entry["iid"] = 8888000 + index
		entry["charges"] = 7
		entry["hacks"] = ["fx_hack_spell#0"]
	owner.deck.reverse()
	if not owner.deck.is_empty():
		owner.deck[0] = "fx_counter_spell"
	var deck_states: Array = []
	for card_id in owner.deck:
		deck_states.append({"charges": 5})
	owner["deck_state"] = deck_states
	for key in owner.get("plans", {}).keys():
		owner.plans[key] = (int(owner.plans[key]) + 1) % 3
	return swapped

func _save_failure(seed_value: int, decks: Array, engine, problems: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path = "%s/seed_%d.json" % [out_dir, seed_value]
	var presets: Array = library.catalog.presets.filter(func(entry): return str(entry.id) in decks)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"seed": seed_value, "decks": decks, "presets": presets, "problems": problems,
		"replay": engine.replay_data()}, "  "))
	file.close()
	saved.append(path)

# --- Torture mode ----------------------------------------------------------------------

## Random boards with statuses, items and improvements; every legal action of
## every card in a full hand of fixture cards is applied to a copy.
func _torture(boards: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 90210
	var hand_pool = _pool(["creep", "spell", "improvement"]).filter(func(card_id): return str(card_id).begins_with("fx_"))
	var improvements = hand_pool.filter(func(card_id): return str(library.get_card(card_id).kind) == "improvement")
	var equipment = _pool(["item"], true)
	var creeps = _pool(["creep"])
	var problems: Array = []
	var applied = 0
	for board in range(boards):
		var engine = EngineClass.new()
		engine.library = library
		engine.start(board + 400)
		for lane_index in range(3):
			var lane: Dictionary = engine.state.lanes[lane_index]
			lane.mana = [12, 12]
			lane.max_mana = [12, 12]
			lane.max_mana_base = [12, 12]
			for side in range(2):
				for count in range(rng.randi_range(0, 3)):
					Zones.summon(engine, creeps[rng.randi_range(0, creeps.size() - 1)], side, lane_index)
				if rng.randi_range(0, 1) == 0:
					Zones.add_improvement(engine, improvements[rng.randi_range(0, improvements.size() - 1)], side, lane_index)
		# Every hero joins a lane, so each colour can be cast somewhere.
		for side in range(2):
			for hero in engine.state.players[side].roster:
				if int(hero.lane) == -1:
					Zones.spawn(engine, hero, rng.randi_range(0, 2))
		engine._roll_arrows()
		for unit in Stats.all_units(engine):
			if bool(unit.get("hero", false)) and rng.randi_range(0, 1) == 0:
				Zones.equip(engine, unit, equipment[rng.randi_range(0, equipment.size() - 1)])
			if int(unit.get("lane", -1)) >= 0 and rng.randi_range(0, 3) == 0:
				var status = ["stun", "silence", "disarm", "damage_immunity", "death_shield", "pierce"][rng.randi_range(0, 5)]
				Kernel.give(engine, unit, {}, {status: 1}, "", "round", {"controller": 1 - int(unit.owner), "card": ""})
		engine._reset_transient()
		Kernel.pulse(engine)
		engine._settle_transient()
		var player = int(engine.state.active_player)
		var hand: Array = []
		for count in range(10):
			hand.append(hand_pool[rng.randi_range(0, hand_pool.size() - 1)])
		engine.state.players[player].hand = hand
		engine.state.players[player].hand_state = []
		Zones.sync(engine)
		for lane_index in range(3):
			engine.state.lane = lane_index
			engine.state.active_player = player
			engine.state.first_pass = -1
			var legal: Array = engine.legal_actions(player)
			for command in legal.slice(0, 120):
				var copy = _copy(engine)
				var result = copy.apply_action(player, command)
				applied += 1
				if not result.ok:
					problems.append("board %d lane %d: %s rejected: %s" % [board, lane_index, JSON.stringify(command), result])
				var broken = Invariants.violations(copy)
				if not broken.is_empty():
					problems.append("board %d lane %d after %s: %s" % [board, lane_index, JSON.stringify(command), broken])
				if problems.size() >= 5:
					break
		if problems.size() >= 5:
			break
	_check(problems.is_empty() and applied >= boards * 10, "Torture: every legal action of every card applies on %d random boards (%d actions): %s" % [boards, applied, problems])

## An independent copy of an engine. A deep duplicate copies every reference
## separately, so each roster hero standing in a lane is linked back to its
## lane unit (the engine shares that dictionary between the two places).
func _copy(engine):
	var copy = EngineClass.new()
	copy.library = engine.library
	copy.state = engine.state.duplicate(true)
	copy.rng.state = engine.rng.state
	copy.next_id = engine.next_id
	copy.match_seed = engine.match_seed
	copy.deck_ids = engine.deck_ids.duplicate()
	for owner in copy.state.players:
		for index in range(owner.roster.size()):
			var hero: Dictionary = owner.roster[index]
			if int(hero.lane) < 0:
				continue
			for unit in copy.state.lanes[int(hero.lane)].units[int(hero.owner)]:
				if unit != null and int(unit.uid) == int(hero.uid):
					owner.roster[index] = unit
	return copy
