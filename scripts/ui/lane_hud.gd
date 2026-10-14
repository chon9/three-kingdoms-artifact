extends Control
## The lane overview HUD in the top-left corner, after Classic's: a fountain
## column (heroes waiting to deploy, with countdowns), then one column per
## lane with both towers' health and the heroes in that lane. The active lane
## is boxed with its phase; the next column shows who holds initiative.
## Heroes and towers about to fall carry a red cross. Click a column to look
## at that lane.

signal lane_pressed(index: int)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const FOUNTAIN_W = 96.0
const COLUMN_W = 140.0
const HEIGHT = 118.0

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

func _draw() -> void:
	if view.is_empty():
		return
	var panel = Rect2(Vector2.ZERO, size)
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
			center = Vector2(FOUNTAIN_W + column * COLUMN_W + COLUMN_W * 0.5, HEIGHT - 13)
		else:
			center = Vector2(FOUNTAIN_W * 0.5, HEIGHT - 13)
		UiKit.draw_text(self, UiKit.body_font(), label, center, 13, UiKit.ALLY_TINT.lightened(0.3) if holder == viewer else UiKit.ENEMY_TINT.lightened(0.3), COLUMN_W - 8)

func _draw_fountain() -> void:
	var round_text = UiKit.t("ROUND_N", {"n": int(view.round)})
	UiKit.draw_text(self, UiKit.title_font(), round_text, Vector2(FOUNTAIN_W * 0.5, 14), 16, UiKit.GOLD_BRIGHT, FOUNTAIN_W - 8)
	for side in range(2):
		var player = 1 - viewer if side == 0 else viewer
		var y = 40.0 if side == 0 else 72.0
		var x = 8.0
		for hero in view.players[player].get("roster", []):
			if int(hero.get("lane", -1)) != -1:
				continue
			var rect = Rect2(x, y - 12, 24, 24)
			_hero_square(rect, hero, false)
			var wait = int(hero.get("ready_round", 1)) - int(view.round)
			if wait <= 0:
				_check(rect.end + Vector2(-4, -3))
			else:
				UiKit.draw_text(self, UiKit.bold_font(), "-%d" % wait, rect.get_center() + Vector2(0, 17), 11, UiKit.PAPER_DIM)
			x += 28.0
			if x > FOUNTAIN_W - 24:
				break
	draw_line(Vector2(FOUNTAIN_W - 1, 8), Vector2(FOUNTAIN_W - 1, HEIGHT - 8), Color(1, 1, 1, 0.08), 1.0)

func _draw_column(index: int, rect: Rect2, active: bool) -> void:
	if active:
		var box = rect.grow(-3)
		UiKit.draw_round_rect(self, box, Color(UiKit.GOLD, 0.1), 5.0, Color(UiKit.GOLD, 0.9), 1.5)
		var phase_key = "PHASE_COMBAT" if combat_lane == index else "PHASE_ACTION"
		UiKit.draw_text(self, UiKit.body_font(), UiKit.t(phase_key), Vector2(rect.get_center().x, rect.end.y - 13), 13, UiKit.GOLD_BRIGHT, COLUMN_W - 10)
	elif combat_lane == index:
		UiKit.draw_text(self, UiKit.body_font(), UiKit.t("PHASE_COMBAT"), Vector2(rect.get_center().x, rect.end.y - 13), 13, UiKit.GOLD_BRIGHT, COLUMN_W - 10)
	if index == camera_lane:
		draw_line(Vector2(rect.position.x + 22, rect.position.y + 3), Vector2(rect.end.x - 22, rect.position.y + 3), Color(1, 1, 1, 0.6), 2.0)
	var lane = view.lanes[index]
	var lane_models: Dictionary = models[index] if index < models.size() else {}
	var pending: Array = lane_models.get("tower_damage", [0, 0])
	for side in range(2):
		var player = 1 - viewer if side == 0 else viewer
		var y = rect.position.y + (26.0 if side == 0 else 60.0)
		var structure = lane.structures[player]
		var icon_rect = Rect2(rect.position.x + 8, y - 11, 22, 22)
		var tint = UiKit.ENEMY_TINT if side == 0 else UiKit.ALLY_TINT
		UiKit.draw_icon(self, "crown_b" if structure.get("ancient", false) else "structure_tower", icon_rect, tint.lightened(0.15))
		var damage = int(pending[1] if side == 0 else pending[0])
		if damage > 0 and damage >= int(structure.health):
			_cross(icon_rect.get_center(), 10.0)
		UiKit.draw_text_left(self, UiKit.bold_font(), str(int(structure.health)), Vector2(rect.position.x + 32, y), 19, UiKit.PAPER, -1.0, 2)
		var x = rect.position.x + 70.0
		for unit in lane.units[player]:
			if unit == null or not unit.get("hero", false):
				continue
			var hero_rect = Rect2(x, y - 12, 24, 24)
			_hero_square(hero_rect, unit, lane_models.get(int(unit.uid), {}).get("dies", false))
			x += 27.0
			if x > rect.end.x - 18:
				break

## A hero portrait (art cropped to the face, or the name's first character).
func _hero_square(rect: Rect2, hero: Dictionary, dies: bool) -> void:
	var card_id = str(hero.get("card", ""))
	var color = UiKit.card_color(str(hero.get("color", "neutral")))
	UiKit.draw_round_rect(self, rect, color, 3.0)
	if not CardArt.draw_portrait(self, rect.grow(-1.5), card_id):
		UiKit.draw_text(self, UiKit.title_font(), Library.loc(card_id).left(1), rect.get_center(), int(rect.size.y * 0.72), UiKit.PAPER)
	UiKit.draw_round_rect(self, rect, Color.TRANSPARENT, 3.0, color.lightened(0.35), 1.5)
	if dies:
		_cross(rect.get_center(), rect.size.x * 0.5)

func _cross(center: Vector2, arm: float) -> void:
	draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), Color("e2332a"), 3.0, true)
	draw_line(center + Vector2(arm, -arm), center + Vector2(-arm, arm), Color("e2332a"), 3.0, true)

func _check(at: Vector2) -> void:
	draw_polyline(PackedVector2Array([at + Vector2(-5, 0), at + Vector2(-1, 4), at + Vector2(6, -5)]), UiKit.HEAL, 2.5, true)
