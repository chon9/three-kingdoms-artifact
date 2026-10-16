extends RefCounted
## Deck codes in Valve's ArtifactDeckCode format (version 2, the format of
## playartifact.com/d/<code>; reference: github.com/ValveSoftware/ArtifactDeckCode,
## deck_encoder.php and deck_decoder.php). Codes name cards by their Valve
## card id, the `source_id` of every hero and card in data/classic_cards.json,
## so codes from the original game and its deck sites import here and codes
## made here open there.
##
## Text: "ADC" + base64 of the bytes with "/" -> "-" and "=" -> "_" ("+" is
## kept, so a code may contain "+"). Bytes:
##   0      version << 4 | hero count (low 3 bits, bit 3 = more bits follow)
##   1      checksum: sum of the card bytes & 0xFF (header and name excluded)
##   2      name length in bytes (version 2 only)
##   ...    hero count overflow (7-bit groups with a carry bit)
##   ...    heroes sorted by id: (turn, id delta) per hero
##   ...    cards sorted by id, main and item cards together, signature
##          cards left out: (count, id delta) per card
##   ...    the name, UTF-8, at most 63 bytes
## A card is a header byte (count - 1 in the top two bits, 3 = the count
## follows after the id; 5 bits of the id delta; 0x20 = more delta bits
## follow) and then 7-bit groups with a 0x80 carry bit.
##
## A hero's turn is the round it deploys in: the three heroes of round 1 are
## turn 1, the fourth hero turn 2 and the fifth turn 3 (Valve's README: "3
## heroes on turn 1, 1 hero on 2 and 1 hero on 3"), the same order as a deck's
## `heroes` list (MatchEngine: ready_round = 1 for heroes 1-3, then 2 and 3).
##
## Everything here is pure and bounded: decoding never trusts the input (it
## comes from the clipboard and from the network) and never logs engine
## errors; failures are {"ok": false, "code", "args", "error"} like engine
## results (i18n key ERR_<CODE>).

const PREFIX = "ADC"
const VERSION = 2
## Longest code text accepted (a full 5-hero, 40+9 card deck with a 63-byte
## name is about 150 characters).
const MAX_CODE_CHARS = 512
const MAX_NAME_BYTES = 63
const HEADER_SIZE = 3
## Most heroes and card entries a code may list.
const MAX_HEROES = 5
const MAX_CARD_ENTRIES = 200
## A varint longer than this many bits is malformed (Valve: 32-bit values).
const MAX_VARINT_SHIFT = 35
## Slots per deployment round: three heroes deploy in round 1, one in round
## 2 and one in round 3.
const TURN_SLOTS = {1: [0, 1, 2], 2: [3], 3: [4]}
const BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

## The deploy round (Valve "turn") of hero slot `index` (0-4).
static func turn_of_slot(index: int) -> int:
	return 1 if index < 3 else index - 1

# --- Encoding ------------------------------------------------------------------

## The code of a deck {name, heroes: [5 ids in deploy order, "" for an empty
## slot], cards: {id: n} with the heroes' signature cards, items: {id: n}}.
## Signature cards are left out (Valve: "signature cards for heroes SHOULD NOT
## be included"); copies beyond a hero's three are kept. Returns "" when a
## card has no Valve id.
static func encode(deck: Dictionary, library) -> String:
	var heroes: Array = []
	var signatures: Dictionary = {}
	var hero_list = deck.get("heroes", [])
	if not hero_list is Array:
		return ""
	for index in range(mini(hero_list.size(), MAX_HEROES)):
		var hero_id = str(hero_list[index])
		if hero_id.is_empty():
			continue
		var source = library.source_of(hero_id)
		if source <= 0:
			return ""
		heroes.append({"id": source, "turn": turn_of_slot(index)})
		var signature = str(library.definition(hero_id).get("signature", ""))
		if not signature.is_empty():
			signatures[signature] = int(signatures.get(signature, 0)) + 3
	var counts: Dictionary = {}
	for list_name in ["cards", "items"]:
		var list = deck.get(list_name, {})
		if not list is Dictionary:
			continue
		for card_id in list:
			var value = list[card_id]
			if not (value is int or value is float):
				continue
			var count = int(value) - int(signatures.get(str(card_id), 0)) if list_name == "cards" else int(value)
			if count <= 0:
				continue
			var source = library.source_of(str(card_id))
			if source <= 0:
				return ""
			counts[source] = int(counts.get(source, 0)) + count
	var cards: Array = []
	for source in counts:
		cards.append({"id": int(source), "count": int(counts[source])})
	return encode_raw(heroes, cards, str(deck.get("name", "")))

## Valve's encoder: `heroes` [{id, turn}], `cards` [{id, count}] by Valve id.
## Returns "" for a zero turn or count or an id below 1.
static func encode_raw(heroes: Array, cards: Array, name: String = "", version: int = VERSION) -> String:
	var sorted_heroes = heroes.duplicate()
	sorted_heroes.sort_custom(func(a, b): return int(a.id) < int(b.id))
	var sorted_cards = cards.duplicate()
	sorted_cards.sort_custom(func(a, b): return int(a.id) < int(b.id))
	var name_bytes = trim_name(name).to_utf8_buffer() if version > 1 else PackedByteArray()
	var bytes = PackedByteArray()
	bytes.append(version << 4 | _bits_with_carry(sorted_heroes.size(), 3))
	bytes.append(0)
	if version > 1:
		bytes.append(name_bytes.size())
	_append_rest(sorted_heroes.size(), 3, bytes)
	var previous = 0
	for hero in sorted_heroes:
		if int(hero.turn) <= 0 or int(hero.id) <= previous:
			return ""
		_append_card(int(hero.turn), int(hero.id) - previous, bytes)
		previous = int(hero.id)
	previous = 0
	for card in sorted_cards:
		if int(card.count) <= 0 or int(card.id) <= previous:
			return ""
		_append_card(int(card.count), int(card.id) - previous, bytes)
		previous = int(card.id)
	var header = HEADER_SIZE if version > 1 else 2
	var checksum = 0
	for index in range(header, bytes.size()):
		checksum += bytes[index]
	bytes[1] = checksum & 0xFF
	bytes.append_array(name_bytes)
	return PREFIX + Marshalls.raw_to_base64(bytes).replace("/", "-").replace("=", "_")

static func _bits_with_carry(value: int, bits: int) -> int:
	var limit = 1 << bits
	var result = value & (limit - 1)
	if value >= limit:
		result |= limit
	return result

## Writes `value` without its first `written` bits as 7-bit groups.
static func _append_rest(value: int, written: int, bytes: PackedByteArray) -> void:
	value >>= written
	while value > 0:
		bytes.append(_bits_with_carry(value, 7))
		value >>= 7

static func _append_card(count: int, delta: int, bytes: PackedByteArray) -> void:
	var extended = count - 1 >= 3
	bytes.append(((3 if extended else count - 1) << 6) | _bits_with_carry(delta, 5))
	_append_rest(delta, 5, bytes)
	if extended:
		_append_rest(count, 0, bytes)

## A deck name as a code carries it: cleaned (clean_name) and cut to whole
## characters of at most MAX_NAME_BYTES UTF-8 bytes.
static func trim_name(name: String) -> String:
	var result = clean_name(name)
	while result.to_utf8_buffer().size() > MAX_NAME_BYTES:
		result = result.left(result.length() - 1)
	return result

## A display-safe deck name: no control characters and no markup brackets
## (tags, BBCode or {placeholders} cannot leak into labels or templates),
## whitespace collapsed and trimmed. Valve's tools run strip_tags() on names.
static func clean_name(text: String) -> String:
	var result = ""
	var in_tag = false
	for character in text:
		var code = character.unicode_at(0)
		if character == "<":
			in_tag = true
			continue
		if in_tag:
			if character == ">":
				in_tag = false
			continue
		if code < 32 or code == 127 or (code >= 0x80 and code < 0xA0) or character in ["[", "]", "{", "}", ">"]:
			continue
		if code == 0x2028 or code == 0x2029 or code == 0xFEFF:
			continue
		result += character
	while result.contains("  "):
		result = result.replace("  ", " ")
	return result.strip_edges()

# --- Decoding ------------------------------------------------------------------

## The code inside pasted text: surrounding whitespace, a link such as
## playartifact.com/d/<code> or a percent-encoded "+" (%2B) are accepted.
## Returns "" when the text holds no code.
static func extract(text: String) -> String:
	var value = text.strip_edges()
	if value.length() > MAX_CODE_CHARS * 3:
		return ""
	var start = value.find(PREFIX)
	if start == -1:
		return ""
	var result = ""
	var index = start
	while index < value.length():
		var character = value[index]
		if character == "%" and index + 2 < value.length():
			var escaped = value.substr(index + 1, 2).to_upper()
			var replacement = {"2B": "+", "2F": "/", "3D": "="}.get(escaped, "")
			if replacement.is_empty():
				break
			result += replacement
			index += 3
			continue
		if not _code_character(character):
			break
		result += character
		index += 1
	return result

static func _code_character(character: String) -> bool:
	var code = character.unicode_at(0)
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
		or character in ["+", "-", "_", "/", "="]

## Valve's decoder: {"ok": true, "version", "checksum", "heroes": [{id, turn}],
## "cards": [{id, count}], "name"} by Valve id, in code order, or a failure.
static func parse(text: String) -> Dictionary:
	var code = extract(text)
	if code.is_empty():
		return _fail("deck_code_prefix", "This is not a deck code (codes start with ADC).")
	if code.length() > MAX_CODE_CHARS:
		return _fail("deck_code_too_long", "This deck code is too long.", {"n": MAX_CODE_CHARS})
	var bytes = _base64(code.substr(PREFIX.length()).replace("-", "/").replace("_", "="))
	if bytes.is_empty():
		return _fail("deck_code_base64", "This deck code is damaged (invalid characters).")
	var version = bytes[0] >> 4
	if version != 1 and version != 2:
		return _fail("deck_code_version", "Unsupported deck code version %d." % version, {"version": version})
	var header = HEADER_SIZE if version > 1 else 2
	if bytes.size() < header:
		return _fail("deck_code_truncated", "This deck code is incomplete.")
	var name_length = bytes[2] if version > 1 else 0
	var card_end = bytes.size() - name_length
	if card_end < header:
		return _fail("deck_code_truncated", "This deck code is incomplete.")
	var checksum = 0
	for index in range(header, card_end):
		checksum += bytes[index]
	if checksum & 0xFF != bytes[1]:
		return _fail("deck_code_checksum", "This deck code is damaged (checksum mismatch).")
	var reader = {"bytes": bytes, "index": header, "end": card_end, "ok": true}
	var hero_count = _read_varint(reader, bytes[0], 3)
	if not reader.ok:
		return _fail("deck_code_truncated", "This deck code is incomplete.")
	if hero_count > MAX_HEROES:
		return _fail("deck_code_hero_turns", "A deck code lists at most five heroes.", {"n": hero_count})
	var heroes: Array = []
	var previous = 0
	for _hero in range(hero_count):
		var entry = _read_card(reader, previous)
		if not reader.ok:
			return _fail("deck_code_truncated", "This deck code is incomplete.")
		heroes.append({"id": entry[0], "turn": entry[1]})
		previous = entry[0]
	var cards: Array = []
	previous = 0
	while reader.index < card_end:
		if cards.size() >= MAX_CARD_ENTRIES:
			return _fail("deck_code_too_long", "This deck code lists too many cards.", {"n": MAX_CARD_ENTRIES})
		var entry = _read_card(reader, previous)
		if not reader.ok:
			return _fail("deck_code_truncated", "This deck code is incomplete.")
		cards.append({"id": entry[0], "count": entry[1]})
		previous = entry[0]
	var name = clean_name(_utf8(bytes.slice(card_end)))
	return {"ok": true, "version": version, "checksum": bytes[1], "heroes": heroes, "cards": cards, "name": name}

## A deck of `library` from a code: {"ok": true, "deck": {name, heroes (five
## slots in deploy order, "" when empty), cards (with three copies of each
## hero's signature card), items}} or a failure. The deck itself may still
## break deck rules (fewer than five heroes, a small main deck): run
## validate_preset before playing it. Unknown Valve ids and cards this game
## cannot put in a deck (drafts, tokens) fail with their own codes.
static func decode(text: String, library) -> Dictionary:
	var raw = parse(text)
	if not raw.ok:
		return raw
	var slots: Array = ["", "", "", "", ""]
	var by_turn: Dictionary = {1: [], 2: [], 3: []}
	for hero in raw.heroes:
		var turn = int(hero.turn)
		if not by_turn.has(turn) or by_turn[turn].size() >= TURN_SLOTS[turn].size():
			return _fail("deck_code_hero_turns", "A deck code needs three round 1 heroes, one round 2 hero and one round 3 hero.")
		var hero_id = library.card_by_source(int(hero.id))
		if hero_id.is_empty():
			return _fail("deck_code_unknown_card", "This deck code contains an unknown card (%d)." % int(hero.id), {"id": int(hero.id)})
		var definition = library.definition(hero_id)
		if str(definition.get("kind", "")) != "hero":
			return _fail("deck_code_hero_turns", "A deck code names a card that is not a hero as a hero.", {"card": hero_id})
		if not library.hero_deckable(hero_id):
			# Also a hero whose signature card cannot be in a deck yet (a draft).
			return _fail("deck_code_unavailable", "%s cannot be used in a deck yet." % hero_id, {"card": hero_id})
		by_turn[turn].append(hero_id)
	for turn in by_turn:
		for index in range(by_turn[turn].size()):
			slots[TURN_SLOTS[turn][index]] = by_turn[turn][index]
	var cards: Dictionary = {}
	var items: Dictionary = {}
	var signatures: Array = []
	for hero_id in slots:
		if not str(hero_id).is_empty():
			var signature = str(library.definition(hero_id).get("signature", ""))
			if not signature.is_empty():
				signatures.append(signature)
	for entry in raw.cards:
		var card_id = library.card_by_source(int(entry.id))
		if card_id.is_empty():
			return _fail("deck_code_unknown_card", "This deck code contains an unknown card (%d)." % int(entry.id), {"id": int(entry.id)})
		var card = library.get_card(card_id)
		if card.is_empty():
			# A hero listed among the cards.
			return _fail("deck_code_unavailable", "%s cannot be used as a deck card." % card_id, {"card": card_id})
		if not library.deckable(card_id) or (str(card.get("kind", "")) == "item" and not library.item_deckable(card_id)):
			return _fail("deck_code_unavailable", "%s cannot be used in a deck yet." % card_id, {"card": card_id})
		if str(card.get("kind", "")) == "item":
			items[card_id] = int(items.get(card_id, 0)) + int(entry.count)
		elif card_id in signatures:
			# Codes from other tools may list signature cards: a hero always
			# brings exactly three.
			cards[card_id] = 3
		else:
			cards[card_id] = int(cards.get(card_id, 0)) + int(entry.count)
	for signature in signatures:
		cards[signature] = 3
	return {"ok": true, "deck": {"name": str(raw.name), "heroes": slots, "cards": cards, "items": items}}

## Reads a variable-length number whose first `base_bits` bits sit in
## `base_value` (0 bits: all of it follows in 7-bit groups).
static func _read_varint(reader: Dictionary, base_value: int, base_bits: int) -> int:
	var result = 0
	var shift = 0
	var more = base_bits == 0
	if base_bits > 0:
		result = base_value & ((1 << base_bits) - 1)
		more = base_value & (1 << base_bits) != 0
		shift = base_bits
	while more:
		if reader.index >= reader.end or shift > MAX_VARINT_SHIFT:
			reader.ok = false
			return 0
		var next: int = reader.bytes[reader.index]
		reader.index += 1
		result |= (next & 0x7F) << shift
		more = next & 0x80 != 0
		shift += 7
	return result

## One serialized card: [id, count] (the count is a hero's turn).
static func _read_card(reader: Dictionary, previous: int) -> Array:
	if reader.index >= reader.end:
		reader.ok = false
		return [0, 0]
	var header: int = reader.bytes[reader.index]
	reader.index += 1
	var extended = (header >> 6) == 3
	var delta = _read_varint(reader, header, 5)
	if not reader.ok:
		return [0, 0]
	var count = _read_varint(reader, 0, 0) if extended else (header >> 6) + 1
	if not reader.ok or count <= 0 or previous + delta <= 0:
		reader.ok = false
		return [0, 0]
	return [previous + delta, count]

## Strict standard base64 (padding optional); empty on any invalid input.
static func _base64(text: String) -> PackedByteArray:
	var out = PackedByteArray()
	var buffer = 0
	var bits = 0
	var padding = 0
	for character in text:
		if character == "=":
			padding += 1
			continue
		if padding > 0:
			return PackedByteArray()
		var value = BASE64.find(character)
		if value == -1:
			return PackedByteArray()
		buffer = (buffer << 6) | value
		bits += 6
		if bits >= 8:
			bits -= 8
			out.append((buffer >> bits) & 0xFF)
			buffer &= (1 << bits) - 1
	if padding > 2 or (text.length() % 4 != 0 and padding > 0):
		return PackedByteArray()
	return out

## UTF-8 to text without engine errors: invalid sequences become U+FFFD and
## control characters (U+0000-U+001F, U+007F) are dropped.
static func _utf8(bytes: PackedByteArray) -> String:
	var result = ""
	var index = 0
	while index < bytes.size():
		var lead = bytes[index]
		var length = 1
		var code = lead
		if lead >= 0xF0 and lead <= 0xF4:
			length = 4
			code = lead & 0x07
		elif lead >= 0xE0:
			length = 3
			code = lead & 0x0F
		elif lead >= 0xC2 and lead <= 0xDF:
			length = 2
			code = lead & 0x1F
		elif lead >= 0x80:
			result += String.chr(0xFFFD)
			index += 1
			continue
		if index + length > bytes.size():
			result += String.chr(0xFFFD)
			break
		var valid = true
		for offset in range(1, length):
			var next = bytes[index + offset]
			if next & 0xC0 != 0x80:
				valid = false
				break
			code = (code << 6) | (next & 0x3F)
		var minimum = [0, 0, 0x80, 0x800, 0x10000][length]
		if not valid or code < minimum or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF):
			result += String.chr(0xFFFD)
			index += 1
			continue
		if code < 0x20 or code == 0x7F:
			# Control characters (NUL makes String.chr log an engine error)
			# never belong in a deck name: drop them.
			index += length
			continue
		result += String.chr(code)
		index += length
	return result

static func _fail(code: String, message: String, args: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "args": args, "error": message}
