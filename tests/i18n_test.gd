extends SceneTree
## Localization coverage: UI keys, card text in both locales and skins,
## placeholders, font glyph coverage, settings persistence, and that the match
## state digest does not depend on the display language or skin.

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const Library = preload("res://scripts/core/card_library.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const EventFormatter = preload("res://scripts/core/event_text.gd")
const UI_CSV = "res://i18n/ui.csv"
const LOCALES = ["en", "zh_CN"]
const FONT_FILES = ["res://assets/fonts/NotoSansSC-Regular.otf", "res://assets/fonts/NotoSansSC-Bold.otf",
	"res://assets/fonts/SanguoKai-Medium.ttf"]
const FONT_RESOURCES = ["res://assets/fonts/body.tres", "res://assets/fonts/body_bold.tres", "res://assets/fonts/title.tres"]
var checks = 0
var failures: Array = []
var used_text: Array = []

func _initialize() -> void:
	_project_settings()
	_ui_keys()
	_card_text()
	_settings()
	_digest_independent_of_locale()
	_fonts()
	Settings.set_locale("en", false)
	Settings.set_skin(Settings.DEFAULT_SKIN, false)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%s: %d i18n checks (UI keys, card text, placeholders, fonts, settings, locale-independent digests)." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _placeholders(text: String) -> Array:
	var regex = RegEx.create_from_string("\\{(\\w+)\\}")
	var names: Array = []
	for found in regex.search_all(text):
		if found.get_string(1) not in names:
			names.append(found.get_string(1))
	names.sort()
	return names

func _project_settings() -> void:
	var translations = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	_check("res://i18n/ui.en.translation" in translations and "res://i18n/ui.zh_CN.translation" in translations, "UI translations are registered")
	_check(ProjectSettings.get_setting("internationalization/locale/fallback", "") == "en", "Fallback locale is en")
	_check(ProjectSettings.get_setting("internationalization/locale/include_text_server_data", false) == true, "Text server data (CJK line breaking) is exported")
	_check(ProjectSettings.get_setting("gui/theme/custom", "") == "res://assets/theme/default_theme.tres", "Project theme sets the default font")

func _ui_keys() -> void:
	var file = FileAccess.open(UI_CSV, FileAccess.READ)
	_check(file != null, "ui.csv opens")
	if file == null:
		return
	var header = file.get_csv_line()
	_check(Array(header) == ["keys", "en", "zh_CN"], "ui.csv columns are keys,en,zh_CN")
	var rows: Dictionary = {}
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 3 or line[0].is_empty():
			continue
		_check(not rows.has(line[0]), "Unique ui key " + line[0])
		rows[line[0]] = [line[1], line[2]]
	_check(rows.size() > 300, "ui.csv has the full key set (%d keys)" % rows.size())
	var objects: Dictionary = {}
	for locale in LOCALES:
		objects[locale] = TranslationServer.get_translation_object(locale)
		_check(objects[locale] != null, "Translation loaded for " + locale)
	if objects.values().has(null):
		return
	for key in rows:
		for index in range(LOCALES.size()):
			var message = String(objects[LOCALES[index]].get_message(key))
			if message.is_empty():
				failures.append("Missing %s translation for %s" % [LOCALES[index], key])
			used_text.append(rows[key][index])
		checks += 1
		if _placeholders(rows[key][0]) != _placeholders(rows[key][1]):
			failures.append("Placeholder mismatch in %s: %s vs %s" % [key, rows[key][0], rows[key][1]])
	for key in EventFormatter.KEYS:
		var template = "EV_" + key.to_upper()
		_check(rows.has(template), "Event %s has template %s" % [key, template])
	for code in ["illegal_action", "bad_index", "deck_selection", "replay_version", "replay_illegal", "deck_hero_count"]:
		_check(rows.has("ERR_" + code.to_upper()), "Error code %s has a translation" % code)
	# Every status the Steam bridge can set needs a translation.
	var bridge_source = FileAccess.get_file_as_string("res://scripts/network/steam_bridge.gd")
	var codes: Array = ["opponent_left", "opponent_disconnected", "opponent_timeout", "not_installed",
		"opponent_left_lobby", "opponent_conceded_left"]
	for found in RegEx.create_from_string("(?:_set_status|_end_session)[(]\"(\\w+)\"").search_all(bridge_source):
		codes.append(found.get_string(1))
	_check(codes.size() > 25, "Found the Steam status codes (%d)" % codes.size())
	for code in codes:
		_check(rows.has("STEAM_" + code.to_upper()), "Steam status %s has a translation" % code)
	for term_key in Library.glossary():
		var entry = Library.glossary()[term_key]
		var row = rows.get("TERM_" + str(term_key).to_upper(), [])
		_check(row.size() == 2 and row[0] == entry.en and row[1] == entry.zh_CN, "Glossary term %s matches ui.csv" % term_key)
		used_text.append(str(entry.get("en_alias", "")))
	Settings.set_locale("en", false)
	_check(EventFormatter.t("LIST_SEPARATOR") == ", " and EventFormatter.t("LANE_LEFT") == "Left lane", "English strings keep their spacing")
	_check(EventFormatter.t("ROUND_N", {"n": 3}) == "Round 3", "Named placeholders format in English")
	# Counted log lines use the _ONE template at 1 (a Jasper Daggers purge of
	# one effect, an Hourglass lock of one card, Book of the Dead's first charge).
	var counted = [
		[{"k": "purge", "uid": 1, "card": "axe", "n": 1}, "An effect on", " effects on"],
		[{"k": "purge", "uid": 1, "card": "axe", "n": 2}, "2 effects on", "An effect"],
		[{"k": "lock", "p": 0, "n": 1}, "A card in Player 1's hand is locked.", "cards"],
		[{"k": "lock", "p": 0, "n": 2}, "2 cards in Player 1's hand are locked.", "A card"],
		[{"k": "charges", "card": "", "n": 1}, "now has 1 charge.", "charges."],
		[{"k": "charges", "card": "", "n": 3}, "now has 3 charges.", "1 charge"],
		[{"k": "battle", "card": "", "bs": [[1, 2]]}, "battles a unit.", "units"],
		[{"k": "charged", "p": 1, "n": 1}, "One of Player 2's cards gains charges.", "1 of"],
		[{"k": "hack", "p": 1, "n": 1}, "A card in Player 2's hand is changed.", "cards in"],
	]
	for entry in counted:
		var line = EventFormatter.format(entry[0])
		_check(line.contains(entry[1]) and not line.contains(entry[2]), "Counted log line agrees with its count: %s" % line)
	Settings.set_locale("zh_CN", false)
	_check(EventFormatter.format({"k": "lock", "p": 0, "n": 1}) == "玩家1有一张手牌被锁定。", "Counted log line in Chinese")
	_check(EventFormatter.format({"k": "lock", "p": 0, "n": 2}) == "玩家1有2张手牌被锁定。", "Counted log line in Chinese, plural")
	_check(EventFormatter.t("LANE_LEFT") == "左路" and EventFormatter.t("TERM_TOWER") == "城楼" and EventFormatter.t("TERM_ANCIENT") == "都城", "Chinese lane, tower and ancient terms")
	_check(EventFormatter.t("ROUND_N", {"n": 3}) == "第3回合", "Named placeholders format in Chinese")
	Settings.set_locale("en", false)

func _card_text() -> void:
	var data = Library.locale_data()
	_check(data.get("default_skin") == "three_kingdoms" and Settings.DEFAULT_SKIN == "three_kingdoms", "Three Kingdoms is the default skin")
	var library = Library.new()
	var ids: Array = []
	for hero in library.heroes:
		ids.append(str(hero.id))
	ids.append_array(library.cards.keys())
	var themed = data.skins.three_kingdoms.cards
	var classic = data.skins.classic.cards
	_check(themed.size() == ids.size() and classic.size() == ids.size(), "Both skins cover all %d cards" % ids.size())
	var factions = ["shu", "wei", "wu", "qun", "neutral"]
	for card_id in ids:
		var definition = library.definition(card_id)
		var entry = themed.get(card_id, {})
		for field in ["name", "text"]:
			var value = entry.get(field, {})
			_check(value is Dictionary and not str(value.get("en", "")).is_empty() and not str(value.get("zh_CN", "")).is_empty(), "%s has en and zh_CN %s" % [card_id, field])
			if value is Dictionary:
				_check(_placeholders(str(value.get("en", ""))) == _placeholders(str(value.get("zh_CN", ""))), "%s %s placeholders match across locales" % [card_id, field])
		# Granted text (EFFECT_SYSTEM_SPEC.md §8.8): both locales, same placeholders.
		var grants = entry.get("grants", [])
		for index in range(grants.size() if grants is Array else 0):
			var grant = grants[index]
			_check(grant is Dictionary and not str(grant.get("en", "")).is_empty() and not str(grant.get("zh_CN", "")).is_empty(),
				"%s granted text %d has en and zh_CN" % [card_id, index])
			if grant is Dictionary:
				_check(_placeholders(str(grant.get("en", ""))) == _placeholders(str(grant.get("zh_CN", ""))),
					"%s granted text %d placeholders match across locales" % [card_id, index])
				for locale in LOCALES:
					var text = Library.loc(card_id, "grant_%d" % index, locale)
					used_text.append(text)
					_check(not text.is_empty() and text.find("{") == -1, "%s granted text %d fills in %s" % [card_id, index, locale])
		_check(classic.has(card_id) and not str(classic[card_id].get("name", {}).get("en", "")).is_empty(), "%s has a classic name" % card_id)
		_check(str(entry.get("faction", "")) in factions, "%s has a faction" % card_id)
		if definition.get("kind", "") == "hero" and definition.text.find(":") != -1:
			var ability = entry.get("ability_name", {})
			_check(ability is Dictionary and not str(ability.get("zh_CN", "")).is_empty() and not str(ability.get("en", "")).is_empty(), "%s has a bilingual ability name" % card_id)
		for skin in ["three_kingdoms", "classic"]:
			for locale in LOCALES:
				for field in ["name", "text"]:
					var text = Library.loc(card_id, field, locale, skin)
					used_text.append(text)
					_check(not text.is_empty() and text.find("{") == -1, "%s/%s %s %s is filled: %s" % [skin, locale, card_id, field, text])
	_check(Library.loc("no_accident", "text", "en") == "Deal 3 damage to a unit.", "Placeholders fill from card numbers")
	_check(Library.loc("jmuy", "name", "zh_CN", "three_kingdoms") == "曹操" and Library.loc("jmuy", "ability_name", "zh_CN", "three_kingdoms") == "求贤令", "Hero and ability names by id")
	_check(Library.loc("jmuy", "name", "zh_CN", "classic") == "J'Muy the Wise", "Classic skin falls back to English")
	_check(Library.loc("vanguard", "name", "zh_CN") == "Iron Vanguard", "Cards without locale entries fall back to the raw definition")
	_check(Library.loc("missing_card") == "missing_card", "Unknown ids fall back to the id")
	_check(Library.faction("axe") == "shu" and Library.faction("jmuy") == "wei" and Library.faction("drow") == "wu" and Library.faction("debbi") == "qun", "Faction badges follow colors")
	_check(Library.term("tower", "zh_CN") == "城楼" and Library.term("initiative", "zh_CN") == "先手" and Library.term("tower", "en") == "Tower", "Glossary terms by locale")
	for preset in library.presets():
		for locale in LOCALES:
			for field in ["name", "description"]:
				var text = Library.preset_text(preset.id, field, locale, "three_kingdoms")
				used_text.append(text)
				_check(not text.is_empty() and text != preset.get(field, ""), "Preset %s has a themed %s %s" % [preset.id, locale, field])
		_check(Library.preset_text(preset.id, "name", "en", "classic") == preset.name, "Classic preset names are the originals")
	_check(Library.preset_text("starter", "name", "zh_CN", "three_kingdoms") == "群雄逐鹿", "Deck names from the mapping")

func _fonts() -> void:
	var characters: Dictionary = {}
	for text in used_text:
		for character in str(text):
			if character.unicode_at(0) > 32:
				characters[character] = true
	_check(characters.size() > 500, "Collected %d used characters" % characters.size())
	for path in FONT_FILES + FONT_RESOURCES:
		var font = load(path) as Font
		_check(font != null, "Font loads: " + path)
		if font == null:
			continue
		var missing: Array = []
		for character in characters:
			if not font.has_char(character.unicode_at(0)):
				missing.append(character)
		_check(missing.is_empty(), "%s covers every used character; missing: %s" % [path, "".join(missing)])
	var kai = load("res://assets/fonts/SanguoKai-Medium.ttf") as FontFile
	_check(kai != null and kai.get_font_name() == "Sanguo Kai", "WenKai subset is renamed (OFL reserved names)")
	var theme = load("res://assets/theme/default_theme.tres") as Theme
	_check(theme != null and theme.default_font != null and theme.default_font.resource_path == "res://assets/fonts/body.tres", "Default theme font is the body font")

func _settings() -> void:
	var path = "user://i18n_test_settings.cfg"
	_check(Settings.normalize_locale("zh") == "zh_CN" and Settings.normalize_locale("zh_TW") == "zh_CN" and Settings.normalize_locale("fr_FR") == "en", "Locale normalization")
	_check(Settings.default_locale() in LOCALES, "OS default locale is supported")
	Settings.locale = "zh_CN"
	Settings.skin = "classic"
	# The v0.6.1 options, each away from its default.
	Settings.muted = true
	Settings.turn_alert = false
	Settings.flash_window = false
	Settings.show_history = false
	Settings.match_intro = false
	_check(Settings.save_settings(path) == OK, "Settings save")
	Settings.locale = "en"
	Settings.skin = "three_kingdoms"
	Settings.muted = false
	Settings.turn_alert = true
	Settings.flash_window = true
	Settings.show_history = true
	Settings.match_intro = true
	Settings.load_settings(path)
	_check(Settings.locale == "zh_CN" and Settings.skin == "classic" and Settings.normalize_locale(TranslationServer.get_locale()) == "zh_CN", "Settings load and apply")
	_check(Settings.muted and not Settings.turn_alert and not Settings.flash_window and not Settings.show_history and not Settings.match_intro
		and Settings.effective_volume() == 0.0, "Mute, the your-action alert, the taskbar flash, the card history and the match intro persist")
	var config = ConfigFile.new()
	config.load(path)
	config.set_value("audio", "muted", "yes")
	config.set_value("display", "match_intro", 0)
	config.save(path)
	Settings.load_settings(path)
	_check(not Settings.muted and Settings.match_intro, "A setting of the wrong type falls back to its default")
	Settings.load_settings("user://missing_settings_file.cfg")
	_check(Settings.skin == Settings.DEFAULT_SKIN and Settings.locale == Settings.default_locale(), "Missing settings fall back to defaults")
	_check(not Settings.muted and Settings.turn_alert and Settings.flash_window and Settings.show_history and Settings.match_intro,
		"The new options default to on (sound unmuted)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _play_match(seed_value: int) -> Dictionary:
	var engine = MatchEngine.new()
	engine.start(seed_value, ["starter", "blue_black_control"])
	var bot = Bot.new()
	var steps = 0
	var texts: Array = []
	while engine.state.winner == -1 and steps < 1500:
		var player = int(engine.state.active_player) if engine.state.phase == "action" else (1 if engine.state.players[0].finished else 0)
		var action = bot.choose_action(engine, player)
		if action.is_empty():
			break
		engine.apply_action(player, action)
		steps += 1
	for event in engine.state.events:
		texts.append(EventFormatter.format(event))
	return {"digest": engine.state_digest(), "state": JSON.stringify(engine.state), "texts": texts,
		"view": JSON.stringify(engine.player_view(1))}

func _digest_independent_of_locale() -> void:
	Settings.set_locale("en", false)
	Settings.set_skin("classic", false)
	var english = _play_match(23)
	Settings.set_locale("zh_CN", false)
	Settings.set_skin("three_kingdoms", false)
	var chinese = _play_match(23)
	_check(english.digest == chinese.digest and english.state == chinese.state, "State digest is identical under en/classic and zh_CN/three_kingdoms")
	_check(english.view == chinese.view, "Network view is identical under both locales")
	_check(chinese.state.find("曹操") == -1 and english.state.find("J'Muy") == -1 and english.state.find("Classic Starter") == -1, "State contains no display names")
	var unfilled = 0
	for text in english.texts + chinese.texts:
		if text == "?" or text.find("{") != -1:
			unfilled += 1
	_check(unfilled == 0 and not chinese.texts.is_empty(), "Every event formats completely in both locales")
	_check(english.texts != chinese.texts, "Event text actually changes with the locale")
	used_text.append_array(chinese.texts)
