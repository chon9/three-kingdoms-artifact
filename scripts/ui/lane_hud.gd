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
##
## Hovering any hero chip (fountain or lane, either side) shows that hero's
## card at hand size under the HUD, with its live stats and its status
## (ready, ready in N rounds, fallen, deploying, in a lane, about to fall);
## right-click inspects it (inspect_overlay.gd).

signal lane_pressed(index: int)
## Right-click on a hero chip: the card and its display model for the inspector.
signal inspect_requested(card_id: String, model: Dictionary)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const EventText = preload("res://scripts/core/event_text.gd")
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
## The board (board_view.gd): the stats of heroes in the fountain.
var board: Control
## The hovered hero chip's uid (-1 for none) and its hover card.
var hovered_uid: int = -1
var preview: HeroPreview

func _init() -> void:
	size = Vector2(FOUNTAIN_W + COLUMN_W * 3.0 + 8.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	preview = HeroPreview.new()
	preview.name = "HeroPreview"
	preview.visible = false
	add_child(preview)

func sync(new_view: Dictionary, new_viewer: int, lane_models: Array, focus_lane: int) -> void:
	view = new_view
	viewer = new_viewer
	models = lane_models
	camera_lane = focus_lane
	queue_redraw()
	if hovered_uid != -1:
		# The hovered hero may have moved, fallen or changed: refresh or hide.
		_show_preview(hovered_uid)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		set_hovered(int(hero_at(event.position).get("hero", {}).get("uid", -1)))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var column = int(floor((event.position.x - FOUNTAIN_W) / COLUMN_W))
			if column >= 0 and column <= 2:
				lane_pressed.emit(column)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var entry = hero_at(event.position)
			if not entry.is_empty():
				set_hovered(-1)
				inspect_requested.emit(str(entry.hero.get("card", "")), hero_model(entry))
				accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		set_hovered(-1)

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

## The chips of lane column `index`, both sides: [{"hero" (or {} for the
## "+N" chip, with "text"), "rect", "lane", "side", "dies"}].
func column_chips(index: int) -> Array:
	var result: Array = []
	if view.is_empty() or index < 0 or index >= view.lanes.size():
		return result
	var lane = view.lanes[index]
	var lane_models: Dictionary = models[index] if index < models.size() else {}
	var left = FOUNTAIN_W + index * COLUMN_W
	for side in range(2):
		var player = 1 - viewer if side == 0 else viewer
		var y = ROW_Y[side]
		var heroes: Array = []
		for unit in lane.units[player]:
			if unit != null and unit.get("hero", false):
				heroes.append(unit)
		var shown = heroes.size() if heroes.size() <= COLUMN_SLOTS else COLUMN_SLOTS - 1
		for slot in range(shown):
			var hero_rect = Rect2(left + 54.0 + slot * (CHIP.x + COL_CHIP_GAP), y - CHIP.y * 0.5, CHIP.x, CHIP.y)
			result.append({"hero": heroes[slot], "rect": hero_rect, "lane": index, "side": side,
				"dies": bool(lane_models.get(int(heroes[slot].uid), {}).get("dies", false))})
		if heroes.size() > COLUMN_SLOTS:
			var more = Rect2(left + 54.0 + shown * (CHIP.x + COL_CHIP_GAP), y - CHIP.y * 0.5, CHIP.x, CHIP.y)
			result.append({"hero": {}, "rect": more, "lane": index, "side": side, "dies": false, "text": "+%d" % (heroes.size() - shown)})
	return result

# --- Hero chips: hover card and inspect ----------------------------------------------

## Every hero chip drawn, fountain and lanes: [{"hero", "rect" (local), "lane"
## (-1 for the fountain), "side" (0 enemy, 1 own), "dies"}]. The "+N" chips
## stand for several heroes and are left out.
func hero_chips() -> Array:
	var result: Array = []
	if view.is_empty():
		return result
	var layout = fountain_layout()
	for side in range(2):
		for entry in layout[side]:
			if not entry.hero.is_empty():
				result.append({"hero": entry.hero, "rect": entry.rect, "lane": -1, "side": side, "dies": false})
	for index in range(3):
		for entry in column_chips(index):
			if not entry.hero.is_empty():
				result.append(entry)
	return result

## The hero chip under `point` (HUD-local), or {}.
func hero_at(point: Vector2) -> Dictionary:
	for entry in hero_chips():
		if entry.rect.grow(1.0).has_point(point):
			return entry
	return {}

## The chip entry showing hero `uid`, or {}.
func hero_entry(uid: int) -> Dictionary:
	for entry in hero_chips():
		if int(entry.hero.get("uid", -1)) == uid:
			return entry
	return {}

## Global centre of any hero chip (fountain or lane) showing `uid`, or (-1, -1).
func hero_chip_center(uid: int) -> Vector2:
	var entry = hero_entry(uid)
	return get_global_transform() * entry.rect.get_center() if not entry.is_empty() else Vector2(-1, -1)

## The display model of a chip's hero: the board's live model in a lane
## (stats, combat preview, statuses), its own stats with items at full
## health in the fountain.
func hero_model(entry: Dictionary) -> Dictionary:
	var hero: Dictionary = entry.hero
	var lane = int(entry.get("lane", -1))
	if lane >= 0 and lane < models.size():
		var model: Dictionary = models[lane].get(int(hero.get("uid", -1)), {})
		if not model.is_empty():
			return model
	if board != null and board.has_method("staged_model"):
		return board.staged_model(hero, int(entry.side) == 1)
	return {}

## True when a fountain hero came back from the field dead: it waits past its
## starting schedule (heroes 1-3 ready in round 1, then rounds 2 and 3) and
## the latest event about it still in the window is its death, not a return
## to the fountain.
func hero_fallen(hero: Dictionary, player: int) -> bool:
	var roster: Array = view.players[player].get("roster", [])
	var index = -1
	for position in range(roster.size()):
		if int(roster[position].get("uid", -2)) == int(hero.get("uid", -1)):
			index = position
	var scheduled = 1 if index < 3 else index - 1
	if int(hero.get("ready_round", 1)) <= scheduled:
		return false
	var events: Array = view.get("events", [])
	for back in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[back]
		if int(event.get("uid", -1)) != int(hero.get("uid", -1)):
			continue
		match str(event.get("k", "")):
			"death":
				return true
			"fountain":
				return false
	return true

## The hover card's texts for a chip: {"side", "where", "status", "tone"
## ("good", "bad" or ""), "ability" (its active ability and cooldown, or "")}.
func hero_status(entry: Dictionary) -> Dictionary:
	var hero: Dictionary = entry.hero
	var own = int(entry.side) == 1
	var player = viewer if own else 1 - viewer
	var result = {"side": UiKit.t("HUD_SIDE_OWN" if own else "HUD_SIDE_ENEMY"), "where": "", "status": "", "tone": "", "ability": ""}
	var card_id = str(hero.get("card", ""))
	if Library.has_active(card_id):
		var cooldown = int(hero.get("cooldown", 0))
		result.ability = UiKit.t("CARD_ABILITY_LINE", {"label": UiKit.t("CARD_ACTIVE_ABILITY"), "ability": EventText.ability_name(card_id)})
		result.ability += "  ·  " + (UiKit.t_n("HUD_COOLDOWN", cooldown) if cooldown > 0 else UiKit.t("HUD_READY"))
	var lane = int(entry.get("lane", -1))
	if lane >= 0:
		result.where = UiKit.t("FOUNTAIN_IN_LANE", {"lane": EventText.lane_name(lane)})
		var model = hero_model(entry)
		var lines: Array = []
		if int(model.get("damage", 0)) > 0:
			lines.append(UiKit.t("HUD_INCOMING_DAMAGE", {"n": int(model.damage)}))
		if bool(entry.get("dies", false)) or bool(model.get("dies", false)):
			lines.append(UiKit.t("HUD_WILL_DIE"))
			result.tone = "bad"
		result.status = "\n".join(lines)
		return result
	result.where = UiKit.t("TERM_FOUNTAIN")
	var wait = int(hero.get("ready_round", 1)) - int(view.get("round", 1))
	var lines: Array = []
	if hero_fallen(hero, player):
		lines.append(UiKit.t("HUD_HERO_FALLEN"))
		result.tone = "bad"
	if wait > 0:
		# Distinct from the ability cooldown line ("Ready in N rounds").
		lines.append(UiKit.t_n("HUD_HERO_DEPLOYS_IN", wait))
	else:
		var plans: Dictionary = view.players[viewer].get("plans", {}) if own else {}
		if plans.has(str(hero.get("uid", -1))):
			lines.append(UiKit.t("HUD_HERO_PLANNED", {"lane": EventText.lane_name(int(plans[str(hero.uid)]))}))
		else:
			lines.append(UiKit.t("FOUNTAIN_READY_NOW"))
		result.tone = "good"
	result.status = "\n".join(lines)
	return result

## Hovers hero `uid` (-1 for none): its chip gets a ring and its card shows
## under the HUD (also the test facade).
func set_hovered(uid: int) -> void:
	if uid == hovered_uid:
		return
	hovered_uid = uid
	_show_preview(uid)
	queue_redraw()

func _show_preview(uid: int) -> void:
	var entry = hero_entry(uid) if uid != -1 else {}
	if entry.is_empty():
		hovered_uid = -1
		preview.visible = false
		return
	var model = hero_model(entry)
	var values: Dictionary = {}
	if not model.is_empty():
		values = {"attack": int(model.get("attack", 0)), "armor": int(model.get("armor", 0)), "health": int(model.get("health", 0)),
			"max_health": int(model.get("max_health", 0)), "items": entry.hero.get("items", {})}
	preview.show_hero(str(entry.hero.get("card", "")), values, hero_status(entry))
	_place_preview(entry.rect)

## Under the HUD, starting near the chip, inside the viewport.
func _place_preview(chip: Rect2) -> void:
	preview.reset_size()
	var area = get_viewport_rect().size if is_inside_tree() else Vector2(1440, 900)
	var to_local = get_global_transform().affine_inverse()
	var top_left = to_local * Vector2.ZERO
	var bottom_right = to_local * area
	var x = clampf(chip.get_center().x - 40.0, top_left.x + 4.0, bottom_right.x - preview.size.x - 4.0)
	var y = HEIGHT + 6.0
	if y + preview.size.y > bottom_right.y - 4.0:
		y = maxf(top_left.y + 4.0, bottom_right.y - preview.size.y - 4.0)
	preview.position = Vector2(x, y)

## Re-renders the hover card after a language or card theme change.
func refresh_text() -> void:
	if hovered_uid != -1:
		_show_preview(hovered_uid)
	queue_redraw()

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
			if int(entry.hero.get("uid", -1)) == hovered_uid:
				_hover_ring(entry.rect)
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
	for entry in column_chips(index):
		if entry.hero.is_empty():
			_overflow_chip(entry.rect, entry.text)
			continue
		_hero_chip(entry.rect, entry.hero, entry.dies)
		if int(entry.hero.get("uid", -1)) == hovered_uid:
			_hover_ring(entry.rect)

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

## The hovered chip's gold ring.
func _hover_ring(rect: Rect2) -> void:
	UiKit.draw_round_rect(self, rect.grow(2.0), Color.TRANSPARENT, 4.0, UiKit.GOLD_BRIGHT, 2.0)

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

## The hover card: the hero's card face at hand size with its live stats,
## beside whose it is, where it is, its status and its rules text.
class HeroPreview:
	extends PanelContainer
	const UiKit = preload("res://scripts/ui/ui_kit.gd")
	const Library = preload("res://scripts/core/card_library.gd")
	const CardView = preload("res://scripts/ui/card_view.gd")
	const CARD = Vector2(180, 262)
	const TEXT_W = 196.0
	var card: Control
	var name_label: Label
	var where_label: Label
	var status_label: Label
	var text_label: Label
	var hint_label: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Above the card history and the panels drawn after the HUD.
		z_index = 40
		# Opaque: the lane's cards must not show through.
		add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.045, 0.05, 1.0), UiKit.GOLD_DARK, 6, 1, 10.0))
		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		add_child(row)
		card = CardView.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.set_size_keep(CARD)
		card.custom_minimum_size = CARD
		row.add_child(card)
		var column = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.custom_minimum_size.x = TEXT_W
		column.add_theme_constant_override("separation", 6)
		row.add_child(column)
		name_label = _label(column, 22, UiKit.GOLD_BRIGHT)
		name_label.add_theme_font_override("font", UiKit.title_font())
		where_label = _label(column, 14, UiKit.PAPER_DIM)
		status_label = _label(column, 16, UiKit.PAPER)
		status_label.add_theme_font_override("font", UiKit.bold_font())
		text_label = _label(column, 14, UiKit.PAPER)
		var spacer = Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(spacer)
		hint_label = _label(column, 12, UiKit.MUTED)

	func _label(parent: Control, font_size: int, color: Color) -> Label:
		var result = Label.new()
		result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		result.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.custom_minimum_size.x = TEXT_W
		result.add_theme_font_size_override("font_size", font_size)
		result.add_theme_color_override("font_color", color)
		parent.add_child(result)
		return result

	## Shows `card_id` with `values` (live stats; {} for the printed ones)
	## and `status` (lane_hud.gd hero_status).
	func show_hero(card_id: String, values: Dictionary, status: Dictionary) -> void:
		card.setup(card_id, values)
		card.set_size_keep(CARD)
		name_label.text = Library.loc(card_id)
		where_label.text = "%s  ·  %s" % [status.get("side", ""), status.get("where", "")]
		status_label.text = str(status.get("status", ""))
		status_label.visible = not status_label.text.is_empty()
		match str(status.get("tone", "")):
			"good":
				status_label.add_theme_color_override("font_color", UiKit.HEAL)
			"bad":
				status_label.add_theme_color_override("font_color", UiKit.DAMAGE.lightened(0.2))
			_:
				status_label.add_theme_color_override("font_color", UiKit.PAPER)
		# Its active ability and cooldown, and the rules text when the card
		# face has no text box (a hero without abilities says so).
		var lines: Array = []
		if not str(status.get("ability", "")).is_empty():
			lines.append(str(status.ability))
		if not card._layout().has_text:
			lines.append(Library.loc(card_id, "text"))
		text_label.text = "\n".join(lines.filter(func(line): return not line.is_empty()))
		text_label.visible = not text_label.text.is_empty()
		hint_label.text = UiKit.t("HUD_HERO_INSPECT")
		visible = true
		reset_size()

	## The texts shown (tests read them).
	func shown_text() -> String:
		var lines: Array = [name_label.text, where_label.text]
		if status_label.visible:
			lines.append(status_label.text)
		lines.append(hint_label.text)
		return "\n".join(lines)
