extends Control
## Deployment: the board shows all three lanes with this round's creep
## assignments as ghost cards for both players, and the viewer's planned
## heroes as ghosts in their lanes. Ready heroes wait in a tray as hero
## cards: drag one onto a lane (the lane lights up), or click a hero and then
## a lane. The initiative coin confirms; both sides reveal together.

signal deploy_requested(uid: int, lane: int)
signal inspect_requested(card_id: String)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const CARD_SIZE = Vector2(128, 186)
const TRAY_HEIGHT = 250.0

var board: Control
var tray: Control
var hero_cards: Array = []
var title_label: Label
var hint_label: Label
var info_label: Label
var dragging: Control = null
var selected: Control = null
var enabled: bool = true
var _press_point: Vector2 = Vector2.ZERO
var _moved: bool = false
var _grab_offset: Vector2 = Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	tray = Tray.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)
	title_label = _label(24, UiKit.GOLD_BRIGHT, true)
	hint_label = _label(16, UiKit.PAPER_DIM, false)
	info_label = _label(15, UiKit.PAPER_DIM, false)
	for label in [title_label, hint_label, info_label]:
		tray.add_child(label)

func _label(font_size: int, color: Color, title: bool) -> Label:
	var label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title:
		label.add_theme_font_override("font", UiKit.title_font())
	return label

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()

func _place() -> void:
	var content = hero_cards.size() * (CARD_SIZE.x + 24.0) + 140.0
	tray.size = Vector2(clampf(content, 560.0, minf(size.x - 420.0, 980.0)), TRAY_HEIGHT)
	tray.position = Vector2((size.x - tray.size.x) * 0.5 - 30.0, size.y - TRAY_HEIGHT - 96.0)
	title_label.position = Vector2(0, 8)
	title_label.size = Vector2(tray.size.x, 32)
	hint_label.position = Vector2(0, 38)
	hint_label.size = Vector2(tray.size.x, 24)
	info_label.position = Vector2(0, TRAY_HEIGHT - 4)
	info_label.size = Vector2(tray.size.x, 24)
	_layout_cards(false)

## Updates the tray from the viewer's roster and the board ghosts from the
## pending creeps and the viewer's plans. `spent_text` reports the
## opponent's shopping (public). Hero cards are kept by uid, so a hero being
## dragged or selected survives states published meanwhile (the opponent
## planning its own deployment).
func sync(view: Dictionary, viewer: int, actions: Array, spent_text: String) -> void:
	var previous: Dictionary = {}
	for card in hero_cards:
		if is_instance_valid(card):
			previous[int(card.get_meta("uid"))] = card
	var kept: Array = []
	var deployable: Dictionary = {}
	for action in actions:
		if action.get("type", "") == "deploy":
			deployable[int(action.unit)] = true
	var player = view.players[viewer]
	var plans: Dictionary = player.get("plans", {})
	var waiting: Array = []
	for hero in player.get("roster", []):
		var uid = int(hero.uid)
		if deployable.has(uid):
			var card: Control = previous.get(uid)
			previous.erase(uid)
			if card == null:
				card = CardView.new()
				card.set_meta("uid", uid)
				card.mouse_default_cursor_shape = Control.CURSOR_DRAG
				card.gui_input.connect(_on_card_input.bind(card))
				tray.add_child(card)
			card.setup(str(hero.card), {"items": hero.get("items", {}), "health": int(hero.health), "max_health": int(hero.max_health)})
			card.set_size_keep(CARD_SIZE)
			card.playable = enabled
			kept.append(card)
		elif int(hero.get("lane", -1)) == -1 and not plans.has(str(uid)):
			waiting.append(Library.loc(str(hero.card)) + " · " + UiKit.t("FOUNTAIN_READY_ROUND", {"n": int(hero.ready_round)}))
	# Ghosts: pending creeps for both sides and this player's planned heroes.
	var pending: Array = view.get("pending_creeps", [[], []])
	for lane_index in range(3):
		var enemy_ids: Array = []
		var own_ids: Array = []
		for lane_value in pending[1 - viewer]:
			if int(lane_value) == lane_index:
				enemy_ids.append("melee_creep")
		for lane_value in pending[viewer]:
			if int(lane_value) == lane_index:
				own_ids.append("melee_creep")
		for hero in player.get("roster", []):
			if int(plans.get(str(hero.uid), -1)) == lane_index:
				own_ids.append(str(hero.card))
		board.lanes[lane_index].set_incoming(enemy_ids, own_ids)
	for uid in previous:
		UiKit.discard(previous[uid])
	hero_cards = kept
	if dragging != null and (not enabled or not hero_cards.has(dragging)):
		dragging = null
		_set_drop_cues(-1, false)
	if selected != null and (not enabled or not hero_cards.has(selected)):
		selected = null
		_set_drop_cues(-1, false)
	for card in hero_cards:
		card.selected = card == selected
	var lines: Array = []
	if not waiting.is_empty():
		lines.append(UiKit.t("LIST_SEPARATOR").join(waiting))
	if not spent_text.is_empty():
		lines.append(spent_text)
	info_label.text = "   ·   ".join(lines)
	refresh_text()
	_place()

func refresh_text() -> void:
	title_label.text = UiKit.t("DEPLOY_READY_HEROES") if not hero_cards.is_empty() else UiKit.t("DEPLOY_TITLE")
	hint_label.text = UiKit.t("DEPLOY_DRAG_HINT") if not hero_cards.is_empty() else UiKit.t("DEPLOY_HIDDEN")
	for card in hero_cards:
		card.refresh()

func open() -> void:
	visible = true
	_place()

func close() -> void:
	visible = false
	dragging = null
	selected = null
	if board != null:
		for lane in board.lanes:
			lane.set_incoming([], [])
			lane.drop_state = 0
			lane.queue_redraw()

func _layout_cards(animate: bool) -> void:
	var count = hero_cards.size()
	var spacing = CARD_SIZE.x + 24.0
	var left = (tray.size.x - (count * spacing - 24.0)) * 0.5
	for index in range(count):
		var card: Control = hero_cards[index]
		if card == dragging:
			continue
		var target = Vector2(left + index * spacing, 64.0 - (12.0 if card == selected else 0.0))
		if animate and not AnimationQueue.instant:
			card.create_tween().tween_property(card, "position", target, AnimationQueue.duration(0.2))
		else:
			card.position = target

func hero_card(uid: int) -> Control:
	for card in hero_cards:
		if int(card.get_meta("uid")) == uid:
			return card
	return null

## Click-to-deploy fallback: with a hero selected, a click on a lane deploys.
func handle_board_click(global_point: Vector2) -> bool:
	if selected == null or board == null:
		return false
	var lane = board.lane_at(global_point)
	if lane == -1:
		return false
	var uid = int(selected.get_meta("uid"))
	selected = null
	_set_drop_cues(-1, false)
	deploy_requested.emit(uid, lane)
	return true

func select_hero(uid: int) -> void:
	selected = hero_card(uid)
	for card in hero_cards:
		card.selected = card == selected
		card.queue_redraw()
	_set_drop_cues(-1, selected != null)
	_layout_cards(true)

func _on_card_input(event: InputEvent, card: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		inspect_requested.emit(card.card_id)
		accept_event()
		return
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var press_point = card.get_global_transform() * event.position
		if event.pressed:
			dragging = card
			_press_point = press_point
			_moved = false
			_grab_offset = card.get_global_transform().affine_inverse() * _press_point
			card.move_to_front()
			accept_event()
		elif dragging == card:
			var point = press_point
			dragging = null
			if _moved:
				var lane = board.lane_at(point) if board != null else -1
				_set_drop_cues(-1, false)
				if lane != -1:
					deploy_requested.emit(int(card.get_meta("uid")), lane)
				# Back into the tray unless the deploy removed it.
				_layout_cards(true)
			else:
				select_hero(int(card.get_meta("uid")) if selected != card else -1)
			accept_event()
	elif event is InputEventMouseMotion and dragging == card:
		var point = card.get_global_transform() * event.position
		if not _moved and point.distance_to(_press_point) > 8.0:
			_moved = true
			selected = null
		if _moved:
			card.position = tray.get_global_transform().affine_inverse() * point - _grab_offset
			var lane = board.lane_at(point) if board != null else -1
			_set_drop_cues(lane, true)
		accept_event()

func _set_drop_cues(hovered_lane: int, active: bool) -> void:
	if board == null:
		return
	for index in range(3):
		var lane = board.lanes[index]
		lane.drop_state = 0 if not active else (2 if index == hovered_lane else 1)
		lane.queue_redraw()

## The tray: a lacquered strip with gold trim that holds the ready heroes.
class Tray:
	extends Control

	func _draw() -> void:
		var rect = Rect2(Vector2.ZERO, size)
		draw_colored_polygon(UiKit.round_rect_points(Rect2(rect.position + Vector2(0, 8), rect.size), 14.0), Color(0, 0, 0, 0.5))
		UiKit.draw_round_rect(self, rect, Color(0.05, 0.05, 0.06, 0.9), 14.0, Color(UiKit.GOLD_DARK, 0.95), 2.0)
		UiKit.draw_ornate(self, rect.grow(-6), 13, Color(UiKit.GOLD, 0.6), 26.0)
