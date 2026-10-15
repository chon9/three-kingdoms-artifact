extends RefCounted
## Spec "gd" escape (tests/card_specs_test.gd): the mod event of Soul of
## Spring carries its granted text ("ab"), and the log line shows that text
## in both skins and both locales (not "none").

const EventText = preload("res://scripts/core/event_text.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const Library = preload("res://scripts/core/card_library.gd")

func check(engine, _labels: Dictionary) -> Array:
	var problems: Array = []
	var mods = engine.state.events.filter(func(event): return str(event.get("k", "")) == "mod" \
		and str(event.get("ab", "")) == "soul_of_spring#0")
	if mods.is_empty():
		return ["the mod event names the granted text (ab soul_of_spring#0)"]
	for skin in ["classic", "three_kingdoms"]:
		Settings.set_skin(skin, false)
		for locale in ["en", "zh_CN"]:
			Settings.set_locale(locale, false)
			var line = EventText.format(mods[0])
			var granted = Library.loc("soul_of_spring", "grant_0").trim_suffix(".").trim_suffix("。")
			if granted.is_empty() or line.find(granted) == -1:
				problems.append("%s/%s: the log line shows the granted text: %s" % [skin, locale, line])
	Settings.set_locale("en", false)
	Settings.set_skin(Settings.DEFAULT_SKIN, false)
	return problems
