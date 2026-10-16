extends RefCounted
## One-ply public-information bot. It evaluates material, projected combat,
## structure pressure, mana, healing, and whether passing secures initiative.
## This is a baseline opponent, not the final competitive AI.
##
## EFFECT_SYSTEM_SPEC.md §9: the bot simulates every candidate on
## simulation_from_view (synthetic randomness, no hidden information); a
## random candidate is simulated with seeds 1 to 3 and averaged (§9.5). Card
## and ability values come from the compiled rules (static values: draws,
## initiative, locks, hacks, mana restores, gold gains), the evaluation counts
## keywords, statuses, improvements (by their cost and charges) and opponent
## locks, and large action sets are prefiltered by a compile-time polarity
## score.

const Stats = preload("res://scripts/core/rules/stats.gd")
## Above this many candidates the prefilter applies (spec §9.4 names 60).
## Classic games reach 81 candidates (the golden game classic_04), and
## pruning them changed recorded choices of the shipped 49 cards, while the
## bot meets its 250 ms budget at that size; so pruning starts above 100.
const PREFILTER_LIMIT = 100
## Candidates simulated after prefiltering, and combinations kept per hand card.
const PREFILTER_KEEP = 40
const PREFILTER_PER_CARD = 3
## Evaluation weights added in M2 (spec §9.3).
const KEYWORD_WEIGHT = 0.3
const IMMUNITY_WEIGHT = 1.0
const HINDERED_ATTACK = 0.25
const IMPROVEMENT_WEIGHT = 2.0
## Spec §9.3 says the improvement term is tuned with the bot-vs-bot matrix.
## M7 tuned it: an improvement is also worth IMPROVEMENT_COST_WEIGHT per mana
## of its printed cost. A flat 2.0 is worth less than the card in hand plus
## the play penalty from cost 3 up, so the bot never played the dearer Classic
## improvements whose effect the one-ply simulation cannot see (Steam Cannon,
## Glyph of Confusion, Selemene's Favor...). No golden game has an
## improvement, so the goldens are unchanged.
const IMPROVEMENT_COST_WEIGHT = 0.25
const IMPROVEMENT_CHARGE_WEIGHT = 0.5
const LOCK_WEIGHT = 0.3
## Spec §9.3 lists cleave, retaliate, regeneration and siege at 0.3 each.
## Siege is left out: the combat preview already prices its tower damage in
## every remaining lane of the round (0.65 per point), and the extra 0.3 per
## point of Thunderhide Pack's printed Siege 6 changed two recorded choices of
## the shipped 49 cards (green_assault matchups). Tuning, not a rules change.
const KEYWORD_TERMS = ["cleave", "retaliate", "regeneration"]
## Spec §9.5 (from M4): a candidate with random effects (a play whose card,
## or an ability whose ops, use pick or chance) is simulated with these seeds
## and its scores averaged; any other candidate with the first seed only.
const RANDOM_SEEDS = [1, 2, 3]
## To keep the §13.6 decision budget, choose_action averages only the random
## candidates among the RANDOM_REFINE best candidates by first-seed score (the
## contenders); the others keep their first-seed score.
const RANDOM_REFINE = 3
## A hacked opponent card hurts its own player's tower when played (Self
## Sabotage): priced like structure health in the evaluation, per point.
const HACK_TOWER_WEIGHT = 0.06
## Mana a restore makes available for the dearest card in hand, per point
## (the play penalty's rate per mana spent); the evaluation has no mana term.
const MANA_WEIGHT = 0.12
## Gold a play or ability adds to its player's purse (static_value.gold: a
## gold op that adds for "you"), per gold; the evaluation has no gold term
## (M7: Revtel Investments' active; also Ravenhook and Payday). About half
## what the shop's stat items return per gold (a Short Sword's +2 Attack is
## worth 1.5 for 3 gold), since gold is spent only at the next shop.
const GOLD_WEIGHT = 0.25
## Simulations run by this bot (tests and profiling read it; choices never do).
var simulations: int = 0
## Whether the last _simulated_score drew any randomness (an outcome without a
## draw is the same for every seed, so the other seeds are skipped).
var _last_drew: bool = false

func choose_action(engine, player: int) -> Dictionary:
	var actions = engine.legal_actions(player)
	if actions.is_empty():
		return {}
	var view = engine.player_view(player)
	if view.phase == "shop":
		for action in actions:
			if action.type == "buy":
				return action
		for action in actions:
			if action.type == "hold" and _should_hold(engine, view, player):
				return action
		return actions.back()
	if view.phase == "deployment":
		# Only unplanned heroes are deployed; the bot never re-plans or takes a
		# hero back, so a deployment phase always ends.
		var best_lane = _deployment_lane(engine, view, player)
		var plans: Dictionary = view.players[player].plans
		var first: Dictionary = {}
		for action in actions:
			if action.type != "deploy" or plans.has(str(action.unit)):
				continue
			if int(action.lane) == best_lane:
				return action
			if first.is_empty():
				first = action
		if not first.is_empty():
			return first
		for action in actions:
			if action.type == "finish_deployment":
				return action
		return {}
	var best_action: Dictionary = actions[0]
	var baseline = _evaluate(engine, view, player)
	var candidates: Array = _prefilter(engine, actions, player)
	var simulated: Array = []
	var drew: Array = []
	var scores: Array = []
	for action in candidates:
		# Pass scores by the first-pass rule alone (_static_score): no simulation.
		var change = 0.0 if action.type == "pass" else _simulated_score(engine, view, player, action, baseline, int(RANDOM_SEEDS[0]))
		simulated.append(change)
		drew.append(action.type != "pass" and _last_drew)
		scores.append(_static_score(engine, view, player, action, change))
	_refine_random(engine, view, player, candidates, simulated, drew, scores, baseline)
	var best_score = -INF
	for index in range(candidates.size()):
		if scores[index] > best_score:
			best_score = scores[index]
			best_action = candidates[index]
	return best_action

## The score of one candidate against the current evaluation `baseline`:
## the simulated evaluation change (averaged over RANDOM_SEEDS for a random
## candidate) plus the card's or ability's static values.
func _score_action(engine, view: Dictionary, player: int, action: Dictionary, baseline: float) -> float:
	if action.type == "pass":
		return _static_score(engine, view, player, action, 0.0)
	var changes: Array = [_simulated_score(engine, view, player, action, baseline, int(RANDOM_SEEDS[0]))]
	if _is_random(engine, view, player, action) and _last_drew:
		for index in range(1, RANDOM_SEEDS.size()):
			changes.append(_simulated_score(engine, view, player, action, baseline, int(RANDOM_SEEDS[index])))
	return _static_score(engine, view, player, action, _average(changes))

## Spec §9.5 within the decision budget: the random candidates among the
## RANDOM_REFINE best candidates (by first-seed score, then legal order) are
## simulated with the other seeds and averaged. One whose first simulation
## drew no randomness (`drew`; a pick from the hidden, empty opponent hand,
## say) has the same outcome for every seed.
func _refine_random(engine, view: Dictionary, player: int, candidates: Array, simulated: Array, drew: Array, scores: Array, baseline: float) -> void:
	var ranked: Array = range(candidates.size())
	ranked.sort_custom(func(a, b): return scores[a] > scores[b] or (scores[a] == scores[b] and a < b))
	for index in ranked.slice(0, RANDOM_REFINE):
		if not drew[index] or not _is_random(engine, view, player, candidates[index]):
			continue
		var changes: Array = [simulated[index]]
		for seed_index in range(1, RANDOM_SEEDS.size()):
			changes.append(_simulated_score(engine, view, player, candidates[index], baseline, int(RANDOM_SEEDS[seed_index])))
		var average = _average(changes)
		if average != simulated[index]:
			scores[index] = _static_score(engine, view, player, candidates[index], average)

## The mean of simulated changes; equal values keep the exact value (an
## average of equal floats can drift by an ulp and break ties differently).
static func _average(values: Array) -> float:
	var first = float(values[0])
	if values.all(func(value): return float(value) == first):
		return first
	var total = 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())

## A candidate's score from its simulated evaluation change `change`: pass
## scores by the first-pass rule; abilities and plays add their static values.
func _static_score(engine, view: Dictionary, player: int, action: Dictionary, change: float) -> float:
	var score = change
	if action.type == "pass":
		# Evaluate the CURRENT lane before a second pass moves the simulation
		# into the next lane; this keeps the score comparable to card plays.
		score = 0.1 if view.first_pass == -1 else 0.0
	elif action.type == "ability":
		# Static values of the compiled ability (spec §9.2): a draw
		# ability is worth a card while the deck has one.
		var ability_value = _ability_static(engine, int(action.unit))
		if int(ability_value.get("draw", 0)) > 0:
			score += 0.9 if view.players[player].deck_count > 0 else -1.0
		score += _lock_value(view, player, int(ability_value.get("lock", 0)))
	else:
		var card_id = str(view.players[player].hand[int(action.hand)])
		var card = engine.library.cards[card_id]
		var value: Dictionary = engine.library.static_value(card_id)
		score -= 0.7 + float(card.get("cost", 0)) * 0.12
		if int(value.draw) > 0:
			# Own deck order is hidden too. Estimate draw value from count,
			# rather than copying live future draws into a search node.
			score += mini(int(value.draw), int(view.players[player].deck_count)) * 0.9
		if bool(value.initiative):
			score += 0.35
		score += _lock_value(view, player, int(value.get("lock", 0)))
		score += _hack_value(view, player, int(value.get("hack", 0)), int(value.get("hack_damage", 0)))
		score += float(value.bias)
		if action.has("position"):
			score += _position_bonus(engine, view, player, card, int(action.position))
	return score

## One simulation of `action` on the player's view with synthetic randomness
## `seed_value`: the evaluation change, plus the mana it restores when its
## static value says it restores the caster's tower (spec §9).
func _simulated_score(engine, view: Dictionary, player: int, action: Dictionary, baseline: float, seed_value: int) -> float:
	simulations += 1
	var simulation = engine.simulation_from_view(player)
	if seed_value != 1:
		simulation.rng.seed = seed_value
	var rng_before = simulation.rng.state
	simulation.apply_action(player, action)
	_last_drew = simulation.rng.state != rng_before
	# The simulation's state already is this player's view: refresh the
	# own hand count instead of copying the whole state again.
	var simulated: Dictionary = simulation.state
	simulated.players[player]["hand_count"] = simulated.players[player].hand.size()
	var score = _evaluate(simulation, simulated, player) - baseline
	var static_value: Dictionary = _static_of(engine, view, player, action)
	if static_value.get("mana", false):
		score += _mana_value(engine, view, simulated, player, action)
	if static_value.get("gold", false):
		score += GOLD_WEIGHT * float(maxi(0, int(simulated.players[player].gold) - int(view.players[player].gold)))
	return score

## The static values of the card a play uses or of the ability it activates.
func _static_of(engine, view: Dictionary, player: int, action: Dictionary) -> Dictionary:
	match str(action.get("type", "")):
		"play":
			return engine.library.static_value(str(view.players[player].hand[int(action.hand)]))
		"ability":
			return _ability_static(engine, int(action.unit))
	return {}

## Spec §9.5: plays of random cards (static_value.random) and abilities with
## random ops are averaged over RANDOM_SEEDS.
func _is_random(engine, view: Dictionary, player: int, action: Dictionary) -> bool:
	return bool(_static_of(engine, view, player, action).get("random", false))

## Restored mana (from the simulated tower of the active lane) that the
## dearest playable card in hand still needs, at MANA_WEIGHT per point.
func _mana_value(engine, view: Dictionary, simulated: Dictionary, player: int, action: Dictionary) -> float:
	var lane = int(view.lane)
	var paid = 0
	var skip = -1
	if str(action.type) == "play":
		skip = int(action.hand)
		paid = int(engine.library.get_card(str(view.players[player].hand[skip])).get("cost", 0))
	var left = int(view.lanes[lane].mana[player]) - paid
	var gained = int(simulated.lanes[lane].mana[player]) - left
	var dearest = 0
	var hand: Array = view.players[player].hand
	var states: Array = view.players[player].get("hand_state", [])
	for index in range(hand.size()):
		if index == skip or (index < states.size() and states[index] is Dictionary and int(states[index].get("lock", 0)) > 0):
			continue
		dearest = maxi(dearest, int(engine.library.get_card(str(hand[index])).get("cost", 0)))
	return MANA_WEIGHT * float(clampi(gained, 0, maxi(0, dearest - left)))

## Spec §9.4: with more than PREFILTER_LIMIT candidates, keep pass and every
## ability, and the best PREFILTER_PER_CARD combinations of each hand card by
## their polarity score (harm on enemies and help on allies, weighted by the
## target's attack plus health); then at most PREFILTER_KEEP candidates, in
## legal_actions order so ties still break the same way.
func _prefilter(engine, actions: Array, player: int) -> Array:
	if actions.size() <= PREFILTER_LIMIT:
		return actions
	var kept: Array = []
	var cards: Dictionary = {}
	engine.frame_begin()
	for index in range(actions.size()):
		var action: Dictionary = actions[index]
		if str(action.type) != "play":
			kept.append(index)
			continue
		var hand = int(action.hand)
		if not cards.has(hand):
			cards[hand] = []
		cards[hand].append([_polarity_score(engine, player, action), index])
	engine.frame_end()
	var ranked: Array = []
	var hands: Array = cards.keys()
	hands.sort()
	for hand in hands:
		var entries: Array = cards[hand]
		entries.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
		ranked.append_array(entries.slice(0, PREFILTER_PER_CARD))
	ranked.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for entry in ranked.slice(0, maxi(0, PREFILTER_KEEP - kept.size())):
		kept.append(entry[1])
	kept.sort()
	return kept.map(func(index): return actions[index])

## The polarity score of a play: +1 per harmed enemy and helped ally, -1 per
## helped enemy and harmed ally, each weighted by attack plus health.
func _polarity_score(engine, player: int, action: Dictionary) -> float:
	var card_id = str(engine.state.players[player].hand[int(action.hand)])
	var polarity: Dictionary = engine.library.static_value(card_id).get("polarity", {})
	var score = 0.0
	for key in polarity:
		if not action.has(key) or int(polarity[key]) == 0:
			continue
		var unit = engine.find_unit(int(action[key]))
		if unit.is_empty():
			continue
		var side = 1.0 if int(unit.owner) != player else -1.0
		score += float(polarity[key]) * side * float(engine.attack_of(unit) + int(unit.health))
	return score

## The static values of a source's active ability ({} when it has none).
func _ability_static(engine, source: int) -> Dictionary:
	# The source's own active, read from its compiled rules (abilities_of
	# would also build every legal ability action and choice step).
	var found: Dictionary = engine.find_object(source)
	if found.is_empty():
		return {}
	var rules: Dictionary = engine.library.rules(str(found.card))
	if int(rules.get("active", -1)) < 0:
		return {}
	var ability: Dictionary = rules.abilities[int(rules.active)]
	return rules.get("ability_static", {}).get(str(ability.id), {})

## Spec §9.3 lock term for a play that locks `locks` random opponent hand
## cards: LOCK_WEIGHT per card it can still hold back. Which cards it hits is
## hidden (the simulation has no opponent hand), so the count comes from the
## compiled static value and the public locks on the opponent's card backs.
func _lock_value(view: Dictionary, player: int, locks: int) -> float:
	if locks <= 0:
		return 0.0
	var unlocked = 0
	for entry in view.players[1 - player].get("hand_public", []):
		if int(entry.get("lock", 0)) <= 0:
			unlocked += 1
	return LOCK_WEIGHT * float(mini(locks, unlocked))

## A play that hacks `hacks` random opponent hand cards, each dealing `damage`
## to its own player's tower when played (Self Sabotage): which cards is
## hidden, so it counts up to the opponent's public hand size.
func _hack_value(view: Dictionary, player: int, hacks: int, damage: int) -> float:
	if hacks <= 0 or damage <= 0:
		return 0.0
	return HACK_TOWER_WEIGHT * float(damage) * float(mini(hacks, int(view.players[1 - player].get("hand_count", 0))))

# Holding is rare: only when the Secret Shop item is just out of reach and
# nothing else was affordable this phase. Prices follow the rules layer (a
# Deed can make them negative, spec §9.7).
func _should_hold(engine, view: Dictionary, player: int) -> bool:
	var secret = str(view.players[player].shop.get("secret", ""))
	if secret.is_empty():
		return false
	var price = int(engine.price_of(player, "secret", secret))
	var gold = int(view.players[player].gold)
	return price > gold and price <= gold + 3

# Creep placement tie-breaker on top of the simulated evaluation: block the
# strongest enemy attacker, or take an open position to push tower damage.
func _position_bonus(engine, view: Dictionary, player: int, card: Dictionary, position: int) -> float:
	var enemies = view.lanes[view.lane].units[1 - player]
	if position >= 0 and position < enemies.size() and enemies[position] != null:
		return engine.attack_of(enemies[position]) * 0.12
	return 0.2 + float(card.get("attack", 0)) * 0.04

func _deployment_lane(engine, view: Dictionary, player: int) -> int:
	var best_lane = 0
	var best_score = -INF
	for lane_index in range(3):
		var lane = view.lanes[lane_index]
		var ally_strength = 0.0
		var enemy_strength = 0.0
		for unit in lane.units[player]:
			if unit != null:
				ally_strength += engine.attack_of(unit) + float(unit.health) * 0.25
		for planned_lane in view.players[player].plans.values():
			if planned_lane == lane_index:
				ally_strength += 10.0
		# Lane creeps for this round are public before heroes are chosen
		# (Kanna's already name her lane, RQ-22).
		var pending = view.get("pending_creeps", [[], []])
		for side in range(2):
			for creep_value in pending[side]:
				if int(creep_value) == lane_index:
					if side == player:
						ally_strength += 2.0
					else:
						enemy_strength += 2.0
		for unit in lane.units[1 - player]:
			if unit != null:
				enemy_strength += engine.attack_of(unit) + float(unit.health) * 0.25
		var score = enemy_strength - ally_strength
		if lane.structures[player].health < 20:
			score += 4.0
		if score > best_score:
			best_score = score
			best_lane = lane_index
	return best_lane

## The evaluation only reads the engine, so it runs in one read frame
## (derived stats are cached for its duration).
func _evaluate(engine, view: Dictionary, player: int) -> float:
	engine.frame_begin()
	var score = _evaluate_view(engine, view, player)
	engine.frame_end()
	return score

func _evaluate_view(engine, view: Dictionary, player: int) -> float:
	if view.winner == player:
		return 100000.0
	if view.winner == 1 - player:
		return -100000.0
	var score = float(view.players[player].hand_count) * 0.9
	# Each opponent card held back by a lock (public on its back). A
	# simulation cannot lock hidden cards, so new locks are scored per
	# candidate by _lock_value; this term is the standing count.
	for entry in view.players[1 - player].get("hand_public", []):
		if int(entry.get("lock", 0)) > 0:
			score += LOCK_WEIGHT
	for lane_index in range(3):
		var lane = view.lanes[lane_index]
		for side in range(2):
			var sign_value = 1.0 if side == player else -1.0
			var structure = lane.structures[side]
			score += sign_value * (float(structure.health) * 0.06 - (35.0 if structure.ancient else 0.0))
			for unit in lane.units[side]:
				if unit != null:
					score += sign_value * _unit_value(engine, unit)
			for improvement in lane.get("improvements", [[], []])[side]:
				var cost = int(engine.library.get_card(str(improvement.card)).get("cost", 0))
				score += sign_value * (IMPROVEMENT_WEIGHT + IMPROVEMENT_COST_WEIGHT * float(cost)
					+ IMPROVEMENT_CHARGE_WEIGHT * float(improvement.get("charges", 0)))
		if lane_index >= view.lane:
			var combat = engine.combat_preview(lane_index)
			var dies: Array = combat.get("dies", [])
			var heal: Dictionary = combat.get("heal", {})
			score += (float(combat.tower_damage[player]) - float(combat.tower_damage[1 - player])) * 0.65
			for side in range(2):
				for unit in lane.units[side]:
					if unit == null:
						continue
					var key = str(unit.uid)
					var loss = int(combat.unit_damage.get(key, 0)) - int(heal.get(key, 0))
					var sign_value = -1.0 if side == player else 1.0
					score += sign_value * minf(maxi(0, loss), unit.health) * 0.35
					if dies.has(int(unit.uid)):
						score += sign_value * (5.0 if unit.hero else 2.0)
	return score

## Material value of a unit on the board (spec §9.3): attack (a quarter of it
## while stunned or disarmed), health, armor, heroes, combat keywords and
## Damage Immunity.
func _unit_value(engine, unit: Dictionary) -> float:
	# One derivation (cached by the evaluation's read frame) serves every term.
	var derived: Dictionary = Stats.derive(engine, unit)
	var keywords: Dictionary = derived.kw
	var attack_term = int(derived.attack) * 0.75
	if Stats.flag(engine, unit, "disarm"):
		attack_term *= HINDERED_ATTACK
	var value = attack_term + float(unit.health) * 0.35 + int(derived.armor) * 0.8 + (3.0 if unit.hero else 0.0)
	var total = 0
	for keyword in KEYWORD_TERMS:
		total += int(keywords.get(keyword, 0))
	if total != 0:
		value += KEYWORD_WEIGHT * float(total)
	if int(keywords.get("damage_immunity", 0)) > 0:
		value += IMMUNITY_WEIGHT
	return value
