extends Control
## The lane overview HUD in the top-left corner, after Classic's: a fountain
## column (heroes waiting to deploy), then one column per lane with both
## towers' health and the heroes in that lane. The active lane is boxed with
## its phase; the next column shows who holds initiative. Heroes and towers
## about to fall carry a red cross. Click a column to look at that lane.
##
## Fountain: the enemy's heroes on the upper row, yours on the lower row, as
## small portrait chips. Each chip's status sits on its own line (above the
## enemy row, below yours), never on the chip: a check when the hero is
## ready, "-N" rounds when it is not, and for your planned heroes three lane
## dots with the chosen lane lit.

signal lane_pressed(index: int)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const FOUNTAIN_W = 140.0
const COLUMN_W = 132.0
const HEIGHT = 124.0
## Portrait chip, taller than wide like Classic's.
const CHIP = Vector2(20, 28)
## Fountain chip pitch is CHIP.x + CHIP_GAP; lane columns use COL_CHIP_GAP.
const CHIP_GAP = 6.0
const COL_CHIP_GAP = 4.0
## Chip and tower row centres: [enemy, own].
const ROW_Y = [34.0, 72.0]
## Fountain status line centres: above the enemy chips, below your chips.
const STATUS_Y = [11.0, 96.0]
## Phase and initiative label centre line.
const LABEL_Y = HEIGHT - 11.0
const FOUNTAIN_SLOTS = 5
const COLUMN_SLOTS = 3

var view: Dictionary = {}
var viewer: int = 0
var models: Array = [{}, {}, {}]
var camera_lane: int = 0
## Lane whose combat is playing (-1 for none).
var combat_lane: int = -1

func _init() -> void:
	size = Vector2(FOUNTAIN_W + COLUMN_W * 3.0 + 8.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func sync(new_view: Dictionary, new_viewer: int, lane_models: Array, focus_lane: int) -> void:
	view = new_view
	viewer = new_viewer
	models = lane_models
	camera_lane = focus_lane
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var column = int(floor((event.position.x - FOUNTAIN_W) / COLUMN_W))
		if column >= 0 and column <= 2:
			lane_pressed.emit(column)
		accept_event()

# --- Fountain layout (also the test facade) -------------------------------------

## Heroes of `player` in the fountain: ready ones first, then by the round
## they become ready, then in roster order.
func fountain_heroes(player: int) -> Array:
	var entries: Array = []
	var roster: Array = view.players[player].get("roster", [])
	for index in range(roster.size()):
		var hero: Dictionary = roster[index]
		if int(hero.get("lane", -1)) == -1:
			entries.append([hero, index])
	var round_now = int(view.get("round", 1))
	entries.sort_custom(func(a, b):
		var ready_a = int(a[0].get("ready_round", 1)) <= round_now
		var ready_b = int(b[0].get("ready_round", 1)) <= round_now
		if ready_a != ready_b:
			return ready_a
		if int(a[0].get("ready_round", 1)) != int(b[0].get("ready_round", 1)):
			return int(a[0].get("ready_round", 1)) < int(b[0].get("ready_round", 1))
		return a[1] < b[1])
	return entries.map(func(entry): return entry[0])

## Per side [enemy, own]: the chips drawn in the fountain, each {"hero" (or
## {} for the "+N" overflow chip), "rect", "status" ("check", "wait",
## "dots" or ""), "text", "status_rect"}.
func fountain_layout() -> Array:
	var result: Array = [[], []]
	if view.is_empty():
		return result
	var plans: Dictionary = view.players[viewer].get("plans", {})
	for side in range(2):
		var player = 1 - viewer if side == 0 else viewer
		var heroes = fountain_heroes(player)
		var shown = mini(heroes.size(), FOUNTAIN_SLOTS)
		for index in range(shown):
			var rect = Rect2(8.0 + index * (CHIP.x + CHIP_GAP), ROW_Y[side] - CHIP.y * 0.5, CHIP.x, CHIP.y)
			if index == FOUNTAIN_SLOTS - 1 and heroes.size() > FOUNTAIN_SLOTS:
				result[side].append({"hero": {}, "rect": rect, "status": "", "text": "+%d" % (heroes.size() - index),
					"status_rect": Rect2()})
				break
			var hero: Dictionary = heroes[index]
			var center = Vector2(rect.get_center().x, STATUS_Y[side])
			var wait = int(hero.get("ready_round", 1)) - int(view.get("round", 1))
			var entry = {"hero": hero, "rect": rect, "status": "check", "text": "",
				"status_rect": Rect2(center - Vector2(5.5, 5.0), Vector2(12, 10))}
			if wait > 0:
				entry.status = "wait"
				entry.text = "-%d" % wait
				var width = UiKit.bold_font().get_string_size(entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				entry.status_rect = Rect2(center - Vector2(width * 0.5, 6.0), Vector2(width, 12))
			elif side == 1 and plans.has(str(hero.get("uid", -1))):
				entry.status = "dots"
				entry.lane = int(plans[str(hero.uid)])
				entry.status_rect = Rect2(center - Vector2(9, 2), Vector2(18, 4))
			result[side].append(entry)
	return result

## Chip and status rectangles per side, for layout checks:
## {"chips": [[Rect2, ...], [...]], "status": [[Rect2, ...], [...]]}.
func fountain_rects() -> Dictionary:
	var result = {"chips": [[], []], "status": [[], []]}
	var layout = fountain_layout()
	for side in range(2):
		for entry in layout[side]:
			result.chips[side].append(entry.rect)
			if entry.status_rect.size != Vector2.ZERO:
				result.status[side].append(entry.status_rect)
	return result

## Global centre of the fountain chip showing hero `uid`, or (-1, -1).
func chip_center(uid: int) -> Vector2:
	for side_entries in fountain_layout():
		for entry in side_entries:
			if not entry.hero.is_empty() and int(entry.hero.get("uid", -1)) == uid:
				return get_global_transform() * entry.rect.get_center()
	return Vector2(-1, -1)

# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	if view.is_empty():
		return
	var points = PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y - 14), Vector2(size.x - 14, size.y), Vector2(0, size.y)])
	draw_colored_polygon(points, Color(0.04, 0.045, 0.05, 0.86))
	draw_polyline(PackedVector2Array([Vector2(size.x, 0), Vector2(size.x, size.y - 14), Vector2(size.x - 14, size.y), Vector2(0, size.y)]), Color(UiKit.GOLD_DARK, 0.9), 2.0, true)
	_draw_fountain()
	var active_lane = int(view.lane) if view.phase == "action" else -1
	for index in range(3):
		_draw_column(index, Rect2(FOUNTAIN_W + index * COLUMN_W, 0, COLUMN_W, HEIGHT), index == active_lane)
	# Initiative caret: next to the active lane (or the fountain after lane 3).
	if view.phase == "action":
		var holder = int(view.first_pass) if int(view.get("first_pass", -1)) != -1 else int(view.active_player)
		var caret = "▲" if holder == viewer else "▼"
		var label = UiKit.t("TERM_INITIATIVE") + " " + caret
		var column = active_lane + 1
		var center: Vector2
		if column <= 2:
			center = Vector2(FOUNTAIN_W + column * COLUMN_W + COLUMN_W * 0.5, LABEL_Y)
		else:
			center = Vector2(FOUNTAIN_W * 0.5, LABEL_Y)
		UiKit.draw_text(self, UiKit.body_font(), label, center, 13, UiKit.ALLY_TINT.lightened(0.3) if holder == viewer else UiKit.ENEMY_TINT.lightened(0.3), COLUMN_W - 8)

func _draw_fountain() -> void:
	draw_rect(Rect2(0, 0, FOUNTAIN_W, HEIGHT - 1), Color(1, 1, 1, 0.035))
	for side_entries in fountain_layout():
		for entry in side_entries:
			if entry.hero.is_empty():
				_overflow_chip(entry.rect, entry.text)
				continue
			_hero_chip(entry.rect, entry.hero, false)
			var center = Vector2(entry.status_rect.get_center().x, entry.status_rect.get_center().y)
			match str(entry.status):
				"wait":
					UiKit.draw_text(self, UiKit.bold_font(), entry.text, center, 12, UiKit.PAPER_DIM)
				"dots":
					_lane_dots(center, int(entry.lane))
				_:
					_check(center + Vector2(-0.5, 0.5))
	draw_line(Vector2(FOUNTAIN_W - 1, 8), Vector2(FOUNTAIN_W - 1, HEIGHT - 8), Color(1, 1, 1, 0.08), 1.0)

func _draw_column(index: int, rect: Rect2, active: bool) -> void:
	if active:
		var box = rect.grow(-3)
		UiKit.draw_round_rect(self, box, Color(UiKit.GOLD, 0.1), 5.0, Color(UiKit.GOLD, 0.9), 1.5)
		var phase_key = "PHASE_COMBAT" if combat_lane == index else "PHASE_ACTION"
		UiKit.draw_text(self, UiKit.body_font(), UiKit.t(phase_key), Vector2(rect.get_center().x, LABEL_Y), 13, UiKit.GOLD_BRIGHT, COLUMN_W - 10)
	elif combat_lane == index:
		UiKit.draw_text(self, UiKit.body_font(), UiKit.t("PHASE_COMBAT"), Vector2(rect.get_center().x, LABEL_Y), 13, UiKit.GOLD_BRIGHT, COLUMN_W - 10)
	if index == camera_lane:
		draw_line(Vector2(rect.position.x + 22, rect.position.y + 3), Vector2(rect.end.x - 22, rect.position.y + 3), Color(1, 1, 1, 0.6), 2.0)
	var lane = view.lanes[index]
	var lane_models: Dictionary = models[index] if index < models.size() else {}
	var pending: Array = lane_models.get("tower_damage", [0, 0])
	for side in range(2):
		var player = 1 - viewer if side == 0 else viewer
		var y = rect.position.y + ROW_Y[side]
		var structure = lane.structures[player]
		var icon_rect = Rect2(rect.position.x + 6, y - 9, 18, 18)
		var tint = UiKit.ENEMY_TINT if side == 0 else UiKit.ALLY_TINT
		UiKit.draw_icon(self, "crown_b" if structure.get("ancient", false) else "structure_tower", icon_rect, tint.lightened(0.15))
		var damage = int(pending[1] if side == 0 else pending[0])
		if damage > 0 and damage >= int(structure.health):
			_cross(icon_rect.get_center(), 9.0)
		UiKit.draw_text_left(self, UiKit.bold_font(), str(int(structure.health)), Vector2(rect.position.x + 26, y), 18, UiKit.PAPER, -1.0, 2)
		var heroes: Array = []
		for unit in lane.units[player]:
			if unit != null and unit.get("hero", false):
				heroes.append(unit)
		var shown = heroes.size() if heroes.size() <= COLUMN_SLOTS else COLUMN_SLOTS - 1
		for slot in range(shown):
			var hero_rect = Rect2(rect.position.x + 54.0 + slot * (CHIP.x + COL_CHIP_GAP), y - CHIP.y * 0.5, CHIP.x, CHIP.y)
			_hero_chip(hero_rect, heroes[slot], lane_models.get(int(heroes[slot].uid), {}).get("dies", false))
		if heroes.size() > COLUMN_SLOTS:
			var more = Rect2(rect.position.x + 54.0 + shown * (CHIP.x + COL_CHIP_GAP), y - CHIP.y * 0.5, CHIP.x, CHIP.y)
			_overflow_chip(more, "+%d" % (heroes.size() - shown))

## A hero portrait chip: the art cropped to the face inside a 2 px frame in
## the hero's colour (or the name's first character without art).
func _hero_chip(rect: Rect2, hero: Dictionary, dies: bool) -> void:
	var card_id = str(hero.get("card", ""))
	var color = UiKit.card_color(str(hero.get("color", "neutral")))
	UiKit.draw_round_rect(self, rect, color, 3.0)
	if not CardArt.draw_portrait(self, rect.grow(-2.0), card_id):
		UiKit.draw_text(self, UiKit.title_font(), Library.loc(card_id).left(1), rect.get_center(), 14, UiKit.PAPER)
	UiKit.draw_round_rect(self, rect, Color.TRANSPARENT, 3.0, color.lightened(0.35), 1.0)
	if dies:
		_cross(rect.get_center(), rect.size.x * 0.5)

## The "+N" chip that stands in for heroes that do not fit.
func _overflow_chip(rect: Rect2, text: String) -> void:
	UiKit.draw_round_rect(self, rect, Color(0.16, 0.16, 0.17), 3.0, Color(1, 1, 1, 0.3), 1.0)
	UiKit.draw_text(self, UiKit.bold_font(), text, rect.get_center(), 12, UiKit.PAPER, rect.size.x)

## Three lane dots under a planned hero; the planned lane is lit.
func _lane_dots(center: Vector2, lane: int) -> void:
	for index in range(3):
		var dot = center + Vector2(-7.0 + index * 7.0, 0)
		draw_circle(dot, 2.0, UiKit.PLAYABLE if index == lane else Color(1, 1, 1, 0.25))

func _cross(center: Vector2, arm: float) -> void:
	draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), Color("e2332a"), 3.0, true)
	draw_line(center + Vector2(arm, -arm), center + Vector2(-arm, arm), Color("e2332a"), 3.0, true)

func _check(at: Vector2) -> void:
	draw_polyline(PackedVector2Array([at + Vector2(-5, 0), at + Vector2(-1, 4), at + Vector2(6, -5)]), UiKit.HEAL, 2.5, true)
