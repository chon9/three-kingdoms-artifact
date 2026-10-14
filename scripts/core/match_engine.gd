extends RefCounted
## Authoritative, UI-independent match state. Every mutation goes through a
## validated command; RNG and command journals make a match reproducible.

const Library = preload("res://scripts/core/card_library.gd")
const PROTOCOL_VERSION = 3
var library = Library.new()
var rng = RandomNumberGenerator.new()
var state: Dictionary = {}
var journal: Array = []
var match_seed: int = 1
var next_id: int = 1
var deck_ids: Array = ["starter", "starter"]

func start(seed_value: int = 1, selected_decks: Array = ["starter", "starter"]) -> Dictionary:
	if not library.presets().is_empty():
		if selected_decks.size() != 2:
			return {"ok": false, "error": "Choose one deck for each player."}
		for preset_id in selected_decks:
			var entry = library.preset(str(preset_id))
			var validation = library.validate_preset(entry)
			if not validation.ok:
				return validation
	deck_ids = selected_decks.duplicate()
	match_seed = seed_value
	rng.seed = seed_value
	journal.clear()
	next_id = 1
	state = {"round": 1, "lane": 0, "phase": "action", "active_player": 0,
		"initiative": 0, "first_pass": -1, "winner": -1, "revision": 0,
		"players": [], "lanes": [], "events": []}
	for player in range(2):
		var deck = library.match_deck(str(deck_ids[player]))
		_shuffle(deck)
		var roster: Array = []
		var hero_list = library.match_heroes(str(deck_ids[player]))
		for index in range(hero_list.size()):
			var hero = _make_unit(hero_list[index], player, true)
			hero["ready_round"] = 1 if index < 3 else index - 1
			roster.append(hero)
		var item_deck = library.item_deck(str(deck_ids[player])) if not library.presets().is_empty() else []
		_shuffle(item_deck)
		state.players.append({"hand": [], "deck": deck, "gold": 0,
			"roster": roster, "plans": {}, "finished": false, "bought": [],
			"item_deck": item_deck, "shop": {}, "preset": str(deck_ids[player]),
			"deck_name": library.preset(str(deck_ids[player])).get("name", "Training")})
	for lane in range(3):
		state.lanes.append({"units": [[], []], "mana": [3, 3],
			"max_mana": [3, 3], "mana_bonus": [0, 0], "structures": [
				{"health": 40, "ancient": false, "destroyed": false},
				{"health": 40, "ancient": false, "destroyed": false}]})
	for player in range(2):
		var lane_order: Array = [0, 1, 2]
		_shuffle(lane_order)
		for index in range(3):
			_spawn(state.players[player].roster[index], lane_order[index])
		for lane in range(3):
			_spawn_creep(player, lane)
		_draw(player, 5)
	state.initiative = rng.randi_range(0, 1)
	state.active_player = state.initiative
	_roll_arrows()
	_event("Round 1. Left lane opens. Destroy two towers or one ancient to win.")
	return {"ok": true}

func legal_actions(player: int) -> Array:
	var actions: Array = []
	if player < 0 or player > 1 or state.is_empty() or state.winner != -1:
		return actions
	var owner = state.players[player]
	if state.phase == "shop":
		if owner.finished:
			return actions
		if library.presets().is_empty():
			for card_id in library.shop_cards():
				if card_id not in owner.bought and owner.gold >= library.cards[card_id].price:
					actions.append({"type": "buy", "card": card_id})
		else:
			for source in owner.shop:
				var card_id = owner.shop[source]
				if not str(card_id).is_empty() and owner.gold >= library.cards[card_id].price:
					actions.append({"type": "buy", "card": card_id, "source": source})
		actions.append({"type": "finish_shop"})
		return actions
	if state.phase == "deployment":
		if owner.finished:
			return actions
		var unplanned = false
		for hero in owner.roster:
			if hero.lane == -1 and hero.ready_round <= state.round and not owner.plans.has(str(hero.uid)):
				unplanned = true
				for lane in range(3):
					actions.append({"type": "deploy", "unit": hero.uid, "lane": lane})
		if not unplanned:
			actions.append({"type": "finish_deployment"})
		return actions
	if state.phase != "action" or state.active_player != player:
		return actions
	actions.append({"type": "pass"})
	var lane = state.lanes[state.lane]
	var colors: Array = []
	for unit in lane.units[player]:
		if unit != null and unit.hero and not unit.get("silenced", false):
			colors.append(unit.color)
			if unit.get("ability", "") == "draw" and int(unit.get("cooldown", 0)) == 0:
				actions.append({"type": "ability", "unit": unit.uid})
	for index in range(owner.hand.size()):
		var card = library.get_card(owner.hand[index])
		if card.is_empty() or card.cost > lane.mana[player]:
			continue
		if card.color != "item" and card.color not in colors:
			continue
		var target_kind = card.get("target", "none")
		if target_kind == "none":
			actions.append({"type": "play", "hand": index})
		else:
			var sides = [0, 1] if target_kind in ["unit", "hero", "red_hero", "creep"] else [1 - player if target_kind in ["enemy", "enemy_hero"] else player]
			for target_player in sides:
				var target_lanes = range(3) if card.get("cross_lane", false) else [state.lane]
				for target_lane in target_lanes:
					for unit in state.lanes[target_lane].units[target_player]:
						_add_target_actions(actions, card, target_kind, unit, index)
	return actions

func _add_target_actions(actions: Array, card: Dictionary, target_kind: String, unit, index: int) -> void:
	if unit == null:
		return
	if target_kind in ["ally_hero", "enemy_hero", "hero", "red_hero", "ally_red_hero"] and not unit.hero:
		return
	if target_kind == "creep" and unit.hero:
		return
	if target_kind in ["red_hero", "ally_red_hero"] and unit.color != "red":
		return
	if card.get("effect", "") == "redirect":
		for destination in combat_targets(unit):
			actions.append({"type": "play", "hand": index, "target": unit.uid, "destination": destination})
	else:
		actions.append({"type": "play", "hand": index, "target": unit.uid})

func apply_action(player: int, command: Dictionary) -> Dictionary:
	# Matching the entire shape rejects unknown fields, forged targets, cross-lane
	# actions, out-of-turn plays, negative indexes and unaffordable purchases.
	# JSON decodes numbers as floats. Canonicalize exact integer command fields
	# before dictionary comparison, without accepting strings or fractions.
	command = command.duplicate(true)
	for field in ["hand", "target", "unit", "lane", "destination"]:
		if command.has(field):
			var value = command[field]
			if not (value is int or value is float) or float(value) != floor(float(value)):
				return {"ok": false, "error": "Command indexes must be whole numbers."}
			command[field] = int(value)
	if command not in legal_actions(player):
		return {"ok": false, "error": "That action is not legal in the current state."}
	journal.append({"player": player, "command": command.duplicate(true)})
	match command.type:
		"pass":
			_pass(player)
		"play":
			_play(player, command)
		"ability":
			var unit = find_unit(int(command.unit))
			_draw(player, 1)
			unit.cooldown = int(unit.ability_cooldown)
			_event("%s uses %s: draw a card." % [unit.name, unit.ability_name])
			_finish_action(player, false)
		"buy":
			var card = library.cards[command.card]
			state.players[player].gold -= int(card.price)
			state.players[player].hand.append(command.card)
			state.players[player].bought.append(command.card)
			if command.has("source"):
				if command.source == "item":
					state.players[player].item_deck.pop_back()
					state.players[player].shop.item = state.players[player].item_deck.back() if not state.players[player].item_deck.is_empty() else ""
				else:
					state.players[player].shop[command.source] = ""
			_event("%s spends %d gold in the shop." % [_player_name(player), card.price])
		"finish_shop":
			state.players[player].finished = true
			if state.players[0].finished and state.players[1].finished:
				_begin_deployment()
		"deploy":
			state.players[player].plans[str(command.unit)] = int(command.lane)
		"finish_deployment":
			state.players[player].finished = true
			if state.players[0].finished and state.players[1].finished:
				_reveal_deployment()
	state.revision += 1
	return {"ok": true}

func _pass(player: int) -> void:
	_event("%s passes." % _player_name(player))
	if state.first_pass == -1:
		state.first_pass = player
		state.active_player = 1 - player
	else:
		state.initiative = state.first_pass
		state.first_pass = -1
		_resolve_combat()
		if state.winner != -1:
			return
		if state.lane < 2:
			state.lane += 1
			state.active_player = state.initiative
			_event("Lane %d opens. %s has initiative." % [state.lane + 1, _player_name(state.initiative)])
		else:
			state.phase = "shop"
			for owner in state.players:
				owner.finished = false
				owner.bought.clear()
			_prepare_shop()
			_event("Shopping. Spend kill gold on equipment, or keep it for later.")

func _prepare_shop() -> void:
	if library.presets().is_empty():
		return
	for owner in state.players:
		var pool = library.catalog.secret_shop
		var consumables = library.catalog.consumables
		owner.shop = {"secret": pool[rng.randi_range(0, pool.size() - 1)],
			"item": owner.item_deck.back() if not owner.item_deck.is_empty() else "",
			"consumable": consumables[rng.randi_range(0, consumables.size() - 1)]}

func _play(player: int, command: Dictionary) -> void:
	var owner = state.players[player]
	var card_id = owner.hand[int(command.hand)]
	var card = library.cards[card_id]
	owner.hand.remove_at(int(command.hand))
	state.lanes[state.lane].mana[player] -= int(card.cost)
	var target = find_unit(int(command.get("target", -1)))
	_event("%s plays %s." % [_player_name(player), card.name])
	if card.kind == "creep":
		_spawn(_make_unit(card, player, false), state.lane)
		_roll_lane_arrows(state.lane)
	else:
		match card.effect:
			"damage":
				_damage_unit(target, int(card.amount), card.get("piercing", false))
			"area_damage":
				for unit in state.lanes[state.lane].units[1 - player]:
					if unit != null:
						_damage_unit(unit, int(card.amount))
				if card.get("include_tower", false):
					_damage_structure(state.lane, 1 - player, int(card.amount))
			"heal":
				target.health = mini(_max_health(target), target.health + int(card.amount))
			"buff":
				target.temp_attack += int(card.get("attack", 0))
				target.temp_armor += int(card.get("armor", 0))
			"modify":
				target.attack += int(card.get("attack", 0))
				target.armor += int(card.get("armor", 0))
			"modify_creeps":
				for unit in state.lanes[state.lane].units[player]:
					if unit != null and not unit.hero:
						unit.attack += int(card.get("attack", 0))
						unit.armor += int(card.get("armor", 0))
			"silence":
				target.silenced = true
				if card.get("neighbors", false):
					var row = state.lanes[target.lane].units[target.owner]
					var position = row.find(target)
					for slot in [position - 1, position + 1]:
						if slot >= 0 and slot < row.size() and row[slot] != null:
							row[slot].silenced = true
			"condemn":
				if card.get("discard_random", false) and not owner.hand.is_empty():
					owner.hand.remove_at(rng.randi_range(0, owner.hand.size() - 1))
				target.health = 0
			"condemn_lane":
				for row in state.lanes[state.lane].units:
					for unit in row:
						if unit != null:
							unit.health = 0
			"global_hero_damage":
				for lane in state.lanes:
					for unit in lane.units[1 - player]:
						if unit != null and unit.hero:
							_damage_unit(unit, int(card.amount), card.get("piercing", false))
			"siege_buff":
				for unit in state.lanes[state.lane].units[player]:
					if unit != null:
						unit.temp_siege += int(card.siege)
						unit.arrow = 0
						unit.combat_target = -1
			"return_hero":
				var row = state.lanes[target.lane].units[target.owner]
				row[row.find(target)] = null
				_enter_fountain(target, state.round + 1)
			"battle_neighbors":
				_battle_neighbors(target)
			"redirect":
				target.combat_target = int(command.destination)
				var destination = find_unit(int(command.destination))
				if not destination.is_empty():
					var row = state.lanes[state.lane].units[1 - target.owner]
					target.arrow = row.find(destination) - state.lanes[state.lane].units[target.owner].find(target)
			"summon":
				for copy in range(int(card.amount)):
					_spawn_creep(player, state.lane)
				_roll_lane_arrows(state.lane)
			"mana":
				state.lanes[state.lane].mana[player] += int(card.amount)
				state.lanes[state.lane].max_mana[player] += int(card.amount)
				state.lanes[state.lane].mana_bonus[player] += int(card.amount)
			"draw":
				_draw(player, int(card.amount))
			"tower_damage":
				_damage_structure(state.lane, 1 - player, int(card.amount))
			"equip":
				var old_max = _max_health(target)
				target.items[card.slot] = card_id
				target.health = mini(_max_health(target), target.health + _max_health(target) - old_max)
	# Deaths resolve before post-spell triggers; condemned Zeus cannot trigger.
	for lane_index in range(3):
		_clean_dead(lane_index)
	if card.kind == "spell" and card.color == "blue":
		_static_field(player)
	_check_winner()
	_finish_action(player, card.get("initiative", false))

func _finish_action(player: int, keep_initiative: bool) -> void:
	state.first_pass = -1
	state.initiative = player if keep_initiative else 1 - player
	state.active_player = state.initiative

func _resolve_combat() -> void:
	var forecast = combat_preview(state.lane)
	_event("Lane %d combat: player 1 deals %d structure damage; player 2 deals %d." % [
		state.lane + 1, forecast.tower_damage[0], forecast.tower_damage[1]])
	# Capture all attacks before any casualties. Dead attackers still deal the
	# damage they committed in this simultaneous combat.
	for uid_string in forecast.unit_damage:
		var unit = find_unit(int(uid_string))
		if not unit.is_empty():
			unit.health -= int(forecast.unit_damage[uid_string])
	for player in range(2):
		_damage_structure(state.lane, 1 - player, int(forecast.tower_damage[player]))
	_clean_dead(state.lane)
	# Surviving wolves grow in the lane whose combat just finished.
	for row in state.lanes[state.lane].units:
		for unit in row:
			if unit != null:
				unit.attack += int(unit.get("combat_growth_attack", 0))
				var growth = int(unit.get("combat_growth_health", 0))
				unit.max_health += growth
				unit.health += growth
	_check_winner()

func combat_preview(lane_index: int) -> Dictionary:
	var result = {"unit_damage": {}, "tower_damage": [0, 0]}
	var lane = state.lanes[lane_index]
	for player in range(2):
		for slot in range(lane.units[player].size()):
			var attacker = lane.units[player][slot]
			if attacker == null:
				continue
			var target = _combat_target(attacker, lane_index, slot)
			if target.is_empty():
				result.tower_damage[player] += battle_attack(attacker, {})
			else:
				var key = str(target.uid)
				result.unit_damage[key] = int(result.unit_damage.get(key, 0)) + maxi(0, battle_attack(attacker, target) - armor_of(target))
				result.tower_damage[player] += int(attacker.get("siege", 0)) + int(attacker.get("temp_siege", 0))
	return result

func _combat_target(unit: Dictionary, lane_index: int, slot: int) -> Dictionary:
	var forced = int(unit.get("combat_target", -1))
	if forced == 0:
		return {}
	if forced > 0:
		var selected = find_unit(forced)
		if not selected.is_empty() and selected.lane == lane_index and selected.owner != unit.owner:
			return selected
	var enemy_row = state.lanes[lane_index].units[1 - unit.owner]
	var target_slot = slot + int(unit.arrow)
	if target_slot >= 0 and target_slot < enemy_row.size() and enemy_row[target_slot] != null:
		return enemy_row[target_slot]
	return {}

func combat_targets(unit: Dictionary) -> Array:
	var result: Array = [0] # Tower.
	for other in state.lanes[unit.lane].units[1 - unit.owner]:
		if other != null:
			result.append(other.uid)
	return result

func battle_attack(attacker: Dictionary, target: Dictionary) -> int:
	var bonus = int(attacker.get("hero_tower_bonus", 0)) if target.is_empty() or target.hero else 0
	if not target.is_empty() and target.hero:
		bonus += int(attacker.get("hero_bonus", 0))
	return attack_of(attacker) + bonus

func _battle_neighbors(hero: Dictionary) -> void:
	var lane = state.lanes[hero.lane]
	var position = lane.units[hero.owner].find(hero)
	var opponents = lane.units[1 - hero.owner]
	var incoming = 0
	var outgoing: Dictionary = {}
	# All enemy neighbors battle the chosen hero simultaneously using the
	# pre-battle board, including continuous armor auras.
	for slot in range(maxi(0, position - 1), mini(opponents.size(), position + 2)):
		var enemy = opponents[slot]
		if enemy != null:
			incoming += maxi(0, battle_attack(enemy, hero) - armor_of(hero))
			outgoing[str(enemy.uid)] = maxi(0, battle_attack(hero, enemy) - armor_of(enemy))
	hero.health -= incoming
	for uid in outgoing:
		find_unit(int(uid)).health -= int(outgoing[uid])

func _damage_unit(unit: Dictionary, amount: int, piercing: bool = false) -> void:
	unit.health -= maxi(0, amount if piercing else amount - armor_of(unit))

func _static_field(player: int) -> void:
	var damage: Dictionary = {}
	var lane = state.lanes[state.lane]
	for slot in range(lane.units[player].size()):
		var zeus = lane.units[player][slot]
		if zeus == null or zeus.health <= 0 or int(zeus.get("static_field", 0)) == 0:
			continue
		var enemies = lane.units[1 - player]
		for neighbor in range(maxi(0, slot - 1), mini(enemies.size(), slot + 2)):
			if enemies[neighbor] != null:
				var key = str(enemies[neighbor].uid)
				damage[key] = int(damage.get(key, 0)) + int(zeus.static_field)
	for key in damage:
		_damage_unit(find_unit(int(key)), int(damage[key]), true)
	_clean_dead(state.lane)

func _damage_structure(lane_index: int, defender: int, amount: int) -> void:
	var structure = state.lanes[lane_index].structures[defender]
	if structure.destroyed:
		return
	structure.health -= amount
	if structure.health <= 0:
		if structure.ancient:
			structure.destroyed = true
			structure.health = 0
			_event("%s's ancient falls." % _player_name(defender))
		else:
			structure.ancient = true
			structure.health = 80
			_event("%s's tower falls. An 80-health ancient is exposed." % _player_name(defender))

func _clean_dead(lane_index: int, _cause_player: int = -1) -> void:
	var lane = state.lanes[lane_index]
	for player in range(2):
		for slot in range(lane.units[player].size()):
			var unit = lane.units[player][slot]
			if unit == null or unit.health > 0:
				continue
			# Classic bounty belongs to the opponent whenever a unit dies,
			# including friendly spells and symmetric board clears.
			var bounty = 5 if unit.hero else 1
			state.players[1 - player].gold += bounty
			if unit.hero:
				_enter_fountain(unit, state.round + (1 if unit.get("rapid_deployment", false) else 2))
			else:
				unit.lane = -1
			_event("%s falls. %s earns %d gold." % [unit.name, _player_name(1 - player), bounty])
			lane.units[player][slot] = null

func _enter_fountain(hero: Dictionary, ready_round: int) -> void:
	hero.lane = -1
	hero.ready_round = ready_round
	hero.temp_attack = 0
	hero.temp_armor = 0
	hero.temp_siege = 0
	hero.silenced = false
	hero.combat_target = -1
	hero.health = _max_health(hero)

func _check_winner() -> void:
	var winners: Array = []
	for player in range(2):
		var fallen_towers = 0
		var fallen_ancient = false
		for lane in state.lanes:
			var structure = lane.structures[1 - player]
			fallen_towers += int(structure.ancient)
			fallen_ancient = fallen_ancient or structure.destroyed
		if fallen_towers >= 2 or fallen_ancient:
			winners.append(player)
	if not winners.is_empty():
		state.winner = 2 if winners.size() == 2 else winners[0]
		state.phase = "finished"
		_event("Draw." if state.winner == 2 else "%s wins." % _player_name(state.winner))

func _begin_deployment() -> void:
	state.round += 1
	state.lane = 0
	state.phase = "deployment"
	for owner in state.players:
		owner.finished = false
		owner.plans.clear()
		for hero in owner.roster:
			hero.temp_attack = 0
			hero.temp_armor = 0
			hero.temp_siege = 0
			hero.silenced = false
			hero.cooldown = maxi(0, int(hero.get("cooldown", 0)) - 1)
	for lane in state.lanes:
		for player in range(2):
			lane.max_mana[player] -= int(lane.get("mana_bonus", [0, 0])[player])
			lane.mana_bonus[player] = 0
			lane.max_mana[player] += 1
			lane.mana[player] = lane.max_mana[player]
			for unit in lane.units[player]:
				if unit != null:
					unit.temp_attack = 0
					unit.temp_armor = 0
					unit.temp_siege = 0
					unit.silenced = false
					unit.combat_target = -1
	_event("Round %d. Choose lanes for available heroes; choices reveal together." % state.round)

func _reveal_deployment() -> void:
	for player in range(2):
		var owner = state.players[player]
		for hero in owner.roster:
			if owner.plans.has(str(hero.uid)):
				hero.health = _max_health(hero)
				_spawn(hero, owner.plans[str(hero.uid)])
		owner.plans.clear()
		owner.finished = false
		for creep in range(2):
			_spawn_creep(player, rng.randi_range(0, 2))
		_draw(player, 2)
	_roll_arrows()
	state.phase = "action"
	state.active_player = state.initiative
	state.first_pass = -1
	_event("Deployment revealed. Lane 1 opens.")

func _make_unit(definition: Dictionary, player: int, is_hero: bool) -> Dictionary:
	var result = {"uid": next_id, "card": definition.id, "name": definition.name,
		"owner": player, "hero": is_hero, "color": definition.get("color", "neutral"),
		"attack": int(definition.attack), "armor": int(definition.get("armor", 0)),
		"max_health": int(definition.health), "health": int(definition.health),
		"temp_attack": 0, "temp_armor": 0, "items": {}, "lane": -1,
		"ready_round": 1, "arrow": 0, "combat_target": -1,
		"neighbor_armor": int(definition.get("neighbor_armor", 0)),
		"neighbor_attack": int(definition.get("neighbor_attack", 0)),
		"global_attack": int(definition.get("global_attack", 0)),
		"hero_bonus": int(definition.get("hero_bonus", 0)),
		"static_field": int(definition.get("static_field", 0)),
		"rapid_deployment": definition.get("rapid_deployment", false),
		"combat_growth_attack": int(definition.get("combat_growth_attack", 0)),
		"combat_growth_health": int(definition.get("combat_growth_health", 0)),
		"siege": int(definition.get("siege", 0)), "temp_siege": 0, "silenced": false,
		"hero_tower_bonus": int(definition.get("hero_tower_bonus", 0)),
		"ability": definition.get("ability", ""), "ability_name": definition.get("ability_name", ""),
		"ability_cooldown": int(definition.get("ability_cooldown", 0)), "cooldown": 0}
	next_id += 1
	return result

func _spawn(unit: Dictionary, lane_index: int) -> void:
	unit.lane = lane_index
	var row = state.lanes[lane_index].units[unit.owner]
	var open_slots: Array = []
	for slot in range(row.size()):
		if row[slot] == null:
			open_slots.append(slot)
	# Prototype placement is reproducible but is not yet Classic's full
	# board insertion algorithm. See docs/RULES.md.
	open_slots.append(row.size())
	var position = open_slots[rng.randi_range(0, open_slots.size() - 1)]
	if position == row.size():
		row.append(unit)
	else:
		row[position] = unit

func _spawn_creep(player: int, lane_index: int) -> void:
	var definition = library.definition("melee_creep")
	if definition.is_empty():
		definition = {"id": "melee_creep", "name": "Melee Creep", "attack": 2, "health": 4, "color": "neutral"}
	_spawn(_make_unit(definition, player, false), lane_index)

func _roll_arrows() -> void:
	for lane_index in range(3):
		_roll_lane_arrows(lane_index)

func _roll_lane_arrows(lane_index: int) -> void:
	var lane = state.lanes[lane_index]
	for player in range(2):
		var enemies = lane.units[1 - player]
		for slot in range(lane.units[player].size()):
			var unit = lane.units[player][slot]
			if unit == null:
				continue
			if int(unit.get("combat_target", -1)) >= 0:
				continue
			unit.arrow = 0
			if slot < enemies.size() and enemies[slot] != null:
				continue
			var roll = rng.randi_range(0, 3)
			var offset = -1 if roll == 0 else (1 if roll == 3 else 0)
			if slot + offset >= 0 and slot + offset < enemies.size() and enemies[slot + offset] != null:
				unit.arrow = offset

func _draw(player: int, count: int) -> void:
	var owner = state.players[player]
	for index in range(count):
		if not owner.deck.is_empty():
			owner.hand.append(owner.deck.pop_back())

func _shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other = rng.randi_range(0, index)
		var original = values[index]
		values[index] = values[other]
		values[other] = original

func find_unit(uid: int) -> Dictionary:
	for lane in state.lanes:
		for row in lane.units:
			for unit in row:
				if unit != null and unit.uid == uid:
					return unit
	return {}

func attack_of(unit: Dictionary) -> int:
	var total = int(unit.attack) + int(unit.temp_attack) + _item_stat(unit, "attack")
	if unit.lane >= 0:
		var row = state.lanes[unit.lane].units[unit.owner]
		var position = row.find(unit)
		for neighbor_slot in [position - 1, position + 1]:
			if position >= 0 and neighbor_slot >= 0 and neighbor_slot < row.size():
				var neighbor = row[neighbor_slot]
				if neighbor != null and neighbor.health > 0:
					total += int(neighbor.get("neighbor_attack", 0))
		for lane in state.lanes:
			for source in lane.units[unit.owner]:
				if source != null and source.health > 0 and source.uid != unit.uid:
					total += int(source.get("global_attack", 0))
	return maxi(0, total)

func armor_of(unit: Dictionary) -> int:
	var total = int(unit.armor) + int(unit.temp_armor) + _item_stat(unit, "armor")
	var lane_index = int(unit.lane)
	if lane_index >= 0:
		var row = state.lanes[lane_index].units[unit.owner]
		var position = row.find(unit)
		for neighbor_slot in [position - 1, position + 1]:
			if position >= 0 and neighbor_slot >= 0 and neighbor_slot < row.size():
				var neighbor = row[neighbor_slot]
				if neighbor != null and neighbor.health > 0:
					total += int(neighbor.get("neighbor_armor", 0))
	return total

func _max_health(unit: Dictionary) -> int:
	return int(unit.max_health) + _item_stat(unit, "health")

func _item_stat(unit: Dictionary, stat: String) -> int:
	var total = 0
	for card_id in unit.items.values():
		total += int(library.cards[card_id].get(stat, 0))
	return total

func _event(message: String) -> void:
	state.events.append(message)
	if state.events.size() > 100:
		state.events.pop_front()

func _player_name(player: int) -> String:
	return "Player %d" % (player + 1)

func player_view(player: int) -> Dictionary:
	var result = state.duplicate(true)
	for index in range(2):
		var owner = result.players[index]
		owner["hand_count"] = owner.hand.size()
		owner["deck_count"] = owner.deck.size()
		owner.deck = []
		owner["item_deck_count"] = owner.get("item_deck", []).size()
		owner.item_deck = []
		if index != player:
			owner.hand = []
			owner.plans = {}
			owner.shop = {}
			owner.bought = []
	return result

func simulation_from_view(player: int):
	# The bot receives only the same observation a player sees. Its simulation
	# has synthetic randomness, never the live engine's future random state.
	var simulation = get_script().new()
	simulation.library = library
	simulation.state = player_view(player)
	simulation.rng.seed = 1
	simulation.next_id = next_id
	simulation.deck_ids = deck_ids.duplicate()
	return simulation

func replay_data() -> Dictionary:
	return {"protocol": PROTOCOL_VERSION, "content_pack": library.content_pack,
		"seed": match_seed, "decks": deck_ids.duplicate(), "actions": journal.duplicate(true)}

func load_replay(data: Dictionary) -> Dictionary:
	if data.get("protocol") != PROTOCOL_VERSION or not Library.PACKS.has(data.get("content_pack", "")):
		return {"ok": false, "error": "Replay version or card pack does not match."}
	if not data.get("seed") is float and not data.get("seed") is int:
		return {"ok": false, "error": "Replay has no valid seed."}
	if not data.get("actions") is Array or data.actions.size() > 20000:
		return {"ok": false, "error": "Invalid replay actions."}
	if not data.get("decks") is Array:
		return {"ok": false, "error": "Replay has no valid deck selection."}
	library = Library.new(data.content_pack)
	var initial = start(int(data.seed), data.get("decks", ["starter", "starter"]))
	if not initial.ok:
		return initial
	for entry in data.actions:
		if not entry is Dictionary or not entry.get("command") is Dictionary:
			return {"ok": false, "error": "Invalid replay entry."}
		var result = apply_action(int(entry.get("player", -1)), entry.command)
		if not result.ok:
			return {"ok": false, "error": "Replay contains an illegal action at revision %d." % state.revision}
	return {"ok": true}

func state_digest() -> String:
	return (JSON.stringify(state) + str(rng.state) + str(next_id)).sha256_text()
