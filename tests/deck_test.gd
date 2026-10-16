extends SceneTree
## Players' own decks (no UI): Valve's ArtifactDeckCode format (the README's
## two example codes, every preset round trip, CJK names cut at 63 bytes, "+"
## in codes, pasted links, malformed and oversized codes, unknown and draft
## cards), deck rules with their coded, localized messages (item copies,
## orphan signature cards), the deck store (save, list, load, delete,
## corrupt and hostile files, its own test folder), the builder's edits
## (signature cards locked to their hero, slots by deploy round, copy
## limits), and decks in matches: roster order follows the deploy slots,
## an own deck stays out of views and the bot's simulation, canonical lists,
## replays of format 8 with full lists (and format 7 still loading), and bot
## matches with random custom decks played to the end.

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Library = preload("res://scripts/core/card_library.gd")
const DeckCode = preload("res://scripts/core/deck_code.gd")
const DeckStore = preload("res://scripts/core/deck_store.gd")
const DeckModel = preload("res://scripts/core/deck_model.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const RulesVersion = preload("res://scripts/core/rules/rules_version.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const VECTORS = "res://tests/data/deck_codes.json"
## Test decks are written here, never to the player's user://decks.
const STORE = "res://.tools/scratch/deck_test_store"
const UI_CSV = "res://i18n/ui.csv"

var checks = 0
var failures: Array = []
var library = Library.new()
var vectors: Dictionary = {}
var errors = ErrorCatcher.new()

## Records engine and script errors: deck codes come from the clipboard and
## the network, so decoding must never log one (the run fails on any).
class ErrorCatcher:
	extends Logger
	var messages: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type != ERROR_TYPE_WARNING:
			messages.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass

func _initialize() -> void:
	OS.add_logger(errors)
	Settings.set_locale("en", false)
	Settings.set_skin("classic", false)
	vectors = JSON.parse_string(FileAccess.get_file_as_string(VECTORS))
	_check(vectors is Dictionary and vectors.has("valve_readme"), "Deck code test vectors load (%s)" % VECTORS)
	if not vectors is Dictionary:
		vectors = {}
	_test_valve_vectors()
	_test_preset_round_trips()
	_test_names_and_text()
	_test_malformed_codes()
	_test_control_bytes_in_names()
	_test_heroes_with_draft_signatures()
	_test_validation_messages()
	_test_store()
	_test_model()
	_test_matches()
	_test_replays()
	_test_bot_matches()
	Settings.set_locale("en", false)
	Settings.set_skin(Settings.DEFAULT_SKIN, false)
	OS.remove_logger(errors)
	_check(errors.messages.is_empty(), "No engine or script errors were logged (%s)" % [errors.messages.slice(0, 3)])
	if failures.is_empty():
		print("PASS: %d deck checks (Valve deck codes and every preset round trip, malformed codes, deck rules and messages, deck store, builder edits, roster order, privacy, replays, bot matches with custom decks)." % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("%d failures in %d deck checks." % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

# --- Codes ------------------------------------------------------------------------

func _test_valve_vectors() -> void:
	var expected = [
		{"slots": [["lycan", "rix", "phantom_assassin"], "debbi", "chen"],
			"cards": {"revtel_convoy": 3, "thunderhide_pack": 3, "untested_grunt": 3, "iron_fog_goldmine": 3, "selemenes_favor": 3,
				"mist_of_avernus": 3, "steam_cannon": 3, "payday": 3, "pick_off": 3},
			"items": {"travelers_cloak": 2, "leather_armor": 1, "red_mist_maul": 1, "poaching_knife": 3, "horn_of_the_alpha": 1, "apotheosis_blade": 1}},
		{"slots": [["keefe", "luna", "bristleback"], "zeus", "earthshaker"],
			"cards": {"red_mist_pillager": 3, "conflagration": 3, "foresight": 3, "clear_the_deck": 3, "new_orders": 3, "tower_barrage": 3,
				"cunning_plan": 3, "ventriloquy": 3, "time_of_triumph": 3, "routed": 2},
			"items": {"travelers_cloak": 2, "leather_armor": 2, "phase_boots": 2, "blade_of_the_vigil": 2, "red_mist_maul": 1}}]
	var readme: Array = vectors.get("valve_readme", [])
	_check(readme.size() == 2, "Both of Valve's README codes are test vectors")
	for index in range(mini(readme.size(), expected.size())):
		var vector: Dictionary = readme[index]
		var want: Dictionary = expected[index]
		var raw = DeckCode.parse(vector.code)
		_check(raw.ok and int(raw.version) == 2 and int(raw.checksum) == int(vector.decoded.checksum) and raw.name == vector.decoded.name,
			"Valve code %d parses: version 2, checksum %d, name %s (%s)" % [index + 1, int(vector.decoded.checksum), vector.decoded.name, raw])
		if not raw.ok:
			continue
		var heroes = raw.heroes.map(func(hero): return [int(hero.id), int(hero.turn)])
		var want_heroes = vector.decoded.heroes.map(func(hero): return [int(hero.id), int(hero.turn)])
		_check(heroes == want_heroes, "Valve code %d heroes and turns: %s" % [index + 1, heroes])
		var cards = raw.cards.map(func(card): return [int(card.id), int(card.count)])
		var want_cards = vector.decoded.cards.map(func(card): return [int(card.id), int(card.count)])
		_check(cards == want_cards, "Valve code %d cards and counts: %s" % [index + 1, cards])
		var decoded = DeckCode.decode(vector.code, library)
		_check(decoded.ok, "Valve code %d decodes into local cards (%s)" % [index + 1, decoded])
		if not decoded.ok:
			continue
		var deck: Dictionary = decoded.deck
		var round_one: Array = deck.heroes.slice(0, 3)
		_check(_same_set(round_one, want.slots[0]) and deck.heroes[3] == want.slots[1] and deck.heroes[4] == want.slots[2],
			"Valve code %d: turn-1 heroes fill round 1, the turn-2 and turn-3 heroes rounds 2 and 3 (%s)" % [index + 1, deck.heroes])
		var main: Dictionary = want.cards.duplicate()
		for hero_id in deck.heroes:
			main[str(library.definition(hero_id).signature)] = 3
		_check(_same_counts(deck.cards, main), "Valve code %d main deck with three copies of each signature card: %s" % [index + 1, deck.cards])
		_check(_same_counts(deck.items, want.items), "Valve code %d item deck: %s" % [index + 1, deck.items])
		_check(library.validate_preset(deck).ok, "Valve code %d is a legal deck here (%s)" % [index + 1, library.validate_preset(deck)])
		_check(DeckCode.encode(deck, library) == vector.code, "Valve code %d encodes back to the identical code" % [index + 1])

func _test_preset_round_trips() -> void:
	var codes: Dictionary = {}
	for vector in vectors.get("local_presets", []):
		codes[str(vector.preset)] = str(vector.code)
	_check(codes.size() >= 3, "Preset code vectors are present")
	var plus_seen = false
	for preset in library.presets():
		var code = DeckCode.encode(preset, library)
		_check(code.begins_with("ADC") and code.length() < 200, "Preset %s encodes (%s)" % [preset.id, code])
		if codes.has(preset.id):
			_check(code == codes[preset.id], "Preset %s encodes to the reference port's code" % preset.id)
		plus_seen = plus_seen or code.contains("+")
		var decoded = DeckCode.decode(code, library)
		_check(decoded.ok, "Preset %s decodes (%s)" % [preset.id, decoded])
		if not decoded.ok:
			continue
		var deck: Dictionary = decoded.deck
		_check(_same_set(deck.heroes.slice(0, 3), preset.heroes.slice(0, 3)) and deck.heroes[3] == preset.heroes[3] and deck.heroes[4] == preset.heroes[4],
			"Preset %s keeps its deploy rounds (%s vs %s)" % [preset.id, deck.heroes, preset.heroes])
		_check(_same_counts(deck.cards, preset.cards) and _same_counts(deck.items, preset.items), "Preset %s keeps every card and item count" % preset.id)
		_check(deck.name == preset.name and library.validate_preset(deck).ok, "Preset %s keeps its name and stays legal" % preset.id)
		_check(DeckCode.encode(deck, library) == code, "Preset %s: encode(decode(code)) is the same code" % preset.id)
	_check(plus_seen, "At least one preset code contains '+' (and decodes)")

func _test_names_and_text() -> void:
	# A CJK name is cut at 63 UTF-8 bytes, between whole characters.
	var deck = library.preset("starter").duplicate(true)
	deck.name = "蜀汉先锋".repeat(8)
	var code = DeckCode.encode(deck, library)
	var decoded = DeckCode.decode(code, library)
	_check(decoded.ok and decoded.deck.name == "蜀汉先锋".repeat(8).left(21) and decoded.deck.name.to_utf8_buffer().size() == 63,
		"A long Chinese name is cut to 21 characters (63 bytes): %s" % (decoded.deck.name if decoded.ok else decoded))
	deck.name = "ab" + "汉".repeat(30)
	decoded = DeckCode.decode(DeckCode.encode(deck, library), library)
	_check(decoded.ok and decoded.deck.name.to_utf8_buffer().size() <= 63 and decoded.deck.name.to_utf8_buffer().size() >= 61, "Cutting never splits a character")
	deck.name = "<b>Shu</b> [color=red]Van{guard}[/color]\n"
	decoded = DeckCode.decode(DeckCode.encode(deck, library), library)
	_check(decoded.ok and decoded.deck.name == "Shu color=redVanguard/color", "Names lose tags, BBCode brackets, braces and control characters: %s" % (decoded.deck.name if decoded.ok else decoded))
	# The edge vector: one hero, an extended count (5) and a CJK name.
	for vector in vectors.get("edge", []):
		var raw = DeckCode.parse(vector.code)
		_check(raw.ok and raw.heroes.size() == 1 and int(raw.heroes[0].id) == 4005 and raw.cards.size() == 1 and int(raw.cards[0].count) == 5
			and raw.name == vector.decoded.name, "Edge code: one hero, a count of five and the name %s (%s)" % [vector.decoded.name, raw])
		var edge = DeckCode.decode(vector.code, library)
		_check(edge.ok and edge.deck.heroes == ["debbi", "", "", "", ""] and int(edge.deck.items.get("travelers_cloak", 0)) == 5,
			"Edge code decodes into slot 1 and five Traveler's Cloaks (%s)" % [edge])
		if edge.ok:
			var issues = library.deck_issues(edge.deck)
			var codes = issues.map(func(issue): return issue.code)
			_check(codes.has("deck_hero_count") and codes.has("deck_item_copies") and codes.has("deck_main_size"),
				"The edge deck breaks the hero, item copy and main size rules: %s" % [codes])
			_check(DeckCode.encode(edge.deck, library) == vector.code, "The edge deck encodes back to its code")
	# "+" in a code, whitespace, a playartifact.com link, %2B.
	var green = DeckCode.encode(library.preset("green_assault"), library)
	_check(green.contains("+"), "The Green Assault code contains '+'")
	for text in [green, "  %s\n" % green, "https://playartifact.com/d/" + green, "https://playartifact.com/d/" + green.replace("+", "%2B") + "?ref=x",
			"Deck: " + green + " (copied)"]:
		var result = DeckCode.decode(text, library)
		_check(result.ok and result.deck.heroes[3] == library.preset("green_assault").heroes[3], "Pasted text decodes: %s" % text.substr(0, 40))
	# Version 1 codes (no name) still decode.
	var raw_two = DeckCode.parse(green)
	var version_one = DeckCode.encode_raw(raw_two.heroes, raw_two.cards, "", 1)
	var parsed_one = DeckCode.parse(version_one)
	_check(parsed_one.ok and int(parsed_one.version) == 1 and parsed_one.name == "" and parsed_one.cards.size() == raw_two.cards.size(),
		"A version 1 code (no name byte) decodes (%s)" % [parsed_one])

func _test_malformed_codes() -> void:
	var good = DeckCode.encode(library.preset("starter"), library)
	var cases = [
		["", "deck_code_prefix"], ["hello world", "deck_code_prefix"], ["ADC", "deck_code_base64"], ["ADC!!!!", "deck_code_base64"],
		["ADC" + "A".repeat(600), "deck_code_too_long"], ["ADCJ*WAP", "deck_code_base64"],
		["ADC" + good.substr(3, 8), "deck_code_truncated"]]
	# Damaged byte: the checksum no longer matches.
	var bytes = DeckCode._base64(good.substr(3).replace("-", "/").replace("_", "="))
	bytes[6] = (bytes[6] + 1) % 256
	cases.append([_code_of(bytes), "deck_code_checksum"])
	# Unsupported version.
	var other = bytes.duplicate()
	other[0] = (3 << 4) | 5
	cases.append([_code_of(other), "deck_code_version"])
	# Truncated: a card whose id continues past the card bytes (checksum fixed up).
	cases.append([_code_of(_with_checksum(PackedByteArray([0x21, 0, 0, 0x20 | 0x05]))), "deck_code_truncated"])
	# The name length claims more bytes than the code has.
	cases.append([_code_of(PackedByteArray([0x25, 0, 40, 1, 2])), "deck_code_truncated"])
	# More than five heroes.
	cases.append([DeckCode.encode_raw([{"id": 4003, "turn": 1}, {"id": 4005, "turn": 1}, {"id": 10006, "turn": 1}, {"id": 10014, "turn": 1},
		{"id": 10017, "turn": 2}, {"id": 10026, "turn": 3}], []), "deck_code_hero_turns"])
	for case in cases:
		var result = DeckCode.decode(case[0], library)
		_check(not result.ok and result.code == case[1], "Malformed code %s fails with %s (got %s)" % [str(case[0]).substr(0, 24), case[1], result.get("code", "ok")])
		_check(not result.ok and EventText.error_text(result).find("{") == -1 and EventText.error_text(result) != "ERR_" + str(result.get("code", "")).to_upper(),
			"%s has a filled message" % case[1])
	# Decks that parse but cannot be built here.
	var heroes = [{"id": 4003, "turn": 1}, {"id": 4005, "turn": 1}, {"id": 10006, "turn": 1}, {"id": 10014, "turn": 2}, {"id": 10017, "turn": 3}]
	var unknown = DeckDecodeCase.new(DeckCode.encode_raw(heroes, [{"id": 3000, "count": 3}, {"id": 99999, "count": 2}], "x"))
	var result = DeckCode.decode(unknown.code, library)
	_check(not result.ok and result.code == "deck_code_unknown_card" and int(result.args.id) == 99999, "An unknown Valve id is named (%s)" % [result])
	var draft_source = library.source_of("chain_frost")
	result = DeckCode.decode(DeckCode.encode_raw(heroes, [{"id": draft_source, "count": 3}], ""), library)
	_check(not result.ok and result.code == "deck_code_unavailable" and result.args.card == "chain_frost", "A draft card cannot be imported (%s)" % [result])
	Settings.set_skin("classic", false)
	_check(EventText.error_text(result).find("Chain Frost") != -1, "The draft card's message names it: %s" % EventText.error_text(result))
	result = DeckCode.decode(DeckCode.encode_raw([{"id": library.source_of("kanna"), "turn": 1}], []), library)
	_check(not result.ok and result.code == "deck_code_unavailable" and result.args.card == "kanna", "A draft hero cannot be imported")
	result = DeckCode.decode(DeckCode.encode_raw([{"id": 4003, "turn": 1}, {"id": 4005, "turn": 2}, {"id": 10006, "turn": 2}], []), library)
	_check(not result.ok and result.code == "deck_code_hero_turns", "Two round-2 heroes are rejected")
	result = DeckCode.decode(DeckCode.encode_raw([{"id": 4003, "turn": 4}], []), library)
	_check(not result.ok and result.code == "deck_code_hero_turns", "A turn past round 3 is rejected")
	result = DeckCode.decode(DeckCode.encode_raw([{"id": library.source_of("payday"), "turn": 1}], []), library)
	_check(not result.ok and result.code == "deck_code_hero_turns", "A spell in the hero list is rejected")
	result = DeckCode.decode(DeckCode.encode_raw([], [{"id": library.source_of("axe"), "count": 1}]), library)
	_check(not result.ok and result.code == "deck_code_unavailable", "A hero in the card list is rejected")
	result = DeckCode.decode(DeckCode.encode_raw([], [{"id": library.source_of("melee_creep"), "count": 3}]), library)
	_check(not result.ok and result.code == "deck_code_unavailable", "A token cannot be imported")
	result = DeckCode.decode(DeckCode.encode_raw([], [{"id": library.source_of("healing_salve"), "count": 3}]), library)
	_check(not result.ok and result.code == "deck_code_unavailable", "A consumable cannot enter an item deck by code")
	# A signature card listed by another tool counts as the hero's three copies.
	var with_signature = DeckCode.encode_raw([{"id": library.source_of("axe"), "turn": 1}], [{"id": library.source_of("berserkers_call"), "count": 3}])
	result = DeckCode.decode(with_signature, library)
	_check(result.ok and int(result.deck.cards.get("berserkers_call", 0)) == 3, "A listed signature card is not doubled (%s)" % [result])
	# Random bytes never crash the decoder and never log engine errors.
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	var survived = 0
	for attempt in range(300):
		var noise = PackedByteArray()
		for index in range(rng.randi_range(1, 60)):
			noise.append(rng.randi_range(0, 255))
		var noisy = DeckCode.decode(_code_of(noise), library)
		survived += int(noisy is Dictionary and noisy.has("ok"))
	_check(survived == 300, "300 random byte strings decode to results or coded failures")

## A zero byte or another control character in a code's name is dropped
## without logging an engine error (String.chr(0) logs "Unexpected NUL
## character"); a hostile guest could otherwise make the host log on demand.
func _test_control_bytes_in_names() -> void:
	var before = errors.messages.size()
	var cases = [
		[PackedByteArray([0x20, 0, 2, 0x41, 0x00]), "A"],
		[PackedByteArray([0x20, 0, 1, 0x00]), ""],
		[PackedByteArray([0x20, 0, 5, 0x41, 0x01, 0x42, 0x1F, 0x7F]), "AB"],
		[PackedByteArray([0x20, 0, 4, 0x00, 0xE8, 0x9C, 0x80]), "蜀"],
		# An overlong two-byte NUL (0xC0 0x80) is invalid UTF-8.
		[PackedByteArray([0x20, 0, 3, 0xC0, 0x80, 0x41]), "��A"],
	]
	for case in cases:
		var raw = DeckCode.parse(_code_of(case[0]))
		_check(raw.ok and raw.name == case[1], "Control bytes leave a name (%s): %s" % [case[0], raw.get("name", raw)])
		var decoded = DeckCode.decode(_code_of(case[0]), library)
		_check(decoded.ok and decoded.deck.name.find(String.chr(0xFFFD)) == -1 or case[1].find(String.chr(0xFFFD)) != -1,
			"A decoded deck name keeps no replacement character for a control byte (%s)" % [decoded])
	# Random codes with correct checksums and names full of low bytes.
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	var decoded_count = 0
	for attempt in range(2000):
		var length = rng.randi_range(0, 12)
		var bytes = PackedByteArray([0x20, 0, length])
		for index in range(length):
			bytes.append(rng.randi_range(0, 0x24) if rng.randf() < 0.7 else rng.randi_range(0, 255))
		var result = DeckCode.decode(_code_of(bytes), library)
		decoded_count += int(result.get("ok", false))
		if result.get("ok", false):
			for character in result.deck.name:
				if character.unicode_at(0) < 0x20:
					_check(false, "A decoded name holds a control character (%s)" % [bytes])
	_check(decoded_count > 1000, "Most random names decode (%d of 2000)" % decoded_count)
	_check(errors.messages.size() == before, "Names with zero and control bytes log no engine errors (%s)" % [errors.messages.slice(before, before + 3)])

## Lich is a playable hero but his signature card Chain Frost is a draft: no
## deck holding him could be legal, so he is not offered, cannot be added,
## is refused by deck rules with his own name, and a code naming him fails.
func _test_heroes_with_draft_signatures() -> void:
	_check(library.deckable("lich") and not library.deckable("chain_frost"), "Lich is deckable but Chain Frost is a draft (the case under test)")
	_check(not library.hero_deckable("lich") and library.hero_deckable("axe") and not library.hero_deckable("kanna") and not library.hero_deckable("berserkers_call"),
		"hero_deckable needs the hero and its signature card to be deckable")
	for hero in library.heroes:
		var hero_id = str(hero.id)
		var signature = str(hero.get("signature", ""))
		var expected = library.deckable(hero_id) and not signature.is_empty() and library.deckable(signature)
		if library.hero_deckable(hero_id) != expected:
			_check(false, "hero_deckable(%s) matches its card and signature card" % hero_id)
	var deck = DeckStore.blank("Lich")
	_check(not DeckModel.can_add(deck, "lich", library) and not DeckModel.add(deck, "lich", library), "The builder cannot add Lich")
	_check(not DeckModel.place_hero(deck, "lich", 0, library) and DeckModel.hero_count(deck) == 0 and not deck.cards.has("chain_frost"),
		"Lich cannot be dropped into a hero slot")
	var preset = library.preset("starter")
	var with_lich = {"name": "Lich", "heroes": preset.heroes.duplicate(), "cards": preset.cards.duplicate(), "items": preset.items.duplicate()}
	var old_signature = str(library.definition(with_lich.heroes[0]).get("signature", ""))
	with_lich.cards.erase(old_signature)
	with_lich.heroes[0] = "lich"
	with_lich.cards["chain_frost"] = 3
	var result = library.validate_preset(with_lich)
	_check(not result.ok and result.code == "deck_hero_invalid" and result.args.card == "lich",
		"A deck with Lich fails on Lich himself, not on a locked card (%s)" % [result])
	var stored = with_lich.duplicate(true)
	var dropped = DeckModel.repair(stored, library)
	_check("lich" in dropped and "chain_frost" in dropped and stored.heroes[0] == "" and not stored.cards.has("chain_frost"),
		"A stored deck with Lich loses him and Chain Frost when repaired (%s)" % [dropped])
	var heroes = [{"id": library.source_of("lich"), "turn": 1}, {"id": 4005, "turn": 1}, {"id": 10006, "turn": 1}, {"id": 10014, "turn": 2}, {"id": 10017, "turn": 3}]
	result = DeckCode.decode(DeckCode.encode_raw(heroes, [{"id": 3000, "count": 3}], "Lich"), library)
	_check(not result.ok and result.code == "deck_code_unavailable" and result.args.card == "lich", "A Lich deck code is refused naming Lich (%s)" % [result])
	_check(EventText.error_text(result).find(Library.loc("lich")) != -1, "The refusal names Lich: %s" % EventText.error_text(result))

## A tiny holder so the malformed-code cases read clearly.
class DeckDecodeCase:
	var code: String
	func _init(value: String) -> void:
		code = value

func _code_of(bytes: PackedByteArray) -> String:
	return "ADC" + Marshalls.raw_to_base64(bytes).replace("/", "-").replace("=", "_")

func _with_checksum(bytes: PackedByteArray) -> PackedByteArray:
	var total = 0
	for index in range(3, bytes.size() - int(bytes[2])):
		total += bytes[index]
	bytes[1] = total & 0xFF
	return bytes

# --- Deck rules ---------------------------------------------------------------------

func _test_validation_messages() -> void:
	var rows = _csv_keys()
	var base = library.preset("starter").duplicate(true)
	var cases: Array = []
	var bad = base.duplicate(true)
	bad.items.short_sword = 4
	cases.append([bad, "deck_item_copies", "short_sword"])
	bad = base.duplicate(true)
	bad.cards.coup_de_grace = 3
	cases.append([bad, "deck_signature_orphan", "coup_de_grace"])
	bad = base.duplicate(true)
	bad.cards.erase("bronze_legionnaire")
	cases.append([bad, "deck_main_size", ""])
	bad = base.duplicate(true)
	bad.heroes[4] = ""
	cases.append([bad, "deck_hero_count", ""])
	bad = base.duplicate(true)
	bad.heroes[4] = "kanna"
	cases.append([bad, "deck_hero_invalid", "kanna"])
	bad = base.duplicate(true)
	bad.cards.chain_frost = 1
	cases.append([bad, "deck_main_card", "chain_frost"])
	bad = base.duplicate(true)
	bad.cards.berserkers_call = 2
	bad.cards.ogre_conscript = 3
	cases.append([bad, "deck_signatures", "berserkers_call"])
	bad = base.duplicate(true)
	bad.items.healing_salve = 1
	cases.append([bad, "deck_item_card", "healing_salve"])
	for case in cases:
		var result = library.validate_preset(case[0])
		_check(not result.ok and result.code == case[1], "Deck rule %s (got %s)" % [case[1], result])
		if case[2] != "":
			_check(str(result.get("args", {}).get("card", "")) == case[2], "%s names the card %s" % [case[1], case[2]])
		for locale in ["en", "zh_CN"]:
			for skin in ["classic", "three_kingdoms"]:
				Settings.set_locale(locale, false)
				Settings.set_skin(skin, false)
				var text = EventText.error_text(result)
				_check(text.find("{") == -1 and not text.begins_with("ERR_"), "%s reads well in %s/%s: %s" % [case[1], locale, skin, text])
				if case[2] != "":
					_check(text.find(Library.loc(case[2])) != -1, "%s message names %s in %s/%s: %s" % [case[1], Library.loc(case[2]), locale, skin, text])
	Settings.set_locale("en", false)
	Settings.set_skin("classic", false)
	_check(EventText.error_text(library.validate_preset(cases[2][0])).find("37/40") != -1, "The main size message gives the count (37/40)")
	var issues = library.deck_issues(cases[0][0].merged({"cards": cases[1][0].cards}, true))
	_check(issues.map(func(issue): return issue.code) == ["deck_signature_orphan", "deck_item_copies"], "deck_issues lists every problem in check order: %s" % [issues.map(func(issue): return issue.code)])
	for code in ["deck_hero_count", "deck_hero_invalid", "deck_missing_lists", "deck_main_card", "deck_main_copies", "deck_main_size", "deck_signatures",
			"deck_signature_orphan", "deck_item_card", "deck_item_copies", "deck_item_size", "deck_code_prefix", "deck_code_too_long", "deck_code_base64",
			"deck_code_version", "deck_code_checksum", "deck_code_truncated", "deck_code_unknown_card", "deck_code_unavailable", "deck_code_hero_turns",
			"deck_store_invalid", "deck_store_full", "deck_store_write", "deck_store_missing", "deck_online_missing"]:
		_check(rows.has("ERR_" + code.to_upper()), "Error code %s has an English and Chinese message" % code)
	for preset in library.presets():
		_check(library.deck_issues(preset).is_empty(), "Preset %s has no deck issues" % preset.id)

func _csv_keys() -> Dictionary:
	var rows: Dictionary = {}
	var file = FileAccess.open(UI_CSV, FileAccess.READ)
	if file == null:
		return rows
	file.get_csv_line()
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() >= 3 and not line[0].is_empty() and not line[1].is_empty() and not line[2].is_empty():
			rows[line[0]] = true
	return rows

# --- Store ----------------------------------------------------------------------------

func _test_store() -> void:
	_check(DeckStore.root == DeckStore.DEFAULT_ROOT and DeckStore.DEFAULT_ROOT == "user://decks", "Decks live in user://decks by default")
	DeckStore.root = STORE
	_clear_store()
	_check(DeckStore.list().is_empty(), "A missing deck folder lists no decks")
	var deck = DeckStore.copy_of(library.preset("starter"), "Shu Vanguard")
	var saved = DeckStore.save(deck)
	_check(saved.ok and FileAccess.file_exists("%s/%s.json" % [STORE, deck.id]), "A deck saves to <id>.json in the store folder (%s)" % [saved])
	var stored = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [STORE, deck.id]))
	_check(stored is Dictionary and int(stored.version) == 1 and stored.name == "Shu Vanguard" and stored.heroes == library.preset("starter").heroes
		and _same_counts(stored.cards, library.preset("starter").cards), "The file holds version 1, the name, heroes in deploy order and card ids")
	var loaded = DeckStore.load_deck(deck.id)
	_check(loaded.id == deck.id and library.validate_preset(loaded).ok and loaded.heroes == deck.heroes, "A saved deck loads back legal")
	var draft = DeckStore.blank("Draft")
	draft.heroes[2] = "axe"
	draft.cards["berserkers_call"] = 3
	_check(DeckStore.save(draft).ok, "An unfinished deck can be saved as a draft")
	var listed = DeckStore.list()
	_check(listed.size() == 2 and listed[0].id == draft.id, "list() shows the most recently changed deck first (%s)" % [listed.map(func(entry): return entry.name)])
	_check(listed[0].heroes == ["", "", "axe", "", ""], "A draft keeps its empty slots")
	_check(DeckStore.unique_name("Shu Vanguard", listed) == "Shu Vanguard 2" and DeckStore.unique_name("New", listed) == "New", "unique_name numbers taken names")
	# Hostile and damaged files are skipped, never fatal.
	_write("%s/garbage.json" % STORE, "{not json")
	_write("%s/wrong_type.json" % STORE, "[1, 2, 3]")
	_write("%s/bad lists.json" % STORE, JSON.stringify({"heroes": "axe", "cards": [], "items": {}}))
	_write("%s/huge.json" % STORE, "{\"pad\": \"%s\"}" % "x".repeat(DeckStore.MAX_FILE_BYTES + 10))
	_write("%s/odd.json" % STORE, JSON.stringify({"id": "../../escape", "name": "<b>Odd</b>\u0007", "heroes": ["axe", 5, null, "x".repeat(200)],
		"cards": {"berserkers_call": 3.0, "payday": 2.5, "pick_off": -4, "x": "3", "untested_grunt": 1e9}, "items": {"short_sword": 2}, "modified": "soon"}))
	listed = DeckStore.list()
	var odd = listed.filter(func(entry): return entry.id == "odd")
	_check(listed.size() == 3 and odd.size() == 1, "Unreadable files are skipped; a readable odd one is sanitized (%d listed)" % listed.size())
	_check(DeckStore.problems.size() == 4, "Skipped files are reported (%s)" % [DeckStore.problems])
	if odd.size() == 1:
		var entry: Dictionary = odd[0]
		_check(entry.name == "Odd" and entry.heroes == ["axe", "", "", "", ""] and entry.cards == {"berserkers_call": 3, "untested_grunt": DeckStore.MAX_COPIES}
			and entry.items == {"short_sword": 2} and int(entry.modified) == 0, "Sanitized: clean name, five slots, whole counts only (%s)" % [entry])
	_check(DeckStore.load_deck("../garbage").is_empty() and not DeckStore.valid_id("a/b") and not DeckStore.valid_id(""), "Ids cannot leave the store folder")
	_check(DeckStore.delete(deck.id).ok and not FileAccess.file_exists("%s/%s.json" % [STORE, deck.id]), "A deck can be deleted")
	_check(not DeckStore.delete(deck.id).ok and DeckStore.delete(deck.id).code == "deck_store_missing", "Deleting a missing deck says so")
	_check(not DeckStore.save({"heroes": 7}).ok, "A non-deck cannot be saved")
	# The chosen decks are remembered by preset id or deck id.
	var mine = DeckStore.copy_of(library.preset("five_tigers"), "Remembered")
	DeckStore.save(mine)
	var listed_before = DeckStore.list().size()
	_check(DeckStore.save_choices([mine, "siege_of_ye"]) == OK and DeckStore.list().size() == listed_before, "Choices are saved beside the decks (not as a deck)")
	var restored = DeckStore.load_choices(["starter", "green_assault"], library)
	_check(restored[0] is Dictionary and restored[0].id == mine.id and restored[0].heroes == mine.heroes and restored[1] == "siege_of_ye",
		"Remembered choices come back: an own deck as stored, a preset by id")
	var edited = DeckStore.load_deck(mine.id)
	edited.name = "Edited"
	DeckStore.save(edited)
	_check(DeckStore.load_choices(["starter", "green_assault"], library)[0].name == "Edited", "An edited deck is played as it is now")
	edited.items = {}
	DeckStore.save(edited)
	_check(DeckStore.load_choices(["starter", "green_assault"], library)[0] == "starter", "A remembered deck that became illegal falls back")
	DeckStore.delete(mine.id)
	_check(DeckStore.load_choices(["starter", "green_assault"], library)[0] == "starter", "A deleted deck falls back to the default")
	_write("%s/%s" % [STORE, DeckStore.CHOICES_FILE], "[seats]\n0=\"preset:nonexistent\"\n1=42\n")
	_check(DeckStore.load_choices(["starter", "green_assault"], library) == ["starter", "green_assault"], "Unknown or malformed choices keep the defaults")
	_clear_store()
	DeckStore.root = DeckStore.DEFAULT_ROOT

func _write(path: String, text: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()

func _clear_store() -> void:
	if DirAccess.dir_exists_absolute(STORE):
		for file_name in DirAccess.get_files_at(STORE):
			DirAccess.remove_absolute("%s/%s" % [STORE, file_name])

# --- Builder edits ----------------------------------------------------------------------

func _test_model() -> void:
	var deck = DeckStore.blank("Model")
	_check(DeckModel.add(deck, "axe", library) and deck.heroes[0] == "axe" and int(deck.cards.get("berserkers_call", 0)) == 3,
		"Adding a hero fills the first slot and brings three signature copies")
	_check(DeckModel.is_locked(deck, "berserkers_call", library) and not DeckModel.remove(deck, "berserkers_call", library)
		and int(deck.cards.berserkers_call) == 3, "Signature cards are locked to their hero")
	_check(not DeckModel.add(deck, "berserkers_call", library) and not DeckModel.can_add(deck, "coup_de_grace", library),
		"Signature cards cannot be added by hand (own or another hero's)")
	_check(not DeckModel.add(deck, "axe", library), "A hero joins a deck once")
	_check(DeckModel.place_hero(deck, "debbi", 4, library) and deck.heroes == ["axe", "", "", "", "debbi"], "A hero dropped on the round 3 slot takes it")
	_check(DeckModel.move_hero(deck, 4, 3) and deck.heroes == ["axe", "", "", "debbi", ""], "Heroes move between slots (deploy order)")
	_check(DeckModel.move_hero(deck, 0, 3) and deck.heroes == ["debbi", "", "", "axe", ""], "Moving onto a hero swaps them")
	_check(DeckModel.place_hero(deck, "drow", 3, library) and deck.heroes[3] == "drow" and not deck.cards.has("berserkers_call")
		and int(deck.cards.get("gust", 0)) == 3, "A hero placed on a taken slot replaces that hero and its signature cards")
	_check(DeckModel.place_hero(deck, "debbi", 3, library) and deck.heroes == ["drow", "", "", "debbi", ""], "Placing a hero already in the deck moves it")
	_check(DeckModel.remove_hero(deck, 3, library) and not deck.cards.has("no_accident"), "Removing a hero removes its signature cards")
	_check(not DeckModel.add(deck, "kanna", library) and not DeckModel.add(deck, "chain_frost", library) and not DeckModel.add(deck, "melee_creep", library)
		and not DeckModel.add(deck, "healing_salve", library), "Drafts, tokens and consumables are never added")
	for copy in range(3):
		DeckModel.add(deck, "payday", library)
		DeckModel.add(deck, "short_sword", library)
	_check(int(deck.cards.payday) == 3 and int(deck.items.short_sword) == 3, "Main cards and items take three copies")
	_check(not DeckModel.add(deck, "payday", library) and not DeckModel.add(deck, "short_sword", library), "A fourth copy is refused")
	_check(DeckModel.remove(deck, "payday", library) and int(deck.cards.payday) == 2, "Removing takes one copy")
	_check(DeckModel.remove(deck, "short_sword", library) and DeckModel.remove(deck, "short_sword", library) and DeckModel.remove(deck, "short_sword", library)
		and not deck.items.has("short_sword"), "The last copy leaves the list")
	var damaged = {"heroes": ["axe", "kanna", "axe", "nobody", "zeus"], "cards": {"payday": 9, "chain_frost": 1, "berserkers_call": 1, "gust": 3},
		"items": {"healing_salve": 1, "short_sword": 5}}
	var dropped = DeckModel.repair(damaged, library)
	_check(damaged.heroes == ["axe", "", "", "", "zeus"] and int(damaged.cards.payday) == 3 and int(damaged.cards.berserkers_call) == 3
		and int(damaged.cards.get("thundergods_wrath", 0)) == 3 and not damaged.cards.has("gust") and damaged.items == {"short_sword": 3},
		"repair() drops what cannot be edited and restores signature cards (%s)" % [damaged])
	_check(_same_set(dropped, ["kanna", "axe", "nobody", "chain_frost", "gust", "healing_salve"]), "repair() reports what it dropped: %s" % [dropped])
	var full = DeckStore.copy_of(library.preset("blue_black_control"), "Stats")
	var numbers = DeckModel.stats(full, library)
	var curve_total = 0
	for bucket in numbers.curve:
		curve_total += bucket[0] + bucket[1] + bucket[2]
	_check(numbers.main == 40 and curve_total == 40 and numbers.items == 9 and numbers.kinds.creep + numbers.kinds.spell + numbers.kinds.improvement == 40,
		"Stats count the main deck by cost and kind (%s)" % [numbers])
	_check(numbers.average > 1.0 and numbers.average < 8.0 and numbers.colors.get("blue", {}).get("heroes", 0) == 2
		and numbers.colors.get("black", {}).get("heroes", 0) == 2 and numbers.colors.get("red", {}).get("heroes", 0) == 1,
		"Stats give the average cost and the heroes per colour (%s)" % [numbers.colors])

# --- Matches ------------------------------------------------------------------------------

func _custom_deck(preset_id: String, order: Array) -> Dictionary:
	var preset = library.preset(preset_id)
	var deck = DeckStore.copy_of(preset, "Mine")
	deck.heroes = order.map(func(index): return preset.heroes[index])
	return deck

func _test_matches() -> void:
	var engine = MatchEngine.new()
	var mine = _custom_deck("blue_black_control", [4, 2, 0, 1, 3])
	var result = engine.start(5, [mine, "starter"])
	_check(result.ok, "A match starts with an own deck (%s)" % [result])
	var roster: Array = engine.state.players[0].roster
	_check(roster.map(func(hero): return hero.card) == mine.heroes, "The roster follows the deck's slots")
	_check(roster.map(func(hero): return int(hero.ready_round)) == [1, 1, 1, 2, 3], "Slots 1-3 deploy in round 1, slot 4 in round 2, slot 5 in round 3")
	var round_one = engine.state.lanes.map(func(lane): return lane.units[0].filter(func(unit): return unit != null and unit.hero).map(func(unit): return unit.card))
	var placed: Array = []
	for cards_in_lane in round_one:
		placed.append_array(cards_in_lane)
	_check(_same_set(placed, mine.heroes.slice(0, 3)), "Round 1 deploys the first three slots (%s)" % [placed])
	_check(engine.state.players[0].preset == "custom" and engine.state.players[1].preset == "starter", "An own deck shows as \"custom\" in state")
	_check(engine.deck_ids[0] == Library.canonical_deck(mine) and not engine.deck_ids[0].has("name") and not engine.deck_ids[0].has("id"),
		"The engine keeps the canonical list without names or ids")
	var state_text = JSON.stringify(engine.state)
	_check(state_text.find("Mine") == -1 and state_text.find(mine.id) == -1, "State holds no deck name or id")
	var view = engine.player_view(1)
	_check(view.players[0].deck.is_empty() and view.players[0].hand.is_empty() and view.players[0].preset == "custom"
		and not JSON.stringify(view).contains("\"cards\""), "The opponent's view holds no list of the own deck")
	var simulation = engine.simulation_from_view(1)
	_check(simulation.deck_ids == ["custom", "starter"], "The bot's simulation never gets an own deck list (%s)" % [simulation.deck_ids])
	# Equal decks, different key order: identical matches.
	var shuffled = mine.duplicate(true)
	var reordered: Dictionary = {}
	var keys = shuffled.cards.keys()
	keys.reverse()
	for key in keys:
		reordered[key] = float(shuffled.cards[key])
	shuffled.cards = reordered
	shuffled.name = "Other name"
	var twin = MatchEngine.new()
	twin.start(5, [shuffled, "starter"])
	_check(twin.state_digest() == engine.state_digest(), "Equal decks give equal matches whatever their key order, count type or name")
	# Invalid own decks never start.
	var bad = mine.duplicate(true)
	bad.items.short_sword = 4
	var failed = MatchEngine.new().start(5, [bad, "starter"])
	_check(not failed.ok and failed.code == "deck_item_copies", "An illegal own deck does not start (%s)" % [failed])
	_check(MatchEngine.new().start(5, [mine, 42]).code == "deck_hero_count", "A deck entry of the wrong type is rejected")

func _test_replays() -> void:
	var engine = MatchEngine.new()
	var mine = _custom_deck("siege_of_ye", [0, 1, 2, 3, 4])
	var theirs = _custom_deck("five_tigers", [3, 4, 0, 1, 2])
	engine.start(77, [mine, theirs])
	var bot = Bot.new()
	for step in range(60):
		var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
		var action = bot.choose_action(engine, player)
		if action.is_empty() or engine.state.winner != -1:
			break
		engine.apply_action(player, action)
	var data = engine.replay_data()
	_check(int(data.protocol) == 8 and data.decks[0] is Dictionary and data.decks[0].heroes == mine.heroes, "Replays of format 8 carry the full deck lists")
	var text = JSON.stringify(data)
	_check(text.find("Mine") == -1, "Replays hold no deck names")
	var restored = MatchEngine.new()
	var loaded = restored.load_replay(JSON.parse_string(text))
	_check(loaded.ok and restored.state_digest() == engine.state_digest(), "A replay with own decks restores the same state (%s)" % [loaded])
	# Format 7: preset ids only.
	var preset_engine = MatchEngine.new()
	preset_engine.start(9, ["starter", "green_assault"])
	preset_engine.apply_action(int(preset_engine.state.active_player), {"type": "pass"})
	var old = JSON.parse_string(JSON.stringify(preset_engine.replay_data()))
	old.protocol = 7
	var old_engine = MatchEngine.new()
	_check(old_engine.load_replay(old).ok and old_engine.state_digest() == preset_engine.state_digest(), "Format 7 replays still load")
	# ...but only with the current rules: every replay saved by v0.5.0 (rules
	# be677f3dead5) is refused, as README and docs/RULES.md say.
	var released = old.duplicate(true)
	released.rules = "be677f3dead5"
	var refused = MatchEngine.new().load_replay(released)
	_check(RulesVersion.RULES_VERSION != "be677f3dead5" and refused.get("code") == "replay_rules" and str(refused.args.replay) == "be677f3dead5",
		"A v0.5.0 replay is refused with replay_rules (%s)" % [refused.get("code")])
	var mixed = JSON.parse_string(text)
	mixed.protocol = 7
	_check(MatchEngine.new().load_replay(mixed).get("code") == "replay_decks", "A format 7 replay cannot hold deck lists")
	var huge = JSON.parse_string(text)
	for index in range(400):
		huge.decks[0].cards["card_%d" % index] = 1
	_check(MatchEngine.new().load_replay(huge).get("code") == "replay_decks", "Oversized deck lists are refused before the deck rules run")
	var forged = JSON.parse_string(text)
	forged.decks[0].items["short_sword"] = 7
	_check(MatchEngine.new().load_replay(forged).get("code") == "deck_item_copies", "Replayed deck lists are checked against the deck rules")
	var future = JSON.parse_string(text)
	future.protocol = 9
	_check(MatchEngine.new().load_replay(future).get("code") == "replay_version", "Unknown replay formats are refused")

func _test_bot_matches() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 404
	var bot = Bot.new()
	var finished = 0
	for match_index in range(3):
		var decks = [_random_deck(rng), _random_deck(rng)]
		_check(library.validate_preset(decks[0]).ok and library.validate_preset(decks[1]).ok, "Random custom decks are legal")
		var engine = MatchEngine.new()
		var started = engine.start(1000 + match_index, decks)
		_check(started.ok, "A bot match with random custom decks starts (%s)" % [started])
		var steps = 0
		while engine.state.winner == -1 and steps < 1500:
			var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
			var action = bot.choose_action(engine, player)
			if action.is_empty():
				break
			var applied = engine.apply_action(player, action)
			if not applied.ok:
				failures.append("Bot action rejected with custom decks: %s" % [applied])
				break
			steps += 1
		finished += int(engine.state.winner != -1)
		var replay = MatchEngine.new()
		_check(replay.load_replay(JSON.parse_string(JSON.stringify(engine.replay_data()))).ok and replay.state_digest() == engine.state_digest(),
			"Custom deck bot match %d replays identically" % match_index)
	_check(finished == 3, "The bot plays custom decks to the end (%d of 3 finished)" % finished)

## A random legal deck built with the builder's edits (DeckModel).
func _random_deck(rng: RandomNumberGenerator) -> Dictionary:
	var deck = DeckStore.blank("Random")
	var heroes: Array = []
	for hero in library.heroes:
		var signature = str(hero.get("signature", ""))
		if library.hero_deckable(str(hero.id)):
			heroes.append(str(hero.id))
	heroes.sort()
	while DeckModel.hero_count(deck) < 5:
		DeckModel.add(deck, heroes[rng.randi_range(0, heroes.size() - 1)], library)
	var main: Array = library.cards.keys().filter(func(card_id): return library.main_deckable(str(card_id)))
	main.sort()
	while DeckModel.main_count(deck) < 40:
		DeckModel.add(deck, main[rng.randi_range(0, main.size() - 1)], library)
	var items: Array = library.cards.keys().filter(func(card_id): return library.item_deckable(str(card_id)))
	items.sort()
	while DeckModel.item_count(deck) < 9:
		DeckModel.add(deck, items[rng.randi_range(0, items.size() - 1)], library)
	return deck

# --- Helpers ----------------------------------------------------------------------------------

func _same_set(a: Array, b: Array) -> bool:
	var left = a.duplicate()
	var right = b.duplicate()
	left.sort()
	right.sort()
	return left == right

func _same_counts(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key) or int(a[key]) != int(b[key]):
			return false
	return true
