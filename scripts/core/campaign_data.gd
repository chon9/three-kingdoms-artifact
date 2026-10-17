extends RefCounted
## The campaign, "The Storyteller's Tales" (说书·三国演义): a storyteller in a
## teahouse tells one episode of the Three Kingdoms per chapter, and in each
## chapter the player fights one of the preset decks. Everything about it is
## data in data/campaign/campaign.json (acts, chapters, decks, seeds, seals
## and every story page in both languages), so a chapter is added or changed
## by editing that file alone. Chapters are played in the order the acts list
## them. Nothing here touches match state: a campaign match is an ordinary
## match against the AI.
##
## Every user-facing string in the file is {"en", "zh_CN"}; text() picks the
## current language and falls back to English. A speaker with a "card" takes
## its name from that card in the Three Kingdoms skin whatever the card theme
## (the tales are Three Kingdoms history); deck and hero names shown around a
## match follow the active card theme like everywhere else.

const Library = preload("res://scripts/core/card_library.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const PATH = "res://data/campaign/campaign.json"
const SCHEMA_VERSION = 1
## The skin speaker names (and story art) come from.
const STORY_SKIN = "three_kingdoms"
## The epilogue's pseudo chapter id for pages() and text().
const EPILOGUE = "epilogue"
## Page lists: a chapter's intro, victory and defeat pages; the epilogue's pages.
const PAGE_LISTS = {"intro": "intro", "victory": "outro_victory", "defeat": "outro_defeat", "epilogue": "pages"}
## Seals of a win, as bits: the victory itself, no tower of yours lost, and a
## win within the chapter's par rounds.
const SEAL_WIN = 1
const SEAL_NO_TOWER = 2
const SEAL_PAR = 4
const ALL_SEALS = 7
const SEAL_BITS = [SEAL_WIN, SEAL_NO_TOWER, SEAL_PAR]
## Art ids starting with this name a file in assets/art/ui/.
const UI_ART_PREFIX = "ui/"
## Curly quotes in English text, and the straight quotes shown instead: the
## bundled CJK fonts draw curly quotes full-width (as Chinese text wants).
const ENGLISH_QUOTES = {"‘": "'", "’": "'", "“": "\"", "”": "\""}

static var _data: Dictionary = {}
static var _chapters: Dictionary = {}
static var _order: Array = []

# --- The file ----------------------------------------------------------------------

## The whole campaign file ({} when it is missing or unreadable).
static func data() -> Dictionary:
	if _data.is_empty():
		_load()
	return _data

## Reads the campaign file again (tests, tools).
static func reload() -> void:
	_data = {}
	_load()

static func _load() -> void:
	_chapters = {}
	_order = []
	var text = FileAccess.get_file_as_string(PATH)
	var json = JSON.new()
	if text.is_empty() or json.parse(text) != OK or not json.data is Dictionary:
		push_error("Campaign file %s is missing or invalid." % PATH)
		_data = {"acts": [], "chapters": []}
		return
	_data = json.data
	for chapter in _data.get("chapters", []):
		if chapter is Dictionary and not str(chapter.get("id", "")).is_empty():
			_chapters[str(chapter.id)] = chapter
	for entry in acts():
		for chapter_id in entry.get("chapters", []):
			if _chapters.has(str(chapter_id)) and str(chapter_id) not in _order:
				_order.append(str(chapter_id))

# --- Structure ---------------------------------------------------------------------

static func acts() -> Array:
	var list = data().get("acts", [])
	return list.filter(func(entry): return entry is Dictionary) if list is Array else []

static func act_ids() -> Array:
	return acts().map(func(entry): return str(entry.get("id", "")))

static func act(act_id: String) -> Dictionary:
	for entry in acts():
		if str(entry.get("id", "")) == act_id:
			return entry
	return {}

## The known chapters of an act, in play order.
static func act_chapters(act_id: String) -> Array:
	var ids: Array = []
	for chapter_id in act(act_id).get("chapters", []):
		if has_chapter(str(chapter_id)):
			ids.append(str(chapter_id))
	return ids

## Every chapter id in play order.
static func chapter_ids() -> Array:
	data()
	return _order.duplicate()

static func has_chapter(chapter_id: String) -> bool:
	data()
	return _chapters.has(chapter_id)

static func chapter(chapter_id: String) -> Dictionary:
	data()
	return _chapters.get(chapter_id, {})

## The act a chapter belongs to ("" when unknown).
static func act_of(chapter_id: String) -> String:
	for entry in acts():
		if chapter_id in entry.get("chapters", []):
			return str(entry.get("id", ""))
	return ""

## Position in play order (-1 when unknown).
static func index_of(chapter_id: String) -> int:
	data()
	return _order.find(chapter_id)

static func previous_chapter(chapter_id: String) -> String:
	var index = index_of(chapter_id)
	return _order[index - 1] if index > 0 else ""

static func next_chapter(chapter_id: String) -> String:
	var index = index_of(chapter_id)
	return _order[index + 1] if index >= 0 and index + 1 < _order.size() else ""

static func first_chapter() -> String:
	data()
	return _order[0] if not _order.is_empty() else ""

static func last_chapter() -> String:
	data()
	return _order[-1] if not _order.is_empty() else ""

static func epilogue() -> Dictionary:
	var entry = data().get("epilogue", {})
	return entry if entry is Dictionary else {}

## The chapter whose victory opens the epilogue ("" when there is none).
static func epilogue_unlock_after() -> String:
	var after = str(epilogue().get("unlock_after", ""))
	return after if has_chapter(after) else ""

# --- Chapter fields ----------------------------------------------------------------

static func year(chapter_id: String) -> int:
	return int(chapter(chapter_id).get("year", 0))

## The deck the tale gives the player (a preset id).
static func player_default(chapter_id: String) -> String:
	return str(chapter(chapter_id).get("player_preset", ""))

## Other presets the tale suggests for the player's side.
static func player_alternatives(chapter_id: String) -> Array:
	var list = chapter(chapter_id).get("player_alternatives", [])
	return list.map(func(entry): return str(entry)) if list is Array else []

## The enemy's preset id.
static func enemy_preset(chapter_id: String) -> String:
	return str(chapter(chapter_id).get("opponent_preset", ""))

## The hero card leading the enemy (shown on the match intro's top plate).
static func enemy_commander(chapter_id: String) -> String:
	return str(chapter(chapter_id).get("enemy_commander", ""))

## The fixed match seed: every attempt of a chapter deals the same way.
static func match_seed(chapter_id: String) -> int:
	return int(chapter(chapter_id).get("seed", 1))

## The third seal: a win within this many rounds.
static func par_rounds(chapter_id: String) -> int:
	return int(chapter(chapter_id).get("par_rounds", 0))

## True when the player's side lost in the histories (a win rewrites the scroll).
static func defy_fate(chapter_id: String) -> bool:
	return bool(chapter(chapter_id).get("defy_fate", false))

## The chapter's illustration (a card id or "ui/<file>").
static func art(chapter_id: String) -> String:
	if chapter_id == EPILOGUE:
		return str(epilogue().get("art", ""))
	return str(chapter(chapter_id).get("art", ""))

## The enemy deck entry for MatchEngine.start(): the preset id, or, when the
## chapter orders the enemy's heroes ("hero_order", the same five heroes in
## the story's deploy order: slots 0-2 deploy in round 1, slot 3 in round 2,
## slot 4 in round 3), a copy of the preset with that hero list. The copy's
## "preset" names it after the preset (MatchController.deck_name_in).
static func enemy_deck(chapter_id: String, library):
	var preset_id = enemy_preset(chapter_id)
	var order = chapter(chapter_id).get("hero_order", [])
	if not order is Array or order.is_empty():
		return preset_id
	var preset: Dictionary = library.preset(preset_id)
	if preset.is_empty():
		return preset_id
	var heroes: Array = order.map(func(hero_id): return str(hero_id))
	var sorted_order = heroes.duplicate()
	sorted_order.sort()
	var sorted_preset: Array = preset.get("heroes", []).map(func(hero_id): return str(hero_id))
	sorted_preset.sort()
	if sorted_order != sorted_preset:
		push_warning("Campaign chapter %s: hero_order is not the preset's heroes; the preset order is used." % chapter_id)
		return preset_id
	return {"preset": preset_id, "name": "", "heroes": heroes, "cards": preset.get("cards", {}).duplicate(),
		"items": preset.get("items", {}).duplicate()}

## The enemy's five heroes in deploy order.
static func enemy_heroes(chapter_id: String, library) -> Array:
	var deck = enemy_deck(chapter_id, library)
	var entry: Dictionary = library.resolve_deck(deck)
	return entry.get("heroes", []).map(func(hero_id): return str(hero_id))

# --- Text --------------------------------------------------------------------------

## `value` in the current language (or `locale`), falling back to English: a
## {"en", "zh_CN"} dictionary, or a plain string as is.
static func text(value, locale: String = "") -> String:
	if value is String:
		return value
	if value is Dictionary:
		var language = Settings.normalize_locale(locale) if not locale.is_empty() else Library.current_locale()
		for key in [language, "en"]:
			if not str(value.get(key, "")).is_empty():
				return english(str(value[key])) if key == "en" else str(value[key])
	return ""

## English text as shown: curly quotes straightened (ENGLISH_QUOTES).
static func english(text: String) -> String:
	for quote in ENGLISH_QUOTES:
		text = text.replace(quote, ENGLISH_QUOTES[quote])
	return text

## A chapter's text field ("title", "teaser", "objective", "era",
## "history_note", "cast_note"); EPILOGUE gives the epilogue's.
static func chapter_text(chapter_id: String, field: String, locale: String = "") -> String:
	var source: Dictionary = epilogue() if chapter_id == EPILOGUE else chapter(chapter_id)
	return text(source.get(field), locale)

static func title(chapter_id: String, locale: String = "") -> String:
	return chapter_text(chapter_id, "title", locale)

## The campaign's own text ("title", "description").
static func campaign_text(field: String, locale: String = "") -> String:
	return text(data().get(field), locale)

## An act's text ("title", "subtitle").
static func act_text(act_id: String, field: String, locale: String = "") -> String:
	return text(act(act_id).get(field), locale)

## The raw pages of a chapter's `kind` ("intro", "victory", "defeat"), or the
## epilogue's pages for EPILOGUE: [{"art", "speaker", "text": {en, zh_CN}}].
## Views localize them as they draw (a language switch re-renders a page).
static func pages(chapter_id: String, kind: String = "intro") -> Array:
	var source: Dictionary = epilogue() if chapter_id == EPILOGUE else chapter(chapter_id)
	var list = source.get(PAGE_LISTS.get(kind if chapter_id != EPILOGUE else "epilogue", ""), [])
	return list.filter(func(page): return page is Dictionary) if list is Array else []

static func page_text(page: Dictionary, locale: String = "") -> String:
	return text(page.get("text"), locale)

## A speaker's display name: a hero speaker's card name in the Three Kingdoms
## skin, otherwise its own name ("" for no speaker or an unknown one).
static func speaker_name(speaker: String, locale: String = "") -> String:
	var entry = data().get("speakers", {}).get(speaker, {})
	if not entry is Dictionary or entry.is_empty():
		return ""
	if entry.has("card"):
		var language = Settings.normalize_locale(locale) if not locale.is_empty() else Library.current_locale()
		return Library.loc(str(entry.card), "name", language, STORY_SKIN)
	return text(entry.get("name"), locale)

# --- Seals -------------------------------------------------------------------------

## The seals a result earns (a bit mask of SEAL_*; 0 without a win).
static func seals_for(won: bool, towers_lost: int, rounds: int, par: int) -> int:
	if not won:
		return 0
	var mask = SEAL_WIN
	if towers_lost <= 0:
		mask |= SEAL_NO_TOWER
	if par > 0 and rounds > 0 and rounds <= par:
		mask |= SEAL_PAR
	return mask

static func seal_count(mask: int) -> int:
	var count = 0
	for bit in SEAL_BITS:
		if mask & bit:
			count += 1
	return count

## The three seals' names for a chapter with `par` rounds.
static func seal_names(par: int) -> Array:
	return [EventText.t("CAMPAIGN_SEAL_WIN"), EventText.t("CAMPAIGN_SEAL_NO_TOWER"), EventText.t("CAMPAIGN_SEAL_PAR", {"n": par})]

## "● Win the battle   ○ Lose no tower   ○ Win by round 12" for `mask`.
static func seal_line(mask: int, par: int) -> String:
	var names = seal_names(par)
	var parts: Array = []
	for index in range(SEAL_BITS.size()):
		parts.append(("● " if mask & SEAL_BITS[index] else "○ ") + str(names[index]))
	return "   ".join(parts)
