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
	# Pathing reset (wiki Pathing, "Resetting Pathing"): an enemy attacking to
	# its left or right now faces this unit, whether its target was rolled or
	# chosen (Battlefield Control, Compel, a taunt). A forced tower target needs
	# the position across to be empty (RQ-19), so the new unit blocks it as
	# well. The position was empty, so the enemy across was never attacking it.
	var opposite = rows[1 - owner][position]
	if opposite != null:
		opposite.combat_target = -1
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

## Forced combat targets that no longer hold after units moved in `lane_index`
## (a move, a swap or a change of control) end: a forced unit target must be an
## enemy in this lane within one position (its arrow follows its offset), and a
## forced tower target needs the position directly across to be empty (RQ-19).
## Only these zone changes call it; deaths and placements keep their own rules.
static func clear_stale_targets(e, lane_index: int) -> void:
	var rows = e.state.lanes[lane_index].units
	for side in range(2):
		var enemies: Array = rows[1 - side]
		for slot in range(rows[side].size()):
			var unit = rows[side][slot]
			if unit == null:
				continue
			var forced = int(unit.get("combat_target", -1))
			if forced == 0:
				if slot < enemies.size() and enemies[slot] != null:
					unit.combat_target = -1
					unit.arrow = 0
			elif forced > 0:
				var target_slot = -1
				for index in range(enemies.size()):
					if enemies[index] != null and int(enemies[index].uid) == forced:
						target_slot = index
				if target_slot == -1 or absi(target_slot - slot) > 1:
					unit.combat_target = -1
					unit.arrow = 0
				else:
					unit.arrow = target_slot - slot

## True when `position` (creep_positions encoding) is free for `owner` in
## `lane_index`: a new end position, or an existing position whose own slot is
## empty. A position chosen before earlier ops filled it is stale.
static func position_open(e, lane_index: int, owner: int, position: int) -> bool:
	var row: Array = e.state.lanes[lane_index].units[owner]
	if position < 0 or position >= row.size():
		return true
	return row[position] == null

## Moves `unit` (spec §3.7, CF-1). Across lanes it leaves its position
## (attackers released, the lane compacted) and enters `to_lane` at `position`,
## or at a random position through spawn() when `position` is null, then rolls
## its arrow. Inside its own lane the slot is emptied without compacting, the
## unit is placed at `position` (computed with the mover still in place), stale
## forced targets end, then the lane compacts. A same-lane move without a
## position, or onto a position that is no longer free, does nothing.
## Returns true when the unit moved.
static func move(e, unit: Dictionary, to_lane: int, position) -> bool:
	var from_lane = int(unit.get("lane", -1))
	var slot = slot_of(e, unit)
	if slot == -1 or to_lane < 0 or to_lane > 2:
		return false
	var owner = int(unit.owner)
	if position != null and not position_open(e, to_lane, owner, int(position)):
		return false
	if to_lane == from_lane:
		if position == null:
			return false
		e.state.lanes[from_lane].units[owner][slot] = null
		place(e, unit, to_lane, int(position))
		clear_stale_targets(e, to_lane)
		compact(e, to_lane)
		if not e._deploying:
			roll_arrow(e, unit)
		normalize_arrows(e, to_lane)
	else:
		release_attackers(e, from_lane, unit, slot)
		e.state.lanes[from_lane].units[owner][slot] = null
		compact(e, from_lane)
		normalize_arrows(e, from_lane)
		unit.combat_target = -1
		unit.arrow = 0
		if position == null:
			spawn(e, unit, to_lane)
		else:
			place(e, unit, to_lane, int(position))
		if not e._deploying:
			roll_arrow(e, unit)
		clear_stale_targets(e, to_lane)
		normalize_arrows(e, to_lane)
	e._event("move", {"uid": int(unit.uid), "card": str(unit.card), "p": owner, "from": from_lane, "to": to_lane,
		"slot": slot_of(e, unit)})
	if to_lane != from_lane:
		Kernel.emit(e, "unit_entered", {"unit": int(unit.uid), "lane": to_lane, "how": "move"})
	return true

## Exchanges two units of the same row (spec §3.7). Arrows stay with the
## positions (RQ-30), forced combat targets included: the unit now in a
## position inherits that position's arrow and forced target, and an enemy
## whose forced target was one of the two keeps its arrow and now attacks the
## unit in that position. Swaps are not entering a lane (RQ-21). Returns true
## when they swapped.
static func swap(e, a: Dictionary, b: Dictionary) -> bool:
	var lane_index = int(a.get("lane", -1))
	if lane_index < 0 or int(b.get("lane", -1)) != lane_index or int(a.owner) != int(b.owner) or int(a.uid) == int(b.uid):
		return false
	var slot_a = slot_of(e, a)
	var slot_b = slot_of(e, b)
	if slot_a == -1 or slot_b == -1:
		return false
	var row: Array = e.state.lanes[lane_index].units[int(a.owner)]
	row[slot_a] = b
	row[slot_b] = a
	var arrow_a = int(a.arrow)
	var forced_a = int(a.get("combat_target", -1))
	a.arrow = int(b.arrow)
	a.combat_target = int(b.get("combat_target", -1))
	b.arrow = arrow_a
	b.combat_target = forced_a
	for enemy in e.state.lanes[lane_index].units[1 - int(a.owner)]:
		if enemy == null:
			continue
		var forced = int(enemy.get("combat_target", -1))
		if forced == int(a.uid):
			enemy.combat_target = int(b.uid)
		elif forced == int(b.uid):
			enemy.combat_target = int(a.uid)
	clear_stale_targets(e, lane_index)
	normalize_arrows(e, lane_index)
	e._event("swap", {"a": int(a.uid), "b": int(b.uid), "card": str(a.card), "other": str(b.card), "p": int(a.owner),
		"lane": lane_index})
	return true

## Gives control of `unit` to `new_owner` (spec §3.7, RQ-17): its attackers
## are released and it leaves its row, then enters the new owner's row in the
## same lane at a random empty position (otherwise a new end) and rolls its
## arrow. Its modifications keep their original player (Purge provenance).
## Roster heroes never change sides (no Classic card does that). Returns true
## when control changed.
static func control(e, unit: Dictionary, new_owner: int) -> bool:
	var lane_index = int(unit.get("lane", -1))
	var slot = slot_of(e, unit)
	var old_owner = int(unit.owner)
	if slot == -1 or old_owner == new_owner or bool(unit.get("roster", false)):
		return false
	release_attackers(e, lane_index, unit, slot)
	e.state.lanes[lane_index].units[old_owner][slot] = null
	compact(e, lane_index)
	unit.owner = new_owner
	unit.combat_target = -1
	unit.arrow = 0
	spawn(e, unit, lane_index)
	if not e._deploying:
		roll_arrow(e, unit)
	clear_stale_targets(e, lane_index)
	normalize_arrows(e, lane_index)
	e._event("control", {"uid": int(unit.uid), "card": str(unit.card), "from": old_owner, "to": new_owner,
		"lane": lane_index, "slot": slot_of(e, unit)})
	Kernel.emit(e, "unit_entered", {"unit": int(unit.uid), "lane": lane_index, "how": "control"})
	return true

## Summons a fresh unit of `card_id` for `owner` into `lane_index`: a random
## empty own slot, otherwise a random end; then its arrow (deferred to the
## deployment roll while deploying). A summoned hero joins its owner's roster
## (RQ-29, Kernel.SUMMONED_HEROES_JOIN_ROSTER), so it goes to the Fountain
## when it dies and is redeployed like any hero.
static func summon(e, card_id: String, owner: int, lane_index: int) -> Dictionary:
	var definition = e._definition_or_creep(card_id)
	var hero = str(definition.get("kind", "creep")) == "hero"
	var unit = e._make_unit(definition, owner, hero)
	unit["roster"] = hero and Kernel.SUMMONED_HEROES_JOIN_ROSTER
	if bool(unit.roster):
		e.state.players[owner].roster.append(unit)
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
		# Handles are found by iid: indexes shift as cards leave the hand.
		var indices: Array = []
		var ids: Array = []
		for card in by_player[player]:
			var index = hand_index(e, card)
			if index != -1 and not indices.has(index):
				indices.append(index)
				ids.append(str(e.state.players[player].hand[index]))
		if indices.is_empty():
			continue
		indices.sort()
		indices.reverse()
		for index in indices:
			take_from_hand(e, player, index)
		e._event("discard", {"p": player, "n": indices.size()}, {str(player): {"cards": ids}})

## The hidden state entry of a card handle ({cardref, p, zone, index, iid}),
## found by its iid in the hand (indexes shift when cards leave) or by its
## index in the deck; {} when the card is no longer there. A deck entry is
## materialized (deck_state padded with {}) when `create` is set.
static func card_entry(e, card, create: bool = false) -> Dictionary:
	if not card is Dictionary or not card.has("cardref"):
		return {}
	var owner: Dictionary = e.state.players[int(card.p)]
	if str(card.zone) == "hand":
		var states: Array = owner.get("hand_state", [])
		for index in range(states.size()):
			if states[index] is Dictionary and int(states[index].get("iid", -1)) == int(card.get("iid", -2)):
				return states[index]
		return {}
	var deck: Array = owner.get("deck", [])
	var index = int(card.index)
	if index < 0 or index >= deck.size() or str(deck[index]) != str(card.card):
		return {}
	if not owner.has("deck_state"):
		owner["deck_state"] = []
	var deck_states: Array = owner.deck_state
	if deck_states.is_empty():
		if not create:
			return {}
		for count in range(deck.size()):
			deck_states.append({})
	if not deck_states[index] is Dictionary:
		deck_states[index] = {}
	return deck_states[index]

## The hand index of a card handle now (by iid), or -1.
static func hand_index(e, card) -> int:
	if not card is Dictionary or not card.has("cardref") or str(card.get("zone", "")) != "hand":
		return -1
	var states: Array = e.state.players[int(card.p)].get("hand_state", [])
	for index in range(states.size()):
		if states[index] is Dictionary and int(states[index].get("iid", -1)) == int(card.get("iid", -2)):
			return index
	return -1

## Adds `n` locks to each card in hand (RQ-14: locks stack; each locked card
## loses one lock per round). The holder learns which cards; the log only the count.
static func lock(e, cards: Array, n: int) -> void:
	if n <= 0:
		return
	var locked = [[], []]
	for card in cards:
		var index = hand_index(e, card)
		if index == -1:
			continue
		var entry: Dictionary = e.state.players[int(card.p)].hand_state[index]
		entry["lock"] = int(entry.get("lock", 0)) + n
		locked[int(card.p)].append(index)
	for player in range(2):
		if not locked[player].is_empty():
			e._event("lock", {"p": player, "n": locked[player].size()}, {str(player): {"idx": locked[player]}})

## Appends `card_id` to `player`'s hand with a fresh iid. A base copy is
## marked base and starts without locks, charges or hacks (RQ-36). The
## receiver learns the card; the log only that a card was gained.
static func add_card(e, player: int, card_id: String, base: bool) -> void:
	var owner: Dictionary = e.state.players[player]
	var entry: Dictionary = {"iid": Kernel.next_oid(e)}
	if base:
		entry["base"] = true
	owner.hand.append(card_id)
	if not owner.has("hand_state"):
		owner["hand_state"] = []
	owner.hand_state.append(entry)
	e._event("gain_card", {"p": player}, {str(player): {"card": card_id}})

## Adds `amount` to a counter of cards in hand or deck, starting from the
## card's printed value when nothing is stored (CF-2). Hidden: the log shows
## how many cards of a player changed.
static func add_card_counter(e, cards: Array, counter: String, amount: int) -> void:
	var changed = [0, 0]
	for card in cards:
		if not card is Dictionary or not card.has("cardref"):
			continue
		var present = hand_index(e, card) != -1 if str(card.zone) == "hand" else _deck_card_present(e, card)
		if not present:
			continue
		var stored: Dictionary = card_entry(e, card, true)
		if not stored.has(counter):
			stored[counter] = int(e.library.get_card(str(card.card)).get(counter, 0))
		stored[counter] = int(stored[counter]) + amount
		changed[int(card.p)] += 1
	for player in range(2):
		if changed[player] > 0:
			e._event("charged", {"p": player, "n": changed[player]})

static func _deck_card_present(e, card: Dictionary) -> bool:
	var deck: Array = e.state.players[int(card.p)].get("deck", [])
	return int(card.index) >= 0 and int(card.index) < deck.size() and str(deck[int(card.index)]) == str(card.card)

## Appends the hack `ability` ("<card>#<grant index>") to cards in hand
## (spec §3.12). The holder learns which cards; the caster only how many.
static func hack(e, cards: Array, ability: String) -> void:
	var hacked = [[], []]
	for card in cards:
		var index = hand_index(e, card)
		if index == -1:
			continue
		var entry: Dictionary = e.state.players[int(card.p)].hand_state[index]
		if not entry.has("hacks"):
			entry["hacks"] = []
		entry.hacks.append(ability)
		hacked[int(card.p)].append(index)
	for player in range(2):
		if not hacked[player].is_empty():
			e._event("hack", {"p": player, "n": hacked[player].size()}, {str(player): {"idx": hacked[player]}})

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
		var hand = str(value.zone) == "hand"
		var states: Array = owner.get("hand_state" if hand else "deck_state", [])
		# A hand handle is found by iid (indexes shift as cards leave the hand).
		var index = hand_index(e, value) if hand else int(value.index)
		if index >= 0 and index < states.size() and states[index] is Dictionary:
			entry = states[index]
	if entry.has("charges"):
		return int(entry.charges)
	return int(e.library.get_card(card_id).get("charges", 0))
