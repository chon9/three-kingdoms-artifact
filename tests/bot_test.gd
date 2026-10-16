extends SceneTree
## Bot (EFFECT_SYSTEM_SPEC.md §9) on the rules fixture pack:
## * the M2 evaluation terms: combat keywords, Damage Immunity, a quarter of
##   the attack for a stunned or disarmed unit, improvements by their cost
##   (M7) and charges, opponent locks (standing, and the ones the bot's own
##   plays add), and the preview's deaths and healing;
## * the prefilter: above PREFILTER_LIMIT candidates, pass, every ability and
##   the best combinations per hand card by compile-time polarity, at most
##   PREFILTER_KEEP, in legal order;
## * Kanna's -1 lane creeps in the deployment choice (§9.6);
## * M7: the static value of gold gains (Revtel Investments cashes in once its
##   charges outweigh the improvement);
## * M4: the static values of hacks (Self Sabotage) and mana restores (Satyr
##   Magician's active), and random candidates averaged over seeds 1 to 3
##   (§9.5; choose_action re-simulates the random contenders among the
##   RANDOM_REFINE best candidates, never a pass or a draw-free simulation);
## * bot_purity: choosing never changes the live engine;
## * bot_hidden_swap: the other player's hidden state never changes a choice;
## * bot_budget: a decision on the dense fixture takes under 250 ms.

const EngineClass = preload("res://scripts/core/match_engine.gd")
const Library = preload("res://scripts/core/card_library.gd")
const BotClass = preload("res://scripts/ai/heuristic_bot.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")
const Zones = preload("res://scripts/core/rules/zones.gd")
const Legacy = preload("res://tests/legacy/legacy_engine.gd")
const LegacyBot = preload("res://tests/legacy/legacy_bot.gd")
const FIXTURES = "res://tests/fixtures/rules_fixtures.json"
const BASELINE = "res://tests/data/perf_baseline.json"
## Spec §13.6 bot decision budget, on times normalized by the machine factor
## (the frozen legacy engine's full bot match against its stored baseline,
## as tests/perf_test.gd does).
const BUDGET_MS = 250.0
var checks = 0
var failures: Array = []
var library
var bot = BotClass.new()

func _initialize() -> void:
	library = Library.from_file(FIXTURES, "rules_fixtures")
	for test in [_test_evaluation_terms, _test_lock_term, _test_hack_term, _test_mana_term, _test_gold_term, _test_random_seeds,
			_test_polarity, _test_prefilter, _test_kanna_deployment, _test_purity_and_swap, _test_budget]:
		test.call()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d bot checks (evaluation terms, locks, hacks, mana restores, gold gains, random candidates over seeds 1-3, polarity, prefilter, Kanna lanes, purity, hidden swap, budget)." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _engine(seed_value: int = 5):
	var engine = EngineClass.new()
	engine.library = library
	engine.start(seed_value)
	for lane in engine.state.lanes:
		lane.units = [[], []]
		lane.mana = [10, 10]
		lane.max_mana = [10, 10]
		lane.max_mana_base = [10, 10]
		lane.mana_bonus = [0, 0]
	for owner in engine.state.players:
		owner.hand = []
		owner.hand_state = []
		for hero in owner.roster:
			hero.lane = -1
	engine.state.lane = 0
	engine.state.active_player = 0
	engine.state.initiative = 0
	engine.state.first_pass = -1
	return engine

func _unit(engine, card_id: String, owner: int, lane_index: int = 0) -> Dictionary:
	var definition = engine.library.definition(card_id)
	var unit = engine._make_unit(definition, owner, definition.get("kind", "") == "hero")
	var row = engine.state.lanes[lane_index].units[owner]
	var position = row.find(null)
	engine._place(unit, lane_index, position if position != -1 else row.size())
	return unit

func _score(engine, player: int = 0) -> float:
	return bot._evaluate(engine, engine.player_view(player, false), player)

## Spec §9.3.
func _test_evaluation_terms() -> void:
	var engine = _engine()
	var unit = _unit(engine, "fx_cleave_3", 0, 1)
	var plain = _unit(engine, "melee_creep", 0, 2)
	var keyword_value = bot._unit_value(engine, unit)
	var stats_only = engine.attack_of(unit) * 0.75 + float(unit.health) * 0.35 + engine.armor_of(unit) * 0.8
	_check(is_equal_approx(keyword_value, stats_only + 0.3 * 3), "Cleave 3 adds 0.3 per point to a unit's value")
	var base = bot._unit_value(engine, plain)
	Kernel.give(engine, plain, {}, {"stun": 1}, "", "round", {"controller": 1, "card": ""})
	_check(is_equal_approx(bot._unit_value(engine, plain), base - engine.attack_of(plain) * 0.75 * 0.75), "A stunned unit keeps a quarter of its attack term")
	var guard = _unit(engine, "fx_retaliate_2", 0, 2)
	var before = bot._unit_value(engine, guard)
	Kernel.give(engine, guard, {}, {"damage_immunity": 1}, "", "round", {"controller": 0, "card": ""})
	_check(is_equal_approx(bot._unit_value(engine, guard), before + 1.0), "Damage Immunity adds 1.0")
	engine = _engine()
	var empty = _score(engine)
	var keg = Zones.add_improvement(engine, "fx_countdown", 0, 1)
	# The Powder Keg costs 3 and starts with 2 charges, the Academy costs 3.
	_check(is_equal_approx(_score(engine) - empty, 2.0 + 0.25 * 3 + 0.5 * 2), "An own improvement is worth 2.0, plus 0.25 per mana of its cost and 0.5 per charge")
	Zones.add_improvement(engine, "fx_library", 1, 1)
	_check(is_equal_approx(_score(engine) - empty, 3.75 - 2.75), "An enemy improvement counts against")
	# M7: a dearer improvement is worth more (Steam Cannon costs 7, Trebuchets 1).
	var worth: Dictionary = {}
	for card_id in ["steam_cannon", "trebuchets"]:
		engine = _engine()
		empty = _score(engine)
		Zones.add_improvement(engine, card_id, 0, 0)
		worth[card_id] = _score(engine) - empty
	_check(is_equal_approx(worth.steam_cannon, 2.0 + 0.25 * 7) and is_equal_approx(worth.trebuchets, 2.0 + 0.25),
		"An improvement's value grows with its cost (%s)" % [worth])
	# So the bot plays an affordable improvement rather than pass, whatever its
	# cost, even when the one-ply simulation sees none of its effect (before
	# M7 a flat 2.0 lost to the card in hand plus the play penalty from cost 3).
	var casters = {"black": "sorla_khan", "blue": "jmuy", "green": "farvhan"}
	for card_id in ["steam_cannon", "glyph_of_confusion", "selemenes_favor", "trebuchets"]:
		engine = _engine()
		_unit(engine, casters[str(library.get_card(card_id).color)], 0, 0)
		engine.state.players[0].hand = [card_id]
		Zones.sync(engine)
		var choice = bot.choose_action(engine, 0)
		_check(str(choice.get("type", "")) == "play", "The bot plays an affordable %s rather than pass (%s)" % [card_id, choice])
	engine = _engine()
	engine.state.players[1].hand = ["foresight", "foresight"]
	Zones.sync(engine)
	empty = _score(engine)
	engine.state.players[1].hand_state[0]["lock"] = 2
	_check(is_equal_approx(_score(engine) - empty, 0.3), "Each locked opponent card is worth 0.3")
	# Deaths and healing come from the combat preview.
	engine = _engine()
	var troll = _unit(engine, "fx_regen_2", 0, 0)
	_unit(engine, "fx_cleave_3", 1, 0)
	troll.health = 2
	var preview = engine.combat_preview(0)
	_check(not preview.dies.has(int(troll.uid)) and int(preview.heal.get(str(troll.uid), 0)) == 2, "The preview knows regeneration saves the unit")
	var saved = _score(engine)
	troll.kw.erase("regeneration")
	var doomed = _score(engine)
	troll.kw["regeneration"] = 2
	_check(saved > doomed + 2.0, "A unit regeneration saves is not counted as dying (%.2f vs %.2f)" % [saved, doomed])

## Spec §9.3 lock term for the bot's own plays: the simulation has no
## opponent hand, so the locks a play adds come from the compiled static value,
## counted up to the opponent's cards that are not locked yet (public).
func _test_lock_term() -> void:
	_check(int(library.static_value("fx_lock_spell").get("lock", 0)) == 2 and int(library.static_value("fx_stun_spell").get("lock", 0)) == 0,
		"The compiled static value counts the random cards a play locks")
	var engine = _engine()
	_unit(engine, "fx_kanna", 0, 0)
	engine.state.players[0].hand = ["fx_lock_spell"]
	engine.state.players[1].hand = ["foresight", "foresight", "foresight", "foresight", "foresight"]
	Zones.sync(engine)
	var play: Dictionary = {}
	for action in engine.legal_actions(0):
		if str(action.type) == "play":
			play = action
	_check(not play.is_empty(), "Seal Cards is playable on the lock board")
	if play.is_empty():
		return
	var scores: Array = []
	for locked in [0, 4, 5]:
		for index in range(5):
			engine.state.players[1].hand_state[index]["lock"] = 1 if index < locked else 0
		var view = engine.player_view(0)
		scores.append(bot._score_action(engine, view, 0, play, bot._evaluate(engine, view, 0)))
	_check(is_equal_approx(scores[0] - scores[2], 0.6), "Locking two of five unlocked opponent cards scores +0.6 (%.2f)" % (scores[0] - scores[2]))
	_check(is_equal_approx(scores[1] - scores[2], 0.3), "With one unlocked card left it scores +0.3 (%.2f)" % (scores[1] - scores[2]))

## M4: hacks on hidden opponent cards (Self Sabotage) are priced from the
## compiled static value: each hacked card deals its tower damage to the
## opponent when played, up to the opponent's public hand size.
func _test_hack_term() -> void:
	var value: Dictionary = library.static_value("self_sabotage")
	_check(int(value.get("hack", 0)) == 2 and int(value.get("hack_damage", 0)) == 6,
		"Self Sabotage's static value hacks 2 cards for 6 tower damage each (%s)" % [value])
	_check(int(library.static_value("buying_time").get("hack", 0)) == 0, "A lock is not a hack")
	var engine = _engine()
	_unit(engine, "jmuy", 0, 0)
	engine.state.players[0].hand = ["self_sabotage"]
	Zones.sync(engine)
	var play: Dictionary = {}
	for action in engine.legal_actions(0):
		if str(action.type) == "play":
			play = action
	_check(not play.is_empty(), "Self Sabotage is playable on the hack board")
	if play.is_empty():
		return
	var scores: Array = []
	for cards in [0, 1, 5]:
		engine.state.players[1].hand = []
		for index in range(cards):
			engine.state.players[1].hand.append("foresight")
		engine.state.players[1].hand_state = []
		Zones.sync(engine)
		var view = engine.player_view(0)
		scores.append(bot._score_action(engine, view, 0, play, bot._evaluate(engine, view, 0)))
	_check(is_equal_approx(scores[1] - scores[0], 0.36) and is_equal_approx(scores[2] - scores[0], 0.72),
		"Hacking 2 cards of 6 damage scores +0.36 with one opponent card and +0.72 with five (%.2f, %.2f)" % [scores[1] - scores[0], scores[2] - scores[0]])

## M4: an action that restores its own tower's mana (Satyr Magician's
## active) is worth the mana the dearest card in hand still needs.
func _test_mana_term() -> void:
	var static_value: Dictionary = library.rules("satyr_magician").get("ability_static", {}).get("magician", {})
	_check(bool(static_value.get("mana", false)) and not bool(static_value.get("random", true)), "Satyr Magician's active restores mana and is not random (%s)" % [static_value])
	var scores: Dictionary = {}
	for hand in [["foresight"], ["fx_summon_hero", "incarnation_of_selemene"], []]:
		var engine = _engine()
		var satyr = _unit(engine, "satyr_magician", 0, 0)
		engine.state.lanes[0].mana[0] = 2
		engine.state.players[0].hand = hand
		Zones.sync(engine)
		var ability = {"type": "ability", "unit": int(satyr.uid)}
		_check(ability in engine.legal_actions(0), "Satyr Magician's active is legal")
		var view = engine.player_view(0)
		scores[hand.size()] = bot._score_action(engine, view, 0, ability, bot._evaluate(engine, view, 0))
	# Foresight costs 4 and Selemene 9 with 2 of 10 mana: 2 and 7 are missing.
	_check(is_equal_approx(scores[1], 0.24) and is_equal_approx(scores[2], 0.84) and is_equal_approx(scores[0], 0.0),
		"The restore is worth 0.12 per missing mana of the dearest card (%s)" % [scores])
	var engine = _engine()
	var satyr = _unit(engine, "satyr_magician", 0, 0)
	engine.state.lanes[0].mana[0] = 2
	engine.state.players[0].hand = ["incarnation_of_selemene"]
	engine.state.first_pass = 1
	Zones.sync(engine)
	_check(bot.choose_action(engine, 0) == {"type": "ability", "unit": int(satyr.uid)}, "The bot restores its mana before it would pass with an unaffordable Selemene")

## M7: gold that a play or ability adds to its player's purse is worth
## GOLD_WEIGHT per gold, read from the simulation (the evaluation has no gold
## term). Spending all gold (Mercenary Exiles, Wrath of Gold) is not a gain.
## Revtel Investments cashes in only when its gold outweighs the improvement:
## 4 gold per charge at 0.25 against 2.0 + 0.25 x 3 + 0.5 per charge.
func _test_gold_term() -> void:
	var revtel_static: Dictionary = library.rules("revtel_investments").get("ability_static", {}).get("cash_out", {})
	var exiles_static: Dictionary = library.rules("mercenary_exiles").get("ability_static", {}).get("empty_the_purse", {})
	_check(bool(revtel_static.get("gold", false)) and bool(library.static_value("payday").get("gold", false))
		and not bool(exiles_static.get("gold", true)) and not bool(library.static_value("wrath_of_gold").get("gold", true)),
		"Gold gains are static values; spending all gold is not (%s, %s)" % [revtel_static, exiles_static])
	var engine = _engine()
	var runner = _unit(engine, "fx_quick_creep", 0, 0)
	var dash = {"type": "ability", "unit": int(runner.uid)}
	_check(dash in engine.legal_actions(0), "Quick Runner's active is legal")
	var view = engine.player_view(0)
	var score = bot._score_action(engine, view, 0, dash, bot._evaluate(engine, view, 0))
	_check(is_equal_approx(score, BotClass.GOLD_WEIGHT), "One gold gained is worth GOLD_WEIGHT (%.3f)" % score)
	for charges in [2, 5, 6, 8]:
		engine = _engine()
		var revtel = Zones.add_improvement(engine, "revtel_investments", 0, 0)
		revtel["charges"] = charges
		var cash = {"type": "ability", "unit": int(revtel.oid)}
		_check(cash in engine.legal_actions(0), "Revtel Investments' active is legal")
		view = engine.player_view(0)
		score = bot._score_action(engine, view, 0, cash, bot._evaluate(engine, view, 0))
		var expected = 0.25 * 4.0 * charges - (2.0 + 0.25 * 3 + 0.5 * charges)
		_check(is_equal_approx(score, expected), "Cashing in %d charges scores %.2f (%.2f)" % [charges, expected, score])
		var choice = bot.choose_action(engine, 0)
		_check((choice == cash) == (charges >= 6), "The bot cashes in at %d charges: %s (%s)" % [charges, charges >= 6, choice])

## Spec §9.5 (M4): a random candidate is simulated with seeds 1, 2 and 3 and
## averaged; a deterministic one with seed 1 only.
func _test_random_seeds() -> void:
	_check(bool(library.static_value("fog_of_war").random) and not bool(library.static_value("lightning_strike").random),
		"Fog of War is a random card, Lightning Strike is not")
	var engine = _engine()
	_unit(engine, "jmuy", 0, 0)
	for count in range(3):
		_unit(engine, "fx_cleave_3", 1, 0)
		_unit(engine, "melee_creep", 0, 0)
	engine.state.players[0].hand = ["fog_of_war", "lightning_strike"]
	Zones.sync(engine)
	var view = engine.player_view(0)
	var baseline = bot._evaluate(engine, view, 0)
	for action in engine.legal_actions(0):
		if str(action.type) != "play":
			continue
		var card_id = str(engine.state.players[0].hand[int(action.hand)])
		var seeds: Array = BotClass.RANDOM_SEEDS.map(func(seed_value): return bot._simulated_score(engine, view, 0, action, baseline, int(seed_value)))
		var static_value: Dictionary = library.static_value(card_id)
		var cost = 0.7 + float(library.get_card(card_id).get("cost", 0)) * 0.12
		var score = bot._score_action(engine, view, 0, action, baseline) + cost - float(static_value.bias)
		if card_id == "fog_of_war":
			_check(seeds[0] != seeds[1] or seeds[1] != seeds[2], "Fog of War's three seeds disarm different enemies (%s)" % [seeds])
			_check(is_equal_approx(score, (seeds[0] + seeds[1] + seeds[2]) / 3.0), "A random card scores the average of seeds 1 to 3 (%.3f vs %s)" % [score, seeds])
		else:
			_check(score == seeds[0], "A deterministic card scores its seed-1 simulation (%.3f vs %.3f)" % [score, seeds[0]])
	var digest = engine.state_digest()
	var rng_state = engine.rng.state
	bot.choose_action(engine, 0)
	_check(engine.state_digest() == digest and engine.rng.state == rng_state, "Averaging over seeds leaves the live engine untouched")
	# Within the decision budget (§13.6), choose_action re-simulates with the
	# other seeds only the random candidates among the RANDOM_REFINE best, and
	# never simulates pass (its score does not read a simulation).
	engine = _engine()
	engine._place(engine.state.players[0].roster[0], 0, 0)
	for count in range(4):
		_unit(engine, "melee_creep", 1, 0)
	_unit(engine, "melee_creep", 0, 0)
	engine.state.players[0].hand = ["fx_bounce_spell"]
	Zones.sync(engine)
	var candidates = engine.legal_actions(0)
	var plays = candidates.filter(func(action): return str(action.type) == "play").size()
	# The contenders: the RANDOM_REFINE best candidates by first-seed score;
	# each random one that drew randomness costs two more simulations.
	view = engine.player_view(0)
	baseline = bot._evaluate(engine, view, 0)
	var scored: Array = []
	for index in range(candidates.size()):
		var action: Dictionary = candidates[index]
		var change = 0.0 if str(action.type) == "pass" else bot._simulated_score(engine, view, 0, action, baseline, 1)
		var drew_random = str(action.type) != "pass" and bot._last_drew and bot._is_random(engine, view, 0, action)
		scored.append([bot._static_score(engine, view, 0, action, change), index, drew_random])
	scored.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var extra = 0
	for entry in scored.slice(0, BotClass.RANDOM_REFINE):
		if entry[2]:
			extra += BotClass.RANDOM_SEEDS.size() - 1
	var before = bot.simulations
	bot.choose_action(engine, 0)
	_check(plays > BotClass.RANDOM_REFINE and extra > 0 and bot.simulations - before == candidates.size() - 1 + extra,
		"choose_action simulates every candidate but pass once and the random contenders twice more (%d simulations, %d extra)" % [bot.simulations - before, extra])
	# A random pick from the opponent's hand draws nothing in the simulation
	# (the hand is hidden, so empty there): one simulation is enough.
	engine = _engine()
	_unit(engine, "jmuy", 0, 0)
	engine.state.players[0].hand = ["self_sabotage"]
	engine.state.players[1].hand = ["foresight", "foresight", "foresight"]
	Zones.sync(engine)
	candidates = engine.legal_actions(0)
	before = bot.simulations
	bot.choose_action(engine, 0)
	_check(bot.simulations - before == candidates.size() - 1, "A random card whose simulation draws no randomness is simulated once (%d simulations)" % (bot.simulations - before))

## Compile-time polarity of choices (spec §9.4).
func _test_polarity() -> void:
	var cases = {"no_accident": {"target": 1}, "healing_salve": {"target": -1}, "fx_stun_spell": {"target": 1},
		"fx_shield_spell": {"target": -1}, "avernus_blessing": {"target": -1}, "fx_curse_spell": {"target": 1},
		"fx_control": {"target": 1}, "berserkers_call": {}, "battlefield_control": {}, "town_portal_scroll": {"target": -1},
		"slay": {"target": 1}, "fx_swap": {},
		# M3: expressions are estimated (a "neg" or a negative number harms), and
		# granted text counts by what it does for its bearer.
		"rend_armor": {"target": 1}, "crippling_blow": {"target": 1}, "steal_strength": {"target": 1, "destination": -1},
		"enrage": {"target": -1}, "viper_strike": {"target": 1}, "soul_of_spring": {"target": -1},
		"defend_the_weak": {"target": -1}, "heroic_resolve": {"target": -1}, "allseeing_ones_favor": {"target": -1}}
	for card_id in cases:
		var polarity: Dictionary = library.static_value(card_id).get("polarity", {})
		_check(polarity == cases[card_id], "Polarity of %s is %s (got %s)" % [card_id, cases[card_id], polarity])

## Spec §9.4: large action sets are pruned to pass, every ability and the best
## combinations per hand card.
func _test_prefilter() -> void:
	var engine = _engine()
	var hero = engine.state.players[0].roster[1]
	engine._place(hero, 0, 0)
	for count in range(6):
		_unit(engine, "melee_creep", 0, 0)
		_unit(engine, "fx_retaliate_2", 1, 0)
	_unit(engine, "fx_quick_creep", 0, 0)
	var debbi = engine.state.players[0].roster[4]
	engine._place(debbi, 0, engine.state.lanes[0].units[0].size())
	engine.state.players[0].hand = ["no_accident", "no_accident", "no_accident", "healing_salve", "healing_salve", "healing_salve",
		"no_accident", "no_accident", "foresight"]
	Zones.sync(engine)
	var actions: Array = engine.legal_actions(0)
	_check(actions.size() > BotClass.PREFILTER_LIMIT, "The board offers more than %d candidates (%d)" % [BotClass.PREFILTER_LIMIT, actions.size()])
	var kept: Array = bot._prefilter(engine, actions, 0)
	_check(kept.size() <= BotClass.PREFILTER_KEEP, "At most %d candidates are simulated (%d)" % [BotClass.PREFILTER_KEEP, kept.size()])
	_check(kept.has({"type": "pass"}) and actions.filter(func(action): return str(action.type) == "ability").all(func(action): return kept.has(action)),
		"Pass and every ability are kept")
	for index in range(9):
		_check(kept.filter(func(action): return str(action.type) == "play" and int(action.hand) == index).size() <= BotClass.PREFILTER_PER_CARD,
			"At most %d combinations of hand card %d are kept" % [BotClass.PREFILTER_PER_CARD, index])
	var order: Array = kept.map(func(action): return actions.find(action))
	var sorted_order = order.duplicate()
	sorted_order.sort()
	_check(order == sorted_order, "Kept candidates stay in legal_actions order")
	var damage = kept.filter(func(action): return str(action.type) == "play" and int(action.hand) == 0)
	_check(not damage.is_empty() and damage.all(func(action): return int(engine.find_unit(int(action.target)).owner) == 1),
		"Damage combinations keep enemy targets")
	var heals = kept.filter(func(action): return str(action.type) == "play" and int(action.hand) == 3)
	_check(not heals.is_empty() and heals.all(func(action): return int(engine.find_unit(int(action.target)).owner) == 0),
		"Healing combinations keep allied targets")
	_check(bot._prefilter(engine, actions.slice(0, 10), 0) == actions.slice(0, 10), "Small action sets are never pruned")
	var choice = bot.choose_action(engine, 0)
	_check(choice in actions, "The bot still chooses a legal action from a pruned set")

## Spec §9.6: the player's -1 lane creeps count in Kanna's lane.
func _test_kanna_deployment() -> void:
	var engine = _engine()
	var kanna = engine._make_unit(engine.library.definition("fx_kanna"), 0, true)
	engine.state.players[0].roster.append(kanna)
	engine._place(kanna, 2, 0)
	_unit(engine, "fx_retaliate_2", 1, 2)
	engine._begin_deployment()
	_check(engine.state.pending_creeps[0] == [-1, -1], "Kanna's creeps are published as -1")
	var view = engine.player_view(0)
	_check(bot._kanna_lane(engine, view, 0) == 2, "The bot reads its own Kanna's lane for -1 creeps")
	_check(bot._kanna_lane(engine, engine.player_view(1), 1) == -1, "The opponent's -1 creeps are not placed anywhere")
	var action = bot.choose_action(engine, 0)
	_check(str(action.get("type", "")) in ["deploy", "finish_deployment"], "The bot deploys with -1 lane creeps")

## bot_purity and bot_hidden_swap over seeded fixture games.
func _test_purity_and_swap() -> void:
	var pure = true
	var swap = true
	var decisions = 0
	for seed_value in [3, 8]:
		var engine = EngineClass.new()
		engine.library = library
		engine.start(seed_value, ["green_assault", "blue_black_control"])
		var agent = RandomNumberGenerator.new()
		agent.seed = seed_value
		var steps = 0
		while engine.state.winner == -1 and steps < 160:
			var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
			if engine.state.phase == "action" and engine.state.players[player].hand.size() < 6:
				engine.state.players[player].hand.append(["fx_stun_spell", "fx_move_any", "fx_lock_spell", "fx_hack_spell", "fx_swap"][steps % 5])
				Zones.sync(engine)
			var digest = engine.state_digest()
			var rng_state = engine.rng.state
			var choice = bot.choose_action(engine, player)
			decisions += 1
			if engine.state_digest() != digest or engine.rng.state != rng_state:
				pure = false
			if steps % 10 == 0:
				var swapped = _swapped(engine, 1 - player)
				if bot.choose_action(swapped, player) != choice:
					swap = false
			var legal = engine.legal_actions(player)
			var command = choice if steps % 2 == 0 else legal[agent.randi_range(0, legal.size() - 1)]
			if not engine.apply_action(player, command).ok:
				break
			steps += 1
	_check(pure and decisions > 100, "bot_purity: choosing never changes the live engine's digest or random state (%d decisions)" % decisions)
	_check(swap, "bot_hidden_swap: the other player's hidden hand, hand state, deck and plans never change the bot's choice")

func _swapped(engine, hidden_owner: int):
	var swapped = EngineClass.new()
	swapped.library = engine.library
	swapped.state = engine.state.duplicate(true)
	swapped.rng.state = engine.rng.state
	swapped.next_id = engine.next_id
	var owner: Dictionary = swapped.state.players[hidden_owner]
	for index in range(owner.hand.size()):
		owner.hand[index] = "fx_counter_spell"
	for entry in owner.get("hand_state", []):
		entry["charges"] = 4
		entry["hacks"] = ["fx_hack_spell#0"]
		entry["iid"] = int(entry.iid) + 5000000
	owner.deck.reverse()
	var states: Array = []
	for card_id in owner.deck:
		states.append({"charges": 3})
	owner["deck_state"] = states
	for key in owner.get("plans", {}).keys():
		owner.plans[key] = (int(owner.plans[key]) + 1) % 3
	return swapped

## bot_budget: a decision on the dense fixture of spec §13.6 (3 lanes of 8
## positions, 16 improvements per side, 6 items, a 10-card hand) built from
## fixture cards with real keywords, auras, triggers and actives.
func _test_budget() -> void:
	var engine = _engine(21)
	var creeps = ["fx_cleave_3", "fx_retaliate_2", "fx_regen_2", "fx_siege_3", "melee_creep", "fx_soulbound_creep"]
	var items = ["broadsword", "fx_regen_armor", "fx_blink_item"]
	var improvements = ["fx_improvement_ping", "fx_tower_guard", "fx_countdown", "fx_library"]
	for side in range(2):
		var roster: Array = engine.state.players[side].roster
		for lane_index in range(3):
			for slot in range(8):
				var unit: Dictionary
				if slot < 2 and lane_index * 2 + slot < roster.size():
					unit = roster[lane_index * 2 + slot]
					Zones.equip(engine, unit, items[(lane_index * 2 + slot) % items.size()])
				else:
					unit = engine._make_unit(engine.library.definition(creeps[(slot + lane_index + side) % creeps.size()]), side, false)
				engine._place(unit, lane_index, slot)
		for count in range(16):
			Zones.add_improvement(engine, improvements[count % improvements.size()], side, count % 3)
	engine.state.players[0].hand = ["fx_stun_spell", "fx_move_any", "fx_swap", "no_accident", "fx_shield_spell", "fx_curse_spell",
		"fx_purge_spell", "fx_bounce_spell", "fx_raze", "fx_lock_spell"]
	Zones.sync(engine)
	engine._roll_arrows()
	Stats.settle(engine)
	var started = Time.get_ticks_usec()
	var runs = 3
	for index in range(runs):
		bot.choose_action(engine, 0)
	var each = (Time.get_ticks_usec() - started) / 1000.0 / runs
	var factor = _machine_factor()
	print("dense fixture: %d legal actions, %.1f ms per decision (%.1f ms normalized, machine factor %.2f)" % [
		engine.legal_actions(0).size(), each, each / factor, factor])
	_check(each / factor < BUDGET_MS, "bot_budget: a decision on the dense fixture takes %.1f ms normalized (< %.0f ms)" % [each / factor, BUDGET_MS])

## This machine's speed against the stored perf baseline: the legacy engine's
## full bot match time over its recorded time (above 1 on a slower machine).
func _machine_factor() -> float:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	if not parsed is Dictionary or not parsed.has("legacy_bot_match"):
		return 1.0
	var started = Time.get_ticks_usec()
	var engine = Legacy.new()
	engine.start(3, ["starter", "starter"])
	var legacy_bot = LegacyBot.new()
	var steps = 0
	while engine.state.winner == -1 and steps < 1500:
		var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
		engine.apply_action(player, legacy_bot.choose_action(engine, player))
		steps += 1
	return maxf(0.25, (Time.get_ticks_usec() - started) / 1000.0 / float(parsed.legacy_bot_match))
