extends Control
## Deployment: the board shows all three lanes. Units entering a lane float
## in that lane's staging strip on its left (yours bottom-left, the enemy's
## top-left), never in a combat position: this round's creeps for both
## players and your planned heroes. The opponent's planned heroes stay
## hidden; its ready heroes are shown face up in a strip at the top centre.
##
## Ready heroes wait in the tray (the camp). Drag one onto a lane to plan it
## (the lanes light up), drag a planned hero to another lane to re-plan it,
## or back onto the tray to take it back. Click a hero, then a lane or the
## tray, does the same. Right-click inspects. The initiative coin confirms;
## after that nothing moves, and both sides reveal together.

signal deploy_requested(uid: int, lane: int)
signal undeploy_requested(uid: int)
signal inspect_requested(card_id: String)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const UnitCard = preload("res://scripts/ui/unit_card.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const LaneView = preload("res://scripts/ui/lane_view.gd")
const CARD_SIZE = Vector2(128, 186)
const TRAY_HEIGHT = 250.0
const TRAY_COLLAPSED = 64.0
const TRAY_COLLAPSED_WIDTH = 420.0
## Top of the tray's hero cards: under the title and hint, clear of the
## frame at the bottom.
const CARD_TOP = 56.0
## Opponent strip: card scale, card pitch and top edge.
const STRIP_SCALE = 0.36
const STRIP_SPACING = 50.0
const STRIP_TOP = 64.0
const DRAG_START = 8.0
const PROXY_SCALE = 0.9
## Seconds a drop waits for the state that confirms it (online latency).
const PENDING_TIMEOUT = 2.0
const CAMP_ART = "res://assets/art/ui/camp_fountain.png"

var board: Control
var tray: Control
var hero_cards: Array = []
var title_label: Label
var hint_label: Label
var info_label: Label
var opponent_strip: Control
## Centre x for the opponent strip (the enemy hand pile); the match screen sets it.
var strip_center_x: float = -1.0
## Tray hero being dragged (a CardView), or null.
var dragging: Control = null
## Hero picked by a click (tray or staged), -1 for none.
var selected_uid: int = -1
var enabled: bool = true
var view: Dictionary = {}
var viewer: int = 0
var actions: Array = []
var _press_point: Vector2 = Vector2.ZERO
var _moved: bool = false
var _grab_offset: Vector2 = Vector2.ZERO
## Staged hero being dragged: {uid, key, from_lane, press, moved, grab, proxy}.
var _staged_drag: Dictionary = {}
## uid -> global point of this client's latest drop (the new card flies from there).
var _last_drop: Dictionary = {}
## uid -> {proxy, target (lane, or -1 for the tray), key, from_lane, time}:
## drops waiting for the state that applies them.
var _pending: Dictionary = {}
var _strip_cards: Dictionary = {}
## Tray collapse progress (0 open, 1 collapsed), its target and tween.
var _collapse: float = 0.0
var _collapse_target: float = -1.0
var _collapse_tween: Tween
var _revealing: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	tray = Tray.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)
	title_label = _label(24, UiKit.GOLD_BRIGHT, true)
	hint_label = _label(16, UiKit.PAPER, false)
	info_label = _label(15, UiKit.PAPER_DIM, false)
	for label in [title_label, hint_label, info_label]:
		tray.add_child(label)
	opponent_strip = Strip.new()
	opponent_strip.name = "OpponentStrip"
	opponent_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(opponent_strip)
	set_process(false)

func _label(font_size: int, color: Color, title: bool) -> Label:
	var label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title:
		label.add_theme_font_override("font", UiKit.title_font())
	return label

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()

# --- Layout ----------------------------------------------------------------------

## Tray rectangle (overlay-local) for collapse progress `collapse` (0 open
## with heroes, 1 a thin strip once every hero is planned).
func tray_rect(collapse: float) -> Rect2:
	var content = hero_cards.size() * (CARD_SIZE.x + 24.0) + 140.0
	var open_size = Vector2(clampf(content, 560.0, minf(size.x - 420.0, 980.0)), TRAY_HEIGHT)
	var tray_size = open_size.lerp(Vector2(_collapsed_width(), TRAY_COLLAPSED), collapse)
	return Rect2(Vector2((size.x - tray_size.x) * 0.5 - 30.0, size.y - TRAY_HEIGHT - 96.0), tray_size)

## Width of the collapsed tray: wide enough for the longest line it shows.
func _collapsed_width() -> float:
	var font = UiKit.body_font()
	var widest = 0.0
	for key in ["DEPLOY_ALL_ASSIGNED", "DEPLOY_WAITING", "DEPLOY_UNASSIGN_HINT", "DEPLOY_HIDDEN"]:
		widest = maxf(widest, font.get_string_size(UiKit.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	return minf(maxf(widest + 56.0, TRAY_COLLAPSED_WIDTH), maxf(TRAY_COLLAPSED_WIDTH, size.x - 420.0))

func _place() -> void:
	# The tray collapses to a thin strip once every ready hero is planned
	# (animated; the first layout after open() snaps).
	var target = 1.0 if hero_cards.is_empty() else 0.0
	if not is_equal_approx(target, _collapse_target):
		var snap = _collapse_target < 0.0
		_collapse_target = target
		if _collapse_tween != null and _collapse_tween.is_valid():
			_collapse_tween.kill()
		if snap or AnimationQueue.instant or not is_inside_tree() or not visible:
			_collapse = target
		else:
			_collapse_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_collapse_tween.tween_method(_set_collapse, _collapse, target, AnimationQueue.duration(0.2))
	_apply_tray_rect()
	_layout_cards(false)
	_place_strip()

func _set_collapse(value: float) -> void:
	_collapse = value
	_apply_tray_rect()
	_layout_cards(false)

func _apply_tray_rect() -> void:
	var rect = tray_rect(_collapse)
	tray.position = rect.position
	tray.size = rect.size
	var collapsed = _collapse > 0.5
	title_label.visible = not collapsed
	title_label.position = Vector2(0, 4)
	title_label.size = Vector2(rect.size.x, 32)
	hint_label.position = Vector2(0, (rect.size.y - 24.0) * 0.5 if collapsed else 31.0)
	hint_label.size = Vector2(rect.size.x, 24)
	# Under the frame, clear of the hero cards and their glow.
	info_label.position = Vector2(0, rect.size.y + 4)
	info_label.size = Vector2(rect.size.x, 24)
	tray.queue_redraw()

func _layout_cards(animate: bool) -> void:
	var count = hero_cards.size()
	var spacing = CARD_SIZE.x + 24.0
	var left = (tray.size.x - (count * spacing - 24.0)) * 0.5
	for index in range(count):
		var card: Control = hero_cards[index]
		if card == dragging:
			continue
		var selected = int(card.get_meta("uid")) == selected_uid
		var target = Vector2(left + index * spacing, CARD_TOP - (12.0 if selected else 0.0))
		if animate and not AnimationQueue.instant and is_inside_tree():
			card.create_tween().tween_property(card, "position", target, AnimationQueue.duration(0.2))
		else:
			card.position = target

## Centres the opponent strip on `x` (the enemy hand pile).
func set_strip_center(x: float) -> void:
	strip_center_x = x
	_place_strip()

func _place_strip() -> void:
	var count = _strip_cards.size()
	var card_size = UnitCard.SIZE * STRIP_SCALE
	var width = card_size.x + STRIP_SPACING * maxi(0, count - 1)
	var center_x = strip_center_x if strip_center_x >= 0.0 else size.x * 0.5
	opponent_strip.position = Vector2(center_x - width * 0.5, STRIP_TOP)
	opponent_strip.size = Vector2(width, card_size.y + 14.0)
	var index = 0
	for uid in _strip_cards:
		var card: Control = _strip_cards[uid]
		card.position = Vector2(index * STRIP_SPACING, 0) + card_size * 0.5 - UnitCard.SIZE * 0.5
		index += 1
	opponent_strip.queue_redraw()

# --- State -----------------------------------------------------------------------

## Updates the tray, the staging strips and the opponent strip from the
## viewer's view and legal actions. `spent_text` reports the opponent's
## shopping (public). Cards are kept by uid, so a hero being dragged or
## selected survives states published meanwhile (the opponent planning).
func sync(new_view: Dictionary, new_viewer: int, new_actions: Array, spent_text: String) -> void:
	view = new_view
	viewer = new_viewer
	actions = new_actions
	var player: Dictionary = view.players[viewer]
	var plans: Dictionary = player.get("plans", {})
	_resolve_pending(plans)
	var previous: Dictionary = {}
	for card in hero_cards:
		if is_instance_valid(card):
			previous[int(card.get_meta("uid"))] = card
	var deployable: Dictionary = {}
	for action in actions:
		if action.get("type", "") == "deploy":
			deployable[int(action.unit)] = true
	var kept: Array = []
	var arrivals: Array = []
	for hero in player.get("roster", []):
		var uid = int(hero.uid)
		# The engine also offers re-plans for planned heroes; only unplanned ones wait here.
		if not deployable.has(uid) or plans.has(str(uid)):
			continue
		var card: Control = previous.get(uid)
		previous.erase(uid)
		if card == null:
			card = CardView.new()
			card.set_meta("uid", uid)
			card.mouse_default_cursor_shape = Control.CURSOR_DRAG
			card.gui_input.connect(_on_card_input.bind(card))
			tray.add_child(card)
			if _last_drop.has(uid):
				arrivals.append([card, _last_drop[uid]])
				_last_drop.erase(uid)
		var max_health = board.display_engine.max_health_of(hero) if board != null else int(hero.max_health)
		card.setup(str(hero.card), {"items": hero.get("items", {}), "health": int(hero.health), "max_health": max_health})
		card.set_size_keep(CARD_SIZE)
		card.playable = enabled
		kept.append(card)
	for uid in previous:
		UiKit.discard(previous[uid])
	hero_cards = kept
	if dragging != null and (not enabled or not hero_cards.has(dragging)):
		dragging = null
		_set_drop_cues(-1, false)
	if not _staged_drag.is_empty() and (not enabled or int(plans.get(str(_staged_drag.uid), -1)) != int(_staged_drag.from_lane)):
		_cancel_staged_drag()
	if selected_uid != -1 and (not enabled or not deployable.has(selected_uid)):
		selected_uid = -1
		_set_drop_cues(-1, false)
	for card in hero_cards:
		card.selected = int(card.get_meta("uid")) == selected_uid
	_sync_staging(plans)
	_sync_strip()
	info_label.text = spent_text
	refresh_text()
	_place()
	for arrival in arrivals:
		var card: Control = arrival[0]
		var target = card.position
		card.position = tray.get_global_transform().affine_inverse() * Vector2(arrival[1]) - CARD_SIZE * 0.5
		if AnimationQueue.instant:
			card.position = target
		else:
			card.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(card, "position", target, AnimationQueue.duration(0.25))

## Staging per lane: both players' creeps for this round (public; creeps
## that follow Kanna already name her lane, RQ-22) and the viewer's planned
## heroes. The opponent's plans are never read.
func _sync_staging(plans: Dictionary) -> void:
	if board == null:
		return
	var pending: Array = view.get("pending_creeps", [[], []])
	var roster: Array = view.players[viewer].get("roster", [])
	for lane_index in range(3):
		var sides: Array = [[], []]
		for side in range(2):
			var player = 1 - viewer if side == 0 else viewer
			var ordinal = 0
			for lane_value in pending[player]:
				if int(lane_value) == lane_index:
					sides[side].append({"key": "c%d_%d" % [side, ordinal], "card_id": "melee_creep", "uid": -1, "kind": "creep",
						"movable": false, "selected": false, "hidden": false, "model": board.staged_model(_creep_unit(player), side == 1)})
					ordinal += 1
		var arrive: Dictionary = {}
		for hero in roster:
			var uid = int(hero.uid)
			if int(plans.get(str(uid), -1)) != lane_index:
				continue
			var key = "h%d" % uid
			var dragged = int(_staged_drag.get("uid", -1)) == uid and _staged_drag.get("moved", false)
			sides[1].append({"key": key, "card_id": str(hero.card), "uid": uid, "kind": "hero", "movable": enabled,
				"selected": uid == selected_uid, "hidden": dragged or _pending.has(uid), "model": board.staged_model(hero, true)})
			if _last_drop.has(uid):
				arrive[key] = _last_drop[uid]
				_last_drop.erase(uid)
		board.lanes[lane_index].set_staged(sides[0], sides[1], arrive)

## A lane creep as a unit dict (the real one is created at the reveal).
func _creep_unit(player: int) -> Dictionary:
	var definition = Library.raw_definition("melee_creep")
	var health = int(definition.get("health", 4))
	return {"uid": -2, "card": "melee_creep", "owner": player, "hero": false, "color": str(definition.get("color", "neutral")),
		"attack": int(definition.get("attack", 2)), "armor": int(definition.get("armor", 0)), "max_health": health,
		"health": health, "items": {}, "lane": -1}

## The opponent's ready heroes, face up (public); a check under each once
## the opponent has confirmed.
func _sync_strip() -> void:
	var enemy: Dictionary = view.players[1 - viewer]
	var seen: Dictionary = {}
	for hero in enemy.get("roster", []):
		if int(hero.get("lane", -1)) != -1 or int(hero.get("ready_round", 1)) > int(view.get("round", 1)):
			continue
		var uid = int(hero.uid)
		seen[uid] = true
		var card: Control = _strip_cards.get(uid)
		if card == null:
			card = UnitCard.new()
			card.preview_hidden = true
			card.scale = Vector2.ONE * STRIP_SCALE
			opponent_strip.add_child(card)
			_strip_cards[uid] = card
		card.apply(board.staged_model(hero, false) if board != null else {"unit": hero, "own": false})
		card.visible = true
	for uid in _strip_cards.keys():
		if not seen.has(uid):
			UiKit.discard(_strip_cards[uid])
			_strip_cards.erase(uid)
	opponent_strip.checks = bool(enemy.get("finished", false))
	opponent_strip.tooltip_text = UiKit.t("DEPLOY_OPPONENT_READY")
	opponent_strip.visible = not _strip_cards.is_empty()

func refresh_text() -> void:
	title_label.text = UiKit.t("DEPLOY_READY_HEROES")
	var key = "DEPLOY_DRAG_HINT"
	if not _staged_drag.is_empty() and _staged_drag.get("moved", false):
		key = "DEPLOY_UNASSIGN_HINT"
	elif hero_cards.is_empty():
		if not view.is_empty() and view.players[viewer].get("finished", false):
			key = "DEPLOY_WAITING"
		elif not view.is_empty() and view.players[viewer].get("plans", {}).is_empty():
			key = "DEPLOY_HIDDEN"
		else:
			key = "DEPLOY_ALL_ASSIGNED"
	hint_label.text = UiKit.t(key)
	opponent_strip.tooltip_text = UiKit.t("DEPLOY_OPPONENT_READY")
	for card in hero_cards:
		card.refresh()
	for uid in _strip_cards:
		_strip_cards[uid].refresh()

func open() -> void:
	visible = true
	_revealing = false
	tray.modulate.a = 1.0
	_collapse_target = -1.0
	_place()

func close() -> void:
	visible = false
	dragging = null
	selected_uid = -1
	_revealing = false
	_cancel_staged_drag()
	for uid in _pending.keys():
		_free_proxy(_pending[uid].proxy)
	_pending.clear()
	_last_drop.clear()
	set_process(false)
	for uid in _strip_cards:
		UiKit.discard(_strip_cards[uid])
	_strip_cards.clear()
	opponent_strip.visible = false
	tray.drop_state = 0
	_collapse_target = -1.0
	if board != null:
		for lane in board.lanes:
			lane.clear_staging()
			lane.drop_state = 0
			lane.queue_redraw()

## The reveal starts: nothing can move any more, the tray fades out and the
## opponent strip stays (the enemy heroes fly from it).
func begin_reveal() -> void:
	_revealing = true
	enabled = false
	dragging = null
	selected_uid = -1
	_cancel_staged_drag()
	for uid in _pending.keys():
		_free_proxy(_pending[uid].proxy)
	_pending.clear()
	_set_drop_cues(-1, false)
	if board != null:
		for lane in board.lanes:
			lane.lock_staging()
	if AnimationQueue.instant:
		tray.modulate.a = 0.0
	else:
		create_tween().tween_property(tray, "modulate:a", 0.0, AnimationQueue.duration(0.2))

## Global centre of the opponent strip card for hero `uid`, or (-1, -1).
func opponent_card_center(uid: int) -> Vector2:
	var card: Control = _strip_cards.get(uid)
	if card == null or not card.visible or not opponent_strip.visible:
		return Vector2(-1, -1)
	return card.get_global_transform() * (UnitCard.SIZE * 0.5)

func hide_opponent_card(uid: int) -> void:
	var card: Control = _strip_cards.get(uid)
	if card != null:
		card.visible = false

func strip_uids() -> Array:
	return _strip_cards.keys()

func hero_card(uid: int) -> Control:
	for card in hero_cards:
		if int(card.get_meta("uid")) == uid:
			return card
	return null

## The card following the pointer while a staged hero is dragged (or null).
func drag_proxy() -> Control:
	var proxy = _staged_drag.get("proxy")
	return proxy if is_instance_valid(proxy) else null

# --- Input: tray cards --------------------------------------------------------------

func select_hero(uid: int) -> void:
	selected_uid = uid
	for card in hero_cards:
		card.selected = int(card.get_meta("uid")) == selected_uid
		card.queue_redraw()
	_set_drop_cues(-1, selected_uid != -1)
	tray.drop_state = 1 if selected_uid != -1 and _is_planned(selected_uid) else 0
	_layout_cards(true)
	if board != null:
		for lane in board.lanes:
			lane.select_staged(selected_uid)

func _is_planned(uid: int) -> bool:
	return not view.is_empty() and view.players[viewer].get("plans", {}).has(str(uid))

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
					var uid = int(card.get_meta("uid"))
					_last_drop[uid] = point
					deploy_requested.emit(uid, lane)
				# Back into the tray unless the deploy removed it.
				_layout_cards(true)
			else:
				var uid = int(card.get_meta("uid"))
				select_hero(uid if selected_uid != uid else -1)
			accept_event()
	elif event is InputEventMouseMotion and dragging == card:
		var point = card.get_global_transform() * event.position
		if not _moved and point.distance_to(_press_point) > DRAG_START:
			_moved = true
			select_hero(-1)
		if _moved:
			card.position = tray.get_global_transform().affine_inverse() * point - _grab_offset
			var lane = board.lane_at(point) if board != null else -1
			_set_drop_cues(lane, true)
		accept_event()

# --- Input: staged heroes (pressed on the board) ------------------------------------

## A press on the board. Right-click on a staged card inspects it; a left
## press on one of your movable staged heroes starts a drag (or a click).
## Returns true when the press was used.
func handle_board_press(global_point: Vector2, button: int) -> bool:
	if board == null or not visible or _revealing:
		return false
	for lane in board.lanes:
		if not lane.visible:
			continue
		var entry: Dictionary = lane.staged_at(global_point)
		if entry.is_empty():
			continue
		if button == MOUSE_BUTTON_RIGHT:
			inspect_requested.emit(str(entry.card_id))
			return true
		if button == MOUSE_BUTTON_LEFT and enabled and entry.get("kind", "") == "hero" and entry.get("movable", false):
			var card: Control = entry.card
			_staged_drag = {"uid": int(entry.uid), "key": str(entry.key), "from_lane": int(lane.lane_index), "press": global_point,
				"moved": false, "grab": card.get_global_transform().affine_inverse() * global_point}
			set_process(true)
			return true
		return false
	return false

## Click-to-deploy fallback: with a hero selected, a click on a lane plans it
## there and a click on the tray takes a planned hero back.
func handle_board_click(global_point: Vector2) -> bool:
	if selected_uid == -1 or board == null or not enabled:
		return false
	var uid = selected_uid
	if tray.get_global_rect().has_point(global_point):
		select_hero(-1)
		if {"type": "undeploy", "unit": uid} in actions:
			undeploy_requested.emit(uid)
		return true
	var lane = board.lane_at(global_point)
	if lane == -1:
		return false
	select_hero(-1)
	if {"type": "deploy", "unit": uid, "lane": lane} in actions:
		_last_drop[uid] = global_point
		deploy_requested.emit(uid, lane)
	return true

func _input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree() or not event is InputEventMouse:
		return
	var point = get_global_transform() * make_input_local(event).position
	if event is InputEventMouseMotion:
		if not _staged_drag.is_empty():
			_staged_drag_motion(point)
		elif dragging == null and not _revealing:
			_update_hover(point)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _staged_drag.is_empty():
		_staged_drag_release(point)

func _update_hover(point: Vector2) -> void:
	if board == null:
		return
	for lane in board.lanes:
		var entry: Dictionary = lane.staged_at(point) if lane.visible else {}
		lane.hovered_key = str(entry.get("key", ""))

func _staged_drag_motion(point: Vector2) -> void:
	var drag = _staged_drag
	if not drag.moved:
		if point.distance_to(drag.press) <= DRAG_START:
			return
		drag.moved = true
		select_hero(-1)
		var lane = board.lanes[drag.from_lane]
		var entry: Dictionary = lane.staged_entry(drag.key)
		var proxy = UnitCard.new()
		proxy.floating = 1.0
		proxy.preview_hidden = true
		proxy.target_state = 4
		proxy.scale = Vector2.ONE * PROXY_SCALE
		proxy.apply(entry.get("model", {}))
		add_child(proxy)
		drag.proxy = proxy
		lane.hovered_key = ""
		lane.set_staged_hidden(drag.key, true)
		refresh_text()
	var proxy: Control = drag.proxy
	var pivot = UnitCard.SIZE * 0.5
	proxy.position = get_global_transform().affine_inverse() * point - pivot - (Vector2(drag.grab) - pivot) * PROXY_SCALE
	_set_drop_cues(board.lane_at(point), true)
	tray.drop_state = 2 if tray.get_global_rect().has_point(point) else 1
	tray.queue_redraw()

func _staged_drag_release(point: Vector2) -> void:
	var drag = _staged_drag
	_staged_drag = {}
	_set_drop_cues(-1, false)
	tray.drop_state = 0
	tray.queue_redraw()
	var uid = int(drag.uid)
	if not drag.moved:
		select_hero(uid if selected_uid != uid else -1)
		return
	var lane = board.lane_at(point)
	var undeploy = {"type": "undeploy", "unit": uid}
	var deploy = {"type": "deploy", "unit": uid, "lane": lane}
	if tray.get_global_rect().has_point(point) and undeploy in actions:
		_last_drop[uid] = point
		_park(drag, -1, tray.get_global_rect().get_center())
		undeploy_requested.emit(uid)
	elif lane != -1 and lane != int(drag.from_lane) and deploy in actions:
		_last_drop[uid] = point
		_park(drag, lane, board.lanes[lane].stage_anchor(1))
		deploy_requested.emit(uid, lane)
	else:
		_send_home(drag.proxy, str(drag.key), int(drag.from_lane))
	refresh_text()

## Parks the drag proxy on its drop target until a state applies the move.
func _park(drag: Dictionary, target: int, at: Vector2) -> void:
	var proxy: Control = drag.proxy
	_pending[int(drag.uid)] = {"proxy": proxy, "target": target, "key": str(drag.key), "from_lane": int(drag.from_lane), "time": 0.0}
	set_process(true)
	if AnimationQueue.instant or not is_instance_valid(proxy):
		return
	var rest = get_global_transform().affine_inverse() * at - UnitCard.SIZE * 0.5
	var tween = proxy.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "position", rest, AnimationQueue.duration(0.15))
	tween.tween_property(proxy, "modulate:a", 0.7, AnimationQueue.duration(0.15))

## Drops applied by a state free their proxy (the staged card arrives from
## the drop point); drops that never apply go home after the timeout.
func _resolve_pending(plans: Dictionary) -> void:
	for uid in _pending.keys():
		var pending: Dictionary = _pending[uid]
		var plan = int(plans.get(str(uid), -1))
		if plan == int(pending.target) or plan != int(pending.from_lane):
			_free_proxy(pending.proxy)
			_pending.erase(uid)

func _process(delta: float) -> void:
	for uid in _pending.keys():
		var pending: Dictionary = _pending[uid]
		pending.time = float(pending.time) + delta
		if pending.time >= PENDING_TIMEOUT:
			_pending.erase(uid)
			_last_drop.erase(uid)
			_send_home(pending.proxy, str(pending.key), int(pending.from_lane))
	if _pending.is_empty() and _staged_drag.is_empty():
		set_process(false)

## Flies a proxy back to its staged slot, then shows the staged card again.
func _send_home(proxy: Control, key: String, lane_index: int) -> void:
	var lane = board.lanes[lane_index] if board != null and lane_index >= 0 else null
	if not is_instance_valid(proxy) or lane == null or AnimationQueue.instant or not is_inside_tree():
		_free_proxy(proxy)
		if lane != null:
			lane.set_staged_hidden(key, false)
		return
	var rest = get_global_transform().affine_inverse() * lane.staged_global_center(key) - UnitCard.SIZE * 0.5
	var tween = proxy.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "position", rest, AnimationQueue.duration(0.2))
	tween.tween_property(proxy, "modulate:a", 1.0, AnimationQueue.duration(0.2))
	tween.tween_property(proxy, "scale", Vector2.ONE * LaneView.STAGE_SCALE, AnimationQueue.duration(0.2))
	tween.chain().tween_callback(func():
		_free_proxy(proxy)
		lane.set_staged_hidden(key, false))

func _cancel_staged_drag() -> void:
	if _staged_drag.is_empty():
		return
	var drag = _staged_drag
	_staged_drag = {}
	_free_proxy(drag.get("proxy"))
	if board != null and drag.get("moved", false):
		board.lanes[int(drag.from_lane)].set_staged_hidden(str(drag.key), false)
	_set_drop_cues(-1, false)
	tray.drop_state = 0

func _free_proxy(proxy) -> void:
	if is_instance_valid(proxy):
		UiKit.discard(proxy)

func _set_drop_cues(hovered_lane: int, active: bool) -> void:
	if board == null:
		return
	for index in range(3):
		var lane = board.lanes[index]
		lane.drop_state = 0 if not active else (2 if index == hovered_lane else 1)
		lane.queue_redraw()

## The tray (the camp where ready heroes wait): camp art under a lacquered
## frame with gold trim. Lights up as a drop target for taking a hero back.
class Tray:
	extends Control
	## 0 none, 1 candidate (a staged hero is held), 2 hovered.
	var drop_state: int = 0

	func _draw() -> void:
		var rect = Rect2(Vector2.ZERO, size)
		var radius = minf(14.0, size.y * 0.3)
		draw_colored_polygon(UiKit.round_rect_points(Rect2(rect.position + Vector2(0, 8), rect.size), radius), Color(0, 0, 0, 0.5))
		var points = UiKit.round_rect_points(rect, radius, 5)
		var art = UiKit.tex(CAMP_ART)
		if art != null:
			UiKit.draw_cover_polygon(self, points, rect, art, Vector2(0.5, 0.55), Color(0.42, 0.4, 0.38))
			# A dark band under the title and hint keeps them readable on the art.
			UiKit.draw_vgradient(self, Rect2(rect.position, Vector2(rect.size.x, minf(76.0, rect.size.y))), Color(0, 0, 0, 0.78), Color(0, 0, 0, 0.0))
			UiKit.draw_round_rect(self, rect, Color.TRANSPARENT, radius, Color(UiKit.GOLD_DARK, 0.95), 2.0)
		else:
			UiKit.draw_round_rect(self, rect, Color(0.05, 0.05, 0.06, 0.9), radius, Color(UiKit.GOLD_DARK, 0.95), 2.0)
		if size.y > 90.0:
			UiKit.draw_ornate(self, rect.grow(-6), 13, Color(UiKit.GOLD, 0.6), 26.0)
		if drop_state > 0:
			UiKit.draw_glow(self, rect, radius, UiKit.PLAYABLE, 0.8 if drop_state == 1 else 1.8)
			if drop_state == 2:
				draw_colored_polygon(points, Color(UiKit.PLAYABLE, 0.1))

## The opponent's ready heroes (top centre): small face-up cards, with a
## check under each once the opponent has confirmed.
class Strip:
	extends Control
	var checks: bool = false

	func _draw() -> void:
		if not checks:
			return
		for child in get_children():
			if not child.visible:
				continue
			var bottom = child.position + Vector2(UnitCard.SIZE.x * 0.5, UnitCard.SIZE.y * 0.5 + UnitCard.SIZE.y * STRIP_SCALE * 0.5 + 6.0)
			draw_polyline(PackedVector2Array([bottom + Vector2(-5, 0), bottom + Vector2(-1, 4), bottom + Vector2(6, -5)]), UiKit.HEAL, 2.5, true)
