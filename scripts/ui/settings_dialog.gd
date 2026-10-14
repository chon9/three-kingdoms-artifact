extends "res://scripts/ui/modal_panel.gd"
## Settings: language (applied live), card theme, animation speed, volume
## and fullscreen. Choices persist in user://settings.cfg.

signal setting_changed(kind: String)

const Settings = preload("res://scripts/core/game_settings.gd")

var language_buttons: Dictionary = {}
var skin_buttons: Dictionary = {}
var speed_buttons: Dictionary = {}
var volume_slider: HSlider
var fullscreen_toggle: CheckButton
var captions: Dictionary = {}
var skin_hint: Label

func _init() -> void:
	super()
	title_key = "SETTINGS_TITLE"
	panel_size = Vector2(700, 520)

func build() -> void:
	captions.language = _row_caption()
	var languages = _row()
	for locale in Settings.LOCALES:
		var choice = button(languages, "", 20)
		choice.name = "Language_" + locale
		choice.toggle_mode = true
		choice.custom_minimum_size = Vector2(180, 46)
		choice.pressed.connect(_choose_locale.bind(locale))
		language_buttons[locale] = choice
	captions.skin = _row_caption()
	var skins = _row()
	for skin in Settings.SKINS:
		var choice = button(skins, "", 18)
		choice.name = "Skin_" + skin
		choice.toggle_mode = true
		choice.custom_minimum_size = Vector2(250, 46)
		choice.pressed.connect(_choose_skin.bind(skin))
		skin_buttons[skin] = choice
	skin_hint = label(body, "", 14, UiKit.MUTED, true)
	captions.speed = _row_caption()
	var speeds = _row()
	for speed in Settings.ANIMATION_SPEEDS:
		var choice = button(speeds, "×%s" % str(speed).trim_suffix(".0"), 18)
		choice.toggle_mode = true
		choice.custom_minimum_size = Vector2(90, 40)
		choice.pressed.connect(_choose_speed.bind(speed))
		speed_buttons[speed] = choice
	captions.volume = _row_caption()
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = Settings.volume
	volume_slider.custom_minimum_size = Vector2(320, 28)
	volume_slider.value_changed.connect(func(value):
		Settings.set_volume(value)
		setting_changed.emit("volume"))
	body.add_child(volume_slider)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_toggle.toggled.connect(func(enabled):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
		setting_changed.emit("fullscreen"))
	body.add_child(fullscreen_toggle)

func _row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	return row

func _row_caption() -> Label:
	var caption = label(body, "", 17, UiKit.GOLD)
	caption.add_theme_font_override("font", UiKit.title_font())
	return caption

func refresh_text() -> void:
	super()
	captions.language.text = UiKit.t("SETTINGS_LANGUAGE")
	captions.skin.text = UiKit.t("SETTINGS_SKIN")
	captions.speed.text = UiKit.t("SETTINGS_ANIMATION_SPEED")
	captions.volume.text = UiKit.t("SETTINGS_VOLUME")
	skin_hint.text = UiKit.t("SETTINGS_SKIN_HINT")
	fullscreen_toggle.text = UiKit.t("SETTINGS_FULLSCREEN")
	for locale in language_buttons:
		language_buttons[locale].text = UiKit.t("LANG_" + locale.to_upper())
		language_buttons[locale].button_pressed = Settings.locale == locale
	for skin in skin_buttons:
		skin_buttons[skin].text = UiKit.t("SKIN_" + skin.to_upper())
		skin_buttons[skin].button_pressed = Settings.skin == skin
	for speed in speed_buttons:
		speed_buttons[speed].button_pressed = is_equal_approx(Settings.animation_speed, speed)

func _choose_locale(locale: String) -> void:
	Settings.set_locale(locale)
	setting_changed.emit("locale")
	refresh_text()

func _choose_skin(skin: String) -> void:
	Settings.set_skin(skin)
	setting_changed.emit("skin")
	refresh_text()

func _choose_speed(speed: float) -> void:
	Settings.set_animation_speed(speed)
	setting_changed.emit("speed")
	refresh_text()
