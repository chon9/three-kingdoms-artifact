extends Control
## Title screen: key art (assets/art/ui/main_menu.png or menu_key_art.png
## when present, otherwise a generated night scene of burning ships at Red
## Cliffs), the title in calligraphy, and the menu: the Campaign, Play vs
## AI, Local hot-seat, Steam lobby, Decks, Replays, Settings and Quit, plus a
## quick language toggle.

signal action_requested(action: String)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const KEY_ART = ["res://assets/art/ui/main_menu.png", "res://assets/art/ui/menu_key_art.png"]
const ITEMS = [["resume", "MENU_RESUME_MATCH"], ["campaign", "MENU_CAMPAIGN"], ["ai", "MENU_PLAY_AI"], ["local", "MENU_PLAY_LOCAL"],
	["online", "MENU_PLAY_ONLINE"], ["decks", "MENU_DECKS"], ["replays", "MENU_REPLAYS"],
	["settings", "MENU_SETTINGS"], ["quit", "MENU_QUIT"]]

var buttons: Dictionary = {}
var language_buttons: Dictionary = {}
var can_resume: bool = false
var _time: float = 0.0
var _embers: CPUParticles2D

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column = VBoxContainer.new()
	column.name = "Menu"
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	for item in ITEMS:
		var entry = MenuEntry.new()
		entry.name = str(item[0]).capitalize()
		entry.action = str(item[0])
		entry.key = str(item[1])
		entry.pressed.connect(func(): action_requested.emit(entry.action))
		column.add_child(entry)
		buttons[item[0]] = entry
	var languages = HBoxContainer.new()
	languages.name = "Languages"
	add_child(languages)
	for locale in Settings.LOCALES:
		var choice = Button.new()
		choice.name = locale
		choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		choice.toggle_mode = true
		choice.add_theme_font_size_override("font_size", 16)
		choice.pressed.connect(func(): action_requested.emit("locale:" + locale))
		languages.add_child(choice)
		language_buttons[locale] = choice
	_embers = CPUParticles2D.new()
	_embers.texture = UiKit.particle("spark_01")
	_embers.amount = 40
	_embers.lifetime = 6.0
	_embers.preprocess = 6.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2(0.2, -1)
	_embers.spread = 25.0
	_embers.gravity = Vector2(6, -6)
	_embers.initial_velocity_min = 20.0
	_embers.initial_velocity_max = 60.0
	_embers.scale_amount_min = 0.04
	_embers.scale_amount_max = 0.1
	_embers.color = Color(1.0, 0.55, 0.25, 0.8)
	var additive = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_embers.material = additive
	add_child(_embers)
	move_child(_embers, 0)

func _ready() -> void:
	refresh_text()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()

func _place() -> void:
	var column: Control = get_node("Menu")
	column.size = column.get_combined_minimum_size()
	# Under the title, and clear of the disclaimer line at the bottom.
	column.position = Vector2(maxf(90.0, size.x * 0.09), minf(size.y * 0.38, size.y - 60.0 - column.size.y))
	var languages: Control = get_node("Languages")
	languages.size = languages.get_combined_minimum_size()
	languages.position = Vector2(size.x - languages.size.x - 28, 24)
	_embers.position = Vector2(size.x * 0.5, size.y * 0.95)
	_embers.emission_rect_extents = Vector2(size.x * 0.5, 20)

func set_can_resume(value: bool) -> void:
	can_resume = value
	buttons.resume.visible = value
	_place()

func refresh_text() -> void:
	for action in buttons:
		buttons[action].refresh_text()
	for locale in language_buttons:
		language_buttons[locale].text = UiKit.t("LANG_" + locale.to_upper())
		language_buttons[locale].button_pressed = Settings.locale == locale
	_place()
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var art: Texture2D = null
	for path in KEY_ART:
		art = UiKit.tex(path)
		if art != null:
			break
	if art != null:
		UiKit.draw_cover(self, art, rect, Vector2(0.5, 0.5))
	else:
		_draw_red_cliffs(rect)
	# Readability wash behind the menu.
	UiKit.draw_hgradient(self, Rect2(0, 0, size.x * 0.55, size.y), Color(0.01, 0.01, 0.02, 0.82), Color(0.01, 0.01, 0.02, 0.0))
	var title_pos = Vector2(maxf(90.0, size.x * 0.09), size.y * 0.17)
	var title = UiKit.t("APP_TITLE")
	var font = UiKit.title_font()
	var title_size = UiKit.fit_size(font, title, size.x * 0.55, 84, 40)
	UiKit.draw_text_left(self, font, title, title_pos + Vector2(3, 4), title_size, Color(0, 0, 0, 0.6))
	UiKit.draw_text_left(self, font, title, title_pos, title_size, UiKit.GOLD_BRIGHT, -1.0, 6)
	UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("APP_SUBTITLE"), title_pos + Vector2(4, title_size * 0.78 + 12.0), 21, UiKit.PAPER_DIM, -1.0, 3)
	var divider = UiKit.divider(1, true)
	if divider != null:
		draw_texture_rect(divider, Rect2(title_pos + Vector2(0, title_size * 1.12 + 12.0), Vector2(420, 44)), false, Color(UiKit.GOLD, 0.8))
	UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("APP_DISCLAIMER"), Vector2(maxf(90.0, size.x * 0.09), size.y - 30), 14, UiKit.MUTED, -1.0, 2)

## Generated key art: night sky and blood moon over ink mountains, burning
## war junks on the Yangtze and the red cliffs in the foreground.
func _draw_red_cliffs(rect: Rect2) -> void:
	var w = rect.size.x
	var h = rect.size.y
	UiKit.draw_vgradient(self, Rect2(0, 0, w, h * 0.36), Color("070a14"), Color("1b0f1a"))
	UiKit.draw_vgradient(self, Rect2(0, h * 0.36, w, h * 0.3), Color("1b0f1a"), Color("4a1a10"))
	var moon = Vector2(w * 0.7, h * 0.24)
	for ring in range(5):
		draw_circle(moon, 90.0 + ring * 38.0, Color(0.8, 0.25, 0.12, 0.07 - ring * 0.012))
	draw_circle(moon, 86.0, Color("b8402a"))
	draw_circle(moon + Vector2(-10, -8), 76.0, Color("cf5634"))
	draw_circle(moon + Vector2(18, 14), 30.0, Color(0.6, 0.18, 0.1, 0.25))
	# Ink mountains with mist between the ranges.
	var rng = RandomNumberGenerator.new()
	rng.seed = 208
	for layer in range(4):
		var base_y = h * (0.4 + layer * 0.055)
		var amplitude = h * (0.17 - layer * 0.03)
		var points = PackedVector2Array([Vector2(0, h * 0.66)])
		var phase = rng.randf_range(0, TAU)
		var steps = 64
		for step in range(steps + 1):
			var x = w * float(step) / steps
			var ridge = absf(sin(phase + step * 0.21)) * 0.55 + absf(sin(phase * 1.7 + step * 0.53)) * 0.3 + absf(sin(step * 1.37 + layer)) * 0.15
			points.append(Vector2(x, base_y + amplitude * 0.5 - amplitude * ridge))
		points.append(Vector2(w, h * 0.66))
		var shade = Color(0.05 + layer * 0.035, 0.035 + layer * 0.02, 0.05 + layer * 0.012, 0.97)
		draw_colored_polygon(points, shade)
		UiKit.draw_vgradient(self, Rect2(0, base_y + amplitude * 0.15, w, h * 0.05), Color(0.55, 0.25, 0.2, 0.0), Color(0.55, 0.25, 0.2, 0.12))
	# River with fire reflections.
	var river_top = h * 0.645
	UiKit.draw_vgradient(self, Rect2(0, river_top, w, h * 0.16), Color(0.22, 0.07, 0.04, 1.0), Color(0.04, 0.03, 0.05, 1.0))
	for index in range(6):
		var ship_x = w * (0.42 + index * 0.095)
		var ship_y = h * (0.672 + (index % 3) * 0.022)
		var size_factor = 0.75 + (index % 3) * 0.18
		_draw_junk(Vector2(ship_x, ship_y), size_factor, index)
	# The red cliffs in the foreground (left), where the menu sits.
	var cliff = PackedVector2Array([Vector2(0, h * 0.3), Vector2(w * 0.12, h * 0.34), Vector2(w * 0.2, h * 0.47),
		Vector2(w * 0.27, h * 0.58), Vector2(w * 0.34, h * 0.74), Vector2(w * 0.38, h), Vector2(0, h)])
	draw_colored_polygon(cliff, Color("1c0b09"))
	for streak in range(9):
		var x = w * (0.02 + streak * 0.035)
		var top = h * (0.35 + streak * 0.03)
		draw_line(Vector2(x, top), Vector2(x + w * 0.02, top + h * 0.3), Color(0.55, 0.12, 0.08, 0.22), 6.0)
	draw_polyline(cliff.slice(0, 6), Color(0.75, 0.25, 0.12, 0.35), 3.0, true)
	var shore = PackedVector2Array([Vector2(w * 0.3, h), Vector2(w * 0.3, h * 0.86)])
	for step in range(17):
		var x = w * (0.3 + 0.7 * step / 16.0)
		shore.append(Vector2(x, h * (0.85 + absf(sin(step * 1.3)) * 0.035)))
	shore.append(Vector2(w, h))
	draw_colored_polygon(shore, Color(0.025, 0.02, 0.025))

## A burning war junk: hull, deck house, batten sails, flames and smoke.
func _draw_junk(base: Vector2, factor: float, index: int) -> void:
	var s = 46.0 * factor
	var flicker = 0.78 + 0.22 * sin(_time * 7.0 + index * 1.7)
	var dark = Color(0.03, 0.02, 0.02)
	# Reflection.
	for streak in range(5):
		var y = base.y + s * (0.35 + streak * 0.22)
		draw_line(Vector2(base.x - s * (0.9 - streak * 0.12), y), Vector2(base.x + s * (0.9 - streak * 0.12), y),
			Color(1.0, 0.45, 0.15, (0.22 - streak * 0.035) * flicker), 3.0)
	var hull = PackedVector2Array([Vector2(base.x - s * 1.25, base.y - s * 0.32), Vector2(base.x + s * 1.3, base.y - s * 0.4),
		Vector2(base.x + s * 0.95, base.y + s * 0.12), Vector2(base.x - s * 0.9, base.y + s * 0.12)])
	draw_colored_polygon(hull, dark)
	draw_rect(Rect2(base.x - s * 0.55, base.y - s * 0.75, s * 0.8, s * 0.42), dark)
	draw_rect(Rect2(base.x - s * 0.4, base.y - s * 1.0, s * 0.5, s * 0.26), dark)
	for mast in range(2):
		var mast_x = base.x + s * (0.15 + mast * 0.6)
		var top = base.y - s * (2.1 - mast * 0.4)
		draw_line(Vector2(mast_x, base.y - s * 0.3), Vector2(mast_x, top), dark, 3.0)
		var sail = PackedVector2Array([Vector2(mast_x - s * 0.42, top + s * 0.1), Vector2(mast_x + s * 0.3, top + s * 0.02),
			Vector2(mast_x + s * 0.36, base.y - s * 0.55), Vector2(mast_x - s * 0.48, base.y - s * 0.5)])
		draw_colored_polygon(sail, Color(0.09, 0.05, 0.04, 0.95))
		for batten in range(5):
			var t = (batten + 1) / 6.0
			var left = sail[0].lerp(sail[3], t)
			var right = sail[1].lerp(sail[2], t)
			draw_line(left, right, Color(0.3, 0.12, 0.06, 0.8), 1.5)
	# Flames and smoke.
	for flame in range(3):
		var fx = base.x + s * (-0.6 + flame * 0.55)
		var height = s * (1.2 + 0.5 * sin(_time * 5.0 + flame * 2.1 + index)) * flicker
		var points = PackedVector2Array([Vector2(fx - s * 0.32, base.y - s * 0.3), Vector2(fx + s * 0.3, base.y - s * 0.3),
			Vector2(fx + s * 0.12, base.y - s * 0.3 - height * 0.6), Vector2(fx + s * 0.02, base.y - s * 0.3 - height),
			Vector2(fx - s * 0.12, base.y - s * 0.3 - height * 0.55)])
		draw_colored_polygon(points, Color(1.0, 0.42 + flame * 0.08, 0.1, 0.8))
		draw_circle(Vector2(fx, base.y - s * 0.6), s * 0.9 * flicker, Color(1.0, 0.4, 0.1, 0.06))
	for puff in range(3):
		var rise = fmod(_time * 18.0 + puff * 40.0 + index * 13.0, 120.0)
		draw_circle(Vector2(base.x + s * 0.2 + puff * 6.0 + rise * 0.25, base.y - s * 2.0 - rise), s * (0.35 + rise / 160.0),
			Color(0.08, 0.06, 0.07, 0.3 * (1.0 - rise / 120.0)))

## A menu entry: calligraphy text with an ink stroke and seal on hover.
class MenuEntry:
	extends Control
	signal pressed
	var action: String = ""
	var key: String = ""
	var text: String = ""
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())

	func refresh_text() -> void:
		text = UiKit.t(key)
		custom_minimum_size = Vector2(420, 54)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()
		elif event.is_action_pressed("ui_accept"):
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var highlight = _hover or has_focus()
		if highlight:
			UiKit.draw_hgradient(self, Rect2(0, 6, size.x, size.y - 12), Color(0.55, 0.12, 0.08, 0.55), Color(0.55, 0.12, 0.08, 0.0))
			UiKit.draw_seal(self, Vector2(-26, size.y * 0.5), 26.0, UiKit.t(key).left(1))
		UiKit.draw_text_left(self, UiKit.title_font(), text, Vector2(16, size.y * 0.5), 32,
			UiKit.GOLD_BRIGHT if highlight else UiKit.PAPER, size.x - 20, 3)
