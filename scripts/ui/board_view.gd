extends Control
## The three lanes and the camera over them. Lane view shows one lane filling
## the screen (lanes sit side by side and the camera slides between them);
## overview shows all three lanes small, side by side. `focus` (0..2) and
## `zoom` (0 lane view, 1 overview) are tweened for the transitions.
##
## The board turns a player view into per-unit display models with a display
## engine (attack and armor with auras, combat targets, the damage preview)
## and hands them to the lanes.

signal lane_selected(index: int)
signal board_pressed(global_point: Vector2, button: int, double_click: bool)

const LaneView = preload("res://scripts/ui/lane_view.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const MatchEngine = preload("res://scripts/core/match_engine.gd")

var lanes: Array = []
var focus: float = 0.0
var zoom: float = 0.0
var focus_lane: int = 0
var overview: bool = false
## Vertical band used by the overview (shop and deployment shrink it).
var overview_top: float = 86.0
var overview_bottom: float = 640.0
var display_engine = MatchEngine.new()
var view: Dictionary = {}
var viewer: int = 0
## Per lane: uid -> display model, plus "tower_damage".
var lane_models: Array = [{}, {}, {}]
var chevrons: Array = []
var _camera: Tween
var _zoom_tween: Tween

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	clip_contents = true
	for index in range(3):
		var lane = LaneView.new()
		lane.lane_index = index
		add_child(lane)
		lanes.append(lane)
	for direction in [-1, 1]:
		var chevron = Chevron.new()
		chevron.direction = direction
		chevron.pressed.connect(_on_chevron.bind(direction))
		add_child(chevron)
		chevrons.append(chevron)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		apply_camera()

# --- Camera ------------------------------------------------------------------

func apply_camera() -> void:
	var width = size.x
	var height = size.y
	if width <= 0.0:
		return
	var margin = 26.0
	var lane_width = (width - margin * 2.0) / 3.0
	for index in range(3):
		var lane: Control = lanes[index]
		var lane_rect = Rect2((index - focus) * width, 0, width, height)
		var over_rect = Rect2(margin + index * lane_width + 5.0, overview_top, lane_width - 10.0, overview_bottom - overview_top)
		lane.position = lane_rect.position.lerp(over_rect.position, zoom)
		lane.size = lane_rect.size.lerp(over_rect.size, zoom)
		lane.zoom = zoom
		lane.visible = Rect2(lane.position, lane.size).intersects(Rect2(Vector2.ZERO, size))
		lane.layout()
	for chevron in chevrons:
		chevron.size = Vector2(54, 116)
		chevron.position = Vector2(10 if chevron.direction < 0 else width - 64, height * 0.456 - 58)
		var target = focus_lane + chevron.direction
		chevron.visible = zoom < 0.5 and target >= 0 and target <= 2
		chevron.modulate.a = 1.0 - zoom * 2.0
	queue_redraw()

## Slides the camera to `index` (lane view). Await the returned tween's
## `finished` signal, or ignore it.
func slide_to(index: int, duration: float = 0.45) -> Tween:
	index = clampi(index, 0, 2)
	focus_lane = index
	if _camera != null and _camera.is_valid():
		_camera.kill()
	if duration <= 0.0:
		focus = index
		apply_camera()
		return null
	_camera = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera.tween_method(_set_focus, focus, float(index), duration)
	return _camera

func set_overview(enabled: bool, duration: float = 0.4) -> Tween:
	overview = enabled
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	if duration <= 0.0:
		zoom = 1.0 if enabled else 0.0
		apply_camera()
		return null
	_zoom_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_method(_set_zoom, zoom, 1.0 if enabled else 0.0, duration)
	return _zoom_tween

func _set_focus(value: float) -> void:
	focus = value
	apply_camera()

func _set_zoom(value: float) -> void:
	zoom = value
	apply_camera()

func _on_chevron(direction: int) -> void:
	var target = clampi(focus_lane + direction, 0, 2)
	slide_to(target)
	lane_selected.emit(target)

# --- State -------------------------------------------------------------------

## Builds display models for every unit and syncs the lanes. Returns, per
## lane, the lane's change record ({"added", "removed", "moved"}).
func sync(new_view: Dictionary, new_viewer: int, actions: Array) -> Array:
	view = new_view
	viewer = new_viewer
	display_engine.state = new_view
	var ability_ready = _ability_ready(actions)
	var changes: Array = []
	for index in range(3):
		changes.append(_sync_lane_models(index, ability_ready))
	queue_redraw()
	return changes

## Syncs only lane `index` to `new_view` (the deployment reveal settles one
## lane at a time); the other lanes keep what they show. Returns that lane's
## change record.
func sync_lane(index: int, new_view: Dictionary, new_viewer: int, actions: Array = []) -> Dictionary:
	view = new_view
	viewer = new_viewer
	display_engine.state = new_view
	return _sync_lane_models(index, _ability_ready(actions))

## Ability sources (unit uids, item and improvement oids) with a legal
## ability action right now.
func _ability_ready(actions: Array) -> Dictionary:
	var ready: Dictionary = {}
	for action in actions:
		if action.get("type", "") == "ability":
			ready[int(action.unit)] = true
	return ready

func _sync_lane_models(index: int, ability_ready: Dictionary) -> Dictionary:
	var models = build_models(index, ability_ready)
	lane_models[index] = models
	lanes[index].active = view.phase == "action" and int(view.lane) == index
	return lanes[index].sync(view.lanes[index], viewer, models)

## Display models for lane `lane_index` of the current view. While heroes are
## being planned, the previous round's arrows are rerolled at the reveal, so
## no damage, death or tower-damage preview is shown. Everything is derived in
## one read frame (EFFECT_SYSTEM_SPEC.md §8.1).
func build_models(lane_index: int, ability_ready: Dictionary = {}) -> Dictionary:
	var lane = view.lanes[lane_index]
	display_engine.frame_begin()
	var preview = display_engine.combat_preview(lane_index)
	var planning = str(view.get("phase", "")) == "deployment"
	var dying: Dictionary = {}
	for uid in preview.get("dies", []):
		dying[int(uid)] = true
	var models: Dictionary = {}
	for side in range(2):
		for unit in lane.units[side]:
			if unit == null:
				continue
			var uid = int(unit.uid)
			var damage = 0 if planning else int(preview.unit_damage.get(str(uid), 0))
			var target = display_engine.combat_target_of(unit)
			var arrow = 0
			if not target.is_empty():
				arrow = signi(display_engine.slot_of(target) - display_engine.slot_of(unit))
			var card_id = str(unit.card)
			var definition = Library.raw_definition(card_id)
			models[uid] = {"unit": unit, "own": side == viewer,
				"attack": display_engine.attack_of(unit), "armor": display_engine.armor_of(unit),
				"health": int(unit.health), "max_health": display_engine.max_health_of(unit),
				"base_attack": int(definition.get("attack", unit.attack)), "base_armor": int(definition.get("armor", unit.armor)),
				"arrow": arrow, "tower": target.is_empty(), "damage": damage,
				"heal": 0 if planning else int(preview.get("heal", {}).get(str(uid), 0)),
				"dies": not planning and dying.has(uid),
				"badges": display_engine.badges(unit), "keywords": _keywords(unit),
				"abilities": _abilities(unit, ability_ready), "mods": _mod_summary(unit),
				"has_active": Library.has_active(card_id), "cooldown": int(unit.get("cooldown", 0)),
				"ability_ready": ability_ready.has(uid), "passive": Library.has_passive(card_id), "preview_hidden": planning}
	if planning:
		models["tower_damage"] = [0, 0]
	else:
		models["tower_damage"] = [int(preview.tower_damage[1 - viewer]), int(preview.tower_damage[viewer])]
	display_engine.frame_end()
	return models

## Non-zero derived keywords of a unit: {keyword: value}.
func _keywords(unit: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for keyword in ["siege", "cleave", "retaliate", "regeneration", "bonus_hero", "bonus_tower", "pierce", "lethal",
			"lethal_creeps", "lethal_heroes", "damage_immunity", "rapid_deployment", "soulbound"]:
		var value = display_engine.keyword_of(unit, keyword)
		if value != 0:
			out[keyword] = value
	return out

## The active abilities of a unit and its items, each ready when its action
## is legal for the viewer now.
func _abilities(unit: Dictionary, ability_ready: Dictionary) -> Array:
	var out: Array = []
	var sources: Array = [[int(unit.uid), str(unit.card), int(unit.get("cooldown", 0))]]
	for slot in ["weapon", "armor", "accessory"]:
		if unit.get("items", {}).has(slot):
			var instance: Dictionary = unit.get("item_state", {}).get(slot, {})
			sources.append([int(instance.get("oid", 0)), str(unit.items[slot]), int(instance.get("cd", 0))])
	for source in sources:
		if Library.has_active(str(source[1])):
			out.append({"source": source[0], "card": source[1], "cd": source[2], "ready": ability_ready.has(source[0])})
	return out

## Modifier entries for the inspect panel: [{src, k, d, st, kw}].
func _mod_summary(unit: Dictionary) -> Array:
	var out: Array = []
	for entry in unit.get("mods", []):
		out.append({"src": str(entry.get("src", "")), "k": str(entry.get("k", "")), "d": str(entry.get("d", "")),
			"st": entry.get("st", {}), "kw": entry.get("kw", {})})
	return out

## Display model for a unit that is not on the board yet (a staged creep or
## hero): its own stats with items, at full health, without combat preview.
func staged_model(unit: Dictionary, own: bool) -> Dictionary:
	var health = display_engine.max_health_of(unit)
	var card_id = str(unit.get("card", ""))
	var definition = Library.raw_definition(card_id)
	return {"unit": unit, "own": own, "attack": display_engine.attack_of(unit), "armor": display_engine.armor_of(unit),
		"health": health, "max_health": health, "base_attack": int(definition.get("attack", unit.get("attack", 0))),
		"base_armor": int(definition.get("armor", unit.get("armor", 0))), "arrow": 0, "tower": false, "damage": 0,
		"heal": 0, "dies": false, "badges": [], "keywords": {}, "abilities": [], "mods": [],
		"has_active": Library.has_active(card_id), "cooldown": int(unit.get("cooldown", 0)),
		"ability_ready": false, "passive": false, "preview_hidden": true}

func model(uid: int) -> Dictionary:
	for models in lane_models:
		if models.has(uid):
			return models[uid]
	return {}

# --- Lookup and hit testing -------------------------------------------------

func unit_card(uid: int) -> Control:
	for lane in lanes:
		if lane.cards.has(uid):
			return lane.cards[uid]
	return null

func lane_of_uid(uid: int) -> int:
	for index in range(3):
		if lanes[index].cards.has(uid):
			return index
	return -1

func unit_at(global_point: Vector2) -> Control:
	for lane in lanes:
		if lane.visible:
			var card = lane.unit_at(global_point)
			if card != null:
				return card
	return null

func lane_at(global_point: Vector2) -> int:
	for index in range(3):
		if lanes[index].visible and lanes[index].contains(global_point):
			return index
	return -1

func tower(lane_index: int, own: bool) -> Control:
	return lanes[lane_index].towers[1 if own else 0]

# --- Input and drawing ----------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		board_pressed.emit(get_global_transform() * event.position, event.button_index, event.double_click)
		accept_event()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	# The strategist's war map (three roads between two capitals) under the
	# lanes; the CC0 wood when the painting is missing.
	var war_map = UiKit.ui_art("board_overview")
	var wood = UiKit.tex(UiKit.WOOD_WARM)
	if war_map != null:
		UiKit.draw_cover(self, war_map, rect, Vector2(0.5, 0.5), Color(0.4, 0.37, 0.34))
	elif wood != null:
		draw_texture_rect(wood, rect, true, Color(0.36, 0.3, 0.26))
	else:
		draw_rect(rect, Color("221a14"))
	UiKit.draw_vgradient(self, Rect2(0, 0, size.x, size.y * 0.3), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0))
	UiKit.draw_vgradient(self, Rect2(0, size.y * 0.7, size.x, size.y * 0.3), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6))
	UiKit.draw_hgradient(self, Rect2(0, 0, size.x * 0.18, size.y), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0))
	UiKit.draw_hgradient(self, Rect2(size.x * 0.82, 0, size.x * 0.18, size.y), Color(0, 0, 0, 0), Color(0, 0, 0, 0.5))

## Translucent lane-switch chevron on a screen edge.
class Chevron:
	extends Control
	signal pressed
	var direction: int = 1
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var rect = Rect2(Vector2.ZERO, size)
		draw_style_box(UiKit.box(Color(0.05, 0.05, 0.06, 0.55 if _hover else 0.35), Color(1, 1, 1, 0.25 if _hover else 0.1), 6, 1, 0.0), rect)
		var center = size * 0.5
		var arm = Vector2(-direction * 12.0, 22.0)
		var tip = center + Vector2(direction * 10.0, 0)
		var color = Color(1, 1, 1, 0.85 if _hover else 0.55)
		draw_polyline(PackedVector2Array([tip + Vector2(arm.x, -arm.y), tip, tip + arm]), color, 6.0, true)
