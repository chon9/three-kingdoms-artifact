class_name CardLibrary
extends RefCounted
## Card data and compiled rules. Unimplemented cards must never silently enter
## a playable deck: a card with any rules error is unplayable and listed in
## `errors`, and presets accept only verified, non-token cards (K13).
##
## Rules data (data/*.json, schema 4) is compiled once per pack by
## scripts/core/rules/rules_db.gd. Display text lives in data/locale/cards.json
## per skin and locale: use the static loc() helpers.

const Settings = preload("res://scripts/core/game_settings.gd")
const RulesDB = preload("res://scripts/core/rules/rules_db.gd")
const PACKS = {
	"artifact_classic_decks_v2": "res://data/classic_cards.json",
	"original_training_fixtures": "res://data/training_cards.json"}
## Item slots an item deck may hold (wiki Item Shop; consumables and Deeds
## are sold only by the Secret Shop and the Consumables Shop).
const EQUIPMENT_SLOTS = ["weapon", "armor", "accessory"]
const LOCALE_PATH = "res://data/locale/cards.json"
const GLOSSARY_PATH = "res://data/locale/glossary.json"
const FALLBACK_LOCALE = "en"
const NO_RULES = {"abilities": [], "auras": [], "events": {}, "grant_events": {}, "grants": [], "active": -1,
	"host": {}, "play": {}, "enter": [], "keywords": {}, "params": {}, "errors": [], "status": "",
	"static": {"draw": 0, "initiative": false, "random": false, "bias": 0.0, "lock": 0, "hack": 0, "mana": false},
	"ability_static": {}}
static var _locale_data: Dictionary = {}
static var _glossary: Dictionary = {}
static var _raw_definitions: Dictionary = {}
## Parsed and compiled packs, shared by every library instance (card data is
## read-only at runtime; the bot creates one engine per simulated action).
static var _packs: Dictionary = {}
## Packs loaded with from_file() (test packs such as the M2 rules fixtures,
## tests/fixtures/rules_fixtures.json): pack id -> {"path", "compiled"}. They
## are never in PACKS, never in a shipped preset and never exported; once
## loaded, the static helpers (raw_definition, compiled_rules, loc) and
## replays find their cards too.
static var _extra: Dictionary = {}
var cards: Dictionary = {}
var heroes: Array = []
var content_pack: String
var catalog: Dictionary
## Card id -> compiled rules (rules_db.gd).
var compiled: Dictionary = {}
## "card_id.path: message" for every rules error and warning of the pack.
var errors: Array = []
var warnings: Array = []
## Event -> {card_id: true} for cards whose abilities listen to it.
var listening: Dictionary = {}
## Event -> true when any card can grant a trigger that listens to it.
var grant_listening: Dictionary = {}
## Card ids with at least one aura (aura sources are scanned per stat read).
var aura_cards: Dictionary = {}
## "<target>:<field>" -> {card_id: true} for cards with an aura that changes
## that field of that kind of object (for example "units:attack",
## "towers:mana", "players:rules"), so a read scans only the sources that can
## change it.
var aura_fields: Dictionary = {}
## Fields that some card's grants can give as a board aura (granted text;
## granted "$host" auras change only their bearer and are not listed).
var granted_aura_fields: Dictionary = {}
## "<target>:<field>" -> {"unit": true, "item": true, "improvement": true,
## "deed": true}: where the cards with such an aura live, so a scan skips the
## zones that cannot hold one.
var aura_holders: Dictionary = {}

func _init(pack: String = "artifact_classic_decks_v2") -> void:
	assert(PACKS.has(pack), "Unsupported content pack")
	content_pack = pack
	var data = _pack(pack)
	catalog = data.catalog
	heroes = data.heroes
	cards = data.cards
	compiled = data.compiled
	errors = data.errors
	warnings = data.warnings
	listening = data.listening
	grant_listening = data.grant_listening
	aura_cards = data.aura_cards
	aura_fields = data.aura_fields
	granted_aura_fields = data.granted_aura_fields
	aura_holders = data.aura_holders

static func _pack(pack: String) -> Dictionary:
	if _packs.has(pack):
		return _packs[pack]
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PACKS[pack]))
	assert(parsed is Dictionary, "Invalid card catalog")
	var data = {"catalog": parsed, "heroes": parsed.heroes, "cards": {}, "compiled": {}, "errors": [],
		"warnings": [], "listening": {}, "grant_listening": {}, "aura_cards": {}, "aura_fields": {},
		"granted_aura_fields": {}, "aura_holders": {}}
	for card in parsed.cards:
		data.cards[card.id] = card
	var entries: Array = []
	for hero in parsed.heroes:
		var entry = hero.duplicate()
		if not entry.has("kind"):
			entry["kind"] = "hero"
		entries.append(entry)
	entries.append_array(parsed.cards)
	for entry in entries:
		_index(data, str(entry.id), RulesDB.compile(entry))
	_check_links(data, entries)
	_packs[pack] = data
	return data

## Adds one compiled card to a pack's indexes (`data` holds the same keys as
## the library fields: compiled, errors, warnings, listening...).
static func _index(data: Dictionary, id: String, rules: Dictionary) -> void:
	data.compiled[id] = rules
	data.errors.append_array(rules.errors)
	data.warnings.append_array(rules.warnings)
	for event in rules.events:
		if not data.listening.has(event):
			data.listening[event] = {}
		data.listening[event][id] = true
	for event in rules.grant_events:
		data.grant_listening[event] = true
	if not rules.auras.is_empty():
		data.aura_cards[id] = true
	var holder = {"hero": "unit", "creep": "unit", "improvement": "improvement"}.get(str(rules.get("kind", "")), "item")
	if str(rules.get("kind", "")) == "item" and data.cards.get(id, {}).get("slot", "") == "deed":
		holder = "deed"
	for index in rules.auras:
		for field in aura_grant_fields(rules.abilities[index]):
			if not data.aura_fields.has(field):
				data.aura_fields[field] = {}
			data.aura_fields[field][id] = true
			if not data.aura_holders.has(field):
				data.aura_holders[field] = {}
			data.aura_holders[field][holder] = true
	for granted in rules.grants:
		# A granted "$host" aura changes only its bearer, which reads it from
		# its own entries (Stats._derive), so it never makes a read scan the
		# board for granted auras (M6: Stonehall's growth on every max-health read).
		if str(granted.get("kind", "")) == "aura" and not (granted.get("affects") is String and str(granted.affects) == "$host"):
			for field in aura_grant_fields(granted):
				data.granted_aura_fields[field] = true

## Checks that need the whole pack (RulesDB sees one card at a time): every
## summoned card is a unit of the pack and every signature is a card of the
## pack (errors, so the card is unplayable), and every parameter is read by
## the rules or by a locale {placeholder} (a warning that catches typos such
## as "amout").
static func _check_links(data: Dictionary, entries: Array) -> void:
	var units: Dictionary = {"melee_creep": true}
	for hero in data.heroes:
		units[str(hero.id)] = true
	for card_id in data.cards:
		if str(data.cards[card_id].get("kind", "")) in ["hero", "creep"]:
			units[str(card_id)] = true
	for entry in entries:
		var id = str(entry.get("id", ""))
		var rules: Dictionary = data.compiled.get(id, {})
		if rules.is_empty():
			continue
		var problems: Array = []
		if entry.has("signature") and not data.cards.has(str(entry.signature)):
			problems.append("%s.signature: signature %s is not a card of this pack" % [id, str(entry.signature)])
		var summoned: Array = []
		for block in [rules.get("play", {}), rules.get("enter", []), rules.get("abilities", []), rules.get("grants", [])]:
			_summoned_cards(block, summoned)
		for card_id in summoned:
			if not units.has(card_id):
				problems.append("%s.summon: %s is not a hero or creep of this pack" % [id, card_id])
		rules.errors.append_array(problems)
		data.errors.append_array(problems)
		var read: Dictionary = {}
		_params_read(entry, read)
		for placeholder in _placeholders(id):
			read[placeholder] = true
		for param in rules.get("params", {}):
			if not read.has(param) and param not in RulesDB.Vocab.CARD_FIELDS:
				var message = "%s.%s: parameter %s is read by no rule and no card text (a typo?)" % [id, param, param]
				rules.warnings.append(message)
				data.warnings.append(message)

static func _summoned_cards(value, out: Array) -> void:
	if value is Dictionary:
		if str(value.get("op", "")) == "summon" and value.has("card"):
			out.append(str(value.card))
		for key in value:
			_summoned_cards(value[key], out)
	elif value is Array:
		for item in value:
			_summoned_cards(item, out)

static func _params_read(value, out: Dictionary) -> void:
	if value is Dictionary:
		if value.has("param"):
			out[str(value.param)] = true
		for key in value:
			_params_read(value[key], out)
	elif value is Array:
		for item in value:
			_params_read(item, out)

## Every {placeholder} in any skin's and locale's text for a card.
static func _placeholders(card_id: String) -> Array:
	var out: Array = []
	var pattern = RegEx.create_from_string("\\{([A-Za-z0-9_]+)\\}")
	for skin in locale_data().get("skins", {}).values():
		var entry = skin.get("cards", {}).get(card_id, {})
		if not entry is Dictionary:
			continue
		for field in entry.values():
			var texts: Array = field.values() if field is Dictionary else [field]
			for text in texts:
				for found in pattern.search_all(str(text)):
					out.append(found.get_string(1))
	return out

## What an aura changes, as "<target>:<field>" keys (rules_db.gd).
static func aura_grant_fields(aura: Dictionary) -> Array:
	return aura.get("fields", [])

## A library of `pack` plus extra card entries (test fixtures, spec M2's
## rules_fixtures pack). The extra entries are compiled into private copies,
## so the shared pack cache stays untouched.
static func with_cards(pack: String, entries: Array):
	var library = load("res://scripts/core/card_library.gd").new(pack)
	library.cards = library.cards.duplicate()
	library.compiled = library.compiled.duplicate()
	library.errors = library.errors.duplicate()
	library.warnings = library.warnings.duplicate()
	library.listening = library.listening.duplicate(true)
	library.grant_listening = library.grant_listening.duplicate()
	library.aura_cards = library.aura_cards.duplicate()
	library.aura_fields = library.aura_fields.duplicate(true)
	library.granted_aura_fields = library.granted_aura_fields.duplicate()
	library.aura_holders = library.aura_holders.duplicate(true)
	var data = {"heroes": library.heroes, "cards": library.cards, "compiled": library.compiled,
		"errors": library.errors, "warnings": library.warnings, "listening": library.listening,
		"grant_listening": library.grant_listening, "aura_cards": library.aura_cards,
		"aura_fields": library.aura_fields, "granted_aura_fields": library.granted_aura_fields,
		"aura_holders": library.aura_holders}
	for entry in entries:
		var id = str(entry.get("id", ""))
		library.cards[id] = entry
		_index(data, id, RulesDB.compile(entry))
	_check_links(data, entries)
	return library

## A library from a pack file outside PACKS (spec M2: test packs such as
## tests/fixtures/rules_fixtures.json). The file has the shape of a pack
## (heroes, cards, optional presets and pools); with "base": "<pack id>" it
## extends that pack (its heroes, cards and catalog), and its own catalog keys
## replace the base ones. Entries are compiled into private copies, so the
## shared pack cache stays untouched. The pack is registered under `pack_id`
## for the static helpers and for replays (open()).
static func from_file(path: String, pack_id: String):
	var parsed = _read_json(path)
	assert(not parsed.is_empty(), "Invalid card pack file %s" % path)
	var script = load("res://scripts/core/card_library.gd")
	var base = str(parsed.get("base", ""))
	var library = script.new(base if PACKS.has(base) else PACKS.keys()[0])
	if not PACKS.has(base):
		library.heroes = []
		library.cards = {}
		library.compiled = {}
		library.errors = []
		library.warnings = []
		library.listening = {}
		library.grant_listening = {}
		library.aura_cards = {}
		library.aura_fields = {}
		library.granted_aura_fields = {}
		library.aura_holders = {}
		library.catalog = {}
	library.content_pack = pack_id
	library.catalog = library.catalog.duplicate(true)
	for key in parsed:
		if key not in ["heroes", "cards", "base"]:
			library.catalog[key] = parsed[key]
	library.heroes = library.heroes.duplicate()
	library.cards = library.cards.duplicate()
	library.compiled = library.compiled.duplicate()
	library.errors = library.errors.duplicate()
	library.warnings = library.warnings.duplicate()
	library.listening = library.listening.duplicate(true)
	library.grant_listening = library.grant_listening.duplicate()
	library.aura_cards = library.aura_cards.duplicate()
	library.aura_fields = library.aura_fields.duplicate(true)
	library.granted_aura_fields = library.granted_aura_fields.duplicate()
	library.aura_holders = library.aura_holders.duplicate(true)
	var data = {"heroes": library.heroes, "cards": library.cards, "compiled": library.compiled,
		"errors": library.errors, "warnings": library.warnings, "listening": library.listening,
		"grant_listening": library.grant_listening, "aura_cards": library.aura_cards,
		"aura_fields": library.aura_fields, "granted_aura_fields": library.granted_aura_fields,
		"aura_holders": library.aura_holders}
	var entries: Array = []
	for hero in parsed.get("heroes", []):
		var entry: Dictionary = hero.duplicate()
		if not entry.has("kind"):
			entry["kind"] = "hero"
		library.heroes.append(entry)
		entries.append(entry)
	for card in parsed.get("cards", []):
		library.cards[str(card.id)] = card
		entries.append(card)
	for entry in entries:
		_index(data, str(entry.get("id", "")), RulesDB.compile(entry))
	_check_links(data, entries)
	library.errors = data.errors
	library.warnings = data.warnings
	# Register the pack: static lookups and replays find its cards from now on.
	raw_definition("")
	for entry in entries:
		if not _raw_definitions.has(str(entry.id)):
			_raw_definitions[str(entry.id)] = entry
	_extra[pack_id] = {"path": path, "compiled": library.compiled}
	return library

## True for a shipped pack (PACKS) or a pack loaded with from_file().
static func known_pack(pack_id: String) -> bool:
	return PACKS.has(pack_id) or _extra.has(pack_id)

## A library of a shipped pack, or of a pack loaded earlier with from_file().
static func open(pack_id: String):
	if _extra.has(pack_id):
		return from_file(str(_extra[pack_id].path), pack_id)
	return load("res://scripts/core/card_library.gd").new(pack_id)

## Compiled rules of a card, hero, token or item ({} shaped as NO_RULES when unknown).
func rules(card_id: String) -> Dictionary:
	return compiled.get(card_id, NO_RULES)

## True when the card compiled without errors (K13).
func playable(card_id: String) -> bool:
	return compiled.has(card_id) and compiled[card_id].errors.is_empty()

## Card ids whose abilities listen to `event`.
func listeners(event: String) -> Array:
	return listening.get(event, {}).keys()

## The bot's static values of a card (spec §9.2): draw, initiative, random,
## bias, lock, hack (opponent hand cards a play hacks) with hack_damage (the
## tower damage each hacked card deals its player), and mana (it restores the
## caster's tower).
func static_value(card_id: String) -> Dictionary:
	return rules(card_id).get("static", NO_RULES.static)

## The rules of a card id in any pack, without a library instance.
static func compiled_rules(card_id: String) -> Dictionary:
	for pack in PACKS:
		var data = _pack(pack)
		if data.compiled.has(card_id):
			return data.compiled[card_id]
	for pack in _extra:
		if _extra[pack].compiled.has(card_id):
			return _extra[pack].compiled[card_id]
	return NO_RULES

## The card has an active ability (shows an ability badge).
static func has_active(card_id: String) -> bool:
	return int(compiled_rules(card_id).get("active", -1)) >= 0

## The card has a continuous or reactive ability, or printed keywords.
static func has_passive(card_id: String) -> bool:
	var rules = compiled_rules(card_id)
	for ability in rules.get("abilities", []):
		if str(ability.get("kind", "")) in ["aura", "trigger"]:
			return true
	return not rules.get("keywords", {}).is_empty()

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
		if hero.is_empty() or hero.get("kind", "") != "hero" or hero_id in seen or not _deckable(str(hero_id)):
			return {"ok": false, "code": "deck_hero_invalid", "args": {}, "error": "Heroes must be supported and unique."}
		seen.append(hero_id)
	if not entry.get("cards") is Dictionary or not entry.get("items") is Dictionary:
		return {"ok": false, "code": "deck_missing_lists", "args": {}, "error": "Missing main or item deck."}
	var main_count = 0
	for card_id in entry.cards:
		var card = get_card(str(card_id))
		var count = entry.cards[card_id]
		if card.is_empty() or card.kind not in ["creep", "spell", "improvement"] or not _deckable(str(card_id)):
			return {"ok": false, "code": "deck_main_card", "args": {}, "error": "Unsupported main-deck card."}
		if not (count is int or count is float) or float(count) != floor(float(count)) or count < 1 or count > 3:
			return {"ok": false, "code": "deck_main_copies", "args": {}, "error": "Main cards need one to three whole copies."}
		main_count += int(count)
	if main_count < 40:
		return {"ok": false, "code": "deck_main_size", "args": {}, "error": "The main deck needs at least forty cards."}
	for hero_id in entry.heroes:
		# A hero without a signature card in the pack cannot fill a deck.
		var signature = str(definition(str(hero_id)).get("signature", ""))
		if signature.is_empty() or int(entry.cards.get(signature, 0)) != 3:
			return {"ok": false, "code": "deck_signatures", "args": {}, "error": "Each hero requires three signature copies."}
	var item_count = 0
	for card_id in entry.items:
		var card = get_card(str(card_id))
		var count = entry.items[card_id]
		# The item deck "can only contain Weapon, Armor and Accessory cards"
		# (wiki Item Shop): consumables and Deeds come from the shops only.
		if card.is_empty() or card.kind != "item" or str(card.get("slot", "")) not in EQUIPMENT_SLOTS \
				or card.get("consumable", false) or not _deckable(str(card_id)):
			return {"ok": false, "code": "deck_item_card", "args": {}, "error": "Item decks use supported equipment."}
		if not (count is int or count is float) or float(count) != floor(float(count)) or count < 1:
			return {"ok": false, "code": "deck_item_copies", "args": {}, "error": "Item counts must be positive whole numbers."}
		item_count += int(count)
	if item_count < 9:
		return {"ok": false, "code": "deck_item_size", "args": {}, "error": "The item deck needs at least nine cards."}
	return {"ok": true}

## Verified, playable and not a token: the only cards a deck may hold (K13).
func _deckable(card_id: String) -> bool:
	var entry = rules(card_id)
	return playable(card_id) and str(entry.get("status", "")) == "verified" and not bool(entry.get("token", false))

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
	if field.begins_with("grant_"):
		# Granted text (spec §8.8): the locale entry's grants[i], else a test
		# pack's grant_text[i].
		var index = int(field.substr(6))
		var granted = _pick(_at(entry.get("grants", []), index), _resolve_locale(locale))
		if granted.is_empty():
			granted = _pick(_at(definition.get("grant_text", []), index), _resolve_locale(locale))
		return format_text(granted, definition)
	var text = _pick(entry.get(field), _resolve_locale(locale))
	if text.is_empty():
		# Test packs carry their text in the entry, as a string or {locale: text}.
		text = _pick(definition.get(field), _resolve_locale(locale))
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
static func _at(values, index: int):
	return values[index] if values is Array and index >= 0 and index < values.size() else null

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
