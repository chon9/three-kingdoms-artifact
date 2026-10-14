extends Control
## One lane table: the enemy wall and tower at the top, the river across the
## middle, the viewer's wall and tower at the bottom, and both unit rows with
## index-aligned combat positions (column n holds the enemy unit above and
## the viewer's unit below). The board sets `zoom` (0 lane view, 1 overview)
## and the lane's rectangle; every position here derives from those.

const UnitCard = preload("res://scripts/ui/unit_card.gd")
const TowerView = preload("res://scripts/ui/tower_view.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const LANE_KEYS = ["LANE_LEFT", "LANE_MIDDLE", "LANE_RIGHT"]
const GAP = 12.0
const OVERVIEW_SCALE = 0.72

var lane_index: int = 0
var zoom: float = 0.0
var active: bool = false
## Deployment drop cue: 0 none, 1 candidate lane, 2 hovered.
var drop_state: int = 0
## uid -> UnitCard
var cards: Dictionary = {}
## Column contents [enemy row, own row]: uid or -1 per combat position.
var columns: Array = [[], []]
## Creep placement candidates while a creep card is held: [{position, column}].
var ghost_slots: Array = []
var hovered_slot: int = -999
## Deployment previews: [enemy card ids, own card ids] shown as ghost cards.
var incoming: Array = [[], []]
var incoming_cards: Array = []
var towers: Array = []
var _scale: float = 1.0
## Combat positions laid out this frame: the rows plus incoming ghost cards.
var _count: int = 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for side in range(2):
		var tower = TowerView.new()
		tower.own = side == 1
		add_child(tower)
		towers.append(tower)

# --- Geometry ----------------------------------------------------------------

func table_rect() -> Rect2:
	var lane_rect = Rect2(48, size.y * 0.04, size.x - 96, size.y * 0.856)
	var over_rect = Rect2(0, 0, size.x, size.y)
	return Rect2(lane_rect.position.lerp(over_rect.position, zoom), lane_rect.size.lerp(over_rect.size, zoom))

func wall_height() -> float:
	return lerpf(size.y * 0.122, size.y * 0.15, zoom)

func row_center_y(own: bool) -> float:
	return size.y * lerpf(0.6 if own else 0.311, 0.665 if own else 0.305, zoom)

func river_y() -> float:
	return size.y * lerpf(0.456, 0.485, zoom)

func tower_center(own: bool) -> Vector2:
	return Vector2(size.x * 0.5, size.y * lerpf(0.767 if own else 0.106, 0.9 if own else 0.075, zoom))

func tower_scale() -> float:
	return lerpf(1.0, 0.7, zoom)

func _fit_scale(count: int) -> float:
	var base = lerpf(1.0, OVERVIEW_SCALE, zoom)
	var available = table_rect().size.x - lerpf(170.0, 12.0, zoom)
	var needed = maxf(1.0, float(count)) * (UnitCard.SIZE.x + _gap())
	return minf(base, available / needed) if needed > 0.0 else base

func spacing() -> float:
	return (UnitCard.SIZE.x + _gap()) * _scale

## Space between cards: tighter in the overview, where width is scarce.
func _gap() -> float:
	return lerpf(GAP, 5.0, zoom)

## Centre x of combat position `column` among `count` positions.
func column_x(column: float, count: int) -> float:
	return size.x * 0.5 + (column - (count - 1) * 0.5) * spacing()

func slot_center(column: float, own: bool) -> Vector2:
	return Vector2(column_x(column, _count), row_center_y(own))

## Incoming ghost cards are appended after the existing combat positions.
func incoming_count() -> int:
	return maxi(incoming[0].size(), incoming[1].size())

# --- Layout ------------------------------------------------------------------

## Positions towers, unit cards, ghost cards and slots for the current zoom.
func layout() -> void:
	_count = columns[1].size() + incoming_count()
	_scale = _fit_scale(_count + (2 if not ghost_slots.is_empty() else 0))
	for side in range(2):
		var tower: Control = towers[side]
		var tower_size = TowerView.SIZE
		tower.scale = Vector2.ONE * tower_scale()
		tower.position = tower_center(side == 1) - tower_size * 0.5
	for side in range(2):
		for column in range(columns[side].size()):
			var uid = int(columns[side][column])
			if uid != -1 and cards.has(uid):
				_place_card(cards[uid], slot_center(column, side == 1))
	_layout_incoming()
	queue_redraw()

func _place_card(card: Control, center: Vector2) -> void:
	if not card.scale.is_equal_approx(Vector2.ONE * _scale):
		card.scale = Vector2.ONE * _scale
		card.refresh()
	card.position = center - UnitCard.SIZE * 0.5

func _layout_incoming() -> void:
	var index = 0
	for side in range(2):
		var start = columns[1].size()
		for card_index in range(incoming[side].size()):
			if index >= incoming_cards.size():
				break
			_place_card(incoming_cards[index], slot_center(start + card_index, side == 1))
			index += 1

# --- State -------------------------------------------------------------------

## Sets the column layout from the lane's rows (unit dicts or null) and the
## per-uid display models. Returns {"added": [cards], "removed": [cards],
## "moved": {card: from_position}} so the board can animate the change.
func sync(lane: Dictionary, viewer: int, models: Dictionary) -> Dictionary:
	var result = {"added": [], "removed": [], "moved": {}}
	var rows = [lane.units[1 - viewer], lane.units[viewer]]
	var seen: Dictionary = {}
	var old_positions: Dictionary = {}
	for uid in cards:
		old_positions[uid] = cards[uid].position
	columns = [[], []]
	for side in range(2):
		for unit in rows[side]:
			if unit == null:
				columns[side].append(-1)
				continue
			var uid = int(unit.uid)
			columns[side].append(uid)
			seen[uid] = true
			var card: Control = cards.get(uid)
			if card == null:
				card = UnitCard.new()
				add_child(card)
				cards[uid] = card
				result.added.append(card)
			card.apply(models.get(uid, {"unit": unit, "own": side == 1}))
	for uid in cards.keys():
		if not seen.has(uid):
			result.removed.append(cards[uid])
			cards.erase(uid)
	var structures = lane.structures
	var damage = models.get("tower_damage", [0, 0])
	towers[0].apply(structures[1 - viewer], int(lane.mana[1 - viewer]), int(lane.max_mana[1 - viewer]), int(damage[1]))
	towers[1].apply(structures[viewer], int(lane.mana[viewer]), int(lane.max_mana[viewer]), int(damage[0]))
	for card in towers:
		move_child(card, 0)
	layout()
	for uid in cards:
		if old_positions.has(uid) and old_positions[uid] != cards[uid].position:
			result.moved[cards[uid]] = old_positions[uid]
	return result

func set_incoming(enemy_cards: Array, own_cards: Array) -> void:
	for card in incoming_cards:
		UiKit.discard(card)
	incoming_cards.clear()
	incoming = [enemy_cards, own_cards]
	for side in range(2):
		for card_id in incoming[side]:
			var card = UnitCard.new()
			card.ghost = true
			var definition = Library.raw_definition(card_id)
			var health = int(definition.get("health", 0))
			card.apply({"unit": {"card": card_id, "color": str(definition.get("color", "neutral")),
				"hero": str(definition.get("kind", "")) == "hero", "attack": int(definition.get("attack", 0)),
				"armor": int(definition.get("armor", 0)), "health": health, "max_health": health, "uid": -2}, "own": side == 1})
			card.target_state = 4 if side == 1 else 0
			add_child(card)
			incoming_cards.append(card)
	layout()

func set_ghost_slots(positions: Array) -> void:
	ghost_slots = []
	var count = columns[1].size()
	for position in positions:
		var column = float(position)
		if count == 0:
			column = 0.0
		elif position == -1:
			column = -1.0
		ghost_slots.append({"position": int(position), "column": column})
	hovered_slot = -999
	layout()

func ghost_rect(slot: Dictionary) -> Rect2:
	var center = slot_center(slot.column, true)
	var card_size = UnitCard.SIZE * _scale
	return Rect2(center - card_size * 0.5, card_size)

# --- Hit testing (global coordinates) ------------------------------------------

func unit_at(global_point: Vector2) -> Control:
	for uid in cards:
		var card: Control = cards[uid]
		if card.visible and card.get_global_rect().has_point(global_point):
			return card
	return null

func slot_at(global_point: Vector2) -> int:
	var local = get_global_transform().affine_inverse() * global_point
	for slot in ghost_slots:
		if ghost_rect(slot).grow(10.0).has_point(local):
			return int(slot.position)
	return -999

func contains(global_point: Vector2) -> bool:
	var local = get_global_transform().affine_inverse() * global_point
	return table_rect().has_point(local)

func slot_global_center(position: int) -> Vector2:
	for slot in ghost_slots:
		if int(slot.position) == position:
			return get_global_transform() * ghost_rect(slot).get_center()
	return get_global_transform() * slot_center(0, true)

# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	var table = table_rect()
	var radius = lerpf(30.0, 16.0, zoom)
	var points = UiKit.round_rect_points(table, radius, 6)
	var shadow = PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(0, 10))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.55))
	_textured(points, UiKit.WOOD_DARK, 760.0, Color(1.42, 1.28, 1.1))
	# Ink-wash shading: warm toward the enemy, cool toward the viewer.
	UiKit.draw_vgradient(self, Rect2(table.position, Vector2(table.size.x, table.size.y * 0.5)),
		Color(0.22, 0.08, 0.05, 0.35), Color(0.1, 0.08, 0.06, 0.0))
	UiKit.draw_vgradient(self, Rect2(table.position + Vector2(0, table.size.y * 0.5), Vector2(table.size.x, table.size.y * 0.5)),
		Color(0.04, 0.09, 0.1, 0.0), Color(0.02, 0.1, 0.11, 0.35))
	_draw_mountains(table)
	_draw_wall(table, false)
	_draw_wall(table, true)
	_draw_river(table)
	_draw_ghost_slots()
	var outline = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.05, 0.04, 0.03, 0.9), 5.0, true)
	draw_polyline(outline, Color(UiKit.GOLD_DARK, 0.85), 2.0, true)
	if zoom > 0.5 and active:
		var glow = table.grow(3)
		UiKit.draw_glow(self, glow, radius + 3.0, UiKit.GOLD, 0.9 * zoom)
	if drop_state > 0:
		UiKit.draw_glow(self, table, radius, UiKit.PLAYABLE, 0.8 if drop_state == 1 else 1.8)
		if drop_state == 2:
			draw_colored_polygon(points, Color(UiKit.PLAYABLE, 0.08))

func _textured(points: PackedVector2Array, path: String, tile: float, tint: Color) -> void:
	var texture = UiKit.tex(path)
	if texture == null:
		draw_colored_polygon(points, Color("4a3a2c"))
		return
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()
	for point in points:
		uvs.append(point / tile)
		colors.append(tint)
	draw_polygon(points, colors, uvs, texture)

func _draw_mountains(table: Rect2) -> void:
	# Faint ink mountains behind each wall give the table a shan-shui feel.
	for side in range(2):
		var own = side == 1
		var rng = RandomNumberGenerator.new()
		rng.seed = 7919 * (lane_index + 1) + side
		var base_y = table.position.y + wall_height() + table.size.y * 0.09 if not own else table.end.y - wall_height() - table.size.y * 0.02
		var polygon = PackedVector2Array()
		var steps = 14
		var amplitude = table.size.y * 0.07
		polygon.append(Vector2(table.position.x + 4, base_y + (0 if not own else amplitude)))
		for step in range(steps + 1):
			var x = table.position.x + 4 + (table.size.x - 8) * float(step) / steps
			var peak = absf(sin(step * 0.9 + rng.randf() * 2.0)) * amplitude * rng.randf_range(0.4, 1.0)
			polygon.append(Vector2(x, base_y - peak if not own else base_y - peak))
		polygon.append(Vector2(table.end.x - 4, base_y + (0 if not own else amplitude)))
		if not own:
			polygon.append(Vector2(table.end.x - 4, base_y))
		draw_colored_polygon(polygon, Color(0, 0, 0, 0.08))

func _draw_wall(table: Rect2, own: bool) -> void:
	var height = wall_height()
	var band = Rect2(table.position.x + 3, table.position.y + 3 if not own else table.end.y - height - 3, table.size.x - 6, height)
	var tint = Color(0.82, 0.62, 0.56) if not own else Color(0.58, 0.72, 0.74)
	var radius = lerpf(28.0, 14.0, zoom)
	var points: PackedVector2Array
	if own:
		points = PackedVector2Array([band.position, Vector2(band.end.x, band.position.y)])
		for step in range(7):
			var angle = PI * 0.5 * step / 6.0
			points.append(Vector2(band.end.x - radius, band.end.y - radius) + Vector2(cos(angle), sin(angle)) * radius)
		for step in range(7):
			var angle = PI * 0.5 + PI * 0.5 * step / 6.0
			points.append(Vector2(band.position.x + radius, band.end.y - radius) + Vector2(cos(angle), sin(angle)) * radius)
	else:
		points = PackedVector2Array()
		for step in range(7):
			var angle = PI + PI * 0.5 * step / 6.0
			points.append(Vector2(band.position.x + radius, band.position.y + radius) + Vector2(cos(angle), sin(angle)) * radius)
		for step in range(7):
			var angle = PI * 1.5 + PI * 0.5 * step / 6.0
			points.append(Vector2(band.end.x - radius, band.position.y + radius) + Vector2(cos(angle), sin(angle)) * radius)
		points.append(band.end)
		points.append(Vector2(band.position.x, band.end.y))
	_textured(points, UiKit.STONE, 520.0, Color(tint.r * 0.62, tint.g * 0.62, tint.b * 0.62))
	# Battlements along the inner edge.
	var edge_y = band.end.y if not own else band.position.y
	var merlon = Vector2(lerpf(30.0, 14.0, zoom), lerpf(13.0, 7.0, zoom))
	var step_x = merlon.x * 2.0
	var x = band.position.x + radius
	var direction = 1.0 if not own else -1.0
	var shade = Color(tint.r * 0.42, tint.g * 0.42, tint.b * 0.42)
	while x + merlon.x < band.end.x - radius:
		var block = Rect2(Vector2(x, edge_y if not own else edge_y - merlon.y), merlon)
		draw_rect(Rect2(block.position + Vector2(0, 3 * direction), block.size), Color(0, 0, 0, 0.35))
		draw_rect(block, shade)
		draw_line(block.position, Vector2(block.end.x, block.position.y), Color(1, 1, 1, 0.08), 1.0)
		x += step_x
	draw_line(Vector2(band.position.x, edge_y), Vector2(band.end.x, edge_y), Color(0, 0, 0, 0.6), 2.0)
	UiKit.draw_vgradient(self, Rect2(band.position.x, band.position.y, band.size.x, band.size.y),
		Color(0, 0, 0, 0.0 if not own else 0.35), Color(0, 0, 0, 0.35 if not own else 0.0))

func _draw_river(table: Rect2) -> void:
	var center_y = river_y()
	var height = lerpf(38.0, 20.0, zoom)
	var band = Rect2(table.position.x + 2, center_y - height * 0.5, table.size.x - 4, height)
	UiKit.draw_vgradient(self, band, Color(0.08, 0.2, 0.23, 0.92), Color(0.03, 0.1, 0.13, 0.95))
	for wave in range(3):
		var points = PackedVector2Array()
		var y = band.position.y + band.size.y * (0.28 + wave * 0.22)
		var steps = 48
		for step in range(steps + 1):
			var x = band.position.x + band.size.x * float(step) / steps
			points.append(Vector2(x, y + sin(step * 0.7 + wave * 1.9 + lane_index) * height * 0.07))
		draw_polyline(points, Color(0.65, 0.9, 0.92, 0.16 - wave * 0.03), 1.4, true)
	draw_line(band.position, Vector2(band.end.x, band.position.y), Color(0.85, 0.75, 0.55, 0.35), 2.0)
	draw_line(Vector2(band.position.x, band.end.y), band.end, Color(0, 0, 0, 0.55), 2.0)
	var label = UiKit.t(LANE_KEYS[lane_index])
	var font = UiKit.title_font()
	var font_size = int(lerpf(21.0, 15.0, zoom))
	var text_width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var label_center = Vector2(band.position.x + lerpf(70.0, 12.0, zoom) + text_width * 0.5, center_y)
	UiKit.draw_text(self, font, label, label_center, font_size, Color(UiKit.GOLD_BRIGHT, 0.85 if active else 0.55), -1.0, 2)

func _draw_ghost_slots() -> void:
	for slot in ghost_slots:
		var rect = ghost_rect(slot)
		var hovered = int(slot.position) == hovered_slot
		UiKit.draw_round_rect(self, rect, Color(UiKit.PLAYABLE, 0.22 if hovered else 0.08), 8.0 * _scale,
			Color(UiKit.PLAYABLE, 0.95 if hovered else 0.6), 2.0)
		var center = rect.get_center()
		var arm = 16.0 * _scale
		draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), Color(UiKit.PLAYABLE, 0.9), 3.0)
		draw_line(center - Vector2(0, arm), center + Vector2(0, arm), Color(UiKit.PLAYABLE, 0.9), 3.0)

