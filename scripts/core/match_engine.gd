extends RefCounted
## Authoritative, UI-independent match state. Every mutation goes through a
## validated command; RNG and command journals make a match reproducible.

## Lane model: lanes[i].units[0] and lanes[i].units[1] are always the same
## length and index-aligned. Index n is one shared combat position holding the
## player-0 unit (or null) and the player-1 unit (or null). Positions that are
## empty on both sides are removed whenever units leave a lane (_compact).

const Library = preload("res://scripts/core/card_library.gd")
# 4: aligned combat positions, play.position for creep cards, hold command,
# structured events and visible pending lane creeps.
# 5: language-neutral state (no display names in units or players) and coded
# error results ({"ok": false, "code": ..., "args": ..., "error": English}).
# The concede command (always legal while the match runs) needs no format
# change: older replays never contain it.
const PROTOCOL_VERSION = 5
const CONCEDE = {"type": "concede"}
const HOLD_COST = 1
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
			return _fail("deck_selection", "Choose one deck for each player.")
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
		"players": [], "lanes": [], "events": [], "event_seq": 0,
		"pending_creeps": [[], []]}
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
			"item_deck": item_deck, "shop": {}, "held_secret": "", "preset": str(deck_ids[player])})
	for lane in range(3):
		state.lanes.append({"units": [[], []], "mana": [3, 3],
			"max_mana": [3, 3], "mana_bonus": [0, 0], "structures": [
				{"health": 40, "ancient": false, "destroyed": false},
				{"health": 40, "ancient": false, "destroyed": false}]})
	# Round 1: heroes 1-3 take one random lane each and one Melee Creep joins
	# every lane per player. Both players' units are placed in one shuffled
	# order so neither side systematically claims combat positions first.
	var placements: Array = []
	for player in range(2):
		var lane_order: Array = [0, 1, 2]
		_shuffle(lane_order)
		for index in range(3):
			placements.append([state.players[player].roster[index], lane_order[index]])
		for lane in range(3):
			placements.append([_make_creep(player), lane])
		_draw(player, 5)
	_place_all(placements)
	state.initiative = rng.randi_range(0, 1)
	state.active_player = state.initiative
	_roll_arrows()
	_event("match_start")
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
			# Hold: pay 1 gold once per shop phase to keep the Secret Shop offer.
			if owner.gold >= HOLD_COST and not str(owner.shop.get("secret", "")).is_empty() and str(owner.get("held_secret", "")).is_empty():
				actions.append({"type": "hold"})
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
		if target_kind == "none" and card.kind == "creep":
			# Creep cards go into a combat position of the player's choice.
			for position in creep_positions(state.lane, player):
				actions.append({"type": "play", "hand": index, "position": position})
		elif target_kind == "none":
			actions.append({"type": "play", "hand": index})
		else:
			var sides = [0, 1] if target_kind in ["unit", "hero", "red_hero", "creep"] else [1 - player if target_kind in ["enemy", "enemy_hero"] else player]
			for target_player in sides:
				var target_lanes = range(3) if card.get("cross_lane", false) else [state.lane]
				for target_lane in target_lanes:
					for unit in state.lanes[target_lane].units[target_player]:
						_add_target_actions(actions, card, target_kind, unit, index)
	return actions

## Legal `position` values for a creep card played by `player` into a lane:
## the index of an existing combat position whose own slot is empty, -1 for a
## new position at the left end, or the current position count for a new
## position at the right end. An empty lane offers only 0.
func creep_positions(lane_index: int, player: int) -> Array:
	var row = state.lanes[lane_index].units[player]
	if row.is_empty():
		return [0]
	var result: Array = [-1]
	for slot in range(row.size()):
		if row[slot] == null:
			result.append(slot)
	result.append(row.size())
	return result

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
	for field in ["hand", "target", "unit", "lane", "destination", "position"]:
		if command.has(field):
			var value = command[field]
			if not (value is int or value is float) or float(value) != floor(float(value)):
				return _fail("bad_index", "Command indexes must be whole numbers.")
			command[field] = int(value)
	if command == CONCEDE:
		if not can_concede(player):
			return _fail("illegal_action", "That action is not legal in the current state.")
	elif command not in legal_actions(player):
		return _fail("illegal_action", "That action is not legal in the current state.")
	journal.append({"player": player, "command": command.duplicate(true)})
	match command.type:
		"concede":
			_concede(player)
		"pass":
			_pass(player)
		"play":
			_play(player, command)
		"ability":
			var unit = find_unit(int(command.unit))
			_draw(player, 1)
			unit.cooldown = int(unit.ability_cooldown)
			_event("ability", {"p": player, "uid": unit.uid, "card": unit.card})
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
					if command.source == "secret":
						state.players[player].held_secret = ""
			# Public log: cost only, never the purchased card's identity.
			_event("buy", {"p": player, "gold": int(card.price)})
		"hold":
			var owner = state.players[player]
			owner.gold -= HOLD_COST
			owner.held_secret = owner.shop.secret
			_event("hold", {"p": player, "gold": HOLD_COST})
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

## Either player may concede in any phase while the match is undecided. It is
## kept out of legal_actions() so turn logic (bots, "is it my turn") ignores it.
func can_concede(player: int) -> bool:
	return player >= 0 and player <= 1 and not state.is_empty() and int(state.winner) == -1

func _concede(player: int) -> void:
	_event("concede", {"p": player})
	state.winner = 1 - player
	state.phase = "finished"
	_event("win", {"p": state.winner})

func _pass(player: int) -> void:
	_event("pass", {"p": player})
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
			_event("lane_open", {"lane": state.lane, "p": state.initiative})
		else:
			state.phase = "shop"
			for owner in state.players:
				owner.finished = false
				owner.bought.clear()
			_prepare_shop()
			_event("shop_open")

func _prepare_shop() -> void:
	if library.presets().is_empty():
		return
	for owner in state.players:
		var pool = library.catalog.secret_shop
		var consumables = library.catalog.consumables
		# The item deck is reshuffled at every shopping phase.
		_shuffle(owner.item_deck)
		# A held Secret Shop offer returns once, then the hold is spent.
		var secret = str(owner.get("held_secret", ""))
		if secret.is_empty():
			secret = pool[rng.randi_range(0, pool.size() - 1)]
		owner.held_secret = ""
		owner.shop = {"secret": secret,
			"item": owner.item_deck.back() if not owner.item_deck.is_empty() else "",
			"consumable": consumables[rng.randi_range(0, consumables.size() - 1)]}

func _play(player: int, command: Dictionary) -> void:
	var owner = state.players[player]
	var card_id = owner.hand[int(command.hand)]
	var card = library.cards[card_id]
	owner.hand.remove_at(int(command.hand))
	state.lanes[state.lane].mana[player] -= int(card.cost)
	var target = find_unit(int(command.get("target", -1)))
	var played = {"p": player, "card": card_id}
	if not target.is_empty():
		played["target"] = target.uid
		played["target_card"] = target.card
	_event("play", played)
	if card.kind == "creep":
		# Only the new unit gets a pathing roll; other arrows are untouched.
		var creep = _make_unit(card, player, false)
		_place(creep, state.lane, int(command.position))
		_roll_arrow(creep)
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
					var position = _slot_of(target)
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
				_remove_from_lane(target)
				_enter_fountain(target, state.round + 1)
			"battle_neighbors":
				_battle_neighbors(target)
			"redirect":
				target.combat_target = int(command.destination)
				var destination = find_unit(int(command.destination))
				if not destination.is_empty():
					target.arrow = _slot_of(destination) - _slot_of(target)
			"summon":
				# Each summoned creep takes a random empty position (or a new
				# position at a random end) and receives its own pathing roll.
				for copy in range(int(card.amount)):
					var summoned = _make_creep(player)
					_spawn(summoned, state.lane)
					_roll_arrow(summoned)
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
	_event("combat", {"lane": state.lane, "damage": [int(forecast.tower_damage[0]), int(forecast.tower_damage[1])]})
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
	var enemy_row = state.lanes[lane_index].units[1 - int(unit.owner)]
	var target_slot = slot + int(unit.arrow)
	if target_slot >= 0 and target_slot < enemy_row.size() and enemy_row[target_slot] != null:
		return enemy_row[target_slot]
	# Pathing never points at an empty position: attack forward instead, which
	# is the blocking unit if one exists, otherwise the tower.
	if slot < enemy_row.size() and enemy_row[slot] != null:
		return enemy_row[slot]
	return {}

## The unit (or {} for the tower) that `unit` would hit in combat right now.
func combat_target_of(unit: Dictionary) -> Dictionary:
	var slot = _slot_of(unit)
	if slot == -1:
		return {}
	return _combat_target(unit, int(unit.lane), slot)

## Legal Battlefield Control destinations: the enemy units in the three combat
## positions across from `unit`, plus the tower (0) when one of those existing
## positions is empty on the enemy side.
func combat_targets(unit: Dictionary) -> Array:
	var result: Array = []
	var slot = _slot_of(unit)
	if slot == -1:
		return result
	var enemy_row = state.lanes[unit.lane].units[1 - int(unit.owner)]
	var tower_open = false
	for offset in [-1, 0, 1]:
		var index = slot + offset
		if index < 0 or index >= enemy_row.size():
			continue
		if enemy_row[index] == null:
			tower_open = true
		else:
			result.append(enemy_row[index].uid)
	if tower_open:
		result.push_front(0) # Tower.
	return result

func battle_attack(attacker: Dictionary, target: Dictionary) -> int:
	var bonus = int(attacker.get("hero_tower_bonus", 0)) if target.is_empty() or target.hero else 0
	if not target.is_empty() and target.hero:
		bonus += int(attacker.get("hero_bonus", 0))
	return attack_of(attacker) + bonus

func _battle_neighbors(hero: Dictionary) -> void:
	var lane = state.lanes[hero.lane]
	var position = _slot_of(hero)
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
			_event("ancient_fall", {"p": defender})
		else:
			structure.ancient = true
			structure.health = 80
			_event("tower_fall", {"p": defender})

func _clean_dead(lane_index: int, _cause_player: int = -1) -> void:
	var lane = state.lanes[lane_index]
	_align(lane_index)
	for player in range(2):
		for slot in range(lane.units[player].size()):
			var unit = lane.units[player][slot]
			if unit == null or unit.health > 0:
				continue
			# Classic bounty belongs to the opponent whenever a unit dies,
			# including friendly spells and symmetric board clears.
			var bounty = 5 if unit.hero else 1
			state.players[1 - player].gold += bounty
			_release_attackers(lane_index, unit, slot)
			if unit.hero:
				_enter_fountain(unit, state.round + (1 if unit.get("rapid_deployment", false) else 2))
			else:
				unit.lane = -1
			_event("death", {"p": player, "uid": unit.uid, "card": unit.card, "gold": bounty})
			lane.units[player][slot] = null
	# Simultaneous deaths keep their positions until every corpse is removed;
	# then positions empty on both sides collapse.
	_compact(lane_index)

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
		if state.winner == 2:
			_event("draw")
		else:
			_event("win", {"p": state.winner})

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
					# A round-long redirect ends; its arrow is rerolled at reveal.
					if int(unit.combat_target) != -1:
						unit.arrow = 0
					unit.combat_target = -1
	# Lane creeps are assigned and revealed to both players before heroes are
	# chosen; they enter play together with the heroes at reveal.
	state.pending_creeps = [[], []]
	for player in range(2):
		for creep in range(2):
			state.pending_creeps[player].append(rng.randi_range(0, 2))
	_event("deployment", {"round": state.round, "creeps": state.pending_creeps.duplicate(true)})

func _reveal_deployment() -> void:
	var placements: Array = []
	var pending = state.get("pending_creeps", [[], []])
	for player in range(2):
		var owner = state.players[player]
		# Both choices are confirmed: draw first, then place units.
		_draw(player, 2)
		for hero in owner.roster:
			if owner.plans.has(str(hero.uid)):
				hero.health = _max_health(hero)
				placements.append([hero, int(owner.plans[str(hero.uid)])])
		owner.plans.clear()
		owner.finished = false
		for lane_index in pending[player]:
			placements.append([_make_creep(player), int(lane_index)])
	state.pending_creeps = [[], []]
	_place_all(placements)
	_roll_arrows()
	state.phase = "action"
	state.active_player = state.initiative
	state.first_pass = -1
	_event("deployment_revealed")

func _make_unit(definition: Dictionary, player: int, is_hero: bool) -> Dictionary:
	# Units carry ids and numbers only; display text is looked up by "card".
	var result = {"uid": next_id, "card": definition.id,
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
		"ability": definition.get("ability", ""),
		"ability_cooldown": int(definition.get("ability_cooldown", 0)), "cooldown": 0}
	next_id += 1
	return result

## Random placement used by Summon, lane creeps and deployed heroes: a random
## combat position whose own slot is empty, otherwise a new position at a
## random end of the lane.
func _spawn(unit: Dictionary, lane_index: int) -> void:
	_align(lane_index)
	var row = state.lanes[lane_index].units[unit.owner]
	var open_slots: Array = []
	for slot in range(row.size()):
		if row[slot] == null:
			open_slots.append(slot)
	var position = 0
	if not open_slots.is_empty():
		position = open_slots[rng.randi_range(0, open_slots.size() - 1)]
	elif not row.is_empty():
		position = -1 if rng.randi_range(0, 1) == 0 else row.size()
	_place(unit, lane_index, position)

## Puts `unit` into combat position `position` (see creep_positions for the
## encoding). New positions are added to both sides so rows stay aligned;
## arrows are relative offsets, so inserting at the left end shifts every
## unit equally and no attacker changes target.
func _place(unit: Dictionary, lane_index: int, position: int) -> void:
	_align(lane_index)
	var rows = state.lanes[lane_index].units
	var owner = int(unit.owner)
	if position < 0:
		for row in rows:
			row.push_front(null)
		position = 0
	elif position >= rows[owner].size():
		for row in rows:
			row.append(null)
		position = rows[owner].size() - 1
	rows[owner][position] = unit
	unit.lane = lane_index
	# Pathing reset: an enemy attacking diagonally now faces this unit.
	var opposite = rows[1 - owner][position]
	if opposite != null and int(opposite.get("combat_target", -1)) < 0:
		opposite.arrow = 0

## Places [unit, lane] pairs from both players in one shuffled order, so the
## result does not depend on which player is processed first.
func _place_all(placements: Array) -> void:
	_shuffle(placements)
	for entry in placements:
		_spawn(entry[0], int(entry[1]))

## Removes a unit that leaves play without dying (e.g. Town Portal).
func _remove_from_lane(unit: Dictionary) -> void:
	var slot = _slot_of(unit)
	if slot == -1:
		return
	var lane_index = int(unit.lane)
	_release_attackers(lane_index, unit, slot)
	state.lanes[lane_index].units[int(unit.owner)][slot] = null
	_compact(lane_index)

## Removing a unit's current target from play resets that attacker's pathing
## to straight forward (including a Battlefield Control choice of that unit).
func _release_attackers(lane_index: int, unit: Dictionary, slot: int) -> void:
	var enemies = state.lanes[lane_index].units[1 - int(unit.owner)]
	for enemy_slot in range(enemies.size()):
		var attacker = enemies[enemy_slot]
		if attacker == null:
			continue
		if int(attacker.get("combat_target", -1)) == int(unit.uid):
			attacker.combat_target = -1
			attacker.arrow = 0
		elif int(attacker.arrow) != 0 and enemy_slot + int(attacker.arrow) == slot:
			attacker.arrow = 0

## Pads the shorter row with empty slots. Engine operations keep rows aligned;
## this only repairs hand-built fixture boards before they are mutated.
func _align(lane_index: int) -> void:
	var rows = state.lanes[lane_index].units
	while rows[0].size() < rows[1].size():
		rows[0].append(null)
	while rows[1].size() < rows[0].size():
		rows[1].append(null)

## Removes every combat position that is empty on both sides.
func _compact(lane_index: int) -> void:
	_align(lane_index)
	var rows = state.lanes[lane_index].units
	for slot in range(rows[0].size() - 1, -1, -1):
		if rows[0][slot] == null and rows[1][slot] == null:
			rows[0].remove_at(slot)
			rows[1].remove_at(slot)

func _slot_of(unit: Dictionary) -> int:
	var lane_index = int(unit.get("lane", -1))
	if lane_index < 0:
		return -1
	var row = state.lanes[lane_index].units[int(unit.owner)]
	for slot in range(row.size()):
		if row[slot] != null and int(row[slot].uid) == int(unit.uid):
			return slot
	return -1

func _make_creep(player: int) -> Dictionary:
	var definition = library.definition("melee_creep")
	if definition.is_empty():
		definition = {"id": "melee_creep", "attack": 2, "health": 4, "color": "neutral"}
	return _make_unit(definition, player, false)

func _spawn_creep(player: int, lane_index: int) -> void:
	_spawn(_make_creep(player), lane_index)

## End of deployment (and match start): every unit gets a fresh pathing roll.
func _roll_arrows() -> void:
	for lane_index in range(3):
		var lane = state.lanes[lane_index]
		for player in range(2):
			for unit in lane.units[player]:
				if unit != null:
					_roll_arrow(unit)

## Pathing: blocked units attack forward. Otherwise 50% forward, 25% left,
## 25% right; a rolled diagonal with no unit there means forward.
func _roll_arrow(unit: Dictionary) -> void:
	if int(unit.get("combat_target", -1)) >= 0:
		return
	var slot = _slot_of(unit)
	if slot == -1:
		return
	var enemies = state.lanes[int(unit.lane)].units[1 - int(unit.owner)]
	unit.arrow = 0
	if slot < enemies.size() and enemies[slot] != null:
		return
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
	if int(unit.lane) >= 0:
		var row = state.lanes[int(unit.lane)].units[int(unit.owner)]
		var position = _slot_of(unit)
		for neighbor_slot in [position - 1, position + 1]:
			if position >= 0 and neighbor_slot >= 0 and neighbor_slot < row.size():
				var neighbor = row[neighbor_slot]
				if neighbor != null and neighbor.health > 0:
					total += int(neighbor.get("neighbor_attack", 0))
		for lane in state.lanes:
			for source in lane.units[int(unit.owner)]:
				if source != null and source.health > 0 and source.uid != unit.uid:
					total += int(source.get("global_attack", 0))
	return maxi(0, total)

func armor_of(unit: Dictionary) -> int:
	var total = int(unit.armor) + int(unit.temp_armor) + _item_stat(unit, "armor")
	var lane_index = int(unit.lane)
	if lane_index >= 0:
		var row = state.lanes[lane_index].units[int(unit.owner)]
		var position = _slot_of(unit)
		for neighbor_slot in [position - 1, position + 1]:
			if position >= 0 and neighbor_slot >= 0 and neighbor_slot < row.size():
				var neighbor = row[neighbor_slot]
				if neighbor != null and neighbor.health > 0:
					total += int(neighbor.get("neighbor_armor", 0))
	return total

func _max_health(unit: Dictionary) -> int:
	return int(unit.max_health) + _item_stat(unit, "health")

## Public read-only helpers for display code (board preview, arrows).
func slot_of(unit: Dictionary) -> int:
	return _slot_of(unit)

func max_health_of(unit: Dictionary) -> int:
	return _max_health(unit)

func _item_stat(unit: Dictionary, stat: String) -> int:
	var total = 0
	for card_id in unit.items.values():
		total += int(library.cards[card_id].get(stat, 0))
	return total

## Events are structured dictionaries ({"k": key, ...}); scripts/core/event_text.gd
## turns them into display text. event_seq counts every event ever emitted so
## views can tell which entries are new even after the 100-entry window rolls.
func _event(key: String, data: Dictionary = {}) -> void:
	var entry = {"k": key}
	entry.merge(data)
	state.events.append(entry)
	state.event_seq = int(state.get("event_seq", 0)) + 1
	if state.events.size() > 100:
		state.events.pop_front()

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
			owner.held_secret = ""
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
		return _fail("replay_version", "Replay version or card pack does not match.")
	if not data.get("seed") is float and not data.get("seed") is int:
		return _fail("replay_seed", "Replay has no valid seed.")
	if not data.get("actions") is Array or data.actions.size() > 20000:
		return _fail("replay_actions", "Invalid replay actions.")
	if not data.get("decks") is Array:
		return _fail("replay_decks", "Replay has no valid deck selection.")
	library = Library.new(data.content_pack)
	var initial = start(int(data.seed), data.get("decks", ["starter", "starter"]))
	if not initial.ok:
		return initial
	for entry in data.actions:
		if not entry is Dictionary or not entry.get("command") is Dictionary:
			return _fail("replay_entry", "Invalid replay entry.")
		var result = apply_action(int(entry.get("player", -1)), entry.command)
		if not result.ok:
			return _fail("replay_illegal", "Replay contains an illegal action at revision %d." % state.revision,
				{"revision": int(state.revision)})
	return {"ok": true}

## Failed command or load result. `code` and `args` are stable for UI
## translation (i18n key ERR_<CODE>); `error` is an English fallback only.
static func _fail(code: String, message: String, args: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "args": args, "error": message}

func state_digest() -> String:
	return (JSON.stringify(state) + str(rng.state) + str(next_id)).sha256_text()
