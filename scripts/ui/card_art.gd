extends RefCounted
## Card artwork lookup and the generated placeholder.
##
## Three Kingdoms skin: assets/art/cards/<id>.png (or .jpg / .webp; see
## tools/optimize_art.py). Classic skin: the locally downloaded original
## render cropped to its art window first, then the Three Kingdoms art.
## Otherwise a generated ink-wash placeholder with the card's name in
## calligraphy. Valve renders are optional, gitignored local files.

const Library = preload("res://scripts/core/card_library.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ART_DIR = "res://assets/art/cards/"
const ART_EXTENSIONS = ["png", "jpg", "webp"]
## Large art is shrunk once to this height and mipmapped, so board-sized
## draws stay smooth and memory stays modest.
const MAX_ART_HEIGHT = 768
const TALL_KINDS = ["hero", "creep"]

static var _entries: Dictionary = {}
static var _textures: Dictionary = {}

## {"texture", "region", "focus"} for a card, or {} when the placeholder is used.
static func art(card_id: String) -> Dictionary:
	var key = Settings.skin + "|" + card_id
	if _entries.has(key):
		return _entries[key]
	var result: Dictionary = {}
	if Settings.skin == "classic":
		result = _classic_render(card_id)
	if result.is_empty():
		for extension in ART_EXTENSIONS:
			var texture = _texture(ART_DIR + card_id + "." + extension)
			if texture != null:
				result = {"texture": texture, "region": Rect2(Vector2.ZERO, texture.get_size()), "focus": Vector2(0.5, 0.28)}
				break
	_entries[key] = result
	return result

## Draws the card's art cover-cropped into `rect` (or the placeholder).
## Returns true when real art was drawn.
static func draw(canvas: CanvasItem, rect: Rect2, card_id: String, compact: bool = false,
		modulate: Color = Color.WHITE, focus_override: Vector2 = Vector2(-1, -1)) -> bool:
	var entry = art(card_id)
	if entry.is_empty():
		draw_placeholder(canvas, rect, card_id, compact)
		return false
	var focus = entry.focus if focus_override.x < 0.0 else focus_override
	UiKit.draw_cover(canvas, entry.texture, rect, focus, modulate, entry.region)
	return true

## A tight face crop for small portraits (hero icons in the lane HUD).
## Card art keeps the face in the upper-middle third (docs/art/ART_PROMPTS.md).
## Returns false (nothing drawn) when the card has no art.
static func draw_portrait(canvas: CanvasItem, rect: Rect2, card_id: String) -> bool:
	var entry = art(card_id)
	if entry.is_empty():
		return false
	var region: Rect2 = entry.region
	var side = region.size.x * 0.5
	var face = Rect2(region.position + Vector2((region.size.x - side) * 0.5, region.size.y * 0.1), Vector2(side, side))
	UiKit.draw_cover(canvas, entry.texture, rect, Vector2(0.5, 0.5), Color.WHITE, face)
	return true

## Ink-wash background in the card's colour with its name in large Kai
## calligraphy (vertical for short Chinese names) and a small English name.
static func draw_placeholder(canvas: CanvasItem, rect: Rect2, card_id: String, compact: bool = false) -> void:
	var definition = Library.raw_definition(card_id)
	var color_id = str(definition.get("color", "neutral"))
	var tint = UiKit.card_color(color_id)
	UiKit.draw_ink_wash(canvas, rect, tint, card_id)
	var chinese = Library.loc(card_id, "name", "zh_CN")
	var english = Library.loc(card_id, "name", "en")
	var cjk = _is_cjk(chinese)
	var font = UiKit.kai_font() if cjk else UiKit.title_font()
	var main_text = chinese if cjk else english
	var ink = Color(UiKit.PAPER, 0.93)
	var name_area = Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.06),
		Vector2(rect.size.x * 0.84, rect.size.y * (0.78 if compact else 0.72)))
	if cjk and main_text.length() <= 4:
		var count = main_text.length()
		var size = int(minf(rect.size.x * (0.44 if count <= 2 else 0.36), name_area.size.y / (count * 1.08)))
		var step = size * 1.06
		var top = name_area.get_center().y - step * count * 0.5 + step * 0.5
		var x = name_area.get_center().x
		for index in range(count):
			UiKit.draw_text(canvas, font, main_text[index], Vector2(x, top + step * index), size, ink, -1.0,
				maxi(2, int(size * 0.08)), Color(0, 0, 0, 0.55))
	else:
		var max_size = int(rect.size.x * (0.2 if cjk else 0.15))
		var text = UiKit.fit_paragraph(main_text, font, name_area.size, max_size, maxi(8, int(max_size * 0.45)))
		var height = text.get_size().y
		var origin = Vector2(name_area.position.x, name_area.get_center().y - height * 0.5)
		text.draw_outline(canvas.get_canvas_item(), origin, maxi(2, int(max_size * 0.08)), Color(0, 0, 0, 0.55))
		text.draw(canvas.get_canvas_item(), origin, ink)
	if not compact and cjk and english != chinese:
		UiKit.draw_text(canvas, UiKit.body_font(), english, Vector2(rect.get_center().x, rect.end.y - rect.size.y * 0.09),
			int(maxf(9.0, rect.size.x * 0.075)), Color(UiKit.PAPER, 0.72), rect.size.x * 0.9, 2)
	if cjk and not compact:
		var seal = UiKit.faction_seal(card_id)
		if Library.faction(card_id) != "neutral" and not seal.is_empty():
			var seal_size = rect.size.x * 0.13
			UiKit.draw_seal(canvas, rect.position + Vector2(rect.size.x - seal_size * 0.85, seal_size * 0.85), seal_size, seal)

static func _is_cjk(text: String) -> bool:
	for index in range(text.length()):
		var code = text.unicode_at(index)
		if code >= 0x3400 and code <= 0x9FFF:
			return true
	return false

static func _classic_render(card_id: String) -> Dictionary:
	var definition = Library.raw_definition(card_id)
	var path = str(definition.get("image", ""))
	if path.is_empty():
		return {}
	var texture = _texture(path)
	if texture == null:
		return {}
	var size = texture.get_size()
	# Classic renders: 10% title bar; heroes and creeps have art down to the
	# stat bar (86%), spells and items down to the text box (54%).
	var tall = str(definition.get("kind", "")) in TALL_KINDS
	var region = Rect2(0, size.y * 0.1, size.x, size.y * (0.76 if tall else 0.44))
	return {"texture": texture, "region": region, "focus": Vector2(0.5, 0.25)}

## Loads (and in rendered runs shrinks and mipmaps) an artwork texture.
static func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = null
	var headless = DisplayServer.get_name() == "headless"
	if not headless and FileAccess.file_exists(path):
		# Development checkout: decode the source file directly so freshly
		# added art works before Godot imports it.
		var image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			texture = _prepared(image)
	if texture == null and ResourceLoader.exists(path):
		texture = UiKit.mipmapped(load(path) as Texture2D, MAX_ART_HEIGHT)
	_textures[path] = texture
	return texture

static func _prepared(image: Image) -> Texture2D:
	if image.is_compressed():
		image.decompress()
	if image.get_height() > MAX_ART_HEIGHT:
		var width = int(round(float(image.get_width()) * MAX_ART_HEIGHT / float(image.get_height())))
		image.resize(width, MAX_ART_HEIGHT, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

## Forgets cached art (after a skin change or when new art files appear).
static func clear_cache() -> void:
	_entries.clear()
