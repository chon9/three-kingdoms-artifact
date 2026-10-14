extends Control
## A full card face drawn in code, used for the hand, shop, deployment tray,
## cast display and inspector. Layout follows Classic cards: a colour title
## bar with the cost gem and the localized name, an art window with a type
## disc, then a rules text box on rice paper (spells, items, creeps with
## abilities) and a stat bar (heroes, creeps) or a gold price coin (items),
## plus the faction emblem (or a seal without the emblem art).
##
## Every size is relative to BASE, so one script draws thumbnails and the
## large inspect view.

const Library = preload("res://scripts/core/card_library.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const BASE = Vector2(180, 262)
const ABILITY_FIELDS = ["neighbor_armor", "neighbor_attack", "siege", "combat_growth_attack",
	"combat_growth_health", "global_attack", "static_field", "hero_bonus", "hero_tower_bonus", "rapid_deployment", "ability"]
const SLOT_ICONS = {"weapon": "sword", "armor": "shield", "accessory": "suit_hearts"}
const KIND_ICONS = {"hero": "crown_a", "creep": "character", "spell": "book_open", "improvement": "structure_wall"}
## Decorative emblem on card backs ("three": three kingdoms, three lanes).
const BACK_GLYPH = "三"

var card_id: String = ""
var definition: Dictionary = {}
## Live values for units: attack, armor, health, max_health, items.
var live: Dictionary = {}
var playable: bool = false
var selected: bool = false
var dimmed: bool = false
var face_down: bool = false
var hovered: bool = false
var glow_color: Color = UiKit.PLAYABLE
var _text: TextParagraph
var _text_key: String = ""
var _pulse: float = 0.0

func _init() -> void:
	size = BASE
	pivot_offset = BASE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func setup(id: String, live_values: Dictionary = {}) -> void:
	card_id = id
	definition = Library.raw_definition(id)
	live = live_values
	refresh()

## Re-localizes text (language or skin change) and redraws.
func refresh() -> void:
	_text_key = ""
	queue_redraw()

func set_size_keep(new_size: Vector2) -> void:
	size = new_size
	pivot_offset = new_size * 0.5
	_text_key = ""
	queue_redraw()

func kind() -> String:
	return str(definition.get("kind", "spell"))

func _process(delta: float) -> void:
	if playable or selected:
		_pulse = fmod(_pulse + delta * 2.2, TAU)
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_text_key = ""

## Layout split: tall art for heroes and plain creeps, a text box otherwise.
func _layout() -> Dictionary:
	var s = size.x / BASE.x
	var title_h = 34.0 * s
	var card_kind = kind()
	var stat_bar = card_kind in ["hero", "creep"]
	var has_text = card_kind not in ["hero", "creep"] or _creep_has_text()
	var art_bottom = size.y * (0.84 if not has_text else (0.53 if not stat_bar else 0.5))
	# Items keep their text clear of the gold price coin in the corner.
	var text_bottom = size.y - (40.0 * s if stat_bar else (34.0 * s if card_kind == "item" else 16.0 * s))
	return {"s": s, "title_h": title_h, "stat_bar": stat_bar, "has_text": has_text,
		"art": Rect2(3.0 * s, title_h, size.x - 6.0 * s, art_bottom - title_h),
		"text": Rect2(4.0 * s, art_bottom, size.x - 8.0 * s, text_bottom - art_bottom),
		"bar": Rect2(0, size.y - 40.0 * s, size.x, 40.0 * s)}

func _creep_has_text() -> bool:
	for field in ABILITY_FIELDS:
		if definition.has(field):
			return true
	return false

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var s = size.x / BASE.x
	var radius = 9.0 * s
	if playable:
		UiKit.draw_glow(self, rect, radius, glow_color, 0.75 + 0.25 * sin(_pulse))
	if selected:
		UiKit.draw_glow(self, rect, radius, UiKit.TARGET, 1.0)
	_draw_shadow(rect, radius)
	if face_down or card_id.is_empty():
		draw_card_back(self, rect)
		return
	var layout = _layout()
	var color_id = str(definition.get("color", "neutral"))
	var bar_color = UiKit.card_color(color_id)
	UiKit.draw_round_rect(self, rect, Color("1b1917"), radius)
	CardArt.draw(self, layout.art, card_id, false)
	# Title bar.
	var title_rect = Rect2(0, 0, size.x, layout.title_h)
	draw_colored_polygon(_top_rounded(title_rect, radius), bar_color)
	UiKit.draw_vgradient(self, Rect2(0, layout.title_h * 0.45, size.x, layout.title_h * 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0.28))
	draw_line(Vector2(0, layout.title_h), Vector2(size.x, layout.title_h), Color(0, 0, 0, 0.55), maxf(1.0, 2.0 * s))
	var card_kind = kind()
	var name_left = 9.0 * s
	if card_kind not in ["hero", "item"]:
		var gem_center = Vector2(19.0 * s, layout.title_h * 0.5)
		UiKit.draw_disc(self, gem_center, 13.5 * s, Color("1d2430"), UiKit.GOLD, 2.0 * s)
		UiKit.draw_text(self, UiKit.bold_font(), str(int(definition.get("cost", 0))), gem_center, int(19 * s), UiKit.PAPER, -1.0, maxi(1, int(2 * s)))
		if definition.get("cross_lane", false):
			for side in [-1, 1]:
				var tip = gem_center + Vector2(side * 17.5 * s, 0)
				draw_colored_polygon(PackedVector2Array([tip + Vector2(side * 4.0 * s, 0), tip + Vector2(0, -4.0 * s), tip + Vector2(0, 4.0 * s)]), UiKit.GOLD_BRIGHT)
		name_left = 38.0 * s
	UiKit.draw_text_left(self, UiKit.title_font(), Library.loc(card_id), Vector2(name_left, layout.title_h * 0.52),
		int(19 * s), UiKit.PAPER, size.x - name_left - 8.0 * s, maxi(1, int(3 * s)))
	# Type disc on the art.
	var disc = layout.art.position + Vector2(15.0, 15.0) * s
	UiKit.draw_disc(self, disc, 11.0 * s, Color(0.08, 0.08, 0.09, 0.9), Color(0.62, 0.6, 0.56), 1.5 * s)
	var icon_name = SLOT_ICONS.get(str(definition.get("slot", "")), "") if card_kind == "item" else KIND_ICONS.get(card_kind, "book_open")
	if card_kind == "item" and definition.get("consumable", false):
		icon_name = "flask_full"
	if card_kind == "item" and icon_name.is_empty():
		icon_name = "pouch"
	UiKit.draw_icon(self, icon_name, Rect2(disc - Vector2(7, 7) * s, Vector2(14, 14) * s), UiKit.PAPER)
	if live.has("items") and card_kind == "hero":
		_draw_item_slots(layout, s)
	if layout.has_text:
		_draw_text_box(layout, s)
	if layout.stat_bar:
		_draw_stat_bar(layout, s, color_id)
	if card_kind == "item":
		var coin = Vector2(size.x - 20.0 * s, size.y - 19.0 * s)
		UiKit.draw_disc(self, coin, 15.0 * s, Color("b98a2e"), UiKit.GOLD_BRIGHT, 2.0 * s)
		UiKit.draw_text(self, UiKit.bold_font(), str(int(definition.get("price", 0))), coin, int(17 * s), Color("2a1a08"))
	var faction = Library.faction(card_id)
	if faction != "neutral" and Library.current_skin() == "three_kingdoms":
		if layout.stat_bar:
			# Heroes and creeps carry the emblem on the art's top-right corner.
			UiKit.draw_card_emblem(self, card_id, layout.art.position + Vector2(layout.art.size.x - 15.0 * s, 15.0 * s), 24.0 * s)
		elif not UiKit.draw_card_emblem(self, card_id, Vector2(size.x * 0.5, size.y - 11.0 * s), 21.0 * s):
			UiKit.draw_seal(self, Vector2(size.x * 0.5, size.y - 9.0 * s), 15.0 * s, UiKit.faction_seal(card_id))
	# Frame.
	UiKit.draw_round_rect(self, rect, Color.TRANSPARENT, radius, bar_color.lightened(0.15), maxf(1.0, 2.0 * s))
	UiKit.draw_round_rect(self, rect.grow(-2.0 * s), Color.TRANSPARENT, radius - 2.0 * s, Color(0, 0, 0, 0.6), 1.0)
	if dimmed:
		UiKit.draw_round_rect(self, rect, Color(0.02, 0.02, 0.03, 0.5), radius)
	if hovered and not dimmed:
		UiKit.draw_round_rect(self, rect, Color.TRANSPARENT, radius, Color(1, 1, 1, 0.35), 1.5)

func _draw_shadow(rect: Rect2, radius: float) -> void:
	for ring in range(3):
		var grown = Rect2(rect.position + Vector2(0, 4 + ring * 2), rect.size).grow(ring * 2.0)
		draw_colored_polygon(UiKit.round_rect_points(grown, radius + ring * 2.0), Color(0, 0, 0, 0.16 - ring * 0.04))

func _top_rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 5
	for step in range(steps + 1):
		var angle = PI + PI * 0.5 * step / steps
		points.append(Vector2(radius, radius) + Vector2(cos(angle), sin(angle)) * radius)
	for step in range(steps + 1):
		var angle = PI * 1.5 + PI * 0.5 * step / steps
		points.append(Vector2(rect.size.x - radius, radius) + Vector2(cos(angle), sin(angle)) * radius)
	points.append(Vector2(rect.size.x, rect.size.y))
	points.append(Vector2(0, rect.size.y))
	return points

func _draw_text_box(layout: Dictionary, s: float) -> void:
	var box: Rect2 = layout.text
	var paper = UiKit.ui_art("paper_tile")
	var ink = Color("ece4d4")
	if paper != null:
		# Rice paper at about its own grain, from a spot that differs per card,
		# with dark ink on it.
		var paper_size = paper.get_size()
		var region_size = (box.size / maxf(0.35, s) * 1.4).min(paper_size)
		var room = paper_size - region_size
		var seed_value = absi(hash(card_id))
		var region = Rect2(Vector2(seed_value % maxi(1, int(room.x)), (seed_value / 7) % maxi(1, int(room.y))), region_size)
		draw_texture_rect_region(paper, box, region, Color(0.88, 0.83, 0.74))
		UiKit.draw_vgradient(self, Rect2(box.position, Vector2(box.size.x, box.size.y * 0.25)), Color(0.2, 0.12, 0.05, 0.25), Color(0.2, 0.12, 0.05, 0.0))
		ink = Color("2a1f16")
	else:
		UiKit.draw_vgradient(self, box, Color("2c2926"), Color("201e1c"))
	draw_line(box.position, Vector2(box.end.x, box.position.y), Color(UiKit.GOLD_DARK, 0.8), maxf(1.0, 1.5 * s))
	var text = Library.loc(card_id, "text")
	var area = box.size - Vector2(12.0, 10.0) * s
	var key = "%s|%s|%s" % [text, area, TranslationServer.get_locale()]
	if key != _text_key:
		_text_key = key
		_text = UiKit.fit_paragraph(text, UiKit.body_font(), area, int(15 * s), maxi(7, int(9 * s)))
	var height = _text.get_size().y
	_text.draw(get_canvas_item(), Vector2(box.position.x + 6.0 * s, box.position.y + (box.size.y - height) * 0.5), ink)

func _draw_stat_bar(layout: Dictionary, s: float, color_id: String) -> void:
	var bar: Rect2 = layout.bar
	var radius = 9.0 * s
	var dark = UiKit.card_color_dark(color_id)
	var points = PackedVector2Array([bar.position, Vector2(bar.end.x, bar.position.y)])
	for step in range(6):
		var angle = 0.0 + PI * 0.5 * step / 5.0
		points.append(Vector2(bar.end.x - radius, bar.end.y - radius) + Vector2(cos(angle), sin(angle)) * radius)
	for step in range(6):
		var angle = PI * 0.5 + PI * 0.5 * step / 5.0
		points.append(Vector2(bar.position.x + radius, bar.end.y - radius) + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, dark)
	draw_line(bar.position, Vector2(bar.end.x, bar.position.y), Color(0, 0, 0, 0.5), maxf(1.0, 2.0 * s))
	var attack = int(live.get("attack", definition.get("attack", 0)))
	var armor = int(live.get("armor", definition.get("armor", 0)))
	var health = int(live.get("health", definition.get("health", 0)))
	var max_health = int(live.get("max_health", health))
	var values = [["sword", attack, UiKit.BUFF if attack > int(definition.get("attack", 0)) else UiKit.PAPER],
		["shield", armor, UiKit.BUFF if armor > int(definition.get("armor", 0)) else UiKit.PAPER],
		["suit_hearts", health, UiKit.DAMAGE if health < max_health else UiKit.PAPER]]
	for index in range(3):
		var center = Vector2(bar.position.x + bar.size.x * (0.2 + 0.3 * index), bar.get_center().y)
		UiKit.draw_icon(self, values[index][0], Rect2(center - Vector2(25, 9) * s, Vector2(18, 18) * s), Color(0, 0, 0, 0.45))
		UiKit.draw_icon(self, values[index][0], Rect2(center - Vector2(26, 10) * s, Vector2(18, 18) * s), Color(UiKit.PAPER, 0.8))
		UiKit.draw_text_left(self, UiKit.bold_font(), str(values[index][1]), center + Vector2(-4, 0) * s, int(21 * s), values[index][2], -1.0, maxi(1, int(3 * s)))

func _draw_item_slots(layout: Dictionary, s: float) -> void:
	var equipped: Dictionary = live.get("items", {})
	var slot_size = Vector2(26, 22) * s
	var left = size.x * 0.5 - slot_size.x * 1.5 - 4.0 * s
	for index in range(3):
		var slot = ["weapon", "armor", "accessory"][index]
		var rect = Rect2(Vector2(left + index * (slot_size.x + 4.0 * s), layout.art.position.y + 4.0 * s), slot_size)
		var filled = equipped.has(slot)
		UiKit.draw_round_rect(self, rect, Color(UiKit.card_color("item"), 0.95) if filled else Color(0, 0, 0, 0.55), 3.0 * s,
			Color(UiKit.GOLD_BRIGHT, 0.9) if filled else Color(1, 1, 1, 0.25), 1.0)
		UiKit.draw_icon(self, SLOT_ICONS[slot], Rect2(rect.get_center() - Vector2(7, 7) * s, Vector2(14, 14) * s),
			Color(0.1, 0.07, 0.03) if filled else Color(1, 1, 1, 0.3))

## The shared card back: dark lacquer, gold lattice border and a seal.
static func draw_card_back(canvas: CanvasItem, rect: Rect2) -> void:
	var radius = rect.size.x * 0.06
	var art_back = UiKit.tex("res://assets/art/ui/card_back.png")
	UiKit.draw_round_rect(canvas, rect, Color("3a1714"), radius)
	if art_back != null:
		UiKit.draw_cover(canvas, art_back, rect.grow(-rect.size.x * 0.03), Vector2(0.5, 0.5))
	else:
		UiKit.draw_vgradient(canvas, rect.grow(-rect.size.x * 0.05), Color("5a1f1a"), Color("2a0f0d"))
		var lattice = UiKit.border(6)
		if lattice != null:
			var inner = rect.grow(-rect.size.x * 0.1)
			canvas.draw_texture_rect(lattice, inner, false, Color(UiKit.GOLD, 0.55))
		var center = rect.get_center()
		canvas.draw_circle(center, rect.size.x * 0.22, Color(0, 0, 0, 0.35))
		canvas.draw_arc(center, rect.size.x * 0.22, 0.0, TAU, 32, Color(UiKit.GOLD, 0.7), maxf(1.0, rect.size.x * 0.02), true)
		UiKit.draw_text(canvas, UiKit.kai_font(), BACK_GLYPH, center, int(rect.size.x * 0.26), UiKit.GOLD_BRIGHT)
	UiKit.draw_round_rect(canvas, rect, Color.TRANSPARENT, radius, Color(UiKit.GOLD_DARK, 0.9), maxf(1.0, rect.size.x * 0.015))
