extends "res://scripts/ui/modal_panel.gd"
## Settings: language (applied live), card theme, animation speed, volume
## and mute, the your-action alert (chime and banner), the taskbar flash, the
## card history strip, the match intro and fullscreen. Choices persist in
## user://settings.cfg.

signal setting_changed(kind: String)

const Settings = preload("res://scripts/core/game_settings.gd")
## The on/off settings, shown two per row, and their captions.
const TOGGLES = ["fullscreen", "mute", "turn_alert", "flash_window", "show_history", "match_intro"]
const TOGGLE_KEYS = {"fullscreen": "SETTINGS_FULLSCREEN", "mute": "SETTINGS_MUTE", "turn_alert": "SETTINGS_TURN_ALERT",
	"flash_window": "SETTINGS_FLASH_WINDOW", "show_history": "SETTINGS_HISTORY", "match_intro": "SETTINGS_MATCH_INTRO"}

var language_buttons: Dictionary = {}
var skin_buttons: Dictionary = {}
var speed_buttons: Dictionary = {}
var volume_slider: HSlider
var fullscreen_toggle: CheckButton
## Every toggle by name (TOGGLES), the fullscreen one included.
var toggles: Dictionary = {}
var captions: Dictionary = {}
var skin_hint: Label

func _init() -> void:
	super()
	title_key = "SETTINGS_TITLE"
	panel_size = Vector2(760, 640)

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
	var grid = GridContainer.new()
	grid.name = "Toggles"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	for toggle_name in TOGGLES:
		var toggle = CheckButton.new()
		toggle.name = toggle_name.capitalize().replace(" ", "")
		toggle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.button_pressed = _value(toggle_name)
		toggle.toggled.connect(_on_toggled.bind(toggle_name))
		grid.add_child(toggle)
		toggles[toggle_name] = toggle
	fullscreen_toggle = toggles.fullscreen

## The current value of toggle `toggle_name`.
func _value(toggle_name: String) -> bool:
	match toggle_name:
		"fullscreen":
			return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		"mute":
			return Settings.muted
		"turn_alert":
			return Settings.turn_alert
		"flash_window":
			return Settings.flash_window
		"show_history":
			return Settings.show_history
		"match_intro":
			return Settings.match_intro
	return false

func _on_toggled(enabled: bool, toggle_name: String) -> void:
	match toggle_name:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
		"mute":
			Settings.set_muted(enabled)
		"turn_alert":
			Settings.set_turn_alert(enabled)
		"flash_window":
			Settings.set_flash_window(enabled)
		"show_history":
			Settings.set_show_history(enabled)
		"match_intro":
			Settings.set_match_intro(enabled)
	setting_changed.emit(toggle_name)

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
	for toggle_name in toggles:
		toggles[toggle_name].text = UiKit.t(TOGGLE_KEYS[toggle_name])
		toggles[toggle_name].set_pressed_no_signal(_value(toggle_name))
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
