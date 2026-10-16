extends RefCounted
## Edits to a player's own deck (DeckStore shape: heroes = five slots in
## deploy order, "" when empty; cards with the heroes' signature cards;
## items), as pure functions shared by the deck builder and tests.
##
## Rules the builder keeps while editing (Classic constructed): a hero joins
## the first free slot (or the slot it is dropped on) and brings three copies
## of its signature card, which are locked: they leave only with their hero.
## Main cards and items take one to three copies; a hero appears once. Only
## cards a deck may hold are offered (CardLibrary.main_deckable,
## item_deckable and deckable heroes: no drafts, no tokens).
##
## Slots 0-2 deploy in round 1, slot 3 in round 2 and slot 4 in round 3
## (MatchEngine: ready_round = 1, 1, 1, 2, 3).

const MAX_COPIES = 3
const SIGNATURE_COPIES = 3
const SLOTS = 5
## Mana curve buckets: costs 1 to 7, then 8 and more.
const CURVE_TOP = 8
const MAIN_KINDS = ["creep", "spell", "improvement"]

## The round slot `index` deploys in (1, 2 or 3).
static func round_of_slot(index: int) -> int:
	return 1 if index < 3 else index - 1

## A deck with exactly five hero slots and its lists present (in place).
static func normalize(deck: Dictionary) -> Dictionary:
	var heroes: Array = deck.get("heroes", []) if deck.get("heroes") is Array else []
	while heroes.size() < SLOTS:
		heroes.append("")
	if heroes.size() > SLOTS:
		heroes = heroes.slice(0, SLOTS)
	deck["heroes"] = heroes.map(func(hero_id): return str(hero_id))
	for list_name in ["cards", "items"]:
		if not deck.get(list_name) is Dictionary:
			deck[list_name] = {}
	return deck

## Copies of `card_id` in the deck (main or item list; 1 for a hero in it).
static func count_of(deck: Dictionary, card_id: String) -> int:
	if card_id in deck.get("heroes", []):
		return 1
	return int(deck.get("cards", {}).get(card_id, deck.get("items", {}).get(card_id, 0)))

static func hero_count(deck: Dictionary) -> int:
	return deck.get("heroes", []).filter(func(hero_id): return not str(hero_id).is_empty()).size()

## Signature cards of the deck's heroes: {card id: hero id}.
static func signatures(deck: Dictionary, library) -> Dictionary:
	var result: Dictionary = {}
	for hero_id in deck.get("heroes", []):
		if not str(hero_id).is_empty():
			var signature = str(library.definition(str(hero_id)).get("signature", ""))
			if not signature.is_empty():
				result[signature] = str(hero_id)
	return result

## True when `card_id` is a locked signature card of one of the deck's heroes.
static func is_locked(deck: Dictionary, card_id: String, library) -> bool:
	return signatures(deck, library).has(card_id)

## Whether one more copy of `card_id` may be added (hero, main card or item).
static func can_add(deck: Dictionary, card_id: String, library) -> bool:
	if library.definition(card_id).get("kind", "") == "hero":
		return library.hero_deckable(card_id) and card_id not in deck.heroes and hero_count(deck) < SLOTS
	if library.main_deckable(card_id):
		return int(deck.cards.get(card_id, 0)) < MAX_COPIES
	if library.item_deckable(card_id):
		return int(deck.items.get(card_id, 0)) < MAX_COPIES
	return false

## Adds one copy of a card, or a hero to the first free slot. False when the
## deck rules forbid it.
static func add(deck: Dictionary, card_id: String, library) -> bool:
	if library.definition(card_id).get("kind", "") == "hero":
		var free = deck.heroes.find("")
		return free != -1 and card_id not in deck.heroes and place_hero(deck, card_id, free, library)
	if not can_add(deck, card_id, library):
		return false
	var list: Dictionary = deck.cards if library.main_deckable(card_id) else deck.items
	list[card_id] = int(list.get(card_id, 0)) + 1
	return true

## Removes one copy of a main card or item (a hero's signature card is
## locked). False when there is nothing to remove.
static func remove(deck: Dictionary, card_id: String, library) -> bool:
	var slot = deck.heroes.find(card_id)
	if slot != -1:
		return remove_hero(deck, slot, library)
	if is_locked(deck, card_id, library):
		return false
	for list_name in ["cards", "items"]:
		var list: Dictionary = deck[list_name]
		if list.has(card_id):
			list[card_id] = int(list[card_id]) - 1
			if int(list[card_id]) <= 0:
				list.erase(card_id)
			return true
	return false

## Puts `hero_id` into hero slot `slot`. A hero already in the deck moves
## there (swapping with the slot's hero); a hero already in that slot
## leaves the deck with its signature cards. The new hero brings three copies
## of its signature card.
static func place_hero(deck: Dictionary, hero_id: String, slot: int, library) -> bool:
	if slot < 0 or slot >= SLOTS or library.definition(hero_id).get("kind", "") != "hero" or not library.hero_deckable(hero_id):
		return false
	var current = deck.heroes.find(hero_id)
	if current != -1:
		return move_hero(deck, current, slot)
	if not str(deck.heroes[slot]).is_empty():
		remove_hero(deck, slot, library)
	deck.heroes[slot] = hero_id
	var signature = str(library.definition(hero_id).get("signature", ""))
	if not signature.is_empty():
		deck.cards[signature] = SIGNATURE_COPIES
	return true

## Takes the hero in `slot` out of the deck with its signature cards.
static func remove_hero(deck: Dictionary, slot: int, library) -> bool:
	if slot < 0 or slot >= SLOTS or str(deck.heroes[slot]).is_empty():
		return false
	var hero_id = str(deck.heroes[slot])
	deck.heroes[slot] = ""
	var signature = str(library.definition(hero_id).get("signature", ""))
	if not signature.is_empty() and not signatures(deck, library).has(signature):
		deck.cards.erase(signature)
	return true

## Swaps hero slots `from` and `to` (deploy order; empty slots move too).
static func move_hero(deck: Dictionary, from: int, to: int) -> bool:
	if from < 0 or from >= SLOTS or to < 0 or to >= SLOTS or str(deck.heroes[from]).is_empty():
		return false
	if from == to:
		return true
	var moving = deck.heroes[from]
	deck.heroes[from] = deck.heroes[to]
	deck.heroes[to] = moving
	return true

## Drops what the builder cannot edit: unknown or unavailable heroes and
## cards (a deck saved by another version, or an imported code) and copies
## beyond the limits; restores the heroes' three signature copies.
## Returns the dropped card ids.
static func repair(deck: Dictionary, library) -> Array:
	normalize(deck)
	var dropped: Array = []
	var seen: Array = []
	for slot in range(SLOTS):
		var hero_id = str(deck.heroes[slot])
		if hero_id.is_empty():
			continue
		if library.definition(hero_id).get("kind", "") != "hero" or not library.hero_deckable(hero_id) or hero_id in seen:
			dropped.append(hero_id)
			deck.heroes[slot] = ""
		else:
			seen.append(hero_id)
	var own = signatures(deck, library)
	for card_id in deck.cards.keys():
		if own.has(card_id):
			continue
		if not library.main_deckable(card_id):
			dropped.append(card_id)
			deck.cards.erase(card_id)
		elif int(deck.cards[card_id]) > MAX_COPIES:
			deck.cards[card_id] = MAX_COPIES
	for card_id in deck.items.keys():
		if not library.item_deckable(card_id):
			dropped.append(card_id)
			deck.items.erase(card_id)
		elif int(deck.items[card_id]) > MAX_COPIES:
			deck.items[card_id] = MAX_COPIES
	for signature in own:
		deck.cards[signature] = SIGNATURE_COPIES
	return dropped

static func main_count(deck: Dictionary) -> int:
	var total = 0
	for card_id in deck.get("cards", {}):
		total += int(deck.cards[card_id])
	return total

static func item_count(deck: Dictionary) -> int:
	var total = 0
	for card_id in deck.get("items", {}):
		total += int(deck.items[card_id])
	return total

## Numbers for the builder's charts: {"curve": [[creeps, spells,
## improvements] per cost 1..8+], "kinds": {kind: copies}, "colors": {color:
## {"heroes", "cards"}}, "slots": {slot: copies}, "average": main deck mana
## cost, "main", "items"}.
static func stats(deck: Dictionary, library) -> Dictionary:
	var curve: Array = []
	for bucket in range(CURVE_TOP):
		curve.append([0, 0, 0])
	var kinds = {"creep": 0, "spell": 0, "improvement": 0}
	var colors: Dictionary = {}
	var slots = {"weapon": 0, "armor": 0, "accessory": 0}
	var cost_total = 0
	var main = 0
	for hero_id in deck.get("heroes", []):
		if str(hero_id).is_empty():
			continue
		var color = str(library.definition(str(hero_id)).get("color", "neutral"))
		if not colors.has(color):
			colors[color] = {"heroes": 0, "cards": 0}
		colors[color].heroes += 1
	for card_id in deck.get("cards", {}):
		var card: Dictionary = library.get_card(str(card_id))
		var copies = int(deck.cards[card_id])
		var kind = str(card.get("kind", ""))
		if not kind in MAIN_KINDS:
			continue
		var cost = int(card.get("cost", 0))
		curve[clampi(cost, 1, CURVE_TOP) - 1][MAIN_KINDS.find(kind)] += copies
		kinds[kind] += copies
		cost_total += cost * copies
		main += copies
		var color = str(card.get("color", "neutral"))
		if not colors.has(color):
			colors[color] = {"heroes": 0, "cards": 0}
		colors[color].cards += copies
	var items = 0
	for card_id in deck.get("items", {}):
		var slot = str(library.get_card(str(card_id)).get("slot", ""))
		var copies = int(deck.items[card_id])
		if slots.has(slot):
			slots[slot] += copies
		items += copies
	return {"curve": curve, "kinds": kinds, "colors": colors, "slots": slots,
		"average": float(cost_total) / main if main > 0 else 0.0, "main": main, "items": items}
