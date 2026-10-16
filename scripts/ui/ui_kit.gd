extends RefCounted
## Shared look of the game UI: palette, fonts, icons, textures, theme and small
## drawing helpers. Everything is static so any view can use it directly.
##
## Palette: ink-wash blacks, rice-paper text, burnished gold trim and cinnabar
## seals. Card frame colours follow Classic's card colours (red, green, blue,
## black, item gold, neutral grey); the Three Kingdoms skin maps them onto
## Shu, Wu, Wei and Qun.

const EventText = preload("res://scripts/core/event_text.gd")
const Library = preload("res://scripts/core/card_library.gd")

const BASE_SIZE = Vector2(1440, 900)
const INK = Color("0d0e10")
const INK_SOFT = Color("17191c")
const INK_PANEL = Color(0.055, 0.058, 0.066, 0.92)
const PAPER = Color("efe6d2")
const PAPER_DIM = Color("b9b0a0")
const MUTED = Color("8c877d")
const GOLD = Color("d8b06a")
const GOLD_BRIGHT = Color("f3d48f")
const GOLD_DARK = Color("7d5f2e")
const CINNABAR = Color("c8372d")
const JADE = Color("58b8a4")
const TARGET = Color("ffcf5a")
const PLAYABLE = Color("54e1ff")
const DAMAGE = Color("e5453b")
const HEAL = Color("78d66e")
const BUFF = Color("8ff07c")
const ENEMY_TINT = Color("c46a5a")
const ALLY_TINT = Color("5fb7b0")

## Title bar / bottom bar colours per card colour (sampled from Classic frames).
const CARD_COLORS = {
	"red": [Color("9a2f3b"), Color("6f2429")],
	"green": [Color("5b7a3e"), Color("455f2f")],
	"blue": [Color("23608a"), Color("174660")],
	"black": [Color("4d3c6e"), Color("2f2638")],
	"item": [Color("c9902f"), Color("8f6420")],
	"neutral": [Color("6f6b65"), Color("45413d")]}
const FACTION_SEALS = {"shu": "FACTION_SHU", "wei": "FACTION_WEI", "wu": "FACTION_WU",
	"qun": "FACTION_QUN", "neutral": "FACTION_NEUTRAL"}
const ICON_DIR = "res://assets/third_party/kenney_board_game_icons/"
const PARTICLE_DIR = "res://assets/third_party/kenney_particle_pack/"
const BORDER_DIR = "res://assets/third_party/kenney_fantasy_ui_borders/"
const WOOD_DARK = "res://assets/third_party/polyhaven_dark_wooden_planks/dark_wooden_planks_diff_1k.jpg"
const STONE = "res://assets/third_party/polyhaven_castle_wall_slates/castle_wall_slates_diff_1k.jpg"
const WOOD_WARM = "res://assets/third_party/ambientcg_wood066/Wood066_1K_Color.jpg"
const UI_ART_DIR = "res://assets/art/ui/"
const ART_EXTENSIONS = ["png", "jpg", "webp"]
## Faction emblems by faction id (Three Kingdoms skin).
const EMBLEMS = {"shu": "emblem_shu", "wei": "emblem_wei", "wu": "emblem_wu", "qun": "emblem_qun"}
## Badge kind -> [fill, rim] for statuses, flags and keywords on units
## (EFFECT_SYSTEM_SPEC.md §8.5), tower values and hand-card marks (§8.6).
const BADGE_STYLES = {
	"stun": [Color(0.3, 0.24, 0.05), Color(1.0, 0.85, 0.3)],
	"silence": [Color(0.2, 0.08, 0.25), Color(0.75, 0.5, 0.95)],
	"disarm": [Color(0.25, 0.1, 0.1), Color(0.85, 0.45, 0.45)],
	"death_shield": [Color(0.12, 0.2, 0.24), Color(0.6, 0.9, 1.0)],
	"damage_immunity": [Color(0.12, 0.18, 0.28), Color(0.7, 0.85, 1.0)],
	"pierce": [Color(0.22, 0.16, 0.06), Color("f3d48f")],
	"lethal": [Color(0.1, 0.1, 0.1), Color(0.9, 0.3, 0.3)],
	"lethal_heroes": [Color(0.1, 0.1, 0.1), Color(0.9, 0.3, 0.3)],
	"lethal_creeps": [Color(0.1, 0.1, 0.1), Color(0.9, 0.3, 0.3)],
	"siege": [Color(0.25, 0.1, 0.06), Color("d8b06a")],
	"cleave": [Color(0.22, 0.08, 0.08), Color(0.95, 0.55, 0.4)],
	"retaliate": [Color(0.2, 0.14, 0.08), Color(0.9, 0.7, 0.4)],
	"regeneration": [Color(0.06, 0.2, 0.1), Color(0.45, 0.9, 0.55)],
	"bounty": [Color(0.24, 0.2, 0.06), Color("f3d48f")],
	"rapid_deployment": [Color(0.08, 0.18, 0.12), Color(0.5, 0.9, 0.6)],
	"soulbound": [Color(0.16, 0.08, 0.22), Color(0.8, 0.6, 1.0)],
	"armor": [Color(0.14, 0.15, 0.17), Color(0.82, 0.8, 0.74)],
	"lock": [Color(0.17, 0.09, 0.25), Color(0.8, 0.62, 1.0)],
	"charges": [Color(0.07, 0.15, 0.26), Color(0.55, 0.82, 1.0)],
	"hacked": [Color(0.25, 0.1, 0.07), Color(1.0, 0.62, 0.45)],
}
## Badges that show their value, with a faint icon behind the number (a lock
## shows its icon with the rounds in a small corner disc instead).
const NUMBER_BADGES = {"siege": "structure_tower", "cleave": "", "retaliate": "shield", "regeneration": "",
	"bounty": "pouch", "armor": "shield", "charges": ""}

static var _textures: Dictionary = {}
static var _ornate: Dictionary = {}
static var _fonts: Dictionary = {}
static var _title: FontVariation
static var _title_language: String = ""
static var _boxes: Dictionary = {}
static var _theme: Theme
static var _system_fallback: SystemFont

# --- Resources ---------------------------------------------------------------

## Cached texture by res:// path; null when the file is missing. Art paths
## also match the same stem saved as .png, .jpg or .webp (tools/optimize_art.py
## turns opaque PNG masters into JPEGs).
static func tex(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = null
	for candidate in _art_variants(path):
		if ResourceLoader.exists(candidate):
			texture = mipmapped(load(candidate) as Texture2D)
			break
	_textures[path] = texture
	return texture

## `path`, then the same stem with the other art extensions.
static func _art_variants(path: String) -> Array:
	var extension = path.get_extension().to_lower()
	if extension not in ART_EXTENSIONS:
		return [path]
	var result: Array = [path]
	for other in ART_EXTENSIONS:
		if other != extension:
			result.append(path.get_basename() + "." + other)
	return result

## Board and interface art from assets/art/ui/ by name (any art extension).
static func ui_art(art_name: String) -> Texture2D:
	return tex(UI_ART_DIR + art_name + ".png")

## Draws `texture` scaled so that `frame` (a rectangle in 0..1 texture
## coordinates, e.g. a building inside a padded sprite) fills the width or
## height of `box` (keeping its aspect), centred and standing on the box's
## bottom edge. The rest of the texture (smoke, flames) is drawn around it.
## Returns the screen rectangle the frame landed in.
static func draw_framed(canvas: CanvasItem, texture: Texture2D, frame: Rect2, box: Rect2, modulate: Color = Color.WHITE,
		flip: bool = false) -> Rect2:
	if texture == null:
		return Rect2()
	var texture_size = texture.get_size()
	var frame_size = frame.size * texture_size
	var scale = minf(box.size.x / frame_size.x, box.size.y / frame_size.y)
	var landed = Rect2(Vector2(box.get_center().x - frame_size.x * scale * 0.5, box.end.y - frame_size.y * scale), frame_size * scale)
	var origin = landed.position - frame.position * texture_size * scale
	var full = Rect2(origin, texture_size * scale)
	if flip:
		# Mirrored around the frame's centre line (through the UVs, so the
		# canvas transform, e.g. a shake offset, stays untouched).
		full.position.x = 2.0 * landed.get_center().x - full.end.x
	var left = 1.0 if flip else 0.0
	var right = 0.0 if flip else 1.0
	canvas.draw_polygon(PackedVector2Array([full.position, Vector2(full.end.x, full.position.y), full.end, Vector2(full.position.x, full.end.y)]),
		PackedColorArray([modulate, modulate, modulate, modulate]),
		PackedVector2Array([Vector2(left, 0), Vector2(right, 0), Vector2(right, 1), Vector2(left, 1)]), texture)
	return landed

## A mipmapped copy (optionally shrunk to `max_height`) of an imported
## texture, so icons and art stay smooth when drawn much smaller than their
## source. Headless runs keep the original.
static func mipmapped(texture: Texture2D, max_height: int = 0) -> Texture2D:
	if texture == null or DisplayServer.get_name() == "headless":
		return texture
	var image = texture.get_image()
	if image == null or image.is_empty():
		return texture
	if image.is_compressed() and image.decompress() != OK:
		return texture
	if max_height > 0 and image.get_height() > max_height:
		var width = int(round(float(image.get_width()) * max_height / float(image.get_height())))
		image.resize(width, max_height, Image.INTERPOLATE_LANCZOS)
	if image.get_format() not in [Image.FORMAT_RGBA8, Image.FORMAT_RGB8]:
		image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func icon(icon_name: String) -> Texture2D:
	return tex(ICON_DIR + icon_name + ".png")

static func particle(particle_name: String) -> Texture2D:
	return tex(PARTICLE_DIR + particle_name + ".png")

static func border(index: int) -> Texture2D:
	return tex(BORDER_DIR + "border/panel-border-%03d.png" % index)

static func divider(index: int, fade: bool = false) -> Texture2D:
	if fade:
		return tex(BORDER_DIR + "divider_fade/divider-fade-%03d.png" % index)
	return tex(BORDER_DIR + "divider/divider-%03d.png" % index)

## Headings, buttons and banners: Sanguo Kai in Chinese; in English Noto
## Sans SC Bold, because Kai's Latin glyphs read as casual handwriting. One
## shared FontVariation is re-pointed when the language changes, so every
## Label and Button using it updates in place (its `changed` signal).
static func title_font() -> Font:
	if _title == null:
		_title = FontVariation.new()
	var language = Library.current_locale()
	if language != _title_language:
		_title_language = language
		var kai = load("res://assets/fonts/SanguoKai-Medium.ttf")
		var bold = load("res://assets/fonts/NotoSansSC-Bold.otf")
		var regular = load("res://assets/fonts/NotoSansSC-Regular.otf")
		var chinese = language == "zh_CN"
		_title.base_font = kai if chinese else bold
		var fallbacks: Array[Font] = []
		fallbacks.append(regular if chinese else kai)
		if _system_fallback != null:
			fallbacks.append(_system_fallback)
		_title.fallbacks = fallbacks
	return _title

## Calligraphy in every language (seals, card backs, Chinese placeholders).
static func kai_font() -> Font:
	return _font("res://assets/fonts/title.tres")

static func body_font() -> Font:
	return _font("res://assets/fonts/body.tres")

static func bold_font() -> Font:
	return _font("res://assets/fonts/body_bold.tres")

static func _font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]

## Players type deck names with any characters, while the bundled fonts are
## subsets (tools/build_fonts.py): the system's CJK fonts back up the game
## fonts for characters they lack. Not in headless runs (no system fonts).
static func add_system_fallback() -> void:
	if _system_fallback != null or DisplayServer.get_name() == "headless":
		return
	_system_fallback = SystemFont.new()
	_system_fallback.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Source Han Sans SC",
		"WenQuanYi Micro Hei", "Hiragino Sans GB", "SimHei", "sans-serif"])
	for font in [body_font(), bold_font(), kai_font(), title_font()]:
		if font is FontVariation and not font.fallbacks.has(_system_fallback):
			var fallbacks: Array[Font] = font.fallbacks.duplicate()
			fallbacks.append(_system_fallback)
			font.fallbacks = fallbacks

## Translated UI string with {named} placeholders.
static func t(key: String, args: Dictionary = {}) -> String:
	return EventText.t(key, args)

## A count string: `key`_ONE (the singular, when ui.csv has it) for n == 1,
## else `key`; {n} is filled in either way.
static func t_n(key: String, n: int, args: Dictionary = {}) -> String:
	var all = args.duplicate()
	all["n"] = n
	if n == 1 and TranslationServer.translate(key + "_ONE") != key + "_ONE":
		return t(key + "_ONE", all)
	return t(key, all)

static func is_zh() -> bool:
	return Library.current_locale() == "zh_CN"

## Text language hint for shaping and line breaking.
static func text_language() -> String:
	return "zh" if is_zh() else "en"

# --- Colours -----------------------------------------------------------------

static func card_color(color_id: String) -> Color:
	return CARD_COLORS.get(color_id, CARD_COLORS.neutral)[0]

static func card_color_dark(color_id: String) -> Color:
	return CARD_COLORS.get(color_id, CARD_COLORS.neutral)[1]

## One-character seal for a card's faction (蜀/魏/吴/群 or S/W/W/Q).
static func faction_seal(card_id: String) -> String:
	var key = FACTION_SEALS.get(Library.faction(card_id), "FACTION_NEUTRAL")
	var text = t(key)
	return text.left(1) if not text.is_empty() else ""

## The faction emblem art for a faction id ("shu", "wei", "wu", "qun"), or null.
static func faction_emblem(faction_id: String) -> Texture2D:
	return ui_art(EMBLEMS[faction_id]) if EMBLEMS.has(faction_id) else null

## Draws a card's faction emblem centred on `center` (`diameter` wide) in the
## Three Kingdoms skin; false when there is none (neutral, Classic skin, no art).
static func draw_card_emblem(canvas: CanvasItem, card_id: String, center: Vector2, diameter: float) -> bool:
	if Library.current_skin() != "three_kingdoms":
		return false
	var texture = faction_emblem(Library.faction(card_id))
	if texture == null:
		return false
	canvas.draw_circle(center + Vector2(0, diameter * 0.06), diameter * 0.48, Color(0, 0, 0, 0.45))
	canvas.draw_texture_rect(texture, Rect2(center - Vector2(diameter, diameter) * 0.5, Vector2(diameter, diameter)), false)
	return true

# --- Styles and theme --------------------------------------------------------

static func box(fill: Color, border_color: Color = Color.TRANSPARENT, radius: int = 6,
		border_width: int = 1, margin: float = 10.0) -> StyleBoxFlat:
	var key = "%s|%s|%d|%d|%s" % [fill.to_html(), border_color.to_html(), radius, border_width, margin]
	if _boxes.has(key):
		return _boxes[key]
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border_color
	style.set_border_width_all(border_width if border_color.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	_boxes[key] = style
	return style

## The game theme: ink panels with gold trim, paper text, Kai titles.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var palette = Theme.new()
	palette.default_font = body_font()
	palette.default_font_size = 17
	for control in ["Label", "Button", "OptionButton", "CheckBox", "CheckButton", "LinkButton", "MenuButton"]:
		palette.set_color("font_color", control, PAPER)
	palette.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	palette.set_color("font_pressed_color", "Button", INK)
	palette.set_color("font_focus_color", "Button", PAPER)
	palette.set_color("font_disabled_color", "Button", Color("5b5850"))
	palette.set_color("font_hover_color", "OptionButton", GOLD_BRIGHT)
	palette.set_color("font_disabled_color", "OptionButton", Color("5b5850"))
	var normal = box(Color("18191c"), GOLD_DARK, 4, 1, 10.0)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover = normal.duplicate()
	hover.bg_color = Color("26231d")
	hover.border_color = GOLD
	var pressed = normal.duplicate()
	pressed.bg_color = GOLD
	pressed.border_color = GOLD_BRIGHT
	var disabled = normal.duplicate()
	disabled.bg_color = Color("131416")
	disabled.border_color = Color("34322d")
	var focus = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(GOLD_BRIGHT, 0.55)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(4)
	for control in ["Button", "OptionButton", "MenuButton"]:
		palette.set_stylebox("normal", control, normal)
		palette.set_stylebox("hover", control, hover)
		palette.set_stylebox("pressed", control, pressed)
		palette.set_stylebox("disabled", control, disabled)
		palette.set_stylebox("focus", control, focus)
	palette.set_stylebox("panel", "PanelContainer", box(INK_PANEL, Color(GOLD_DARK, 0.9), 6, 1, 14.0))
	palette.set_stylebox("panel", "Panel", box(INK_PANEL, Color(GOLD_DARK, 0.9), 6, 1, 14.0))
	var popup = box(Color("141518"), GOLD_DARK, 4, 1, 6.0)
	palette.set_stylebox("panel", "PopupMenu", popup)
	palette.set_stylebox("hover", "PopupMenu", box(Color("2a261f"), Color.TRANSPARENT, 2, 0, 4.0))
	palette.set_color("font_color", "PopupMenu", PAPER)
	palette.set_color("font_hover_color", "PopupMenu", GOLD_BRIGHT)
	palette.set_stylebox("panel", "TooltipPanel", box(Color(0.06, 0.06, 0.07, 0.96), GOLD_DARK, 4, 1, 8.0))
	palette.set_color("font_color", "TooltipLabel", PAPER)
	palette.set_font_size("font_size", "TooltipLabel", 15)
	var field = box(Color("0f1012"), GOLD_DARK, 3, 1, 8.0)
	palette.set_stylebox("normal", "LineEdit", field)
	palette.set_stylebox("focus", "LineEdit", box(Color("0f1012"), GOLD, 3, 1, 8.0))
	palette.set_color("font_color", "LineEdit", PAPER)
	palette.set_color("font_placeholder_color", "LineEdit", MUTED)
	palette.set_color("default_color", "RichTextLabel", PAPER)
	palette.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	var grabber = box(Color(GOLD_DARK, 0.85), Color.TRANSPARENT, 3, 0, 4.0)
	var track = box(Color(1, 1, 1, 0.04), Color.TRANSPARENT, 3, 0, 4.0)
	for bar in ["VScrollBar", "HScrollBar"]:
		palette.set_stylebox("scroll", bar, track)
		palette.set_stylebox("grabber", bar, grabber)
		palette.set_stylebox("grabber_highlight", bar, box(GOLD, Color.TRANSPARENT, 3, 0, 4.0))
		palette.set_stylebox("grabber_pressed", bar, box(GOLD_BRIGHT, Color.TRANSPARENT, 3, 0, 4.0))
	var line = StyleBoxLine.new()
	line.color = Color(GOLD_DARK, 0.7)
	line.thickness = 1
	palette.set_stylebox("separator", "HSeparator", line)
	palette.set_constant("separation", "HSeparator", 12)
	palette.set_stylebox("panel", "AcceptDialog", box(Color("121315"), GOLD_DARK, 0, 1, 12.0))
	palette.set_stylebox("embedded_border", "Window", box(Color("121315"), GOLD_DARK, 4, 1, 8.0))
	palette.set_color("title_color", "Window", GOLD)
	palette.set_font("title_font", "Window", title_font())
	palette.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.08), Color.TRANSPARENT, 3, 0, 3.0))
	palette.set_stylebox("grabber_area", "HSlider", box(GOLD_DARK, Color.TRANSPARENT, 3, 0, 3.0))
	palette.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color.TRANSPARENT, 3, 0, 3.0))
	palette.set_constant("separation", "VBoxContainer", 8)
	palette.set_constant("separation", "HBoxContainer", 10)
	_theme = palette
	return _theme

## Detaches `node` from the tree now and frees it at the end of the frame, so
## a discarded control can neither draw nor catch input in the meantime.
static func discard(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()

# --- Drawing helpers ---------------------------------------------------------

## Baseline position that vertically centres `size`-pixel text on `center_y`.
static func baseline(font: Font, center_y: float, size: int) -> float:
	return center_y + (font.get_ascent(size) - font.get_descent(size)) * 0.5

## Draws one line of text centred on `center` (shrinking it to `max_width`).
static func draw_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, size: int,
		color: Color, max_width: float = -1.0, outline: int = 0, outline_color: Color = Color(0, 0, 0, 0.85)) -> void:
	if text.is_empty():
		return
	var fitted = fit_size(font, text, max_width, size, maxi(8, int(size * 0.55))) if max_width > 0.0 else size
	if max_width > 0.0:
		text = elide(font, text, max_width, fitted)
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
	var position = Vector2(center.x - width * 0.5, baseline(font, center.y, fitted))
	if outline > 0:
		canvas.draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, outline, outline_color)
	canvas.draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, color)

## Draws left-aligned text with its baseline centred on `left_center.y`.
static func draw_text_left(canvas: CanvasItem, font: Font, text: String, left_center: Vector2, size: int,
		color: Color, max_width: float = -1.0, outline: int = 0) -> void:
	var fitted = fit_size(font, text, max_width, size, maxi(8, int(size * 0.55))) if max_width > 0.0 else size
	if max_width > 0.0:
		text = elide(font, text, max_width, fitted)
	var position = Vector2(left_center.x, baseline(font, left_center.y, fitted))
	if outline > 0:
		canvas.draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, outline, Color(0, 0, 0, 0.85))
	canvas.draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, color)

## `text` cut to `max_width` at font `size` with an ellipsis at the end, or
## unchanged when it fits (a 32-character Steam name in a name plate). Never
## wider than `max_width` ("" when not even the ellipsis fits).
static func elide(font: Font, text: String, max_width: float, size: int) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_width:
		return text
	var dots = "…" if font.has_char(0x2026) else "..."
	if font.get_string_size(dots, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		return ""
	# The longest prefix that fits with the ellipsis (binary search).
	var low = 0
	var high = text.length()
	while low < high:
		var middle = (low + high + 1) >> 1
		if font.get_string_size(text.left(middle).strip_edges(false, true) + dots, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_width:
			low = middle
		else:
			high = middle - 1
	return text.left(low).strip_edges(false, true) + dots

## Largest font size (down to `min_size`) at which `text` fits `max_width`.
static func fit_size(font: Font, text: String, max_width: float, size: int, min_size: int) -> int:
	var current = size
	while current > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, current).x > max_width:
		current -= 1
	return current

## A wrapped paragraph; CJK breaks between characters, English between words.
static func paragraph(text: String, font: Font, size: int, width: float,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> TextParagraph:
	var result = TextParagraph.new()
	result.width = width
	result.alignment = align
	result.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	result.add_string(text, font, size, text_language())
	return result

## The largest paragraph (font size max..min) whose height fits `area`.
static func fit_paragraph(text: String, font: Font, area: Vector2, max_size: int, min_size: int,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> TextParagraph:
	var size = max_size
	while size > min_size:
		var candidate = paragraph(text, font, size, area.x, align)
		if candidate.get_size().y <= area.y:
			return candidate
		size -= 1
	return paragraph(text, font, min_size, area.x, align)

## Draws a texture scaled to cover `rect`, keeping its aspect; `focus` (0..1)
## picks which part of an over-tall image stays visible.
static func draw_cover(canvas: CanvasItem, texture: Texture2D, rect: Rect2, focus: Vector2 = Vector2(0.5, 0.35),
		modulate: Color = Color.WHITE, source: Rect2 = Rect2()) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var region = source if source.size != Vector2.ZERO else Rect2(Vector2.ZERO, texture.get_size())
	var scale = maxf(rect.size.x / region.size.x, rect.size.y / region.size.y)
	var visible = rect.size / scale
	var origin = region.position + (region.size - visible) * focus
	canvas.draw_texture_rect_region(texture, rect, Rect2(origin, visible), modulate)

## Fills `points` (a polygon inside `rect`, e.g. a rounded rectangle) with
## `texture` scaled to cover `rect`, keeping its aspect; `focus` (0..1) picks
## the visible part. `source` limits the texture to a region.
static func draw_cover_polygon(canvas: CanvasItem, points: PackedVector2Array, rect: Rect2, texture: Texture2D,
		focus: Vector2 = Vector2(0.5, 0.5), modulate: Color = Color.WHITE, source: Rect2 = Rect2()) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var texture_size = texture.get_size()
	var region = source if source.size != Vector2.ZERO else Rect2(Vector2.ZERO, texture_size)
	var scale = maxf(rect.size.x / region.size.x, rect.size.y / region.size.y)
	var visible = rect.size / scale
	var origin = region.position + (region.size - visible) * focus
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()
	for point in points:
		uvs.append((origin + (point - rect.position) / scale) / texture_size)
		colors.append(modulate)
	canvas.draw_polygon(points, colors, uvs, texture)

## A filled vertical gradient quad.
static func draw_vgradient(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	canvas.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))

## A filled horizontal gradient quad.
static func draw_hgradient(canvas: CanvasItem, rect: Rect2, left: Color, right: Color) -> void:
	canvas.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), PackedColorArray([left, right, right, left]))

## Points of a rounded rectangle, for polygons and outlines.
static func round_rect_points(rect: Rect2, radius: float, segments: int = 4) -> PackedVector2Array:
	var points = PackedVector2Array()
	var r = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners = [[rect.position + Vector2(r, r), PI], [Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5],
		[rect.end - Vector2(r, r), 0.0], [Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5]]
	for corner in corners:
		for step in range(segments + 1):
			var angle = corner[1] + PI * 0.5 * float(step) / float(segments)
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * r)
	return points

## Soft glowing outline around a rounded rectangle (playable / target cues).
static func draw_glow(canvas: CanvasItem, rect: Rect2, radius: float, color: Color, strength: float = 1.0) -> void:
	for ring in range(5):
		var grow = 2.0 + ring * 2.6
		var alpha = color.a * strength * (0.55 - ring * 0.1)
		if alpha <= 0.0:
			continue
		var points = round_rect_points(rect.grow(grow), radius + grow)
		points.append(points[0])
		canvas.draw_polyline(points, Color(color, alpha), 2.6, true)

static func draw_round_rect(canvas: CanvasItem, rect: Rect2, color: Color, radius: float,
		border_color: Color = Color.TRANSPARENT, border_width: float = 0.0) -> void:
	var style = box(color, border_color, int(radius), int(border_width), 0.0)
	canvas.draw_style_box(style, rect)

static func draw_icon(canvas: CanvasItem, icon_name: String, rect: Rect2, color: Color) -> void:
	var texture = icon(icon_name)
	if texture != null:
		canvas.draw_texture_rect(texture, rect, false, color)

## The gold icon: the painted coin (assets/art/ui/gold_coin) or the pouch.
static func draw_gold_icon(canvas: CanvasItem, rect: Rect2) -> void:
	var coin = ui_art("gold_coin")
	if coin != null:
		canvas.draw_texture_rect(coin, rect.grow(rect.size.x * 0.12), false)
	else:
		draw_icon(canvas, "pouch", rect, GOLD)

## Procedural ink-wash landscape: paper wash, layered mountains, mist and a
## sun disc, tinted by `tint`. Deterministic per `seed_text`.
static func draw_ink_wash(canvas: CanvasItem, rect: Rect2, tint: Color, seed_text: String, dark: bool = true) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var top = tint.darkened(0.55) if dark else tint.lightened(0.55)
	var bottom = tint.darkened(0.82) if dark else tint.lightened(0.2)
	draw_vgradient(canvas, rect, top, bottom)
	var sun_center = rect.position + Vector2(rect.size.x * rng.randf_range(0.62, 0.8), rect.size.y * rng.randf_range(0.18, 0.3))
	var sun_radius = minf(rect.size.x * rng.randf_range(0.11, 0.16), rect.size.y * 0.22)
	canvas.draw_circle(sun_center, sun_radius * 1.6, Color(tint.lightened(0.4), 0.08))
	canvas.draw_circle(sun_center, sun_radius, Color(CINNABAR.lerp(tint, 0.35), 0.55 if dark else 0.35))
	for layer in range(3):
		var points = PackedVector2Array()
		var base_y = rect.position.y + rect.size.y * (0.42 + layer * 0.14)
		var amplitude = rect.size.y * (0.16 - layer * 0.035)
		var phase = rng.randf_range(0.0, TAU)
		var frequency = rng.randf_range(1.6, 2.8)
		var steps = 18
		points.append(Vector2(rect.position.x, rect.end.y))
		for step in range(steps + 1):
			var x = rect.position.x + rect.size.x * float(step) / float(steps)
			var wave = sin(phase + float(step) / steps * TAU * frequency * 0.5) * 0.6 + sin(phase * 1.7 + float(step) * 0.9) * 0.4
			points.append(Vector2(x, base_y - amplitude * (0.55 + 0.45 * wave)))
		points.append(Vector2(rect.end.x, rect.end.y))
		var shade = Color(0, 0, 0, 0.28 + layer * 0.12) if dark else Color(tint.darkened(0.5 + layer * 0.1), 0.25 + layer * 0.12)
		canvas.draw_colored_polygon(points, shade)
		var mist = Rect2(rect.position.x, base_y - amplitude * 0.15, rect.size.x, rect.size.y * 0.09)
		draw_vgradient(canvas, mist, Color(tint.lightened(0.6), 0.0), Color(tint.lightened(0.5), 0.10))
	draw_vgradient(canvas, Rect2(rect.position.x, rect.end.y - rect.size.y * 0.3, rect.size.x, rect.size.y * 0.3),
		Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.45 if dark else 0.15))

## Kenney fantasy border `index` as a 9-slice frame tinted `color`: the
## lattice corners keep their size whatever the rectangle.
static func draw_ornate(canvas: CanvasItem, rect: Rect2, index: int, color: Color, corner: float = 30.0) -> void:
	var key = "%d|%s|%s" % [index, color.to_html(), corner]
	if not _ornate.has(key):
		var texture = border(index)
		if texture == null:
			return
		var style = StyleBoxTexture.new()
		style.texture = texture
		style.draw_center = false
		style.modulate_color = color
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_texture_margin(side, 32.0)
			style.set_expand_margin(side, 0.0)
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		_ornate[key] = style
	var scale_factor = corner / 32.0
	if is_equal_approx(scale_factor, 1.0):
		canvas.draw_style_box(_ornate[key], rect)
		return
	canvas.draw_set_transform(rect.position, 0.0, Vector2(scale_factor, scale_factor))
	canvas.draw_style_box(_ornate[key], Rect2(Vector2.ZERO, rect.size / scale_factor))
	canvas.draw_set_transform(Vector2.ZERO)

## A red square seal stamp with one character.
static func draw_seal(canvas: CanvasItem, center: Vector2, size: float, character: String, color: Color = CINNABAR) -> void:
	var rect = Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	draw_round_rect(canvas, rect, color, size * 0.12)
	draw_round_rect(canvas, rect.grow(-size * 0.09), Color.TRANSPARENT, size * 0.08, Color(PAPER, 0.75), maxf(1.0, size * 0.05))
	draw_text(canvas, kai_font(), character, center, int(size * 0.62), PAPER)

## A badge disc of `radius` (EFFECT_SYSTEM_SPEC.md §8.5, §8.6): statuses
## and flags show a glyph, numeric keywords, tower values and hand marks
## show `value` over a faint icon. `alpha` fades the whole badge.
static func draw_badge(canvas: CanvasItem, kind: String, value: int, center: Vector2, radius: float, alpha: float = 1.0) -> void:
	var style: Array = BADGE_STYLES.get(kind, [Color(0.15, 0.15, 0.16), Color(0.7, 0.7, 0.7)])
	var rim = Color(style[1], alpha)
	draw_disc(canvas, center, radius, Color(style[0], alpha), rim, maxf(1.2, radius * 0.14))
	if kind == "lock":
		draw_icon(canvas, "lock_closed", Rect2(center - Vector2(radius, radius) * 0.72, Vector2(radius, radius) * 1.44),
			Color(Color(style[1]).lightened(0.35), alpha))
		var corner = center + Vector2(radius, radius) * 0.68
		draw_disc(canvas, corner, radius * 0.56, Color(0.07, 0.04, 0.1, alpha), rim, maxf(1.0, radius * 0.08))
		draw_text(canvas, bold_font(), str(value), corner, int(radius * 0.8), Color(PAPER, alpha), -1.0, 1)
		return
	if NUMBER_BADGES.has(kind):
		_badge_backdrop(canvas, kind, center, radius, Color(style[1], 0.38 * alpha))
		var text = str(value) if kind != "bounty" or value < 0 else "+%d" % value
		var font_size = int(radius * (1.28 if text.length() <= 1 else (1.08 if text.length() == 2 else 0.9)))
		draw_text(canvas, bold_font(), text, center + Vector2(0, radius * 0.02), font_size, Color(PAPER, alpha), -1.0,
			maxi(1, int(radius * 0.22)), Color(0, 0, 0, 0.85 * alpha))
	elif not draw_badge_glyph(canvas, kind, center, radius * 0.84, Color(Color(style[1]).lightened(0.2), alpha)):
		draw_text(canvas, bold_font(), "?", center, int(radius * 1.2), Color(PAPER, alpha))

## A status or flag glyph drawn in a circle of `radius` around `center`:
## dizzy stars (stun), a lock (silence), a broken sword (disarm), a shield
## with a star (damage immunity), an ankh (death shield), an arrow (pierce),
## a skull (lethal), chevrons (rapid deployment), linked rings (soulbound), a
## page with a scribble (a hacked card). False for kinds without a glyph.
static func draw_badge_glyph(canvas: CanvasItem, kind: String, center: Vector2, radius: float, color: Color) -> bool:
	var r = radius
	var width = maxf(1.4, r * 0.2)
	match kind:
		"stun":
			for index in range(3):
				var angle = -PI * 0.5 + TAU * index / 3.0
				_star(canvas, center + Vector2(cos(angle), sin(angle)) * r * 0.46, r * 0.44, color)
		"silence":
			draw_icon(canvas, "lock_closed", Rect2(center - Vector2(r, r) * 0.78, Vector2(r, r) * 1.56), color)
		"disarm":
			draw_icon(canvas, "sword", Rect2(center - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), color)
			# The break across the blade, with the tip knocked aside.
			var fill = Color(0.25, 0.1, 0.1, color.a)
			canvas.draw_line(center + Vector2(-r * 0.05, -r * 0.6), center + Vector2(r * 0.6, r * 0.05), fill, maxf(2.0, r * 0.3), true)
			canvas.draw_line(center + Vector2(-r * 0.55, r * 0.55), center + Vector2(r * 0.55, -r * 0.55), Color(0.95, 0.3, 0.25, color.a),
				maxf(1.2, r * 0.14), true)
		"damage_immunity":
			draw_icon(canvas, "shield", Rect2(center - Vector2(r, r) * 0.84, Vector2(r, r) * 1.68), color)
			_star(canvas, center + Vector2(0, -r * 0.06), r * 0.42, Color(0.13, 0.18, 0.32, color.a))
		"death_shield":
			canvas.draw_arc(center + Vector2(0, -r * 0.4), r * 0.3, 0.0, TAU, 16, color, width, true)
			canvas.draw_line(center + Vector2(0, -r * 0.1), center + Vector2(0, r * 0.82), color, width, true)
			canvas.draw_line(center + Vector2(-r * 0.56, r * 0.1), center + Vector2(r * 0.56, r * 0.1), color, width, true)
		"pierce":
			var tail = center + Vector2(-r * 0.62, r * 0.62)
			var tip = center + Vector2(r * 0.7, -r * 0.7)
			canvas.draw_line(tail, tip - Vector2(r * 0.2, -r * 0.2), color, width, true)
			canvas.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-r * 0.62, r * 0.08), tip + Vector2(-r * 0.08, r * 0.62)]), color)
			canvas.draw_line(tail, tail + Vector2(-r * 0.05, -r * 0.35), color, width * 0.8, true)
			canvas.draw_line(tail, tail + Vector2(r * 0.35, r * 0.05), color, width * 0.8, true)
		"lethal", "lethal_heroes", "lethal_creeps":
			draw_icon(canvas, "skull", Rect2(center - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), color)
		"rapid_deployment":
			for offset in [-0.3, 0.26]:
				var x = center.x + r * offset
				canvas.draw_polyline(PackedVector2Array([Vector2(x - r * 0.26, center.y - r * 0.52), Vector2(x + r * 0.24, center.y),
					Vector2(x - r * 0.26, center.y + r * 0.52)]), color, width, true)
		"soulbound":
			canvas.draw_arc(center + Vector2(-r * 0.28, 0), r * 0.44, 0.0, TAU, 16, color, width * 0.85, true)
			canvas.draw_arc(center + Vector2(r * 0.28, 0), r * 0.44, 0.0, TAU, 16, color, width * 0.85, true)
		"hacked":
			var page = Rect2(center - Vector2(r * 0.52, r * 0.68), Vector2(r * 1.04, r * 1.36))
			canvas.draw_colored_polygon(round_rect_points(page, r * 0.12), Color(PAPER, 0.9 * color.a))
			var scribble = PackedVector2Array()
			for step in range(7):
				scribble.append(Vector2(page.position.x + page.size.x * (0.14 + 0.72 * step / 6.0),
					center.y + (r * 0.2 if step % 2 == 0 else -r * 0.2)))
			canvas.draw_polyline(scribble, Color(0.85, 0.2, 0.15, color.a), maxf(1.2, r * 0.16), true)
		_:
			return false
	return true

## The faint art behind a numeric badge's value.
static func _badge_backdrop(canvas: CanvasItem, kind: String, center: Vector2, r: float, color: Color) -> void:
	var icon_name = str(NUMBER_BADGES.get(kind, ""))
	if not icon_name.is_empty():
		draw_icon(canvas, icon_name, Rect2(center - Vector2(r, r) * 0.78, Vector2(r, r) * 1.56), color)
	match kind:
		"retaliate":
			# Spikes around the rim.
			for index in range(10):
				var direction = Vector2.from_angle(TAU * index / 10.0)
				canvas.draw_line(center + direction * r * 0.92, center + direction * r * 1.14, Color(color, 1.0), maxf(1.0, r * 0.14), true)
		"regeneration":
			canvas.draw_rect(Rect2(center - Vector2(r * 0.2, r * 0.66), Vector2(r * 0.4, r * 1.32)), color)
			canvas.draw_rect(Rect2(center - Vector2(r * 0.66, r * 0.2), Vector2(r * 1.32, r * 0.4)), color)
		"cleave":
			canvas.draw_arc(center + Vector2(-r * 0.3, 0), r * 0.62, -PI * 0.5, PI * 0.5, 10, color, maxf(1.0, r * 0.18), true)
			canvas.draw_arc(center + Vector2(r * 0.3, 0), r * 0.62, PI * 0.5, PI * 1.5, 10, color, maxf(1.0, r * 0.18), true)
		"charges":
			for index in range(8):
				canvas.draw_circle(center + Vector2.from_angle(TAU * index / 8.0) * r * 0.72, maxf(0.8, r * 0.09), color)

static func _star(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points = PackedVector2Array()
	for index in range(10):
		var angle = -PI * 0.5 + PI * index / 5.0
		var reach = radius if index % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * reach)
	canvas.draw_colored_polygon(points, color)

## A gold-rimmed disc used for cost gems, price coins and stat badges.
static func draw_disc(canvas: CanvasItem, center: Vector2, radius: float, fill: Color, rim: Color = GOLD, rim_width: float = 2.0) -> void:
	canvas.draw_circle(center + Vector2(0, radius * 0.08), radius + 1.5, Color(0, 0, 0, 0.45))
	canvas.draw_circle(center, radius, rim)
	canvas.draw_circle(center, radius - rim_width, fill)
	canvas.draw_arc(center, radius - rim_width - 1.5, PI * 1.1, PI * 1.9, 12, Color(1, 1, 1, 0.12), maxf(1.0, radius * 0.12), true)
