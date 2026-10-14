extends "res://scripts/ui/modal_panel.gd"
## Every supported hero and card as localized card faces. Click a card to
## inspect it in the dialog's own inspector.

const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const InspectOverlay = preload("res://scripts/ui/inspect_overlay.gd")
const CARD_SIZE = Vector2(150, 218)

var library = Library.new()
var grid: GridContainer
var count_label: Label
var cards: Array = []
var inspector: Control

func _init() -> void:
	super()
	title_key = "CATALOG_TITLE"
	panel_size = Vector2(1240, 820)

func build() -> void:
	count_label = label(body, "", 15, UiKit.MUTED)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	var definitions: Array = []
	for hero in library.heroes:
		definitions.append(str(hero.id))
	for card_id in library.cards:
		definitions.append(str(card_id))
	for card_id in definitions:
		var card = CardView.new()
		card.setup(card_id)
		card.set_size_keep(CARD_SIZE)
		card.custom_minimum_size = CARD_SIZE
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				inspect(card_id))
		grid.add_child(card)
		cards.append(card)
	inspector = InspectOverlay.new()
	inspector.name = "Inspector"
	add_child(inspector)
	inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func inspect(card_id: String) -> void:
	inspector.show_card(card_id)

func refresh_text() -> void:
	super()
	count_label.text = UiKit.t("CATALOG_COUNT", {"n": cards.size()})
	for card in cards:
		card.refresh()
	if inspector != null:
		inspector.refresh_text()
