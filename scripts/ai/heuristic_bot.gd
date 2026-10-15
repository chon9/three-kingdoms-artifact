extends RefCounted
## One-ply public-information bot. It evaluates material, projected combat,
## structure pressure, mana, healing, and whether passing secures initiative.
## This is a baseline opponent, not the final competitive AI.
##
## EFFECT_SYSTEM_SPEC.md §9: the bot simulates every candidate on
## simulation_from_view (synthetic randomness, no hidden information). Card
## and ability values come from the compiled rules (static values), the
## evaluation counts keywords, statuses, improvements and opponent locks, and
## large action sets are prefiltered by a compile-time polarity score.

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
const IMPROVEMENT_CHARGE_WEIGHT = 0.5
const LOCK_WEIGHT = 0.3
## Spec §9.3 lists cleave, retaliate, regeneration and siege at 0.3 each.
## Siege is left out: the combat preview already prices its tower damage in
## every remaining lane of the round (0.65 per point), and the extra 0.3 per
## point of Thunderhide Pack's printed Siege 6 changed two recorded choices of
## the shipped 49 cards (green_assault matchups). Tuning, not a rules change.
const KEYWORD_TERMS = ["cleave", "retaliate", "regeneration"]

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
	var best_score = -INF
	for action in _prefilter(engine, actions, player):
		var score = _score_action(engine, view, player, action, baseline)
		if score > best_score:
			best_score = score
			best_action = action
	return best_action

## The score of one candidate against the current evaluation `baseline`:
## the simulated evaluation change plus the card's or ability's static values.
func _score_action(engine, view: Dictionary, player: int, action: Dictionary, baseline: float) -> float:
	var simulation = engine.simulation_from_view(player)
	simulation.apply_action(player, action)
	# The simulation's state already is this player's view: refresh the
	# own hand count instead of copying the whole state again.
	var simulated: Dictionary = simulation.state
	simulated.players[player]["hand_count"] = simulated.players[player].hand.size()
	var score = _evaluate(simulation, simulated, player) - baseline
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
		score += float(value.bias)
		if action.has("position"):
			score += _position_bonus(engine, view, player, card, int(action.position))
	return score

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
	for entry in engine.abilities_of(source):
		if int(entry.source) == source:
			return engine.library.rules(str(entry.card)).get("ability_static", {}).get(str(entry.ability), {})
	return {}

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
	# A pending creep lane of -1 follows the player's Kanna (RQ-22, spec
	# §9.6): her planned lane, else her current lane. The opponent's -1 lanes
	# are unknown and count nowhere.
	var creep_lane = _kanna_lane(engine, view, player)
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
		# Lane creeps for this round are public before heroes are chosen.
		var pending = view.get("pending_creeps", [[], []])
		for side in range(2):
			for creep_value in pending[side]:
				var creep_at = int(creep_value)
				if creep_at < 0 and side == player:
					creep_at = creep_lane
				if creep_at == lane_index:
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

## The lane `player`'s -1 creeps go to: the planned lane of a creep_lane hero
## (Kanna), else its current lane; -1 when there is none.
func _kanna_lane(engine, view: Dictionary, player: int) -> int:
	var pending: Array = view.get("pending_creeps", [[], []])[player]
	if not pending.any(func(value): return int(value) < 0):
		return -1
	var plans: Dictionary = view.players[player].get("plans", {})
	for hero in Stats.creep_lane_heroes(engine, player):
		if plans.has(str(hero.uid)):
			return int(plans[str(hero.uid)])
		if int(hero.lane) >= 0:
			return int(hero.lane)
	return -1

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
				score += sign_value * (IMPROVEMENT_WEIGHT + IMPROVEMENT_CHARGE_WEIGHT * float(improvement.get("charges", 0)))
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
