extends RefCounted
## A player's own decks: one JSON file per deck in user://decks/ (<id>.json):
##   {"version": 1, "id", "name", "heroes": [5 hero ids in deploy order, ""
##    for an empty slot], "cards": {card id: copies, the heroes' signature
##    cards included}, "items": {card id: copies}, "modified": unix seconds}
## Card ids (not Valve ids) keep the files readable; deck codes
## (scripts/core/deck_code.gd) carry Valve ids. A deck may be saved while it
## still breaks deck rules (a draft): CardLibrary.validate_preset decides
## whether it can be played, and the pickers offer only valid decks.
##
## Files are untrusted (hand edits, other versions, damage): reads are
## size-limited, parsed without engine errors and sanitized; unreadable files
## are skipped and listed in `problems`. Writes go to a temporary file first.
## Tests point `root` at their own folder, never the player's decks.
##
## The decks last chosen for the two seats are remembered in choices.cfg in
## the same folder ("preset:<id>" or "deck:<id>" per seat): a deck by its id,
## so an edited deck is played as it is now.

const DeckCode = preload("res://scripts/core/deck_code.gd")
const VERSION = 1
const DEFAULT_ROOT = "user://decks"
const MAX_DECKS = 200
const MAX_FILE_BYTES = 65536
const MAX_NAME_CHARS = 32
const MAX_ENTRIES = 300
const MAX_ID_CHARS = 64
const MAX_COPIES = 99
const SLOTS = 5
const CHOICES_FILE = "choices.cfg"

## The folder decks are read from and written to.
static var root: String = DEFAULT_ROOT
## Files the last list() skipped, with the reason: [{"file", "code"}].
static var problems: Array = []

static func _path(id: String) -> String:
	return "%s/%s.json" % [root, id]

## True for an id this store writes: letters, digits, "_" and "-" (no path
## separators, so an id can never leave the folder).
static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 40:
		return false
	for character in id:
		var code = character.unicode_at(0)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or character in ["_", "-"]):
			return false
	return true

## A new random deck id ("d" + 16 hex digits).
static func new_id() -> String:
	return "d" + Crypto.new().generate_random_bytes(8).hex_encode()

## An empty deck named `name`.
static func blank(name: String = "") -> Dictionary:
	return {"version": VERSION, "id": new_id(), "name": clean_name(name), "heroes": ["", "", "", "", ""],
		"cards": {}, "items": {}, "modified": 0}

## A new deck with the lists of `source` (a preset or another deck), a new id
## and `name`.
static func copy_of(source: Dictionary, name: String) -> Dictionary:
	var deck = sanitize(source)
	if deck.is_empty():
		deck = blank(name)
	deck.id = new_id()
	deck.name = clean_name(name)
	deck.modified = 0
	return deck

## A deck name as stored and shown: cleaned (DeckCode.clean_name) and at most
## MAX_NAME_CHARS characters.
static func clean_name(text: String) -> String:
	var name = DeckCode.clean_name(text)
	if name.length() > MAX_NAME_CHARS:
		name = name.left(MAX_NAME_CHARS).strip_edges()
	return name

## `base`, or `base` with the lowest free number (" 2", " 3", ...) when a
## deck in `decks` already has that name.
static func unique_name(base: String, decks: Array) -> String:
	var taken: Dictionary = {}
	for deck in decks:
		taken[str(deck.get("name", "")).to_lower()] = true
	var name = clean_name(base)
	if not taken.has(name.to_lower()):
		return name
	for number in range(2, 1000):
		var suffix = " %d" % number
		var candidate = clean_name(name.left(MAX_NAME_CHARS - suffix.length()) + suffix)
		if not taken.has(candidate.to_lower()):
			return candidate
	return name

## A deck in the stored shape from untrusted data, or {} when `raw` is not a
## deck. Unknown card ids stay (the deck rules report them); malformed
## entries are dropped; counts become whole numbers from 1 to MAX_COPIES.
static func sanitize(raw) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var heroes: Array = []
	var raw_heroes = raw.get("heroes", [])
	if not raw_heroes is Array:
		return {}
	for index in range(SLOTS):
		var hero_id = raw_heroes[index] if index < raw_heroes.size() else ""
		heroes.append(hero_id if hero_id is String and hero_id.length() <= MAX_ID_CHARS else "")
	var deck = {"version": VERSION, "id": str(raw.get("id", "")), "name": clean_name(str(raw.get("name", "")) if raw.get("name") is String else ""),
		"heroes": heroes, "cards": {}, "items": {}, "modified": 0}
	if not valid_id(deck.id):
		deck.id = new_id()
	var modified = raw.get("modified", 0)
	if (modified is int or modified is float) and is_finite(float(modified)):
		deck.modified = maxi(0, int(modified))
	for list_name in ["cards", "items"]:
		var list = raw.get(list_name, {})
		if not list is Dictionary:
			return {}
		for card_id in list:
			if deck[list_name].size() >= MAX_ENTRIES:
				break
			var value = list[card_id]
			if not card_id is String or card_id.is_empty() or card_id.length() > MAX_ID_CHARS:
				continue
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)):
				continue
			var count = clampi(int(value), 0, MAX_COPIES)
			if count > 0:
				deck[list_name][card_id] = count
	return deck

## Every stored deck, most recently changed first (then by name). Files that
## cannot be read are skipped and recorded in `problems`.
static func list() -> Array:
	problems = []
	var decks: Array = []
	if not DirAccess.dir_exists_absolute(root):
		return decks
	var files: Array = []
	for file_name in DirAccess.get_files_at(root):
		if file_name.get_extension() == "json":
			files.append(file_name)
	files.sort()
	for file_name in files:
		if decks.size() >= MAX_DECKS:
			problems.append({"file": file_name, "code": "deck_store_full"})
			continue
		var id = file_name.get_basename()
		var deck = _read("%s/%s" % [root, file_name])
		if deck.is_empty() or not valid_id(id):
			problems.append({"file": file_name, "code": "deck_store_unreadable"})
			continue
		deck.id = id
		decks.append(deck)
	decks.sort_custom(func(a, b):
		if int(a.modified) != int(b.modified):
			return int(a.modified) > int(b.modified)
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return decks

## The stored deck `id`, or {} when it is missing or unreadable.
static func load_deck(id: String) -> Dictionary:
	if not valid_id(id):
		return {}
	var deck = _read(_path(id))
	if not deck.is_empty():
		deck.id = id
	return deck

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return {}
	var text = file.get_as_text()
	file.close()
	# JSON.parse (unlike JSON.parse_string) reports bad input without
	# logging an engine error.
	var json = JSON.new()
	if json.parse(text) != OK:
		return {}
	return sanitize(json.data)

## Writes `deck` (sanitized, with a fresh `modified` time). Returns {"ok":
## true, "deck": what was stored} or {"ok": false, "code", "args", "error"}.
static func save(deck: Dictionary) -> Dictionary:
	var clean = sanitize(deck)
	if clean.is_empty():
		return _fail("deck_store_invalid", "This deck cannot be saved.")
	if clean.name.is_empty():
		clean.name = "?"
	clean.modified = maxi(int(Time.get_unix_time_from_system()), int(deck.get("modified", 0)) + 1)
	var existing = Array(DirAccess.get_files_at(root) if DirAccess.dir_exists_absolute(root) else PackedStringArray()).filter(
		func(file_name): return str(file_name).get_extension() == "json")
	if not FileAccess.file_exists(_path(clean.id)) and existing.size() >= MAX_DECKS:
		return _fail("deck_store_full", "You have too many decks; delete one first.", {"n": MAX_DECKS})
	DirAccess.make_dir_recursive_absolute(root)
	var temporary = _path(clean.id) + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("deck_store_write", "The deck could not be saved.", {"error": error_string(FileAccess.get_open_error())})
	file.store_string(JSON.stringify(clean, "\t"))
	file.close()
	var error = DirAccess.rename_absolute(temporary, _path(clean.id))
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("deck_store_write", "The deck could not be saved.", {"error": error_string(error)})
	return {"ok": true, "deck": clean}

## Deletes the stored deck `id`.
static func delete(id: String) -> Dictionary:
	if not valid_id(id) or not FileAccess.file_exists(_path(id)):
		return _fail("deck_store_missing", "This deck no longer exists.")
	var error = DirAccess.remove_absolute(_path(id))
	if error != OK:
		return _fail("deck_store_write", "The deck could not be deleted.", {"error": error_string(error)})
	return {"ok": true}

static func _fail(code: String, message: String, args: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "args": args, "error": message}

# --- Chosen decks ------------------------------------------------------------------

## Remembers the decks of the two seats (preset ids or own decks).
static func save_choices(entries: Array) -> Error:
	var config = ConfigFile.new()
	for seat in range(mini(entries.size(), 2)):
		var entry = entries[seat]
		if entry is String and not entry.is_empty() and entry.length() <= MAX_ID_CHARS:
			config.set_value("seats", str(seat), "preset:" + entry)
		elif entry is Dictionary and valid_id(str(entry.get("id", ""))):
			config.set_value("seats", str(seat), "deck:" + str(entry.id))
	DirAccess.make_dir_recursive_absolute(root)
	return config.save("%s/%s" % [root, CHOICES_FILE])

## The remembered decks as deck entries: a preset id, or the stored deck for
## a deck id. A seat whose choice no longer resolves (a deleted or now illegal
## deck, an unknown preset) keeps its entry from `defaults`.
static func load_choices(defaults: Array, library) -> Array:
	var result: Array = defaults.duplicate(true)
	var config = ConfigFile.new()
	var path = "%s/%s" % [root, CHOICES_FILE]
	if not FileAccess.file_exists(path) or config.load(path) != OK:
		return result
	for seat in range(mini(result.size(), 2)):
		var value = config.get_value("seats", str(seat), "")
		if not value is String:
			continue
		if value.begins_with("preset:") and not library.preset(value.substr(7)).is_empty():
			result[seat] = value.substr(7)
		elif value.begins_with("deck:"):
			var deck = load_deck(value.substr(5))
			if not deck.is_empty() and library.validate_preset(deck).ok:
				result[seat] = deck
	return result
