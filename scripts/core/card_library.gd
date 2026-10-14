extends RefCounted
## Data and effect implementations are separate. Unimplemented cards must never
## silently enter a playable deck.

const PACKS = {
	"artifact_classic_decks_v2": "res://data/classic_cards.json",
	"original_training_fixtures": "res://data/training_cards.json"}
var cards: Dictionary = {}
var heroes: Array = []
var content_pack: String
var catalog: Dictionary

func _init(pack: String = "artifact_classic_decks_v2") -> void:
	assert(PACKS.has(pack), "Unsupported content pack")
	content_pack = pack
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PACKS[pack]))
	assert(parsed is Dictionary, "Invalid card catalog")
	catalog = parsed
	heroes = parsed.heroes
	for card in parsed.cards:
		cards[card.id] = card

func get_card(card_id: String) -> Dictionary:
	return cards.get(card_id, {})

func definition(card_id: String) -> Dictionary:
	if cards.has(card_id):
		return cards[card_id]
	for hero in heroes:
		if hero.id == card_id:
			return hero
	return {}

func match_deck(preset_id: String = "starter") -> Array:
	if not catalog.has("deck"):
		return training_deck()
	return expand_counts(preset(preset_id).get("cards", catalog.deck))

func expand_counts(counts: Dictionary) -> Array:
	var result: Array = []
	for card_id in counts:
		assert(cards.has(card_id), "Unsupported card in deck")
		for copy in range(int(counts[card_id])):
			result.append(card_id)
	return result

func presets() -> Array:
	return catalog.get("presets", [])

func preset(preset_id: String) -> Dictionary:
	for entry in presets():
		if entry.id == preset_id:
			return entry
	return {}

func match_heroes(preset_id: String = "starter") -> Array:
	if presets().is_empty():
		return heroes
	var result: Array = []
	for hero_id in preset(preset_id).heroes:
		result.append(definition(hero_id))
	return result

func item_deck(preset_id: String) -> Array:
	return expand_counts(preset(preset_id).get("items", {}))

func validate_preset(entry: Dictionary) -> Dictionary:
	if not entry.get("heroes") is Array or entry.heroes.size() != 5:
		return {"ok": false, "error": "A deck needs five heroes."}
	var seen: Array = []
	for hero_id in entry.heroes:
		var hero = definition(str(hero_id))
		if hero.is_empty() or hero.get("kind", "") != "hero" or hero_id in seen:
			return {"ok": false, "error": "Heroes must be supported and unique."}
		seen.append(hero_id)
	if not entry.get("cards") is Dictionary or not entry.get("items") is Dictionary:
		return {"ok": false, "error": "Missing main or item deck."}
	var main_count = 0
	for card_id in entry.cards:
		var card = get_card(str(card_id))
		var count = entry.cards[card_id]
		if card.is_empty() or card.kind not in ["creep", "spell", "improvement"] or card_id == "melee_creep":
			return {"ok": false, "error": "Unsupported main-deck card."}
		if not (count is int or count is float) or float(count) != floor(float(count)) or count < 1 or count > 3:
			return {"ok": false, "error": "Main cards need one to three whole copies."}
		main_count += int(count)
	if main_count < 40:
		return {"ok": false, "error": "The main deck needs at least forty cards."}
	for hero_id in entry.heroes:
		if int(entry.cards.get(definition(hero_id).signature, 0)) != 3:
			return {"ok": false, "error": "Each hero requires three signature copies."}
	var item_count = 0
	for card_id in entry.items:
		var card = get_card(str(card_id))
		var count = entry.items[card_id]
		if card.is_empty() or card.kind != "item" or card.get("consumable", false):
			return {"ok": false, "error": "Item decks use supported equipment."}
		if not (count is int or count is float) or float(count) != floor(float(count)) or count < 1:
			return {"ok": false, "error": "Item counts must be positive whole numbers."}
		item_count += int(count)
	if item_count < 9:
		return {"ok": false, "error": "The item deck needs at least nine cards."}
	return {"ok": true}

func training_deck() -> Array:
	# Forty cards; original test content, not a legal Classic constructed deck.
	var result: Array = []
	for card_id in cards:
		if cards[card_id].kind != "item":
			for copy in range(3 if card_id != "red_veteran" else 1):
				result.append(card_id)
	return result

func shop_cards() -> Array:
	return catalog.get("shop", ["training_sword", "training_plate", "training_cloak"])
