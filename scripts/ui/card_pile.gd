extends Control
## Face-down cards on the table: a deck stack with its count (DECK) or the
## opponent's hand as a fan of card backs along the top edge (HAND).

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const DECK = 0
const HAND = 1

var mode: int = DECK
var count: int = 0
var label: String = ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_count(value: int, label_text: String = "") -> void:
	count = value
	label = label_text
	queue_redraw()

## Global point where cards leave or enter this pile.
func origin() -> Vector2:
	if mode == HAND:
		return get_global_transform() * Vector2(size.x * 0.5, 20)
	return get_global_transform() * (size * 0.5)

func _draw() -> void:
	if mode == HAND:
		_draw_hand()
	else:
		_draw_deck()

func _draw_deck() -> void:
	var card_size = Vector2(size.x, size.x * 1.42)
	var layers = clampi(int(ceil(count / 6.0)), 1, 5) if count > 0 else 0
	for layer in range(layers):
		var offset = Vector2(-layer * 1.5, -layer * 2.5)
		var rect = Rect2(Vector2(0, size.y - card_size.y) + offset + Vector2(layers * 1.5, 0), card_size)
		CardView.draw_card_back(self, rect)
	if count == 0:
		UiKit.draw_round_rect(self, Rect2(Vector2(0, size.y - card_size.y), card_size), Color(0, 0, 0, 0.3), 6.0, Color(1, 1, 1, 0.15), 1.0)
	var badge = Vector2(size.x * 0.5, size.y - card_size.y * 0.5)
	UiKit.draw_disc(self, badge, 18.0, Color(0.06, 0.06, 0.07, 0.95), UiKit.GOLD, 2.0)
	UiKit.draw_text(self, UiKit.bold_font(), str(count), badge, 17, UiKit.PAPER)
	if not label.is_empty():
		UiKit.draw_text(self, UiKit.body_font(), label, Vector2(size.x * 0.5, size.y + 12), 13, UiKit.PAPER_DIM, size.x + 30, 2)

func _draw_hand() -> void:
	if count <= 0:
		return
	var card_size = Vector2(58, 84)
	var spacing = minf(40.0, (size.x - card_size.x) / maxf(1.0, count - 1))
	var width = card_size.x + spacing * (count - 1)
	var left = (size.x - width) * 0.5
	for index in range(count):
		var offset = index - (count - 1) * 0.5
		var center = Vector2(left + card_size.x * 0.5 + index * spacing, card_size.y * 0.5 - 26 + absf(offset) * 1.5)
		draw_set_transform(center, deg_to_rad(-offset * 2.5), Vector2.ONE)
		CardView.draw_card_back(self, Rect2(-card_size * 0.5, card_size))
		draw_set_transform(Vector2.ZERO)
