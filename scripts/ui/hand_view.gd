extends Control
## The viewer's hand: an overlapping fan of full card faces along the bottom
## edge. Hovering lifts and enlarges a card; playable cards glow and the
## others are dimmed with a tooltip reason. Play logic lives in the match
## screen: the hand reports presses and exposes card geometry.

signal card_pressed(index: int, button: int)
signal card_hovered(index: int)

const CardView = preload("res://scripts/ui/card_view.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const CARD_SIZE = Vector2(170, 248)
const VISIBLE = 132.0
const LOWERED_VISIBLE = 74.0
const HOVER_SCALE = 1.34
## Deepest the fan's outer cards sink below the middle ones, so every card
## keeps a readable spine (VISIBLE minus this, minus the tilt).
const MAX_ARC_DROP = 36.0

var cards: Array = []
var ids: Array = []
var hovered: int = -1
## Index lifted out of the fan by a drag or click-hold (-1 for none).
var held: int = -1
var lowered: bool = false
var interactive: bool = true
## Horizontal room for the fan (local x); the match screen keeps it clear of
## the player panel. Negative values fall back to a share of the width.
var fan_left: float = -1.0
var fan_right: float = -1.0
var _tweens: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout(false)

## Rebuilds the hand from card ids, reusing faces for unchanged cards.
## `states[index]` is {"playable": bool, "reason": String}. New cards fly in
## from `origin` (global) when `animate` is true.
func sync(hand: Array, states: Array, origin: Vector2, animate: bool) -> void:
	var old_cards = cards.duplicate()
	var old_ids = ids.duplicate()
	var used: Dictionary = {}
	var new_cards: Array = []
	var fresh: Array = []
	for index in range(hand.size()):
		var card_id = str(hand[index])
		var reused: Control = null
		for old_index in range(old_ids.size()):
			if not used.has(old_index) and old_ids[old_index] == card_id and is_instance_valid(old_cards[old_index]):
				reused = old_cards[old_index]
				used[old_index] = true
				break
		if reused == null:
			reused = _make_card(card_id)
			fresh.append(reused)
		new_cards.append(reused)
	for old_index in range(old_cards.size()):
		if not used.has(old_index) and is_instance_valid(old_cards[old_index]):
			UiKit.discard(old_cards[old_index])
	cards = new_cards
	ids = hand.duplicate()
	hovered = -1
	held = -1
	for index in range(cards.size()):
		var card: Control = cards[index]
		var state: Dictionary = states[index] if index < states.size() else {}
		card.playable = state.get("playable", false) and interactive
		card.dimmed = not state.get("playable", false) and state.has("reason")
		card.tooltip_text = state.get("reason", "")
		card.hovered = false
		card.selected = false
		card.visible = true
		move_child(card, index)
	for card in fresh:
		if animate and not AnimationQueue.instant:
			card.position = get_global_transform().affine_inverse() * origin - CARD_SIZE * 0.5
			card.scale = Vector2(0.45, 0.45)
			card.rotation = 0.0
	layout(animate)

func _make_card(card_id: String) -> Control:
	var card = CardView.new()
	card.setup(card_id)
	card.size = CARD_SIZE
	card.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	add_child(card)
	card.mouse_entered.connect(_on_enter.bind(card))
	card.mouse_exited.connect(_on_exit.bind(card))
	card.gui_input.connect(_on_card_input.bind(card))
	return card

func refresh_text() -> void:
	for card in cards:
		card.refresh()

## Where card `index` rests in the fan (local position, rotation, scale).
func slot(index: int) -> Dictionary:
	var count = cards.size()
	var left = fan_left if fan_left >= 0.0 else size.x * 0.1
	var right = fan_right if fan_right > left else size.x * 0.73
	var max_span = maxf(0.0, right - left - CARD_SIZE.x)
	var spacing = minf(CARD_SIZE.x * 0.8, max_span / maxf(1.0, count - 1))
	var center_x = (left + right) * 0.5
	var offset = index - (count - 1) * 0.5
	var half = maxf(1.0, (count - 1) * 0.5)
	var arc = minf(2.4, MAX_ARC_DROP / (half * half))
	var visible_height = LOWERED_VISIBLE if lowered else VISIBLE
	var position = Vector2(center_x + offset * spacing - CARD_SIZE.x * 0.5,
		size.y - visible_height + offset * offset * arc)
	var rotation_value = deg_to_rad(offset * minf(1.0, 6.0 / half))
	var scale_value = 1.0
	if hovered != -1 and hovered != held and not lowered:
		if index == hovered:
			position = Vector2(center_x + offset * spacing - CARD_SIZE.x * 0.5, size.y - CARD_SIZE.y - 10)
			rotation_value = 0.0
			scale_value = HOVER_SCALE
		else:
			position.x += signf(index - hovered) * minf(70.0, CARD_SIZE.x * HOVER_SCALE * 0.5 - spacing * 0.4 + 10.0)
	return {"position": position, "rotation": rotation_value, "scale": scale_value}

func layout(animate: bool = true) -> void:
	for index in range(cards.size()):
		if index == held:
			continue
		var card: Control = cards[index]
		var target = slot(index)
		var key = card.get_instance_id()
		if _tweens.has(key) and _tweens[key].is_valid():
			_tweens[key].kill()
		if not animate or AnimationQueue.instant or not is_inside_tree():
			card.position = target.position
			card.rotation = target.rotation
			card.scale = Vector2.ONE * target.scale
			continue
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var time = AnimationQueue.duration(0.22)
		tween.tween_property(card, "position", target.position, time)
		tween.tween_property(card, "rotation", target.rotation, time)
		tween.tween_property(card, "scale", Vector2.ONE * target.scale, time)
		_tweens[key] = tween
	_restack()

func _restack() -> void:
	for index in range(cards.size()):
		move_child(cards[index], index)
	if hovered >= 0 and hovered < cards.size():
		move_child(cards[hovered], -1)
	if held >= 0 and held < cards.size():
		move_child(cards[held], -1)

func stop_tween(card: Control) -> void:
	var key = card.get_instance_id()
	if _tweens.has(key) and _tweens[key].is_valid():
		_tweens[key].kill()
	_tweens.erase(key)

func set_lowered(value: bool) -> void:
	if lowered != value:
		lowered = value
		layout(true)

func card_index(card: Control) -> int:
	return cards.find(card)

## Global point on card `index`'s visible spine as it rests in the fan (the
## part not covered by the next card), near the top where its name shows.
func card_center(index: int) -> Vector2:
	if index < 0 or index >= cards.size():
		return Vector2.ZERO
	var target = slot(index)
	var strip = CARD_SIZE.x
	if index + 1 < cards.size():
		strip = minf(CARD_SIZE.x, slot(index + 1).position.x - target.position.x)
	return get_global_transform() * _slot_point(target, Vector2(strip * 0.5, 40.0))

## Where local point `local` of a card resting in `target` ends up (the card
## turns and scales around its bottom centre).
func _slot_point(target: Dictionary, local: Vector2) -> Vector2:
	var pivot = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	return target.position + pivot + ((local - pivot) * target.scale).rotated(target.rotation)

## Height of card `index`'s face left showing above the bottom edge.
func visible_height(index: int) -> float:
	var target = slot(index)
	var lowest_top = maxf(_slot_point(target, Vector2.ZERO).y, _slot_point(target, Vector2(CARD_SIZE.x, 0)).y)
	return size.y - lowest_top

func index_at(global_point: Vector2) -> int:
	for index in range(cards.size() - 1, -1, -1):
		var card: Control = cards[index]
		if card.get_global_rect().has_point(global_point):
			return index
	return -1

func set_hovered(index: int) -> void:
	if hovered == index:
		return
	if hovered >= 0 and hovered < cards.size():
		cards[hovered].hovered = false
		cards[hovered].queue_redraw()
	hovered = index
	if index >= 0 and index < cards.size():
		cards[index].hovered = true
		cards[index].queue_redraw()
	layout(true)
	card_hovered.emit(index)

func _on_enter(card: Control) -> void:
	if held == -1 and interactive and not lowered:
		set_hovered(card_index(card))

func _on_exit(card: Control) -> void:
	if held == -1 and card_index(card) == hovered:
		set_hovered(-1)

func _on_card_input(event: InputEvent, card: Control) -> void:
	if event is InputEventMouseButton and event.pressed:
		var index = card_index(card)
		if index != -1:
			card_pressed.emit(index, event.button_index)
			accept_event()
