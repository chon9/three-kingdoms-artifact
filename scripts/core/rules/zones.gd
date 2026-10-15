extends RefCounted
## Zones (EFFECT_SYSTEM_SPEC.md §2.5, §4.7): combat positions and arrows,
## hand and deck state, item instances, summons and the Fountain. Static
## functions over the engine `e`; no instance members.

const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Stats = preload("res://scripts/core/rules/stats.gd")

# --- Combat positions and arrows ------------------------------------------------------

## Random placement used by Summon, lane creeps and deployed heroes: a random
## combat position whose own slot is empty, otherwise a new position at a
## random end of the lane.
static func spawn(e, unit: Dictionary, lane_index: int) -> void:
	align(e, lane_index)
	var row = e.state.lanes[lane_index].units[unit.owner]
	var open_slots: Array = []
	for slot in range(row.size()):
		if row[slot] == null:
			open_slots.append(slot)
	var position = 0
	if not open_slots.is_empty():
		position = open_slots[Kernel.rand_index(e, open_slots.size())]
	elif not row.is_empty():
		position = -1 if Kernel.rand_index(e, 2) == 0 else row.size()
	place(e, unit, lane_index, position)

## Puts `unit` into combat position `position` (see creep_positions for the
## encoding). New positions are added to both sides so rows stay aligned;
## arrows are relative offsets, so inserting at the left end shifts every
## unit equally and no attacker changes target.
static func place(e, unit: Dictionary, lane_index: int, position: int) -> void:
	align(e, lane_index)
	var rows = e.state.lanes[lane_index].units
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
	# Pathing reset: an enemy attacking diagonally now faces this unit. A
	# forced tower target (Battlefield Control) needs the position across to
	# be empty (RQ-19), so the new unit blocks it as well.
	var opposite = rows[1 - owner][position]
	if opposite != null:
		var forced = int(opposite.get("combat_target", -1))
		if forced == 0:
			opposite.combat_target = -1
			opposite.arrow = 0
		elif forced < 0:
			opposite.arrow = 0

## Places [unit, lane] pairs from both players in one shuffled order, so the
## result does not depend on which player is processed first.
static func place_all(e, placements: Array) -> void:
	Kernel.shuffle(e, placements)
	for entry in placements:
		spawn(e, entry[0], int(entry[1]))

## Removes a unit that leaves play without dying (e.g. Town Portal).
static func remove_from_lane(e, unit: Dictionary) -> void:
	var slot = slot_of(e, unit)
	if slot == -1:
		return
	var lane_index = int(unit.lane)
	release_attackers(e, lane_index, unit, slot)
	e.state.lanes[lane_index].units[int(unit.owner)][slot] = null
	compact(e, lane_index)

## Removing a unit's current target from play resets that attacker's pathing
## to straight forward (including a Battlefield Control choice of that unit).
static func release_attackers(e, lane_index: int, unit: Dictionary, slot: int) -> void:
	var enemies = e.state.lanes[lane_index].units[1 - int(unit.owner)]
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
static func align(e, lane_index: int) -> void:
	var rows = e.state.lanes[lane_index].units
	while rows[0].size() < rows[1].size():
		rows[0].append(null)
	while rows[1].size() < rows[0].size():
		rows[1].append(null)

## Removes every combat position that is empty on both sides.
static func compact(e, lane_index: int) -> void:
	align(e, lane_index)
	var rows = e.state.lanes[lane_index].units
	for slot in range(rows[0].size() - 1, -1, -1):
		if rows[0][slot] == null and rows[1][slot] == null:
			rows[0].remove_at(slot)
			rows[1].remove_at(slot)

static func slot_of(e, unit: Dictionary) -> int:
	var lane_index = int(unit.get("lane", -1))
	if lane_index < 0 or lane_index > 2:
		return -1
	var row = e.state.lanes[lane_index].units[int(unit.owner)]
	for slot in range(row.size()):
		if row[slot] != null and int(row[slot].uid) == int(unit.uid):
			return slot
	return -1

## A diagonal arrow without a forced target is reset when the unit is blocked
## or the diagonal is empty (the board invariant I2).
static func normalize_arrows(e, lane_index: int) -> void:
	var rows = e.state.lanes[lane_index].units
	for side in range(2):
		var enemies = rows[1 - side]
		for slot in range(rows[side].size()):
			var unit = rows[side][slot]
			if unit == null or int(unit.arrow) == 0 or int(unit.get("combat_target", -1)) >= 0:
				continue
			var diagonal = slot + int(unit.arrow)
			var blocked = slot < enemies.size() and enemies[slot] != null
			if blocked or diagonal < 0 or diagonal >= enemies.size() or enemies[diagonal] == null:
				unit.arrow = 0

## End of deployment (and match start): every unit gets a fresh pathing roll.
static func roll_arrows(e) -> void:
	for lane_index in range(3):
		var lane = e.state.lanes[lane_index]
		for player in range(2):
			for unit in lane.units[player]:
				if unit != null:
					roll_arrow(e, unit)

## Pathing: blocked units attack forward. Otherwise 50% forward, 25% left,
## 25% right; a rolled diagonal with no unit there means forward.
static func roll_arrow(e, unit: Dictionary) -> void:
	if int(unit.get("combat_target", -1)) >= 0:
		return
	var slot = slot_of(e, unit)
	if slot == -1:
		return
	var enemies = e.state.lanes[int(unit.lane)].units[1 - int(unit.owner)]
	unit.arrow = 0
	if slot < enemies.size() and enemies[slot] != null:
		return
	var roll = Kernel.rand_index(e, 4)
	var offset = -1 if roll == 0 else (1 if roll == 3 else 0)
	if slot + offset >= 0 and slot + offset < enemies.size() and enemies[slot + offset] != null:
		unit.arrow = offset

# --- Units entering and leaving ------------------------------------------------------

## Summons a fresh unit of `card_id` for `owner` into `lane_index`: a random
## empty own slot, otherwise a random end; then its arrow (deferred to the
## deployment roll while deploying). Summoned heroes are not roster heroes.
static func summon(e, card_id: String, owner: int, lane_index: int) -> Dictionary:
	var definition = e._definition_or_creep(card_id)
	var hero = str(definition.get("kind", "creep")) == "hero"
	var unit = e._make_unit(definition, owner, hero)
	unit["roster"] = false
	spawn(e, unit, lane_index)
	if not e._deploying:
		roll_arrow(e, unit)
	e._event("summon", {"uid": int(unit.uid), "card": str(unit.card), "p": owner, "lane": lane_index, "slot": slot_of(e, unit)})
	Kernel.emit(e, "unit_entered", {"unit": int(unit.uid), "lane": lane_index, "how": "summon"})
	return unit

## The Fountain (spec §4.7): out of the lane, ready on `ready_round`, every
## temporary entry removed (Modify and items stay), fully healed.
static func enter_fountain(e, hero: Dictionary, ready_round: int) -> void:
	hero.lane = -1
	hero.ready_round = ready_round
	hero.combat_target = -1
	hero["condemned"] = false
	var kept: Array = []
	for entry in hero.get("mods", []):
		if str(entry.get("k", "")) != "give":
			kept.append(entry)
	hero["mods"] = kept
	hero.health = Stats.max_health(e, hero)
	hero["hp_seen"] = int(hero.health)
	Stats.mirror_statuses(hero)

## Equips `card_id` on `hero`: the slot's old instance is discarded silently,
## a new item instance is created and the hero's "until equip" entries end.
static func equip(e, hero: Dictionary, card_id: String) -> Dictionary:
	var definition: Dictionary = e.library.get_card(card_id)
	var slot = str(definition.get("slot", ""))
	hero.items[slot] = card_id
	if not hero.has("item_state"):
		hero["item_state"] = {}
	var instance = {"oid": Kernel.next_oid(e), "cd": 0, "charges": int(definition.get("charges", 0)), "mods": []}
	hero.item_state[slot] = instance
	Kernel._drop_entries(hero, "equip")
	return instance

## An improvement enters its lane (spec §4.7): if that side already holds the
## cap, one random existing improvement there is removed first (RQ-47).
static func add_improvement(e, card_id: String, owner: int, lane_index: int) -> Dictionary:
	var lane: Dictionary = e.state.lanes[lane_index]
	if not lane.has("improvements"):
		lane["improvements"] = [[], []]
	var row: Array = lane.improvements[owner]
	if row.size() >= Kernel.IMPROVEMENT_CAP:
		var removed: Dictionary = row[Kernel.rand_index(e, row.size())]
		row.erase(removed)
		e._event("improvement_gone", {"oid": int(removed.oid), "card": str(removed.card)})
	e.state["order_seq"] = int(e.state.get("order_seq", 0)) + 1
	var improvement = {"oid": Kernel.next_oid(e), "card": card_id, "owner": owner, "lane": lane_index, "cd": 0,
		"charges": int(e.library.get_card(card_id).get("charges", 0)), "mods": [], "condemned": false,
		"order": int(e.state.order_seq), "used": {}}
	row.append(improvement)
	e._event("improvement", {"oid": int(improvement.oid), "card": card_id, "p": owner, "lane": lane_index})
	Kernel.emit(e, "improvement_entered", {"oid": int(improvement.oid), "card": card_id, "owner": owner, "lane": lane_index})
	return improvement

## A Deed is played into its owner's public deeds zone (RQ-41).
static func add_deed(e, card_id: String, owner: int) -> Dictionary:
	var deed = {"oid": Kernel.next_oid(e), "card": card_id, "owner": owner}
	if not e.state.players[owner].has("deeds"):
		e.state.players[owner]["deeds"] = []
	e.state.players[owner].deeds.append(deed)
	return deed

# --- Hand and deck ---------------------------------------------------------------

## Pads or truncates hand_state and deck_state to their zones, so fixtures
## that assign hand = ["gust"] keep working. Called before a command runs.
static func sync(e) -> void:
	for owner in e.state.players:
		if not owner.has("hand_state"):
			owner["hand_state"] = []
		var states: Array = owner.hand_state
		while states.size() > owner.hand.size():
			states.pop_back()
		while states.size() < owner.hand.size():
			states.append({"iid": Kernel.next_oid(e)})
		if not owner.has("deck_state"):
			owner["deck_state"] = []
		var deck_states: Array = owner.deck_state
		if not deck_states.is_empty():
			while deck_states.size() > owner.deck.size():
				deck_states.pop_back()
			while deck_states.size() < owner.deck.size():
				deck_states.push_front({})

## Draws up to `count` cards from the back of the deck. Each drawn card gets a
## fresh iid and emits card_drawn. Returns the drawn iids.
static func draw(e, player: int, count: int) -> Array:
	var owner = e.state.players[player]
	var drawn: Array = []
	for index in range(count):
		if owner.deck.is_empty():
			continue
		var card_id = owner.deck.pop_back()
		var entry: Dictionary = {}
		var deck_states: Array = owner.get("deck_state", [])
		if not deck_states.is_empty():
			var stored = deck_states.pop_back()
			if stored is Dictionary:
				entry = stored.duplicate(true)
		entry["iid"] = Kernel.next_oid(e)
		owner.hand.append(card_id)
		if not owner.has("hand_state"):
			owner["hand_state"] = []
		owner.hand_state.append(entry)
		drawn.append(int(entry.iid))
		Kernel.emit(e, "card_drawn", {"player": player, "card": {"cardref": true, "p": player, "zone": "hand",
			"index": owner.hand.size() - 1, "card": str(card_id), "iid": int(entry.iid)}})
	return drawn

## Takes the card at `index` out of the hand together with its state.
static func take_from_hand(e, player: int, index: int) -> Dictionary:
	var owner = e.state.players[player]
	var card_id = str(owner.hand[index])
	owner.hand.remove_at(index)
	var entry: Dictionary = {}
	if index < owner.get("hand_state", []).size():
		entry = owner.hand_state[index]
		owner.hand_state.remove_at(index)
	return {"card": card_id, "state": entry}

## Discards the given card handles from their owners' hands.
static func discard(e, cards: Array) -> void:
	var by_player = [[], []]
	for card in cards:
		if card is Dictionary and card.has("cardref") and str(card.zone) == "hand":
			by_player[int(card.p)].append(card)
	for player in range(2):
		if by_player[player].is_empty():
			continue
		var indices: Array = []
		var ids: Array = []
		for card in by_player[player]:
			indices.append(int(card.index))
			ids.append(str(card.card))
		indices.sort()
		indices.reverse()
		for index in indices:
			take_from_hand(e, player, index)
		e._event("discard", {"p": player, "n": indices.size()}, {str(player): {"cards": ids}})

## A card instance's counter: its stored value, else the card's printed
## charges (CF-2). Reads `$played` ({card, state}) or a card handle.
static func card_counter(e, value) -> int:
	if not value is Dictionary:
		return 0
	var card_id = str(value.get("card", ""))
	var entry: Dictionary = {}
	if value.has("state"):
		entry = value.state if value.state is Dictionary else {}
	elif value.has("cardref"):
		var owner = e.state.players[int(value.p)]
		var states: Array = owner.get("hand_state" if str(value.zone) == "hand" else "deck_state", [])
		if int(value.index) < states.size() and states[int(value.index)] is Dictionary:
			entry = states[int(value.index)]
	if entry.has("charges"):
		return int(entry.charges)
	return int(e.library.get_card(card_id).get("charges", 0))
