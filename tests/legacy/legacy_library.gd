extends RefCounted
## FROZEN legacy card library (commit 1573c6b), the reference for
## tests/differential_test.gd. It reads the frozen schema-3 data next to it.
## Do not change it, except to apply a deliberate fidelity fix (FX-n) that the
## new rules engine also applies.
## Data and effect implementations are separate. Unimplemented cards must never
## silently enter a playable deck.
##
## Rules data (data/*.json) is read for ids and numbers. Display text lives in
## data/locale/cards.json per skin and locale: use the static loc() helpers.

const Settings = preload("res://scripts/core/game_settings.gd")
const PACKS = {
	"artifact_classic_decks_v2": "res://tests/legacy/classic_cards_v3.json",
	"original_training_fixtures": "res://tests/legacy/training_cards_v1.json"}
const LOCALE_PATH = "res://data/locale/cards.json"
const GLOSSARY_PATH = "res://data/locale/glossary.json"
const FALLBACK_LOCALE = "en"
static var _locale_data: Dictionary = {}
static var _glossary: Dictionary = {}
static var _raw_definitions: Dictionary = {}
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
		return {"ok": false, "code": "deck_hero_count", "args": {}, "error": "A deck needs five heroes."}
	var seen: Array = []
	for hero_id in entry.heroes:
		var hero = definition(str(hero_id))
		if hero.is_empty() or hero.get("kind", "") != "hero" or hero_id in seen:
			return {"ok": false, "code": "deck_hero_invalid", "args": {}, "error": "Heroes must be supported and unique."}
		seen.append(hero_id)
	if not entry.get("cards") is Dictionary or not entry.get("items") is Dictionary:
		return {"ok": false, "code": "deck_missing_lists", "args": {}, "error": "Missing main or item deck."}
	var main_count = 0
	for card_id in entry.cards:
		var card = get_card(str(card_id))
		var count = entry.cards[card_id]
		if card.is_empty() or card.kind not in ["creep", "spell", "improvement"] or card_id == "melee_creep":
			return {"ok": false, "code": "deck_main_card", "args": {}, "error": "Unsupported main-deck card."}
		if not (count is int or count is float) or float(count) != floor(float(count)) or count < 1 or count > 3:
			return {"ok": false, "code": "deck_main_copies", "args": {}, "error": "Main cards need one to three whole copies."}
		main_count += int(count)
	if main_count < 40:
		return {"ok": false, "code": "deck_main_size", "args": {}, "error": "The main deck needs at least forty cards."}
	for hero_id in entry.heroes:
		if int(entry.cards.get(definition(hero_id).signature, 0)) != 3:
			return {"ok": false, "code": "deck_signatures", "args": {}, "error": "Each hero requires three signature copies."}
	var item_count = 0
	for card_id in entry.items:
		var card = get_card(str(card_id))
		var count = entry.items[card_id]
		if card.is_empty() or card.kind != "item" or card.get("consumable", false):
			return {"ok": false, "code": "deck_item_card", "args": {}, "error": "Item decks use supported equipment."}
		if not (count is int or count is float) or float(count) != floor(float(count)) or count < 1:
			return {"ok": false, "code": "deck_item_copies", "args": {}, "error": "Item counts must be positive whole numbers."}
		item_count += int(count)
	if item_count < 9:
		return {"ok": false, "code": "deck_item_size", "args": {}, "error": "The item deck needs at least nine cards."}
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

# --- Display text -----------------------------------------------------------

## Display text for a card, hero, token or item by id. `field` is "name",
## "text" or "ability_name". Uses the current skin and locale unless given;
## falls back zh_CN -> en -> the raw definition field -> the card id (names
## only). {placeholders} are filled from the card definition's numbers.
static func loc(card_id: String, field: String = "name", locale: String = "", skin: String = "") -> String:
	var definition = raw_definition(card_id)
	var entry = _skin_section(skin, "cards").get(card_id, {})
	var text = _pick(entry.get(field), _resolve_locale(locale))
	if text.is_empty():
		text = str(definition.get(field, ""))
	if text.is_empty() and field == "name":
		text = card_id
	return format_text(text, definition)

## Deck preset display text; `field` is "name" or "description".
static func preset_text(preset_id: String, field: String = "name", locale: String = "", skin: String = "") -> String:
	var entry = _skin_section(skin, "presets").get(preset_id, {})
	var text = _pick(entry.get(field), _resolve_locale(locale))
	if not text.is_empty():
		return text
	for path in PACKS.values():
		for preset in _read_json(path).get("presets", []):
			if preset is Dictionary and str(preset.get("id", "")) == preset_id:
				return str(preset.get(field, preset_id))
	return preset_id if field == "name" else ""

## Faction id (shu, wei, wu, qun or neutral) for Three Kingdoms badges.
static func faction(card_id: String) -> String:
	var entry = locale_data().get("skins", {}).get("three_kingdoms", {}).get("cards", {}).get(card_id, {})
	return str(entry.get("faction", "neutral"))

## Glossary term by key (data/locale/glossary.json), e.g. "tower" -> "Tower"
## or "城楼". Unknown keys return the key itself.
static func term(key: String, locale: String = "") -> String:
	var entry = glossary().get(key, {})
	return _pick(entry, _resolve_locale(locale)) if not entry.is_empty() else key

## Every glossary entry keyed by term key: {key, en, en_alias, zh_CN}.
static func glossary() -> Dictionary:
	if _glossary.is_empty():
		for entry in _read_json(GLOSSARY_PATH).get("terms", []):
			_glossary[str(entry.key)] = entry
	return _glossary

## Fills {field} placeholders from a definition's numeric fields.
static func format_text(text: String, definition: Dictionary) -> String:
	if not "{" in text:
		return text
	var values: Dictionary = {}
	for key in definition:
		var value = definition[key]
		if value is int or value is float:
			values[key] = str(int(value))
	return text.format(values)

static func current_locale() -> String:
	return Settings.normalize_locale(TranslationServer.get_locale())

static func current_skin() -> String:
	return Settings.skin

static func skins() -> Array:
	return locale_data().get("skins", {}).keys()

static func locale_data() -> Dictionary:
	if _locale_data.is_empty():
		_locale_data = _read_json(LOCALE_PATH)
	return _locale_data

## A rules definition by id from any content pack, without a library instance.
static func raw_definition(card_id: String) -> Dictionary:
	if _raw_definitions.is_empty():
		for path in PACKS.values():
			var parsed = _read_json(path)
			for entry in parsed.get("heroes", []) + parsed.get("cards", []):
				if entry is Dictionary and not _raw_definitions.has(str(entry.get("id", ""))):
					_raw_definitions[str(entry.id)] = entry
	return _raw_definitions.get(card_id, {})

static func _skin_section(skin: String, section: String) -> Dictionary:
	var skin_id = skin if not skin.is_empty() else Settings.skin
	var all_skins = locale_data().get("skins", {})
	if not all_skins.has(skin_id):
		skin_id = str(locale_data().get("default_skin", Settings.DEFAULT_SKIN))
	return all_skins.get(skin_id, {}).get(section, {})

static func _resolve_locale(locale: String) -> String:
	return Settings.normalize_locale(locale) if not locale.is_empty() else current_locale()

## Plain strings are used as-is; {locale: text} dictionaries fall back to en.
static func _pick(value, locale: String) -> String:
	if value is String:
		return value
	if value is Dictionary:
		for key in [locale, FALLBACK_LOCALE]:
			if not str(value.get(key, "")).is_empty():
				return str(value[key])
	return ""

static func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
