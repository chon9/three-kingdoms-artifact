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
static var loaded: bool = false

## First-run language: Chinese system locales get zh_CN, everything else en.
static func default_locale() -> String:
	return "zh_CN" if OS.get_locale_language() == "zh" else "en"

## Maps any Godot locale string onto a supported locale.
static func normalize_locale(value: String) -> String:
	return "zh_CN" if value.to_lower().begins_with("zh") else "en"

## Reads the settings file (missing file: OS-based defaults) and applies the
## locale to the TranslationServer.
static func load_settings(path: String = PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path) == OK:
		locale = normalize_locale(str(config.get_value("display", "locale", default_locale())))
		var stored_skin = str(config.get_value("display", "skin", DEFAULT_SKIN))
		skin = stored_skin if stored_skin in SKINS else DEFAULT_SKIN
		animation_speed = clampf(float(config.get_value("display", "animation_speed", 1.0)), 0.5, 3.0)
		volume = clampf(float(config.get_value("audio", "volume", 0.7)), 0.0, 1.0)
	else:
		locale = default_locale()
		skin = DEFAULT_SKIN
		animation_speed = 1.0
		volume = 0.7
	loaded = true
	apply()

static func save_settings(path: String = PATH) -> Error:
	var config = ConfigFile.new()
	config.load(path) # Keep sections written by other code or newer versions.
	config.set_value("display", "locale", locale)
	config.set_value("display", "skin", skin)
	config.set_value("display", "animation_speed", animation_speed)
	config.set_value("audio", "volume", volume)
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
