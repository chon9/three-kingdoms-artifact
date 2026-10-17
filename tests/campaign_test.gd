extends SceneTree
## The campaign ("The Storyteller's Tales", data/campaign/campaign.json):
## the file's shape and every reference in it (presets, heroes, commanders,
## hero orders, art, speakers, seeds), every text in both languages within
## its length budget, every character in the bundled fonts, the progress
## store (fresh, unlocks, seals, records, deck choices, reset, a damaged
## file, a newer version's file, chapters it no longer has, its own test
## file), and that every tale starts a valid match with its armies, its
## enemy's heroes in story order and its seed. With `-- --bots` two bot
## games per tale also play out and the win rates are printed (balance
## tuning; slow).

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const Library = preload("res://scripts/core/card_library.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const CampaignData = preload("res://scripts/core/campaign_data.gd")
const CampaignStore = preload("res://scripts/core/campaign_store.gd")
const LOCALES = ["en", "zh_CN"]
## Story page length budgets (characters).
const PAGE_BUDGET = {"en": 220, "zh_CN": 90}
const FONT_FILES = ["res://assets/fonts/SanguoKai-Medium.ttf", "res://assets/fonts/NotoSansSC-Regular.otf",
	"res://assets/fonts/NotoSansSC-Bold.otf"]
const TEST_PATH = "user://test_campaign.cfg"
var checks = 0
var failures: Array = []
var library = Library.new()
## Every user-facing string of the file (for the glyph check).
var texts: Array = []
var errors = ErrorCatcher.new()

## Engine and script errors fail the run, except the one a damaged progress
## file is expected to log.
class ErrorCatcher:
	extends Logger
	var messages: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var message = "%s:%d %s %s %s" % [file, line, function, code, rationale]
		if message.contains("ConfigFile parse error"):
			return
		messages.append(message)

	func _log_message(_message: String, _error: bool) -> void:
		pass

func _initialize() -> void:
	OS.add_logger(errors)
	_structure()
	_text()
	_glyphs()
	print("(A ConfigFile parse error below is expected: the damaged-file check.)")
	_store()
	_matches()
	if "--bots" in OS.get_cmdline_user_args():
		_bot_games()
	_check(errors.messages.is_empty(), "No engine or script errors: %s" % "; ".join(errors.messages))
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d campaign checks (file shape, presets, heroes, commanders, art, speakers, both languages, page budgets, font glyphs, progress store, every tale's match)." % [
		"PASS" if failures.is_empty() else "FAIL", checks])
	Settings.set_locale("en", false)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

## A {"en", "zh_CN"} text: both present and non-empty; collected for the
## glyph check.
func _bilingual(value, what: String) -> void:
	var ok = value is Dictionary
	for locale in LOCALES:
		ok = ok and value.get(locale) is String and not str(value.get(locale)).strip_edges().is_empty()
	_check(ok, "%s has en and zh_CN text" % what)
	if value is Dictionary:
		for locale in LOCALES:
			texts.append(str(value.get(locale, "")))

func _art_exists(art: String) -> bool:
	if art.begins_with(CampaignData.UI_ART_PREFIX):
		return FileAccess.file_exists("res://assets/art/ui/" + art.substr(CampaignData.UI_ART_PREFIX.length()))
	return FileAccess.file_exists("res://assets/art/cards/%s.jpg" % art) and not library.definition(art).is_empty()

# --- The file ----------------------------------------------------------------------

func _structure() -> void:
	var data = CampaignData.data()
	_check(int(data.get("schema_version", 0)) == CampaignData.SCHEMA_VERSION, "Schema version %d" % CampaignData.SCHEMA_VERSION)
	_check(data.get("acts") is Array and data.get("chapters") is Array and data.get("speakers") is Dictionary, "Acts, chapters and speakers are present")
	var presets: Dictionary = {}
	for preset in library.presets():
		presets[str(preset.id)] = preset
	_check(presets.size() == 24, "24 preset decks (%d)" % presets.size())
	# Chapter ids are unique, every chapter is in exactly one act, and the acts
	# list them in the chapters' own order.
	var ids: Array = []
	for chapter in data.get("chapters", []):
		var chapter_id = str(chapter.get("id", ""))
		_check(not chapter_id.is_empty() and chapter_id not in ids and chapter_id != CampaignData.EPILOGUE, "Chapter id %s is unique" % chapter_id)
		ids.append(chapter_id)
	var listed: Array = []
	for act in data.get("acts", []):
		var act_id = str(act.get("id", ""))
		_check(not act_id.is_empty() and act.get("chapters") is Array and not act.chapters.is_empty(), "Act %s has chapters" % act_id)
		for chapter_id in act.get("chapters", []):
			_check(str(chapter_id) in ids and str(chapter_id) not in listed, "Act %s lists %s once" % [act_id, chapter_id])
			_check(str(CampaignData.chapter(str(chapter_id)).get("act", "")) == act_id, "Chapter %s names its act %s" % [chapter_id, act_id])
			listed.append(str(chapter_id))
	_check(listed == ids and CampaignData.chapter_ids() == ids, "The acts list every chapter in the chapters' order")
	_check(ids.size() == 24 and CampaignData.act_ids().size() == 4, "24 chapters in 4 acts (%d, %d)" % [ids.size(), CampaignData.act_ids().size()])
	# Each preset is the enemy of exactly one tale.
	var enemies: Dictionary = {}
	var seeds: Dictionary = {}
	var last_year = 0
	for index in range(ids.size()):
		var chapter_id: String = ids[index]
		var chapter = CampaignData.chapter(chapter_id)
		_check(int(chapter.get("index", -1)) == index, "Chapter %s has index %d" % [chapter_id, index])
		var year = CampaignData.year(chapter_id)
		_check(year >= 180 and year <= 280 and year >= last_year, "Chapter %s's year %d follows the one before" % [chapter_id, year])
		last_year = year
		var enemy = CampaignData.enemy_preset(chapter_id)
		_check(presets.has(enemy), "Chapter %s's enemy %s is a preset" % [chapter_id, enemy])
		enemies[enemy] = int(enemies.get(enemy, 0)) + 1
		_check(presets.has(CampaignData.player_default(chapter_id)), "Chapter %s's army %s is a preset" % [chapter_id, CampaignData.player_default(chapter_id)])
		var alternatives = chapter.get("player_alternatives", [])
		_check(alternatives is Array, "Chapter %s's alternatives are a list" % chapter_id)
		for alternative in CampaignData.player_alternatives(chapter_id):
			_check(presets.has(alternative) and alternative != CampaignData.player_default(chapter_id), "Chapter %s's alternative %s is another preset" % [chapter_id, alternative])
		var enemy_heroes: Array = presets.get(enemy, {}).get("heroes", [])
		var commander = CampaignData.enemy_commander(chapter_id)
		_check(commander in enemy_heroes, "Chapter %s's commander %s leads the enemy army" % [chapter_id, commander])
		var order = chapter.get("hero_order", [])
		if not order.is_empty():
			var sorted_order = order.duplicate()
			sorted_order.sort()
			var sorted_preset = enemy_heroes.duplicate()
			sorted_preset.sort()
			_check(sorted_order == sorted_preset, "Chapter %s's hero order is the enemy's five heroes" % chapter_id)
		var seed_value = chapter.get("seed")
		_check((seed_value is int or seed_value is float) and int(seed_value) > 0 and not seeds.has(int(seed_value)), "Chapter %s has its own seed" % chapter_id)
		seeds[int(seed_value)] = true
		_check(CampaignData.par_rounds(chapter_id) >= 3 and CampaignData.par_rounds(chapter_id) <= 30, "Chapter %s's par rounds are sensible" % chapter_id)
		_check(chapter.get("defy_fate") is bool, "Chapter %s says whether it defies fate" % chapter_id)
		_check(_art_exists(CampaignData.art(chapter_id)), "Chapter %s's art %s exists" % [chapter_id, CampaignData.art(chapter_id)])
		for kind in ["intro", "victory", "defeat"]:
			var pages = CampaignData.pages(chapter_id, kind)
			_check(not pages.is_empty() and pages.size() <= 6, "Chapter %s has %s pages (%d)" % [chapter_id, kind, pages.size()])
			for page in pages:
				_page(page, "%s %s" % [chapter_id, kind])
		_check(CampaignData.pages(chapter_id, "intro").size() >= 3, "Chapter %s's story has at least three pages" % chapter_id)
	for preset_id in presets:
		_check(int(enemies.get(preset_id, 0)) == 1, "Preset %s is the enemy of exactly one tale (%d)" % [preset_id, int(enemies.get(preset_id, 0))])
	# The epilogue.
	var epilogue = CampaignData.epilogue()
	_check(CampaignData.epilogue_unlock_after() == CampaignData.last_chapter(), "The epilogue opens after the last tale")
	_check(_art_exists(CampaignData.art(CampaignData.EPILOGUE)), "The epilogue's art exists")
	_check(not CampaignData.pages(CampaignData.EPILOGUE, "epilogue").is_empty(), "The epilogue has pages")
	for page in CampaignData.pages(CampaignData.EPILOGUE, "epilogue"):
		_page(page, "epilogue")
	_check(epilogue.get("title") is Dictionary, "The epilogue has a title")
	# Speakers: a hero card or a name of their own.
	for speaker in data.get("speakers", {}):
		var entry = data.speakers[speaker]
		if entry.has("card"):
			_check(library.definition(str(entry.card)).get("kind", "") == "hero", "Speaker %s is the hero %s" % [speaker, entry.card])
		else:
			_bilingual(entry.get("name"), "Speaker %s's name" % speaker)

func _page(page: Dictionary, where: String) -> void:
	_check(_art_exists(str(page.get("art", ""))), "%s page art %s exists" % [where, page.get("art", "")])
	var speaker = str(page.get("speaker", ""))
	_check(speaker.is_empty() or CampaignData.data().speakers.has(speaker), "%s page speaker %s is known" % [where, speaker])
	_bilingual(page.get("text"), "%s page" % where)
	var text = page.get("text", {})
	if text is Dictionary:
		for locale in LOCALES:
			var length = str(text.get(locale, "")).length()
			_check(length <= PAGE_BUDGET[locale], "%s page fits the %s budget (%d of %d characters)" % [where, locale, length, PAGE_BUDGET[locale]])

# --- Text --------------------------------------------------------------------------

func _text() -> void:
	var data = CampaignData.data()
	_bilingual(data.get("title"), "The campaign title")
	_bilingual(data.get("description"), "The campaign description")
	for act_id in CampaignData.act_ids():
		for field in ["title", "subtitle"]:
			_bilingual(CampaignData.act(act_id).get(field), "Act %s %s" % [act_id, field])
	for chapter_id in CampaignData.chapter_ids():
		for field in ["title", "teaser", "objective", "era", "history_note", "cast_note"]:
			_bilingual(CampaignData.chapter(chapter_id).get(field), "Chapter %s %s" % [chapter_id, field])
		# The cast note shows in the briefing beside the two armies.
		var cast = CampaignData.chapter(chapter_id).get("cast_note", {})
		for locale in LOCALES:
			var length = str(cast.get(locale, "")).length() if cast is Dictionary else 0
			_check(length <= PAGE_BUDGET[locale], "Chapter %s cast note fits the %s budget (%d of %d characters)" % [chapter_id, locale, length, PAGE_BUDGET[locale]])
	_cast()
	for field in ["title", "era", "history_note"]:
		_bilingual(CampaignData.epilogue().get(field), "Epilogue %s" % field)
	# Names in both languages: hero speakers from the Three Kingdoms skin
	# whatever the card theme; the language picks the text.
	Settings.set_skin("classic", false)
	for locale in LOCALES:
		Settings.set_locale(locale, false)
		for speaker in data.get("speakers", {}):
			var name = CampaignData.speaker_name(speaker)
			texts.append(name)
			var entry = data.speakers[speaker]
			var expected = Library.loc(str(entry.card), "name", locale, "three_kingdoms") if entry.has("card") else str(entry.name[locale])
			_check(not name.is_empty() and name == expected, "Speaker %s is named %s in %s, any card theme (%s)" % [speaker, expected, locale, name])
		_check(CampaignData.title("hulao") == str(CampaignData.chapter("hulao").title[locale]), "Titles follow the language (%s)" % locale)
	Settings.set_skin(Settings.DEFAULT_SKIN, false)
	Settings.set_locale("en", false)
	_check(CampaignData.text({"en": "Only English"}, "zh_CN") == "Only English", "A missing translation falls back to English")
	# English is shown with straight quotes (the CJK fonts draw curly ones
	# full-width); Chinese keeps its own.
	var quoted = {"en": "Cao Cao’s “poem”", "zh_CN": "“此间乐”"}
	_check(CampaignData.text(quoted, "en") == "Cao Cao's \"poem\"" and CampaignData.text(quoted, "zh_CN") == "“此间乐”",
		"English text is shown with straight quotes, Chinese with its own")
	for chapter_id in CampaignData.chapter_ids():
		for page in CampaignData.pages(chapter_id, "intro"):
			var shown = CampaignData.page_text(page, "en")
			_check(not shown.contains("’") and not shown.contains("“"), "%s's English pages show no curly quotes" % chapter_id)
	_check(CampaignData.speaker_name("nobody").is_empty() and CampaignData.pages("nowhere").is_empty() and CampaignData.chapter("nowhere").is_empty(),
		"Unknown speakers and chapters give nothing")
	# The seal line.
	_check(CampaignData.seals_for(false, 0, 3, 12) == 0, "A defeat earns no seal")
	_check(CampaignData.seals_for(true, 1, 13, 12) == CampaignData.SEAL_WIN, "A win earns the victory seal")
	_check(CampaignData.seals_for(true, 0, 13, 12) == CampaignData.SEAL_WIN | CampaignData.SEAL_NO_TOWER, "No tower lost earns the second seal")
	_check(CampaignData.seals_for(true, 2, 12, 12) == CampaignData.SEAL_WIN | CampaignData.SEAL_PAR, "A win by the par round earns the third seal")
	_check(CampaignData.seals_for(true, 0, 5, 12) == CampaignData.ALL_SEALS and CampaignData.seal_count(CampaignData.ALL_SEALS) == 3, "All three seals")
	var line = CampaignData.seal_line(CampaignData.SEAL_WIN | CampaignData.SEAL_PAR, 9)
	_check(line.count("●") == 2 and line.count("○") == 1 and line.contains("9"), "The seal line marks earned seals and names the par round: " + line)
	texts.append(line)

## The cast notes name every hero who stands on both sides (the tale's own
## army against its enemy) in both languages, by the Three Kingdoms name the
## story uses; a mirror match (the prologue's drill) says so instead. And
## history_note keeps to history against the novel: who is borrowed tonight
## is the cast note's business.
func _cast() -> void:
	for chapter_id in CampaignData.chapter_ids():
		var mine = library.resolve_deck(CampaignData.player_default(chapter_id)).get("heroes", [])
		var theirs = CampaignData.enemy_heroes(chapter_id, library)
		var both = theirs.filter(func(hero): return hero in mine)
		var cast = CampaignData.chapter(chapter_id).get("cast_note", {})
		var history = CampaignData.chapter(chapter_id).get("history_note", {})
		if not (cast is Dictionary and history is Dictionary):
			continue
		var mirror = CampaignData.player_default(chapter_id) == CampaignData.chapter(chapter_id).get("opponent_preset", "")
		for locale in LOCALES:
			var note = str(cast.get(locale, ""))
			if mirror:
				_check(note.contains("5") or note.contains("five") or note.contains("五"), "Chapter %s's mirror match says both sides are the same (%s)" % [chapter_id, locale])
				continue
			var missing = both.map(func(hero): return Library.loc(str(hero), "name", locale, CampaignData.STORY_SKIN)).filter(
				func(name): return not note.contains(name))
			_check(missing.is_empty(), "Chapter %s's cast note names the heroes on both sides in %s; missing: %s" % [chapter_id, locale, missing])
			var past = str(history.get(locale, ""))
			_check(not past.contains("borrowed") and not past.contains("借将") and not past.contains("扮相"),
				"Chapter %s's history note leaves the cast to the cast note (%s)" % [chapter_id, locale])

## Every character of the campaign's text is in each bundled font (a missed
## tools/build_fonts.py run fails here).
func _glyphs() -> void:
	var characters: Dictionary = {}
	for text in texts:
		for character in str(text):
			if character.unicode_at(0) > 32:
				characters[character] = true
	_check(characters.size() > 1000, "Collected the campaign's characters (%d)" % characters.size())
	for path in FONT_FILES:
		var font = load(path) as Font
		_check(font != null, "Font loads: " + path)
		if font == null:
			continue
		var missing: Array = []
		for character in characters:
			if not font.has_char(character.unicode_at(0)):
				missing.append(character)
		_check(missing.is_empty(), "%s covers the campaign's text; missing: %s" % [path, "".join(missing)])

# --- Progress ------------------------------------------------------------------------

func _remove(path: String) -> void:
	for file in [path, path + ".bad", path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))

func _store() -> void:
	var ids = CampaignData.chapter_ids()
	var first: String = ids[0]
	var second: String = ids[1]
	var third: String = ids[2]
	_check(TEST_PATH.begins_with("user://test_"), "The test uses its own progress file")
	_remove(TEST_PATH)
	CampaignStore.load_progress(TEST_PATH)
	_check(CampaignStore.path == TEST_PATH and not CampaignStore.read_only, "The store reads the test file")
	_check(CampaignStore.is_unlocked(first) and not CampaignStore.is_unlocked(second) and not CampaignStore.is_unlocked(ids[-1]),
		"Fresh progress: only the first tale is open")
	_check(CampaignStore.act_unlocked(CampaignData.act_ids()[0]) and not CampaignStore.act_unlocked(CampaignData.act_ids()[1]), "Fresh progress: only the first book is open")
	_check(CampaignStore.furthest_chapter() == first and CampaignStore.progress().won == 0 and CampaignStore.progress().total == ids.size(),
		"Fresh progress counts nothing")
	_check(not CampaignStore.is_unlocked("nowhere") and CampaignStore.record("nowhere", true, 0, 3).is_empty(), "An unknown tale is never open and never recorded")
	# A defeat: an attempt, nothing opens.
	var lost = CampaignStore.record(first, false, 2, 7)
	_check(not lost.won and lost.seals == 0 and not lost.first_win and lost.unlocked == "" and CampaignStore.attempts(first) == 1
		and not CampaignStore.is_won(first) and not CampaignStore.is_unlocked(second), "A defeat counts an attempt and opens nothing")
	# A win: the next tale opens; its seals.
	var par = CampaignData.par_rounds(first)
	var won = CampaignStore.record(first, true, 1, par + 1)
	_check(won.won and won.first_win and won.unlocked == second and won.seals == CampaignData.SEAL_WIN and won.new_seals == CampaignData.SEAL_WIN,
		"A first win opens the next tale: %s" % won)
	_check(CampaignStore.is_won(first) and CampaignStore.is_unlocked(second) and not CampaignStore.is_unlocked(third)
		and CampaignStore.wins(first) == 1 and CampaignStore.attempts(first) == 2 and CampaignStore.best_rounds(first) == par + 1
		and CampaignStore.first_won_unix(first) > 0, "The win is recorded")
	# Seals only grow; the best round only improves.
	var better = CampaignStore.record(first, true, 0, par)
	_check(not better.first_win and better.unlocked == "" and better.seals == CampaignData.ALL_SEALS
		and better.new_seals == CampaignData.SEAL_NO_TOWER | CampaignData.SEAL_PAR and CampaignStore.seals(first) == CampaignData.ALL_SEALS
		and CampaignStore.best_rounds(first) == par, "A better win adds seals: %s" % better)
	CampaignStore.record(first, true, 3, par + 5)
	CampaignStore.record(first, false, 2, 4)
	_check(CampaignStore.seals(first) == CampaignData.ALL_SEALS and CampaignStore.best_rounds(first) == par and CampaignStore.is_won(first)
		and CampaignStore.wins(first) == 3 and CampaignStore.attempts(first) == 5, "Seals, the best round and the win never go back")
	_check(CampaignStore.furthest_chapter() == second and CampaignStore.progress().won == 1 and CampaignStore.progress().seals == 3,
		"Progress counts the won tale and its seals")
	# Choices.
	CampaignStore.set_deck_choice(second, "own:d0123456789abcdef")
	CampaignStore.set_last_chapter(second)
	CampaignStore.set_seen_epilogue(true)
	# Everything survives a reload.
	CampaignStore.load_progress(TEST_PATH)
	_check(CampaignStore.is_won(first) and CampaignStore.seals(first) == CampaignData.ALL_SEALS and CampaignStore.attempts(first) == 5
		and CampaignStore.is_unlocked(second) and CampaignStore.deck_choice(second) == "own:d0123456789abcdef"
		and CampaignStore.last_chapter() == second and CampaignStore.seen_epilogue(), "Progress and choices survive a reload")
	var config = ConfigFile.new()
	_check(config.load(ProjectSettings.globalize_path(TEST_PATH)) == OK and int(config.get_value("meta", "version", 0)) == CampaignStore.VERSION
		and config.has_section("chapter." + first), "The file is versioned and keyed by tale id")
	# Saves go to <file>.tmp and are moved over the file: none is left behind,
	# and a half-written one from a crash neither breaks loading nor survives
	# the next save.
	_check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "A save leaves no .tmp file behind")
	var torn = FileAccess.open(TEST_PATH + ".tmp", FileAccess.WRITE)
	torn.store_string("[meta]\nversion=1\n[chapter.%s]\nwon=tr" % first)
	torn.close()
	CampaignStore.load_progress(TEST_PATH)
	_check(CampaignStore.is_won(first) and CampaignStore.attempts(first) == 5 and not FileAccess.file_exists(TEST_PATH + ".bad"),
		"A torn .tmp from a crashed save leaves the progress whole")
	_check(CampaignStore.save() == OK and not FileAccess.file_exists(TEST_PATH + ".tmp") and config.load(ProjectSettings.globalize_path(TEST_PATH)) == OK
		and bool(config.get_value("chapter." + first, "won", false)), "The next save replaces the torn .tmp and the file stays whole")
	# A tale the campaign no longer has is kept but counts for nothing; values
	# of the wrong type read as their defaults.
	config.set_value("chapter.retired_tale", "won", true)
	config.set_value("chapter.retired_tale", "seals", 7)
	config.set_value("chapter." + second, "attempts", "many")
	config.set_value("chapter." + second, "won", "yes")
	config.save(ProjectSettings.globalize_path(TEST_PATH))
	CampaignStore.load_progress(TEST_PATH)
	_check(CampaignStore.progress().won == 1 and CampaignStore.progress().seals == 3 and CampaignStore.attempts(second) == 0
		and not CampaignStore.is_won(second), "Unknown tales and wrong values count for nothing")
	CampaignStore.record(second, true, 0, 3)
	config = ConfigFile.new()
	config.load(ProjectSettings.globalize_path(TEST_PATH))
	_check(config.has_section("chapter.retired_tale") and CampaignStore.is_unlocked(third), "Saving keeps tales it does not know")
	# Reset: only the first tale open again.
	_check(CampaignStore.reset() == OK and not CampaignStore.is_won(first) and not CampaignStore.is_unlocked(second)
		and CampaignStore.progress().won == 0 and CampaignStore.deck_choice(second).is_empty() and CampaignStore.last_chapter().is_empty(),
		"Reset forgets everything")
	CampaignStore.load_progress(TEST_PATH)
	_check(CampaignStore.progress().won == 0 and CampaignStore.progress().attempts == 0, "The reset is saved")
	# unlock_all (screenshots and tests).
	CampaignStore.unlock_all()
	_check(CampaignStore.progress().won == ids.size() and CampaignStore.is_unlocked(ids[-1]) and CampaignStore.epilogue_unlocked(),
		"unlock_all opens every tale and the epilogue")
	# A damaged file: fresh progress, the file kept aside.
	var damaged = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	damaged.store_string("[meta]\nversion=1\n[chapter.%s\nwon=tr ue ===\n" % first)
	damaged.close()
	CampaignStore.load_progress(TEST_PATH)
	_check(not CampaignStore.read_only and CampaignStore.progress().won == 0 and CampaignStore.is_unlocked(first)
		and FileAccess.file_exists(TEST_PATH + ".bad"), "A damaged file starts fresh and is kept as .bad")
	_check(CampaignStore.record(first, true, 0, 4).first_win, "Fresh progress after a damaged file records again")
	# A newer version's file: read, never written over.
	config = ConfigFile.new()
	config.set_value("meta", "version", CampaignStore.VERSION + 1)
	config.set_value("chapter." + first, "won", true)
	config.set_value("chapter." + first, "seals", 3)
	config.set_value("future", "feature", "kept")
	config.save(ProjectSettings.globalize_path(TEST_PATH))
	var before = FileAccess.get_file_as_string(TEST_PATH)
	CampaignStore.load_progress(TEST_PATH)
	_check(CampaignStore.read_only and CampaignStore.is_won(first) and CampaignStore.is_unlocked(second), "A newer version's file is read")
	CampaignStore.record(second, true, 0, 3)
	CampaignStore.set_deck_choice(first, "preset:starter")
	_check(CampaignStore.save() != OK and CampaignStore.reset() != OK and FileAccess.get_file_as_string(TEST_PATH) == before,
		"A newer version's file is never written over")
	_remove(TEST_PATH)
	# A missing file is fresh progress.
	CampaignStore.load_progress(TEST_PATH)
	_check(not CampaignStore.read_only and CampaignStore.progress().won == 0, "A missing file is fresh progress")
	CampaignStore.path = CampaignStore.DEFAULT_PATH
	_check(CampaignStore.path == "user://campaign.cfg", "The game's own progress file is user://campaign.cfg")

# --- Matches -------------------------------------------------------------------------

## Every tale starts a valid match: its army (and every alternative) against
## its enemy, the enemy's heroes in story order, the tale's seed.
func _matches() -> void:
	for chapter_id in CampaignData.chapter_ids():
		var enemy = CampaignData.enemy_deck(chapter_id, library)
		var order = CampaignData.chapter(chapter_id).get("hero_order", [])
		var heroes = CampaignData.enemy_heroes(chapter_id, library)
		_check(heroes.size() == 5, "Chapter %s's enemy has five heroes" % chapter_id)
		if not order.is_empty():
			_check(enemy is Dictionary and str(enemy.preset) == CampaignData.enemy_preset(chapter_id) and heroes == order,
				"Chapter %s's enemy deploys in story order" % chapter_id)
		else:
			_check(enemy is String and enemy == CampaignData.enemy_preset(chapter_id), "Chapter %s's enemy is its preset" % chapter_id)
		for army in [CampaignData.player_default(chapter_id)] + CampaignData.player_alternatives(chapter_id):
			var engine = MatchEngine.new()
			var result = engine.start(CampaignData.match_seed(chapter_id), [army, enemy])
			_check(result.ok, "Chapter %s starts with %s: %s" % [chapter_id, army, result])
			if not result.ok:
				continue
			var roster = engine.state.players[1].roster.map(func(hero): return str(hero.card))
			_check(roster == heroes and engine.legal_actions(int(engine.state.active_player)).size() > 0,
				"Chapter %s's match has the enemy's heroes in order and a move to make" % chapter_id)
			_check(str(engine.state.players[1].preset) == (MatchEngine.CUSTOM_DECK if enemy is Dictionary else str(enemy)),
				"Chapter %s's enemy deck label" % chapter_id)
		# The same seed deals the same way every attempt.
		var a = MatchEngine.new()
		var b = MatchEngine.new()
		a.start(CampaignData.match_seed(chapter_id), [CampaignData.player_default(chapter_id), enemy])
		b.start(CampaignData.match_seed(chapter_id), [CampaignData.player_default(chapter_id), enemy])
		_check(a.state_digest() == b.state_digest(), "Chapter %s deals the same way every attempt" % chapter_id)

## Two bot games per tale (both seats played by the bot): they finish, and
## the tale's army's wins are printed for balance tuning.
func _bot_games() -> void:
	var bot = Bot.new()
	var report: Array = []
	for chapter_id in CampaignData.chapter_ids():
		var wins = 0
		var rounds: Array = []
		for game in range(2):
			var engine = MatchEngine.new()
			engine.start(CampaignData.match_seed(chapter_id) + game * 1000, [CampaignData.player_default(chapter_id), CampaignData.enemy_deck(chapter_id, library)])
			var steps = 0
			while int(engine.state.winner) == -1 and steps < 4000:
				var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
				var action = bot.choose_action(engine, player)
				if action.is_empty():
					break
				engine.apply_action(player, action)
				steps += 1
			_check(int(engine.state.winner) != -1, "Chapter %s bot game %d finishes" % [chapter_id, game])
			if int(engine.state.winner) == 0:
				wins += 1
			rounds.append(int(engine.state.round))
		report.append("%s %d/2 (rounds %s, par %d)" % [chapter_id, wins, rounds, CampaignData.par_rounds(chapter_id)])
	print("Bot games, the tale's army winning: " + "; ".join(report))
