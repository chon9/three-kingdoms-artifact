extends "res://scripts/ui/modal_panel.gd"
## Every supported hero and card as localized card faces, heroes first, then
## by colour, kind and cost. Filter buttons narrow the grid to one colour (a
## faction in the Three Kingdoms skin). Click a card to inspect it in the
## dialog's own inspector.

const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const InspectOverlay = preload("res://scripts/ui/inspect_overlay.gd")
const CARD_SIZE = Vector2(150, 218)
## Filter keys: "all", a card colour, or "neutral" (items and colourless units).
const FILTERS = ["all", "red", "green", "blue", "black", "neutral"]
const COLOR_RANK = {"red": 0, "green": 1, "blue": 2, "black": 3, "neutral": 4, "item": 5}
const KIND_RANK = {"hero": 0, "creep": 1, "spell": 2, "improvement": 3, "item": 4}
## Filter label keys per skin: colours in the classic skin, the matching
## factions in the Three Kingdoms skin.
const CLASSIC_LABELS = {"all": "CATALOG_FILTER_ALL", "red": "COLOR_RED", "green": "COLOR_GREEN", "blue": "COLOR_BLUE",
	"black": "COLOR_BLACK", "neutral": "COLOR_NEUTRAL"}
const FACTION_LABELS = {"all": "CATALOG_FILTER_ALL", "red": "FACTION_SHU", "green": "FACTION_WU", "blue": "FACTION_WEI",
	"black": "FACTION_QUN", "neutral": "FACTION_NEUTRAL"}

var library = Library.new()
var grid: GridContainer
var count_label: Label
var cards: Array = []
var filter_buttons: Dictionary = {}
var current_filter: String = "all"
var inspector: Control

func _init() -> void:
	super()
	title_key = "CATALOG_TITLE"
	panel_size = Vector2(1240, 820)

func build() -> void:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	var group = ButtonGroup.new()
	for key in FILTERS:
		var entry = button(header, "", 16)
		entry.name = "Filter_" + key
		entry.toggle_mode = true
		entry.button_group = group
		entry.button_pressed = key == current_filter
		entry.pressed.connect(apply_filter.bind(key))
		filter_buttons[key] = entry
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	count_label = label(header, "", 15, UiKit.MUTED)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	for card_id in definitions(library):
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

## Every hero and card id of the pack in display order: heroes first, then
## colour (red, green, blue, black, neutral, items), kind, cost and id.
static func definitions(pack) -> Array:
	var ids: Array = []
	for hero in pack.heroes:
		ids.append(str(hero.id))
	for card_id in pack.cards:
		ids.append(str(card_id))
	var keys: Dictionary = {}
	for card_id in ids:
		var entry: Dictionary = pack.definition(card_id)
		keys[card_id] = [int(KIND_RANK.get(str(entry.get("kind", "")), 9) == 0) * -1, int(bool(entry.get("token", false))),
			int(COLOR_RANK.get(str(entry.get("color", "neutral")), 9)), int(KIND_RANK.get(str(entry.get("kind", "")), 9)),
			int(entry.get("cost", 0)), card_id]
	ids.sort_custom(func(a, b): return keys[a] < keys[b])
	return ids

## The filter a card belongs to ("neutral" for items and colourless units).
static func filter_of(card_id: String) -> String:
	var color = str(Library.raw_definition(card_id).get("color", "neutral"))
	return color if color in FILTERS else "neutral"

func apply_filter(key: String) -> void:
	current_filter = key if key in FILTERS else "all"
	var shown = 0
	for card in cards:
		card.visible = current_filter == "all" or filter_of(card.card_id) == current_filter
		shown += int(card.visible)
	for filter in filter_buttons:
		filter_buttons[filter].set_pressed_no_signal(filter == current_filter)
	count_label.text = UiKit.t("CATALOG_COUNT", {"n": shown})

func inspect(card_id: String) -> void:
	inspector.show_card(card_id)

func refresh_text() -> void:
	super()
	var labels = FACTION_LABELS if Library.current_skin() == "three_kingdoms" else CLASSIC_LABELS
	for key in filter_buttons:
		filter_buttons[key].text = UiKit.t(labels[key])
	for card in cards:
		card.refresh()
	apply_filter(current_filter)
	if inspector != null:
		inspector.refresh_text()
