extends Control
## The shopping phase: an open chest over the dimmed overview with the three
## offers (Secret Shop with HOLD, the item deck with its remaining count, one
## consumable), price coins on the cards, BUY buttons that grey out when you
## cannot afford them, your gold, and a VIEW BOARD toggle. The initiative
## coin finishes shopping. With the art in assets/art/ui/, the chest opens on
## the army market (shop_armory) and the Secret Shop offer stands in its own
## black-market stall (black_market).

signal buy_requested(source: String)
signal hold_requested
signal view_board_toggled(showing_board: bool)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const Library = preload("res://scripts/core/card_library.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const SOURCES = ["secret", "item", "consumable"]
const CHEST_SIZE = Vector2(940, 560)
const CARD_SIZE = Vector2(206, 300)

var chest: Control
var slots: Dictionary = {}
var hold_button: Button
var held_label: Label
var view_board_button: Button
var back_button: Button
var status_label: Label
var showing_board: bool = false
var player: Dictionary = {}
var actions: Array = []
var _gold: int = 0
## Source -> price after the rules layer, from the last sync.
var _prices: Dictionary = {}
var _tween: Tween

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	chest = Chest.new()
	chest.size = CHEST_SIZE
	chest.secret_rect = Rect2(Vector2(58, 100), Vector2(CARD_SIZE.x + 52, CARD_SIZE.y + 104))
	chest.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(chest)
	for index in range(SOURCES.size()):
		var source = SOURCES[index]
		var card = CardView.new()
		card.set_size_keep(CARD_SIZE)
		card.position = Vector2(84 + index * 270, 112)
		chest.add_child(card)
		var buy = _button(Vector2(card.position.x + 18, card.position.y + CARD_SIZE.y + 14), Vector2(CARD_SIZE.x - 36, 42))
		buy.name = "Buy" + source.capitalize()
		buy.pressed.connect(func(): buy_requested.emit(source))
		chest.add_child(buy)
		var label = _label(Vector2(card.position.x - 20, card.position.y + CARD_SIZE.y + 64), Vector2(CARD_SIZE.x + 40, 26), 17, UiKit.PAPER_DIM)
		label.add_theme_font_override("font", UiKit.title_font())
		chest.add_child(label)
		var sold = _label(card.position + Vector2(0, CARD_SIZE.y * 0.42), Vector2(CARD_SIZE.x, 40), 22, UiKit.MUTED)
		sold.add_theme_font_override("font", UiKit.title_font())
		chest.add_child(sold)
		slots[source] = {"card": card, "buy": buy, "label": label, "sold": sold}
	hold_button = _button(Vector2(70, 62), Vector2(176, 38))
	hold_button.name = "Hold"
	hold_button.pressed.connect(func(): hold_requested.emit())
	chest.add_child(hold_button)
	held_label = _label(Vector2(40, 66), Vector2(250, 30), 15, UiKit.GOLD_BRIGHT)
	chest.add_child(held_label)
	status_label = _label(Vector2(0, CHEST_SIZE.y - 46), Vector2(CHEST_SIZE.x, 22), 16, UiKit.PAPER_DIM)
	chest.add_child(status_label)
	view_board_button = _button(Vector2(CHEST_SIZE.x * 0.5 - 110, CHEST_SIZE.y - 22), Vector2(220, 44))
	view_board_button.name = "ViewBoard"
	view_board_button.pressed.connect(func(): set_showing_board(true))
	chest.add_child(view_board_button)
	back_button = Button.new()
	back_button.name = "BackToShop"
	back_button.visible = false
	back_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	back_button.pressed.connect(func(): set_showing_board(false))
	add_child(back_button)

func _button(position_value: Vector2, size_value: Vector2) -> Button:
	var button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.position = position_value
	button.size = size_value
	button.add_theme_font_override("font", UiKit.title_font())
	button.add_theme_font_size_override("font_size", 20)
	return button

func _label(position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()

func _draw() -> void:
	if not showing_board:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.01, 0.5))

func _place() -> void:
	chest.position = Vector2((size.x - CHEST_SIZE.x) * 0.5 - 40.0, 92.0 if not showing_board else size.y + 40.0)
	back_button.size = Vector2(230, 46)
	back_button.position = Vector2((size.x - back_button.size.x) * 0.5 - 40.0, size.y - 214)

## Updates offers and buttons from the viewer's player view and actions.
## `prices` maps a source to its offer's price after the rules layer (a Shop
## Deed discounts the Secret Shop, RQ-26); a missing source shows the printed
## price.
func sync(viewer_state: Dictionary, legal: Array, waiting: bool, prices: Dictionary = {}) -> void:
	player = viewer_state
	actions = legal
	_prices = prices
	_gold = int(viewer_state.get("gold", 0))
	var shop: Dictionary = viewer_state.get("shop", {})
	for source in SOURCES:
		var slot = slots[source]
		var card_id = str(shop.get(source, ""))
		var card: Control = slot.card
		card.visible = not card_id.is_empty()
		slot.sold.visible = card_id.is_empty()
		if not card_id.is_empty():
			card.setup(card_id)
			card.set_size_keep(CARD_SIZE)
		card.price_override = prices.get(source) if not card_id.is_empty() else null
		var affordable = false
		for action in legal:
			if action.get("type", "") == "buy" and action.get("source", "") == source:
				affordable = true
		card.playable = affordable
		card.dimmed = not affordable and not card_id.is_empty()
		slot.buy.disabled = not affordable
		slot.buy.tooltip_text = "" if affordable else (UiKit.t("SHOP_NOT_ENOUGH_GOLD") if not card_id.is_empty() else UiKit.t("SHOP_SOLD"))
	var can_hold = {"type": "hold"} in legal
	var held = not str(viewer_state.get("held_secret", "")).is_empty()
	hold_button.visible = not held
	hold_button.disabled = not can_hold
	held_label.visible = held
	status_label.visible = waiting
	refresh_text()

func refresh_text() -> void:
	var labels = {"secret": UiKit.t("SHOP_SECRET"),
		"item": UiKit.t("SHOP_ITEM_DECK_COUNT", {"n": int(player.get("item_deck_count", 0)), "total": maxi(9, int(player.get("item_deck_count", 0)))}),
		"consumable": UiKit.t("SHOP_CONSUMABLES")}
	var shop: Dictionary = player.get("shop", {})
	for source in SOURCES:
		var slot = slots[source]
		slot.label.text = labels[source]
		# A discounted offer says so under its card: free, or pays gold.
		var card_id = str(shop.get(source, ""))
		if _prices.has(source) and not card_id.is_empty():
			var price = int(_prices[source])
			if price < int(Library.raw_definition(card_id).get("price", 0)):
				var note = UiKit.t("SHOP_PRICE_FREE") if price == 0 else (UiKit.t("SHOP_PRICE_PAYS", {"gold": -price}) if price < 0 else "")
				if not note.is_empty():
					slot.label.text = "%s  ·  %s" % [labels[source], note]
		slot.buy.text = UiKit.t("BTN_BUY")
		slot.sold.text = UiKit.t("SHOP_SOLD")
		slot.card.refresh()
	hold_button.text = UiKit.t("BTN_HOLD", {"n": 1})
	hold_button.tooltip_text = UiKit.t("BTN_HOLD_TOOLTIP", {"n": 1})
	held_label.text = UiKit.t("SHOP_HELD")
	view_board_button.text = UiKit.t("BTN_VIEW_BOARD")
	back_button.text = UiKit.t("BTN_VIEW_SHOP")
	status_label.text = UiKit.t("SHOP_WAITING")
	chest.title = UiKit.t("SHOP_TITLE")
	chest.gold = _gold
	chest.queue_redraw()

func open(animate: bool) -> void:
	visible = true
	showing_board = false
	back_button.visible = false
	_place()
	if animate and not AnimationQueue.instant:
		var rest = chest.position
		chest.position = rest + Vector2(0, 60)
		chest.modulate.a = 0.0
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(chest, "position", rest, AnimationQueue.duration(0.35))
		_tween.parallel().tween_property(chest, "modulate:a", 1.0, AnimationQueue.duration(0.25))
	else:
		chest.modulate.a = 1.0

func close() -> void:
	visible = false
	showing_board = false
	back_button.visible = false

func set_showing_board(value: bool) -> void:
	showing_board = value
	back_button.visible = value and visible
	queue_redraw()
	view_board_toggled.emit(value)
	if AnimationQueue.instant or not is_inside_tree():
		_place()
		return
	var target = Vector2((size.x - CHEST_SIZE.x) * 0.5 - 40.0, 92.0 if not value else size.y + 40.0)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(chest, "position", target, AnimationQueue.duration(0.3))

## Global centre of an offer card (where a bought card leaves from).
func slot_center(source: String) -> Vector2:
	var card: Control = slots[source].card
	return card.get_global_transform() * (card.size * 0.5)

## The chest: a lacquered wooden box with an open lid and gold trim.
class Chest:
	extends Control
	var title: String = ""
	var gold: int = 0
	## The Secret Shop offer's stall (card, BUY button and label).
	var secret_rect: Rect2 = Rect2()

	func _draw() -> void:
		var body = Rect2(0, 40, size.x, size.y - 40)
		draw_colored_polygon(UiKit.round_rect_points(Rect2(body.position + Vector2(0, 14), body.size), 18.0), Color(0, 0, 0, 0.6))
		var wood = UiKit.tex(UiKit.WOOD_WARM)
		var armory = UiKit.ui_art("shop_armory")
		var points = UiKit.round_rect_points(body, 18.0, 5)
		if armory != null:
			UiKit.draw_cover_polygon(self, points, body, armory, Vector2(0.5, 0.55), Color(0.62, 0.58, 0.54))
		elif wood != null:
			var uvs = PackedVector2Array()
			var colors = PackedColorArray()
			for point in points:
				uvs.append(point / 700.0)
				colors.append(Color(0.62, 0.42, 0.3))
			draw_polygon(points, colors, uvs, wood)
		else:
			draw_colored_polygon(points, Color("4a2c1c"))
		# Lid (seen from the front, opened backwards).
		var lid = PackedVector2Array([Vector2(26, 46), Vector2(size.x - 26, 46), Vector2(size.x - 60, 0), Vector2(60, 0)])
		draw_colored_polygon(lid, Color(0.2, 0.11, 0.07))
		draw_polyline(PackedVector2Array([Vector2(26, 46), Vector2(60, 0), Vector2(size.x - 60, 0), Vector2(size.x - 26, 46)]), Color(UiKit.GOLD_DARK, 0.9), 3.0, true)
		# Inner well (the market shows through it when painted).
		var well = Rect2(30, 92, size.x - 60, size.y - 142)
		UiKit.draw_round_rect(self, well, Color(0.07, 0.05, 0.04, 0.5 if armory != null else 0.92), 10.0, Color(UiKit.GOLD_DARK, 0.8), 2.0)
		UiKit.draw_vgradient(self, Rect2(well.position, Vector2(well.size.x, 60)), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0))
		_draw_secret_stall()
		# Gold lattice corners.
		UiKit.draw_ornate(self, Rect2(10, 52, size.x - 20, size.y - 62), 11, Color(UiKit.GOLD, 0.75), 30.0)
		# Title plate and gold.
		var plate = Rect2(size.x * 0.5 - 110, 6, 220, 40)
		UiKit.draw_round_rect(self, plate, Color(0.1, 0.06, 0.04), 6.0, UiKit.GOLD, 2.0)
		UiKit.draw_text(self, UiKit.title_font(), title, plate.get_center(), 26, UiKit.GOLD_BRIGHT)
		var purse = Vector2(size.x - 150, 76)
		UiKit.draw_gold_icon(self, Rect2(purse - Vector2(16, 16), Vector2(32, 32)))
		UiKit.draw_text_left(self, UiKit.bold_font(), str(gold), purse + Vector2(22, 0), 28, UiKit.GOLD_BRIGHT, -1.0, 3)

	## The Secret Shop's stall: a dark alley market behind its offer, framed
	## in Qun purple.
	func _draw_secret_stall() -> void:
		var stall = UiKit.ui_art("black_market")
		if stall == null or secret_rect.size == Vector2.ZERO:
			return
		var points = UiKit.round_rect_points(secret_rect, 10.0, 4)
		draw_colored_polygon(UiKit.round_rect_points(Rect2(secret_rect.position + Vector2(0, 6), secret_rect.size), 10.0), Color(0, 0, 0, 0.5))
		UiKit.draw_cover_polygon(self, points, secret_rect, stall, Vector2(0.62, 0.5), Color(0.8, 0.74, 0.86))
		UiKit.draw_vgradient(self, Rect2(secret_rect.position + Vector2(0, secret_rect.size.y * 0.62), Vector2(secret_rect.size.x, secret_rect.size.y * 0.38)),
			Color(0, 0, 0, 0.0), Color(0.03, 0.01, 0.05, 0.75))
		UiKit.draw_round_rect(self, secret_rect, Color.TRANSPARENT, 10.0, Color(0.62, 0.42, 0.78, 0.9), 2.0)
