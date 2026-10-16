class_name GameSettings
extends RefCounted
## Player display preferences, persisted to user://settings.cfg. These only
## change how things are shown: nothing here may reach match state, digests,
## replays or network packets.

const PATH = "user://settings.cfg"
const LOCALES = ["en", "zh_CN"]
const SKINS = ["three_kingdoms", "classic"]
const DEFAULT_SKIN = "three_kingdoms"
const ANIMATION_SPEEDS = [1.0, 1.5, 2.0]
static var locale: String = "en"
static var skin: String = DEFAULT_SKIN
static var animation_speed: float = 1.0
static var volume: float = 0.7
## Every sound off (the M key toggles it in a match).
static var muted: bool = false
## A chime and a banner when it becomes your action.
static var turn_alert: bool = true
## The taskbar flashes when it becomes your action while the window is not
## focused (online and against the AI).
static var flash_window: bool = true
## The strip of recently played cards under the lane overview.
static var show_history: bool = true
## The two armies' heroes face each other before every match.
static var match_intro: bool = true
static var loaded: bool = false

## First-run language: Chinese system locales get zh_CN, everything else en.
static func default_locale() -> String:
	return "zh_CN" if OS.get_locale_language() == "zh" else "en"

## Maps any Godot locale string onto a supported locale.
static func normalize_locale(value: String) -> String:
	return "zh_CN" if value.to_lower().begins_with("zh") else "en"

## A stored flag, or `fallback` when the file holds anything but a bool.
static func _flag(config: ConfigFile, section: String, key: String, fallback: bool) -> bool:
	var value = config.get_value(section, key, fallback)
	return value if value is bool else fallback

## Reads the settings file (missing file: OS-based defaults) and applies the
## locale to the TranslationServer.
static func load_settings(path: String = PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path) == OK:
		locale = normalize_locale(str(config.get_value("display", "locale", default_locale())))
		var stored_skin = str(config.get_value("display", "skin", DEFAULT_SKIN))
		skin = stored_skin if stored_skin in SKINS else DEFAULT_SKIN
		animation_speed = clampf(float(config.get_value("display", "animation_speed", 1.0)), 0.5, 3.0)
		show_history = _flag(config, "display", "show_history", true)
		match_intro = _flag(config, "display", "match_intro", true)
		volume = clampf(float(config.get_value("audio", "volume", 0.7)), 0.0, 1.0)
		muted = _flag(config, "audio", "muted", false)
		turn_alert = _flag(config, "audio", "turn_alert", true)
		flash_window = _flag(config, "audio", "flash_window", true)
	else:
		locale = default_locale()
		skin = DEFAULT_SKIN
		animation_speed = 1.0
		show_history = true
		match_intro = true
		volume = 0.7
		muted = false
		turn_alert = true
		flash_window = true
	loaded = true
	apply()

static func save_settings(path: String = PATH) -> Error:
	var config = ConfigFile.new()
	config.load(path) # Keep sections written by other code or newer versions.
	config.set_value("display", "locale", locale)
	config.set_value("display", "skin", skin)
	config.set_value("display", "animation_speed", animation_speed)
	config.set_value("display", "show_history", show_history)
	config.set_value("display", "match_intro", match_intro)
	config.set_value("audio", "volume", volume)
	config.set_value("audio", "muted", muted)
	config.set_value("audio", "turn_alert", turn_alert)
	config.set_value("audio", "flash_window", flash_window)
	return config.save(path)

## Pushes the current locale to the TranslationServer.
static func apply() -> void:
	TranslationServer.set_locale(locale)

static func set_locale(value: String, persist: bool = true) -> void:
	locale = normalize_locale(value)
	apply()
	if persist:
		save_settings()

static func set_skin(value: String, persist: bool = true) -> void:
	skin = value if value in SKINS else DEFAULT_SKIN
	if persist:
		save_settings()

static func set_animation_speed(value: float, persist: bool = true) -> void:
	animation_speed = clampf(value, 0.5, 3.0)
	if persist:
		save_settings()

static func set_volume(value: float, persist: bool = true) -> void:
	volume = clampf(value, 0.0, 1.0)
	if persist:
		save_settings()

static func set_muted(value: bool, persist: bool = true) -> void:
	muted = value
	if persist:
		save_settings()

static func set_turn_alert(value: bool, persist: bool = true) -> void:
	turn_alert = value
	if persist:
		save_settings()

static func set_flash_window(value: bool, persist: bool = true) -> void:
	flash_window = value
	if persist:
		save_settings()

static func set_show_history(value: bool, persist: bool = true) -> void:
	show_history = value
	if persist:
		save_settings()

static func set_match_intro(value: bool, persist: bool = true) -> void:
	match_intro = value
	if persist:
		save_settings()

## The volume sounds play at: 0 while muted.
static func effective_volume() -> float:
	return 0.0 if muted else volume
