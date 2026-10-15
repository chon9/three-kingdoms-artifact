extends Control
## One lane table: the enemy wall and tower at the top, the river across the
## middle, the viewer's wall and tower at the bottom, and both unit rows with
## index-aligned combat positions (column n holds the enemy unit above and
## the viewer's unit below). The board sets `zoom` (0 lane view, 1 overview)
## and the lane's rectangle; every position here derives from those.
##
## Deployment staging: while heroes are planned, units entering this lane
## float in a strip on the lane's left side (the viewer's in the bottom-left
## corner, the enemy's in the top-left corner), tilted, lifted and bobbing.
## They never take a combat position; the rows shift right to make room.
## The reveal draws the candidate slots, the deciding highlight and the
## pathing slabs here; match_screen.gd drives its timeline.
##
## Improvements (EFFECT_SYSTEM_SPEC.md §8.4) sit as chips on each wall to the
## right of the tower: up to six, then a "+n" chip (all of them while the
## target stepper asks for an improvement); the overview collapses each row
## to one count chip. New chips scale in, removed ones fade out.

const UnitCard = preload("res://scripts/ui/unit_card.gd")
const TowerView = preload("res://scripts/ui/tower_view.gd")
const ImprovementChip = preload("res://scripts/ui/improvement_chip.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const LANE_KEYS = ["LANE_LEFT", "LANE_MIDDLE", "LANE_RIGHT"]
const GAP = 12.0
const OVERVIEW_SCALE = 0.72
## Staged cards read about 1.2x the (shrunk) overview row.
const STAGE_SCALE = 0.74
## Tilt in degrees: [enemy, own].
const STAGE_TILT = [4.0, -5.0]
const STAGE_MARGIN = 12.0
const STAGE_STEP_X = 6.0
## Fan x-steps counted toward the reserved strip.
const STAGE_MAX_FAN_X = 3
const BOB_PERIOD = 2.4
const BOB_AMP = 3.0
const LIFT = 8.0
const HOVER_SCALE = 1.12
const HOVER_LIFT = 8.0
const ENEMY_ARROW_TINT = Color("c9d36a")
## Improvement chips: shown per wall in lane view, spacing, gap after the tower.
const CHIPS_SHOWN = 6
const CHIP_STEP = 50.0
const CHIP_GAP = 26.0

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
var towers: Array = []
## Improvement chips per wall [enemy, own] in play order, and by oid.
var improvement_rows: Array = [[], []]
var chips: Dictionary = {}
## Per wall: the "+n" chip in lane view, the count chip in the overview.
var more_chips: Array = []
## Shows every chip of both walls (the stepper is choosing an improvement).
var chip_expand: bool = false:
	set(value):
		if chip_expand != value:
			chip_expand = value
			layout()
var _synced: bool = false
## Draws every chip's marks after all chips (_draw_chip_marks).
var _chip_marks: Control
## The chip under the pointer, drawn in front of its neighbours (an open
## row overlaps them).
var hovered_chip: Control = null:
	set(value):
		if hovered_chip != value:
			hovered_chip = value
			_restack_chips()
## 0..1: how much of the staging strip is reserved (tweened as the strip
## opens, and to 0 when the reveal settles this lane).
var staging: float = 0.0
## Staged units [enemy entries, own entries], back to front. An entry is
## {key, card_id, uid, kind ("creep" or "hero"), movable, selected, hidden,
## model, card (UnitCard)} plus layout state.
var staged: Array = [[], []]
## Staged card under the pointer (raised to the front), "" for none.
var hovered_key: String = "":
	set(value):
		if hovered_key != value:
			hovered_key = value
			_hover_changed()
## Hides arrows, damage tags and death marks on every card (reveal).
var preview_hidden: bool = false:
	set(value):
		preview_hidden = value
		for uid in cards:
			cards[uid].preview_hidden = value
		for tower in towers:
			tower.preview_hidden = value
## Reveal: candidate columns per side [enemy, own] drawn as slot outlines,
## the deciding highlight ({"side", "column", "landing"}) and the pathing
## slabs ({column, attacker_own, arrow}) with their animation progress.
var candidates: Array = [[], []]
var candidate_alpha: float = 0.0:
	set(value):
		candidate_alpha = value
		queue_redraw()
var roulette: Dictionary = {}
var slabs: Array = []
var slab_t: float = 0.0:
	set(value):
		slab_t = value
		queue_redraw()
var slab_alpha: float = 1.0:
	set(value):
		slab_alpha = value
		queue_redraw()
## uids whose cards are flying into place; layout leaves them alone.
var flying: Dictionary = {}
var _scale: float = 1.0
## Combat positions laid out this frame.
var _count: int = 0
var _bob_time: float = 0.0
var _staging_tween: Tween
var _staging_target: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(false)
	for side in range(2):
		var tower = TowerView.new()
		tower.own = side == 1
		add_child(tower)
		towers.append(tower)
	for side in range(2):
		var more = ImprovementChip.new()
		more.visible = false
		add_child(more)
		more_chips.append(more)
	_chip_marks = Control.new()
	_chip_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_marks.draw.connect(_draw_chip_marks)
	add_child(_chip_marks)

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
	var available = table_rect().size.x - stage_reserve() - lerpf(170.0, 12.0, zoom)
	var needed = maxf(1.0, float(count)) * (UnitCard.SIZE.x + _gap())
	return minf(base, available / needed) if needed > 0.0 else base

func spacing() -> float:
	return (UnitCard.SIZE.x + _gap()) * _scale

## Space between cards: tighter in the overview, where width is scarce.
func _gap() -> float:
	return lerpf(GAP, 5.0, zoom)

## Centre x of the unit rows: the table centre, or the centre of what the
## staging strip leaves.
func row_center_x() -> float:
	var table = table_rect()
	var reserve = stage_reserve()
	return table.position.x + reserve + (table.size.x - reserve) * 0.5

## Centre x of combat position `column` among `count` positions.
func column_x(column: float, count: int) -> float:
	return row_center_x() + (column - (count - 1) * 0.5) * spacing()

func slot_center(column: float, own: bool) -> Vector2:
	return Vector2(column_x(column, _count), row_center_y(own))

## Card-sized rectangle of a combat position.
func slot_rect(column: float, own: bool) -> Rect2:
	var card_size = UnitCard.SIZE * _scale
	return Rect2(slot_center(column, own) - card_size * 0.5, card_size)

# --- Staging geometry ----------------------------------------------------------

func stage_card_size() -> Vector2:
	return UnitCard.SIZE * STAGE_SCALE

## Width of the bounding box of a staged card tilted 5 degrees.
func _stage_rot_width() -> float:
	var card_size = stage_card_size()
	var angle = deg_to_rad(5.0)
	return card_size.x * cos(angle) + card_size.y * sin(angle)

## Width reserved on the lane's left for the staging strip.
func stage_reserve() -> float:
	return staging * (STAGE_MARGIN + _stage_rot_width() + STAGE_STEP_X * STAGE_MAX_FAN_X + 8.0)

## Resting centre of staged card `index` of `count` on `side` (0 enemy at
## the top-left, 1 own at the bottom-left; index 0 is the back card).
func fan_center(side: int, index: int, count: int) -> Vector2:
	var card_size = stage_card_size()
	var table = table_rect()
	var x = table.position.x + STAGE_MARGIN + card_size.x * 0.5 + STAGE_STEP_X * mini(index, STAGE_MAX_FAN_X)
	if side == 1:
		var top = river_y() + 12.0
		var bottom = table.end.y - 8.0
		var step = clampf((bottom - top - card_size.y) / maxf(1.0, count - 1), 0.0, 0.3 * card_size.y)
		return Vector2(x, bottom - card_size.y * 0.5 - step * index)
	# The enemy fan hangs from the top edge: leave room for the lift, the bob
	# and the tilt so the back card never pokes out of the table.
	var enemy_top = table.position.y + 8.0 + LIFT + BOB_AMP + 3.5
	var enemy_bottom = river_y() - 12.0
	var enemy_step = clampf((enemy_bottom - enemy_top - card_size.y) / maxf(1.0, count - 1), 0.0, 0.3 * card_size.y)
	return Vector2(x, enemy_top + card_size.y * 0.5 + enemy_step * index)

func _fan_rotation(side: int, index: int) -> float:
	return deg_to_rad(STAGE_TILT[side] + 1.5 * index * (1.0 if side == 1 else -1.0))

## Where a staged entry rests now: {"center", "rotation", "scale"} (local),
## with the lift, the bob and the hover raise.
func _stage_target(side: int, index: int, entry: Dictionary) -> Dictionary:
	var count = staged[side].size()
	var center = fan_center(side, index, count)
	var bob = 0.0 if AnimationQueue.instant else sin(_bob_time * TAU / BOB_PERIOD + index * 1.3) * BOB_AMP
	var hover = float(entry.get("h", 0.0))
	center.y += -LIFT + bob - HOVER_LIFT * hover
	return {"center": center, "rotation": lerpf(_fan_rotation(side, index), 0.0, hover),
		"scale": STAGE_SCALE * lerpf(1.0, HOVER_SCALE, hover)}

# --- Layout ------------------------------------------------------------------

## Positions towers, unit cards, staged cards and slots for the current zoom.
func layout() -> void:
	_count = maxi(columns[0].size(), columns[1].size())
	_scale = _fit_scale(_count + (2 if not ghost_slots.is_empty() else 0))
	for side in range(2):
		var tower: Control = towers[side]
		var tower_size = TowerView.SIZE
		tower.scale = Vector2.ONE * tower_scale()
		tower.position = tower_center(side == 1) - tower_size * 0.5
	for side in range(2):
		for column in range(columns[side].size()):
			var uid = int(columns[side][column])
			if uid != -1 and cards.has(uid) and not flying.has(uid):
				_place_card(cards[uid], slot_center(column, side == 1))
	_layout_chips()
	_layout_staged()
	queue_redraw()

## Places the improvement chips of both walls for the current zoom: lane view
## shows up to CHIPS_SHOWN per wall (all while `chip_expand`) and a "+n"
## chip, the overview one count chip per wall; the two cross-fade.
func _layout_chips() -> void:
	var detail = clampf(1.0 - zoom * 2.5, 0.0, 1.0)
	var collapsed = clampf(zoom * 2.5 - 1.5, 0.0, 1.0)
	var chip_scale = lerpf(1.0, 0.7, zoom)
	for side in range(2):
		var own = side == 1
		var row: Array = improvement_rows[side]
		var tower_right = tower_center(own).x + TowerView.SIZE.x * 0.5 * tower_scale()
		var first = tower_right + CHIP_GAP * lerpf(1.0, 0.5, zoom) + ImprovementChip.SIZE.x * 0.5 * chip_scale
		var y = tower_center(own).y
		var shown = row.size() if chip_expand or row.size() <= CHIPS_SHOWN else CHIPS_SHOWN - 1
		var step = CHIP_STEP * chip_scale
		if chip_expand and row.size() > CHIPS_SHOWN:
			# Every chip in the usual six-chip span (they overlap), clear of
			# the screen's corner controls.
			step = step * (CHIPS_SHOWN - 1) / (row.size() - 1)
		for index in range(row.size()):
			var chip_node: Control = row[index]
			var visible_now = index < shown and detail > 0.0
			chip_node.visible = visible_now
			if not visible_now:
				continue
			chip_node.position = Vector2(first + step * index, y) - ImprovementChip.SIZE * 0.5
			chip_node.scale = Vector2.ONE * chip_scale * (0.25 + 0.75 * float(chip_node.get_meta("pop", 1.0)))
			chip_node.modulate.a = detail
		var more: Control = more_chips[side]
		var hidden = row.size() - shown
		# The "+n" chip glows while an own chip it hides can be used now.
		var hidden_ready = false
		for index in range(shown, row.size()):
			hidden_ready = hidden_ready or bool(row[index].usable)
		if collapsed > 0.0 and not row.is_empty():
			more.apply_count(row.size(), own, true)
			more.position = Vector2(first, y) - ImprovementChip.SIZE * 0.5
			more.scale = Vector2.ONE * chip_scale
			more.modulate.a = collapsed
			more.visible = true
		elif hidden > 0 and detail > 0.0:
			more.apply_count(hidden, own, false, hidden_ready)
			more.position = Vector2(first + step * shown, y) - ImprovementChip.SIZE * 0.5
			more.scale = Vector2.ONE * chip_scale
			more.modulate.a = detail
			more.visible = true
		else:
			more.visible = false
	_chip_marks.queue_redraw()

## Second pass over the chips: their book marks, charges and cooldown numbers
## drawn above every chip, so overlapping chips (an open row) never hide them.
func _draw_chip_marks() -> void:
	for side in range(2):
		for chip_node in improvement_rows[side]:
			if chip_node.visible and not chip_node.gone:
				chip_node.draw_marks(_chip_marks, chip_node.modulate.a)

func _place_card(card: Control, center: Vector2) -> void:
	if not card.scale.is_equal_approx(Vector2.ONE * _scale):
		card.scale = Vector2.ONE * _scale
		card.refresh()
	card.position = center - UnitCard.SIZE * 0.5

## Places every staged card: its fan slot, eased in from where it started
## (an arrival or a re-fan) by its progress `t`.
func _layout_staged() -> void:
	for side in range(2):
		for index in range(staged[side].size()):
			var entry: Dictionary = staged[side][index]
			var card: Control = entry.card
			if not is_instance_valid(card):
				continue
			var target = _stage_target(side, index, entry)
			var t = float(entry.get("t", 1.0))
			if t < 1.0 and entry.has("from"):
				var eased = 1.0 - pow(1.0 - t, 3.0)
				var from: Dictionary = entry.from
				target = {"center": from.center.lerp(target.center, eased),
					"rotation": lerp_angle(float(from.rotation), float(target.rotation), eased),
					"scale": lerpf(float(from.scale), float(target.scale), eased)}
			card.position = target.center - UnitCard.SIZE * 0.5
			card.rotation = target.rotation
			if not card.scale.is_equal_approx(Vector2.ONE * target.scale):
				card.scale = Vector2.ONE * target.scale
			card.visible = not entry.get("hidden", false)

func _process(delta: float) -> void:
	_bob_time += delta
	_layout_staged()

func _update_processing() -> void:
	set_process(staging > 0.0 and not staged_cards().is_empty() and not AnimationQueue.instant)

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
				card.preview_hidden = preview_hidden
				add_child(card)
				cards[uid] = card
				result.added.append(card)
			card.apply(models.get(uid, {"unit": unit, "own": side == 1}))
	for uid in cards.keys():
		if not seen.has(uid):
			result.removed.append(cards[uid])
			cards.erase(uid)
			flying.erase(uid)
	var structures = lane.structures
	var damage = models.get("tower_damage", [0, 0])
	var stats: Array = models.get("tower_stats", [{}, {}])
	towers[0].apply(structures[1 - viewer], int(lane.mana[1 - viewer]), int(lane.max_mana[1 - viewer]), int(damage[1]), stats[0])
	towers[1].apply(structures[viewer], int(lane.mana[viewer]), int(lane.max_mana[viewer]), int(damage[0]), stats[1])
	for card in towers:
		move_child(card, 0)
	_sync_chips(models.get("improvements", [[], []]))
	if not result.added.is_empty():
		_restack_staged()
	layout()
	for uid in cards:
		if old_positions.has(uid) and old_positions[uid] != cards[uid].position:
			result.moved[cards[uid]] = old_positions[uid]
	_synced = true
	return result

## Rebuilds both walls' chips from the board's improvement models
## ([enemy, own] lists of {oid, card, charges, cd, has_active, ready}),
## keeping chips by oid: new ones scale in (after the first sync), removed
## ones fade out.
func _sync_chips(rows: Array) -> void:
	var seen: Dictionary = {}
	for side in range(2):
		var fresh: Array = []
		var models: Array = rows[side] if side < rows.size() else []
		for model in models:
			var oid = int(model.get("oid", -1))
			seen[oid] = true
			var chip_node: Control = chips.get(oid)
			if chip_node == null:
				chip_node = ImprovementChip.new()
				add_child(chip_node)
				move_child(chip_node, towers.size())
				chip_node.changed.connect(_chip_marks.queue_redraw)
				chips[oid] = chip_node
				if _synced and not AnimationQueue.instant and is_inside_tree():
					chip_node.set_meta("pop", 0.0)
					var tween = chip_node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					tween.tween_method(_set_chip_pop.bind(chip_node), 0.0, 1.0, AnimationQueue.duration(0.35))
			chip_node.apply(model, side == 1)
			fresh.append(chip_node)
		improvement_rows[side] = fresh
	for oid in chips.keys():
		if not seen.has(oid):
			_remove_chip(chips[oid])
			chips.erase(oid)
	_restack_chips()

## Chips in row order behind the hovered one, which is drawn last of them;
## their marks pass stays above every chip.
func _restack_chips() -> void:
	var index = towers.size()
	for side in range(2):
		for chip_node in improvement_rows[side]:
			if chip_node != hovered_chip:
				move_child(chip_node, index)
				index += 1
	if is_instance_valid(hovered_chip) and hovered_chip.get_parent() == self:
		move_child(hovered_chip, index)
		index += 1
	for more in more_chips:
		move_child(more, index)
		index += 1
	move_child(_chip_marks, index)
	_chip_marks.queue_redraw()

func _set_chip_pop(value: float, chip_node: Control) -> void:
	if is_instance_valid(chip_node):
		chip_node.set_meta("pop", value)
		_layout_chips()

func _remove_chip(chip_node: Control) -> void:
	chip_node.gone = true
	if hovered_chip == chip_node:
		hovered_chip = null
	_chip_marks.queue_redraw()
	chip_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_node.set_target_state(0)
	if AnimationQueue.instant or not is_inside_tree() or not chip_node.visible:
		UiKit.discard(chip_node)
		return
	var tween = chip_node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(chip_node, "modulate:a", 0.0, AnimationQueue.duration(0.35))
	tween.tween_property(chip_node, "scale", chip_node.scale * 1.45, AnimationQueue.duration(0.35))
	tween.chain().tween_callback(chip_node.queue_free)

## The improvement chip `oid` shown in this lane (null when there is none).
func chip(oid: int) -> Control:
	return chips.get(oid)

## The improvement chip under `global_point` (visible, staying), or null.
## Overlapping chips (an open row) prefer the hovered one, then the nearest.
func improvement_at(global_point: Vector2) -> Control:
	if is_instance_valid(hovered_chip) and _chip_hit(hovered_chip, global_point) >= 0.0:
		return hovered_chip
	var best: Control = null
	var best_distance = INF
	for side in range(2):
		for chip_node in improvement_rows[side]:
			var distance = _chip_hit(chip_node, global_point)
			if distance >= 0.0 and distance < best_distance:
				best = chip_node
				best_distance = distance
	return best

## Distance from a shown chip's centre to `global_point` (local units) when
## the point is on it, else -1.
func _chip_hit(chip_node: Control, global_point: Vector2) -> float:
	if not chip_node.visible or chip_node.gone or chip_node.modulate.a < 0.5:
		return -1.0
	var local = chip_node.get_global_transform().affine_inverse() * global_point
	var distance = local.distance_to(ImprovementChip.SIZE * 0.5)
	return distance if distance <= ImprovementChip.RADIUS + 3.0 else -1.0

## True when `global_point` is on a wall's "+n" chip (lane view, not the
## overview's count chip).
func more_at(global_point: Vector2) -> bool:
	for more in more_chips:
		if more.visible and more.count > 0 and not more.summary and more.modulate.a >= 0.5:
			var local = more.get_global_transform().affine_inverse() * global_point
			if local.distance_to(ImprovementChip.SIZE * 0.5) <= ImprovementChip.RADIUS + 3.0:
				return true
	return false

## True when `global_point` is on, or within `margin` of, a shown chip.
func chip_rows_contain(global_point: Vector2, margin: float) -> bool:
	for side in range(2):
		for chip_node in improvement_rows[side]:
			if chip_node.visible and not chip_node.gone and chip_node.get_global_rect().grow(margin).has_point(global_point):
				return true
	return false

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
	return slot_rect(slot.column, true)

# --- Staging -------------------------------------------------------------------

## Shows the units entering this lane in the staging strip. `enemy` and
## `own` are entries {key, card_id, uid, kind, movable, selected, hidden,
## model}; existing cards are kept by key. A new entry whose key is in
## `arrive_from` (a global point) flies in from there.
func set_staged(enemy: Array, own: Array, arrive_from: Dictionary = {}) -> void:
	var old: Dictionary = {}
	for side in range(2):
		for entry in staged[side]:
			old[entry.key] = entry
	var lists = [enemy, own]
	var fresh: Array = [[], []]
	var moves: Array = []
	for side in range(2):
		var reflow = lists[side].size() != staged[side].size()
		for index in range(lists[side].size()):
			var spec: Dictionary = lists[side][index]
			var entry: Dictionary = old.get(spec.key, {})
			old.erase(spec.key)
			if entry.is_empty():
				entry = {"t": 1.0, "h": 0.0, "card": _make_stage_card()}
				if arrive_from.has(spec.key) and not AnimationQueue.instant:
					entry.from = {"center": get_global_transform().affine_inverse() * Vector2(arrive_from[spec.key]),
						"rotation": 0.0, "scale": STAGE_SCALE * 0.9}
					entry.t = 0.0
					moves.append([entry, 0.25])
			elif reflow or staged[side].find(entry) != index:
				if _begin_move(entry):
					moves.append([entry, 0.2])
			for field in spec:
				entry[field] = spec[field]
			_apply_stage_card(entry)
			fresh[side].append(entry)
	for key in old:
		_discard_entry(old[key])
	staged = fresh
	for move in moves:
		_tween_entry(move[0], move[1])
	_restack_staged()
	_set_staging_target(0.0 if staged_cards().is_empty() else 1.0)
	_update_processing()
	layout()

func _make_stage_card() -> Control:
	var card = UnitCard.new()
	card.floating = 1.0
	card.preview_hidden = true
	card.scale = Vector2.ONE * STAGE_SCALE
	add_child(card)
	return card

func _apply_stage_card(entry: Dictionary) -> void:
	var card: Control = entry.card
	if card.model != entry.model:
		card.apply(entry.model)
	card.target_state = 3 if entry.get("selected", false) else (4 if entry.get("movable", false) else 0)
	card.visible = not entry.get("hidden", false)
	card.queue_redraw()

## Prepares easing `entry` from where it is drawn now to its (new) fan slot;
## false when it should simply jump (instant mode, no card yet).
func _begin_move(entry: Dictionary) -> bool:
	if AnimationQueue.instant or not is_instance_valid(entry.get("card")) or not is_inside_tree():
		return false
	var card: Control = entry.card
	entry.from = {"center": card.position + UnitCard.SIZE * 0.5, "rotation": card.rotation, "scale": card.scale.x}
	entry.t = 0.0
	return true

func _tween_entry(entry: Dictionary, seconds: float) -> void:
	if entry.get("tween") is Tween and entry.tween.is_valid():
		entry.tween.kill()
	if not is_inside_tree():
		entry.t = 1.0
		return
	var tween = create_tween()
	tween.tween_method(_set_entry_progress.bind(entry, "t"), float(entry.get("t", 0.0)), 1.0, AnimationQueue.duration(seconds))
	entry.tween = tween

## Tween step for an entry's arrival (`t`) or hover (`h`) progress.
func _set_entry_progress(value: float, entry: Dictionary, field: String) -> void:
	entry[field] = value
	if not is_processing():
		_layout_staged()

func _discard_entry(entry: Dictionary) -> void:
	if entry.get("tween") is Tween and entry.tween.is_valid():
		entry.tween.kill()
	if entry.get("hover_tween") is Tween and entry.hover_tween.is_valid():
		entry.hover_tween.kill()
	if is_instance_valid(entry.get("card")):
		UiKit.discard(entry.card)

## Staged cards stay above the unit cards, back to front, the hovered one last.
func _restack_staged() -> void:
	var hovered_card: Control = null
	for side in range(2):
		for entry in staged[side]:
			if is_instance_valid(entry.card):
				move_child(entry.card, -1)
				if entry.key == hovered_key:
					hovered_card = entry.card
	if hovered_card != null:
		move_child(hovered_card, -1)

## Opens or closes the staging strip, sliding the rows aside.
func _set_staging_target(target: float) -> void:
	if is_equal_approx(_staging_target, target):
		return
	_staging_target = target
	if _staging_tween != null and _staging_tween.is_valid():
		_staging_tween.kill()
	if AnimationQueue.instant or not is_inside_tree() or zoom < 0.99:
		staging = target
		return
	_staging_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_staging_tween.tween_method(set_staging, staging, target, AnimationQueue.duration(0.2))

## Sets the reserved strip (tweened by the reveal) and lays the lane out.
func set_staging(value: float) -> void:
	staging = value
	_update_processing()
	layout()

## Tweens the strip closed (the reveal's re-centre); returns the tween.
func close_staging(seconds: float) -> Tween:
	_staging_target = 0.0
	if _staging_tween != null and _staging_tween.is_valid():
		_staging_tween.kill()
	if seconds <= 0.0 or not is_inside_tree():
		set_staging(0.0)
		return null
	_staging_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_staging_tween.tween_method(set_staging, staging, 0.0, seconds)
	return _staging_tween

func _hover_changed() -> void:
	for side in range(2):
		for entry in staged[side]:
			var target = 1.0 if entry.key == hovered_key else 0.0
			if is_equal_approx(float(entry.get("h", 0.0)), target):
				continue
			if entry.get("hover_tween") is Tween and entry.hover_tween.is_valid():
				entry.hover_tween.kill()
			if AnimationQueue.instant or not is_inside_tree():
				entry.h = target
				continue
			var tween = create_tween()
			tween.tween_method(_set_entry_progress.bind(entry, "h"), float(entry.get("h", 0.0)), target, AnimationQueue.duration(0.12))
			entry.hover_tween = tween
	_restack_staged()
	_layout_staged()

## Every staged card, enemy then own, back to front.
func staged_cards() -> Array:
	var result: Array = []
	for side in range(2):
		for entry in staged[side]:
			if is_instance_valid(entry.get("card")):
				result.append(entry.card)
	return result

func staged_entry(key: String) -> Dictionary:
	for side in range(2):
		for entry in staged[side]:
			if entry.key == key:
				return entry
	return {}

func _staged_side_index(key: String) -> Vector2i:
	for side in range(2):
		for index in range(staged[side].size()):
			if staged[side][index].key == key:
				return Vector2i(side, index)
	return Vector2i(-1, -1)

## Global resting centre of a staged entry (without the bob).
func staged_global_center(key: String) -> Vector2:
	var at = _staged_side_index(key)
	if at.x == -1:
		return get_global_transform() * fan_center(1, staged[1].size(), staged[1].size() + 1)
	var center = fan_center(at.x, at.y, staged[at.x].size()) - Vector2(0, LIFT)
	return get_global_transform() * center

## Global centre where the next own staged card would rest (drop targets).
func stage_anchor(side: int) -> Vector2:
	var count = staged[side].size() + 1
	return get_global_transform() * (fan_center(side, count - 1, count) - Vector2(0, LIFT))

func set_staged_hidden(key: String, hidden: bool) -> void:
	var entry = staged_entry(key)
	if entry.is_empty():
		return
	entry.hidden = hidden
	_apply_stage_card(entry)

## Marks the staged hero `uid` as selected (stronger glow); -1 clears.
func select_staged(uid: int) -> void:
	for entry in staged[1]:
		if entry.get("kind", "") == "hero":
			entry.selected = int(entry.uid) == uid
			_apply_stage_card(entry)

## Nothing moves any more (the player confirmed or the reveal started).
func lock_staging() -> void:
	hovered_key = ""
	for side in range(2):
		for entry in staged[side]:
			entry.movable = false
			entry.selected = false
			entry.hidden = false
			_apply_stage_card(entry)

## The movable own staged hero under `global_point` (front to back), or -1.
func staged_hero_at(global_point: Vector2) -> int:
	var entry = _staged_at(global_point, true)
	return int(entry.uid) if not entry.is_empty() else -1

## Any staged entry under `global_point` (creeps and enemy units included).
func staged_at(global_point: Vector2) -> Dictionary:
	return _staged_at(global_point, false)

func _staged_at(global_point: Vector2, movable_heroes: bool) -> Dictionary:
	var order: Array = []
	for side in [1, 0]:
		var entries: Array = staged[side].duplicate()
		entries.reverse()
		order.append_array(entries)
	for index in range(order.size()):
		if order[index].key == hovered_key:
			order.push_front(order.pop_at(index))
			break
	for entry in order:
		if movable_heroes and (entry.get("kind", "") != "hero" or not entry.get("movable", false)):
			continue
		var card: Control = entry.card
		if not is_instance_valid(card) or not card.visible:
			continue
		var local = card.get_global_transform().affine_inverse() * global_point
		if Rect2(Vector2.ZERO, UnitCard.SIZE).has_point(local):
			return entry
	return {}

## Removes the staged entry `key` and returns its card (still parented), so
## the reveal can fly it into place; null when there is none.
func take_staged(key: String) -> Control:
	var at = _staged_side_index(key)
	if at.x == -1:
		return null
	return _take(at.x, at.y)

## Takes the front-most staged entry of `kind` on `side` (creeps are
## interchangeable; enemy heroes are matched the same way).
func take_staged_kind(side: int, kind: String) -> Control:
	for index in range(staged[side].size() - 1, -1, -1):
		if staged[side][index].get("kind", "") == kind:
			return _take(side, index)
	return null

func _take(side: int, index: int) -> Control:
	var entry: Dictionary = staged[side][index]
	if entry.get("tween") is Tween and entry.tween.is_valid():
		entry.tween.kill()
	if entry.get("hover_tween") is Tween and entry.hover_tween.is_valid():
		entry.hover_tween.kill()
	staged[side].remove_at(index)
	for other in staged[side]:
		if _begin_move(other):
			_tween_entry(other, 0.2)
	if hovered_key == entry.key:
		hovered_key = ""
	return entry.card

## Reveal: an enemy hero enters the enemy staging fan from `from_global`
## (its card in the opponent strip, drawn at `from_scale`).
func stage_enemy_hero(uid: int, model: Dictionary, from_global: Vector2, from_scale: float) -> void:
	var entry = {"key": "h%d" % uid, "card_id": str(model.get("unit", {}).get("card", "")), "uid": uid, "kind": "hero",
		"movable": false, "selected": false, "hidden": false, "model": model, "t": 1.0, "h": 0.0, "card": _make_stage_card()}
	for other in staged[0]:
		if _begin_move(other):
			_tween_entry(other, 0.2)
	staged[0].append(entry)
	if not AnimationQueue.instant and is_inside_tree():
		entry.from = {"center": get_global_transform().affine_inverse() * from_global, "rotation": 0.0, "scale": from_scale}
		entry.t = 0.0
		_tween_entry(entry, 0.45)
	_apply_stage_card(entry)
	_restack_staged()
	_update_processing()
	layout()

## Frees every staged card and closes the strip at once.
func clear_staging() -> void:
	for side in range(2):
		for entry in staged[side]:
			_discard_entry(entry)
	staged = [[], []]
	hovered_key = ""
	if _staging_tween != null and _staging_tween.is_valid():
		_staging_tween.kill()
	_staging_target = 0.0
	staging = 0.0
	_update_processing()
	layout()

## Clears the reveal visuals: candidate outlines, highlight, slabs, flights.
func reset_reveal() -> void:
	candidates = [[], []]
	candidate_alpha = 0.0
	roulette = {}
	slabs = []
	slab_t = 0.0
	slab_alpha = 1.0
	flying.clear()
	preview_hidden = false
	queue_redraw()

## Pathing slabs for the reveal: every unit with nothing opposite it gets a
## slab in that empty cell, showing where it will attack.
func build_slabs(models: Dictionary) -> void:
	slabs = []
	for side in range(2):
		for column in range(columns[side].size()):
			var uid = int(columns[side][column])
			if uid == -1 or column >= columns[1 - side].size() or int(columns[1 - side][column]) != -1:
				continue
			slabs.append({"column": column, "attacker_own": side == 1, "arrow": int(models.get(uid, {}).get("arrow", 0))})
	slab_t = 0.0
	slab_alpha = 1.0

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
	var enemy_ground = UiKit.ui_art("board_lane_enemy")
	var own_ground = UiKit.ui_art("board_lane_player")
	var painted = enemy_ground != null and own_ground != null
	if painted:
		_draw_ground(table, radius, enemy_ground, own_ground)
	else:
		_textured(points, UiKit.WOOD_DARK, 760.0, Color(1.42, 1.28, 1.1))
	# Ink-wash shading: warm toward the enemy, cool toward the viewer.
	UiKit.draw_vgradient(self, Rect2(table.position, Vector2(table.size.x, table.size.y * 0.5)),
		Color(0.22, 0.08, 0.05, 0.35), Color(0.1, 0.08, 0.06, 0.0))
	UiKit.draw_vgradient(self, Rect2(table.position + Vector2(0, table.size.y * 0.5), Vector2(table.size.x, table.size.y * 0.5)),
		Color(0.04, 0.09, 0.1, 0.0), Color(0.02, 0.1, 0.11, 0.35))
	if not painted:
		_draw_mountains(table)
	_draw_wall(table, false)
	_draw_wall(table, true)
	_draw_river(table)
	_draw_ghost_slots()
	_draw_reveal()
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

## The battlefield ground (assets/art/ui/board_lane_*): the enemy's half,
## darker and colder, above the river and yours below, each painting
## cover-fitted with its outer edge (banner, palisade) toward the walls and
## dimmed so the cards stay readable.
func _draw_ground(table: Rect2, radius: float, enemy_ground: Texture2D, own_ground: Texture2D) -> void:
	var middle = river_y()
	var top = Rect2(table.position, Vector2(table.size.x, middle - table.position.y))
	var bottom = Rect2(Vector2(table.position.x, middle), Vector2(table.size.x, table.end.y - middle))
	UiKit.draw_cover_polygon(self, _half_points(top, radius, true), top, enemy_ground, Vector2(0.5, 0.2), Color(0.58, 0.56, 0.56))
	UiKit.draw_cover_polygon(self, _half_points(bottom, radius, false), bottom, own_ground, Vector2(0.5, 0.8), Color(0.66, 0.64, 0.6))

## A rectangle with its top (or bottom) corners rounded: half of the table.
func _half_points(rect: Rect2, radius: float, round_top: bool) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 6
	if round_top:
		for step in range(steps + 1):
			var angle = PI + PI * 0.5 * step / steps
			points.append(rect.position + Vector2(radius, radius) + Vector2(cos(angle), sin(angle)) * radius)
		for step in range(steps + 1):
			var angle = PI * 1.5 + PI * 0.5 * step / steps
			points.append(Vector2(rect.end.x - radius, rect.position.y + radius) + Vector2(cos(angle), sin(angle)) * radius)
		points.append(rect.end)
		points.append(Vector2(rect.position.x, rect.end.y))
	else:
		points.append(rect.position)
		points.append(Vector2(rect.end.x, rect.position.y))
		for step in range(steps + 1):
			var angle = PI * 0.5 * step / steps
			points.append(rect.end - Vector2(radius, radius) + Vector2(cos(angle), sin(angle)) * radius)
		for step in range(steps + 1):
			var angle = PI * 0.5 + PI * 0.5 * step / steps
			points.append(Vector2(rect.position.x + radius, rect.end.y - radius) + Vector2(cos(angle), sin(angle)) * radius)
	return points

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
	var art = UiKit.ui_art("board_river")
	if art != null:
		_draw_river_art(art, table, center_y)
	else:
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
	var font_size = int(lerpf(22.0, 17.0, zoom))
	var text_width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var label_center = Vector2(band.position.x + lerpf(70.0, 12.0, zoom) + stage_reserve() + text_width * 0.5, center_y)
	# A dark outline keeps the name readable on the painted river.
	UiKit.draw_text(self, font, label, label_center, font_size, Color(UiKit.GOLD_BRIGHT, 0.95 if active else 0.85), -1.0, 4,
		Color(0.02, 0.02, 0.03, 0.9))

## The painted river (assets/art/ui/board_river): the water and both banks
## from the middle of the painting, repeated across the lane with every
## other copy mirrored (no seams), its banks fading into the ground.
func _draw_river_art(art: Texture2D, table: Rect2, center_y: float) -> void:
	var height = lerpf(58.0, 30.0, zoom)
	var top_v = 0.25
	var bottom_v = 0.71
	var art_size = art.get_size()
	var tile = height * art_size.x / (art_size.y * (bottom_v - top_v))
	var rows = [[0.0, 0.0], [0.24, 1.0], [0.76, 1.0], [1.0, 0.0]]
	var left = table.position.x + 2.0
	var right = table.end.x - 2.0
	var tint = Color(0.78, 0.82, 0.84)
	var index = 0
	var x = left
	while x < right:
		var width = minf(tile, right - x)
		var u0 = 0.0
		var u1 = width / tile
		if index % 2 == 1:
			u0 = 1.0
			u1 = 1.0 - width / tile
		for row in range(3):
			var y0 = center_y - height * 0.5 + height * rows[row][0]
			var y1 = center_y - height * 0.5 + height * rows[row + 1][0]
			var v0 = lerpf(top_v, bottom_v, rows[row][0])
			var v1 = lerpf(top_v, bottom_v, rows[row + 1][0])
			var a0 = Color(tint, rows[row][1])
			var a1 = Color(tint, rows[row + 1][1])
			draw_polygon(PackedVector2Array([Vector2(x, y0), Vector2(x + width, y0), Vector2(x + width, y1), Vector2(x, y1)]),
				PackedColorArray([a0, a0, a1, a1]),
				PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]), art)
		x += width
		index += 1

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

## Reveal visuals: candidate slot outlines with a chevron toward the river,
## the deciding highlight and the pathing slabs.
func _draw_reveal() -> void:
	if candidate_alpha > 0.0:
		for side in range(2):
			for column in candidates[side]:
				var rect = slot_rect(column, side == 1)
				UiKit.draw_round_rect(self, rect, Color(UiKit.PLAYABLE, 0.05 * candidate_alpha), 8.0 * _scale,
					Color(UiKit.PLAYABLE, 0.55 * candidate_alpha), 2.0)
				_chevron(rect.get_center(), -1.0 if side == 1 else 1.0, 9.0 * _scale / 0.72, Color(UiKit.PLAYABLE, 0.6 * candidate_alpha))
	if not roulette.is_empty():
		var rect = slot_rect(roulette.column, int(roulette.side) == 1)
		if roulette.get("landing", false):
			UiKit.draw_round_rect(self, rect, Color(UiKit.PLAYABLE, 0.28), 8.0 * _scale, Color(UiKit.PLAYABLE.lightened(0.4), 1.0), 3.0)
		else:
			UiKit.draw_round_rect(self, rect, Color(UiKit.PLAYABLE, 0.14), 8.0 * _scale, Color(UiKit.PLAYABLE, 0.95), 2.5)
		UiKit.draw_glow(self, rect, 8.0 * _scale, UiKit.PLAYABLE, 1.0 if roulette.get("landing", false) else 0.6)
	for slab in slabs:
		_draw_slab(slab)

## A small chevron pointing up (direction -1) or down (+1).
func _chevron(center: Vector2, direction: float, arm: float, color: Color) -> void:
	var tip = center + Vector2(0, direction * arm * 0.6)
	draw_polyline(PackedVector2Array([tip + Vector2(-arm, -direction * arm), tip, tip + Vector2(arm, -direction * arm)]), color, 3.0, true)

## A pathing slab: drops into the empty cell across from an unblocked unit,
## flips over to show where that unit will attack, then fades.
func _draw_slab(slab: Dictionary) -> void:
	var own = bool(slab.attacker_own)
	var center = slot_center(slab.column, not own)
	var card_size = UnitCard.SIZE * _scale * 0.86
	var drop = clampf(slab_t / 0.4, 0.0, 1.0)
	var flip = clampf((slab_t - 0.4) / 0.3, 0.0, 1.0)
	var grow = lerpf(1.25, 1.0, drop)
	var alpha = drop * slab_alpha
	if alpha <= 0.0:
		return
	var squash = absf(cos(flip * PI)) if flip > 0.0 and flip < 1.0 else 1.0
	draw_set_transform(center, 0.0, Vector2(grow * squash, grow))
	var rect = Rect2(-card_size * 0.5, card_size)
	UiKit.draw_round_rect(self, rect, Color(0.07, 0.07, 0.08, 0.92 * alpha), 7.0 * _scale, Color(UiKit.GOLD_DARK, alpha), 2.0)
	var tint = UiKit.PAPER if own else ENEMY_ARROW_TINT
	if flip < 0.5:
		UiKit.draw_text(self, UiKit.bold_font(), "▼", Vector2.ZERO, int(28.0 * _scale / 0.72), Color(UiKit.GOLD, 0.8 * alpha))
	else:
		var direction = Vector2(int(slab.arrow), -1.0 if own else 1.0).normalized()
		var length = card_size.y * 0.32
		var tail = -direction * length
		var tip = direction * length
		var side = direction.orthogonal() * length * 0.45
		var neck = tip - direction * length * 0.55
		draw_line(tail, neck, Color(tint, alpha), maxf(3.0, 7.0 * _scale), true)
		draw_colored_polygon(PackedVector2Array([tip, neck + side, neck - side]), Color(tint, alpha))
	draw_set_transform(Vector2.ZERO)
