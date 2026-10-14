extends RefCounted
## One-ply public-information bot. It evaluates material, projected combat,
## structure pressure, mana, healing, and whether passing secures initiative.
## This is a baseline opponent, not the final competitive AI.

func choose_action(engine, player: int) -> Dictionary:
	var actions = engine.legal_actions(player)
	if actions.is_empty():
		return {}
	var view = engine.player_view(player)
	if view.phase == "shop":
		for action in actions:
			if action.type == "buy":
				return action
		return actions.back()
	if view.phase == "deployment":
		var best_lane = _deployment_lane(engine, view, player)
		for action in actions:
			if action.type == "deploy" and action.lane == best_lane:
				return action
		return actions.back()
	var best_action: Dictionary = actions[0]
	var baseline = _evaluate(engine, view, player)
	var best_score = -INF
	for action in actions:
		var simulation = engine.simulation_from_view(player)
		simulation.apply_action(player, action)
		var score = _evaluate(simulation, simulation.player_view(player), player) - baseline
		if action.type == "pass":
			# Evaluate the CURRENT lane before a second pass moves the simulation
			# into the next lane; this keeps the score comparable to card plays.
			score = 0.1 if view.first_pass == -1 else 0.0
		elif action.type == "ability":
			score += 0.9 if view.players[player].deck_count > 0 else -1.0
		else:
			var card = engine.library.cards[view.players[player].hand[int(action.hand)]]
			score -= 0.7 + float(card.cost) * 0.12
			if card.get("effect", "") == "draw":
				# Own deck order is hidden too. Estimate draw value from count,
				# rather than copying live future draws into a search node.
				score += mini(int(card.amount), int(view.players[player].deck_count)) * 0.9
			if card.get("initiative", false):
				score += 0.35
		if score > best_score:
			best_score = score
			best_action = action
	return best_action

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

func _evaluate(engine, view: Dictionary, player: int) -> float:
	if view.winner == player:
		return 100000.0
	if view.winner == 1 - player:
		return -100000.0
	var score = float(view.players[player].hand_count) * 0.9
	for lane_index in range(3):
		var lane = view.lanes[lane_index]
		for side in range(2):
			var sign_value = 1.0 if side == player else -1.0
			var structure = lane.structures[side]
			score += sign_value * (float(structure.health) * 0.06 - (35.0 if structure.ancient else 0.0))
			for unit in lane.units[side]:
				if unit != null:
					score += sign_value * (engine.attack_of(unit) * 0.75 + float(unit.health) * 0.35 + engine.armor_of(unit) * 0.8 + (3.0 if unit.hero else 0.0))
		if lane_index >= view.lane:
			var combat = engine.combat_preview(lane_index)
			score += (float(combat.tower_damage[player]) - float(combat.tower_damage[1 - player])) * 0.65
			for side in range(2):
				for unit in lane.units[side]:
					if unit == null:
						continue
					var damage = int(combat.unit_damage.get(str(unit.uid), 0))
					var sign_value = -1.0 if side == player else 1.0
					score += sign_value * minf(damage, unit.health) * 0.35
					if damage >= unit.health:
						score += sign_value * (5.0 if unit.hero else 2.0)
	return score
