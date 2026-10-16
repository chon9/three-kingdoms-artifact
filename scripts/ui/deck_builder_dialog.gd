extends "res://scripts/ui/modal_panel.gd"
## The deck builder. Left: the collection (every card a deck may hold:
## available heroes, main cards without other heroes' signature cards, and
## equipment) as card faces with their copies in the deck, filtered by colour
## (faction in the Three Kingdoms skin), kind or item slot, mana cost and a
## search of names and rules text in the current language. Right: the deck:
## five hero slots laid out by deploy round (three in round 1, one each in
## rounds 2 and 3; drag heroes to reorder), the main deck grouped by kind and
## the item deck grouped by slot, with copies, - and +, signature cards
## locked to their hero, and the requirement lamps with the first unmet rule.
## Bottom: the mana curve, counts, Save, Play and Back. Messages show as a
## toast over the bottom of the collection.
##
## Click or drag a card to add a copy, drag a row or hero back to the
## collection to remove it, right-click anything to inspect it, hover a row
## to see its card. Clicking an empty hero slot shows the heroes; the next
## hero clicked fills that slot. A preset chosen as a template asks before
## it replaces a deck that holds cards. Codes import from and export to the clipboard (Valve's
## ArtifactDeckCode format, scripts/core/deck_code.gd). Presets serve as
## templates. Edits follow scripts/core/deck_model.gd; the deck rules are
## CardLibrary.deck_issues.

signal saved(deck: Dictionary)
signal play_requested(deck: Dictionary)
signal back_requested(deck_id: String)

const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const InspectOverlay = preload("res://scripts/ui/inspect_overlay.gd")
const CatalogDialog = preload("res://scripts/ui/catalog_dialog.gd")
const DeckCode = preload("res://scripts/core/deck_code.gd")
const DeckStore = preload("res://scripts/core/deck_store.gd")
const DeckModel = preload("res://scripts/core/deck_model.gd")
const Widgets = preload("res://scripts/ui/deck_widgets.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const COLOR_FILTERS = ["all", "red", "green", "blue", "black", "neutral"]
## Kind filters: "item" is every item, the slots narrow it.
const KIND_FILTERS = ["hero", "creep", "spell", "improvement", "item", "weapon", "armor", "accessory"]
const KIND_ICONS = {"hero": "crown_a", "creep": "character", "spell": "book_open", "improvement": "structure_wall",
	"item": "pouch", "weapon": "sword", "armor": "shield", "accessory": "suit_hearts"}
const KIND_KEYS = {"hero": "KIND_HERO", "creep": "KIND_CREEP", "spell": "KIND_SPELL", "improvement": "KIND_IMPROVEMENT",
	"item": "KIND_ITEM", "weapon": "SLOT_WEAPON", "armor": "SLOT_ARMOR", "accessory": "SLOT_ACCESSORY"}
const MAIN_GROUPS = ["creep", "spell", "improvement"]
const ITEM_GROUPS = ["weapon", "armor", "accessory"]
## Requirement lamps and the deck issues that switch each one off.
const REQUIREMENTS = [["DECKB_REQ_HEROES", ["deck_hero_count", "deck_hero_invalid"]],
	["DECKB_REQ_MAIN", ["deck_main_size"]],
	["DECKB_REQ_SIGNATURES", ["deck_signatures", "deck_signature_orphan"]],
	["DECKB_REQ_ITEMS", ["deck_item_size"]],
	["DECKB_REQ_LEGAL", ["deck_main_card", "deck_main_copies", "deck_item_card", "deck_item_copies", "deck_missing_lists"]]]
const CARD_RATIO = 262.0 / 180.0
const GRID_GAP = 12

var library = Library.new()
## The deck being edited (DeckStore shape).
var deck: Dictionary = {}
## True until the deck is saved for the first time.
var is_new: bool = false
var _saved_snapshot: String = ""

var collection: Array = []
var grid: GridContainer
var collection_scroll: ScrollContainer
var collection_zone: Control
var empty_label: Label
var search_field: LineEdit
var count_label: Label
var color_buttons: Dictionary = {}
var kind_buttons: Dictionary = {}
var cost_buttons: Dictionary = {}
var filter_color: String = "all"
var filter_kind: String = ""
var filter_cost: int = 0
var _search_cache: Dictionary = {}

var name_field: LineEdit
var template_button: OptionButton
var import_button: Button
var export_button: Button
var deck_panel: Control
var heroes_label: Label
var round_labels: Array = []
var hero_slots: Array = []
var list: VBoxContainer
var list_scroll: ScrollContainer
var rows: Dictionary = {}
var lamps: Control
var issue_label: Label
var curve: Control
var kinds_label: Label
var slots_label: Label
var average_label: Label
var color_counts: Control
## The footer's statistics column: a plain clipping Control, so however long
## its labels or however many colours the deck holds, it never widens the
## footer (and the panel past the window).
var stats_holder: Control
var stats_column: VBoxContainer
## Short messages (saved, imported, all hero slots taken) show as a toast
## over the bottom of the collection: they never change the layout.
var status_toast: PanelContainer
var status_label: Label
var save_button: Button
var play_button: Button
var hint_label: Label
var inspector: Control
var preview: Control
var prompt: Control
var issues: Array = []
var _force_close: bool = false
var _status_tween: Tween
## The empty hero slot a click chose: the next hero clicked fills it (-1: none).
var pending_slot: int = -1
## The collection card under the mouse; its enlarged face shows after a pause.
var _hover_card: String = ""
var _hover_timer: Timer
## Generated colour-dot chip icons by colour.
static var _icons: Dictionary = {}

func _init() -> void:
	super()
	title_key = "DECKB_TITLE"
	panel_size = Vector2(1400, 864)

## Edits `entry` (a stored deck, or a new one). The builder works on a copy;
## nothing is written until Save.
func setup(entry: Dictionary, new_deck: bool = false) -> void:
	deck = DeckStore.sanitize(entry)
	if deck.is_empty():
		deck = DeckStore.blank(UiKit.t("DECKLIST_NEW_NAME"))
	DeckModel.repair(deck, library)
	is_new = new_deck
	_saved_snapshot = "" if new_deck else _snapshot()

func build() -> void:
	if deck.is_empty():
		setup(DeckStore.blank(UiKit.t("DECKLIST_NEW_NAME")), true)
	_build_header()
	var row = HBoxContainer.new()
	row.name = "Columns"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	_build_collection(row)
	_build_deck_panel(row)
	_build_footer()
	inspector = InspectOverlay.new()
	inspector.name = "Inspector"
	add_child(inspector)
	inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.timeout.connect(_show_collection_preview)
	add_child(_hover_timer)
	preview = CardView.new()
	preview.name = "Preview"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_size_keep(Vector2(220, 320))
	preview.visible = false
	add_child(preview)
	_rebuild()

# --- Layout --------------------------------------------------------------------------

func _build_header() -> void:
	var column = title_label.get_parent()
	var header = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	column.move_child(header, 0)
	column.remove_child(title_label)
	header.add_child(title_label)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_field = LineEdit.new()
	name_field.name = "DeckName"
	name_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_field.max_length = DeckStore.MAX_NAME_CHARS
	name_field.custom_minimum_size = Vector2(300, 40)
	name_field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_field.add_theme_font_override("font", UiKit.title_font())
	name_field.add_theme_font_size_override("font_size", 20)
	name_field.add_theme_color_override("font_color", UiKit.GOLD_BRIGHT)
	name_field.text_changed.connect(func(text):
		deck.name = DeckStore.clean_name(text)
		_update_state())
	header.add_child(name_field)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	template_button = OptionButton.new()
	template_button.name = "Template"
	template_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	template_button.add_theme_font_size_override("font_size", 16)
	template_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	template_button.fit_to_longest_item = false
	template_button.custom_minimum_size = Vector2(230, 38)
	template_button.clip_text = true
	template_button.item_selected.connect(_template_chosen)
	header.add_child(template_button)
	import_button = button(header, "", 17)
	import_button.name = "Import"
	import_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	import_button.pressed.connect(open_import)
	export_button = button(header, "", 17)
	export_button.name = "Export"
	export_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	export_button.pressed.connect(export_code)

func _build_collection(parent: Control) -> void:
	var box = VBoxContainer.new()
	box.name = "Collection"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var first = HBoxContainer.new()
	first.add_theme_constant_override("separation", 6)
	box.add_child(first)
	search_field = LineEdit.new()
	search_field.name = "Search"
	search_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	search_field.custom_minimum_size = Vector2(230, 36)
	search_field.clear_button_enabled = true
	search_field.add_theme_font_size_override("font_size", 16)
	search_field.text_changed.connect(func(_text): apply_filters())
	first.add_child(search_field)
	var colors = ButtonGroup.new()
	for key in COLOR_FILTERS:
		var chip = _chip(first, 15)
		chip.name = "Color_" + key
		chip.button_group = colors
		chip.button_pressed = key == filter_color
		chip.pressed.connect(func(): set_color_filter(key))
		color_buttons[key] = chip
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first.add_child(spacer)
	count_label = label(first, "", 14, UiKit.MUTED)
	var second = HBoxContainer.new()
	second.add_theme_constant_override("separation", 6)
	box.add_child(second)
	for key in KIND_FILTERS:
		var chip = _chip(second, 15)
		chip.name = "Kind_" + key
		chip.icon = UiKit.icon(KIND_ICONS[key])
		chip.expand_icon = true
		chip.custom_minimum_size = Vector2(42, 34)
		chip.add_theme_constant_override("icon_max_width", 20)
		chip.pressed.connect(func(): set_kind_filter(key))
		kind_buttons[key] = chip
		if key == "improvement":
			second.add_child(_divider())
	second.add_child(_divider())
	for cost in range(1, 9):
		var chip = _chip(second, 15)
		chip.name = "Cost_%d" % cost
		chip.text = str(cost) if cost < 8 else "8+"
		chip.custom_minimum_size = Vector2(36, 34)
		chip.pressed.connect(func(): set_cost_filter(cost))
		cost_buttons[cost] = chip
	var zone = Widgets.DropZone.new()
	zone.name = "CollectionZone"
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.22), Color(UiKit.GOLD_DARK, 0.35), 6, 1, 8.0))
	zone.accept_drop = func(data): return Widgets.is_drag(data, ["row", "slot"])
	zone.drop = _collection_drop
	box.add_child(zone)
	collection_zone = zone
	collection_scroll = ScrollContainer.new()
	collection_scroll.name = "CollectionScroll"
	collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	collection_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	zone.add_child(collection_scroll)
	grid = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 6
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP + 2)
	collection_scroll.add_child(grid)
	collection_scroll.resized.connect(_layout_grid)
	collection_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _reveal_visible())
	empty_label = label(zone, "", 17, UiKit.MUTED)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_label.visible = false
	for card_id in eligible_cards():
		var card = Widgets.CollectionCard.new()
		card.name = "Card_" + card_id
		card.setup(card_id)
		card.add_requested.connect(add_card)
		card.inspect_requested.connect(inspect)
		card.hover_changed.connect(_collection_hover)
		card.accept_drop = zone.accept_drop
		card.drop = _collection_drop
		grid.add_child(card)
		collection.append(card)

func _build_deck_panel(parent: Control) -> void:
	var zone = Widgets.DropZone.new()
	zone.name = "DeckPanel"
	zone.custom_minimum_size = Vector2(410, 0)
	zone.add_theme_stylebox_override("panel", UiKit.box(Color(0.03, 0.03, 0.035, 0.78), Color(UiKit.GOLD_DARK, 0.9), 6, 1, 12.0))
	zone.accept_drop = _deck_accepts
	zone.drop = _deck_drop
	parent.add_child(zone)
	deck_panel = zone
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	zone.add_child(box)
	heroes_label = label(box, "", 18, UiKit.GOLD_BRIGHT)
	heroes_label.add_theme_font_override("font", UiKit.title_font())
	var rounds = HBoxContainer.new()
	rounds.name = "Rounds"
	rounds.add_theme_constant_override("separation", 10)
	rounds.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(rounds)
	for group in [[0, 1, 2], [3], [4]]:
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		column.mouse_filter = Control.MOUSE_FILTER_PASS
		rounds.add_child(column)
		var round_label = label(column, "", 13, UiKit.GOLD)
		round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		round_labels.append(round_label)
		var slots = HBoxContainer.new()
		slots.add_theme_constant_override("separation", 5)
		slots.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_child(slots)
		for index in group:
			var slot = Widgets.HeroSlot.new()
			slot.name = "Slot%d" % index
			slot.slot = index
			slot.dropped.connect(_slot_drop)
			slot.fallback_accept = _deck_accepts
			slot.fallback_drop = _deck_drop
			slot.remove_requested.connect(remove_hero)
			slot.inspect_requested.connect(inspect)
			slot.empty_clicked.connect(choose_slot)
			slots.add_child(slot)
			hero_slots.append(slot)
	box.add_child(_separator())
	var scroll = Widgets.DropScroll.new()
	scroll.name = "DeckList"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.accept_drop = _deck_accepts
	scroll.drop = _deck_drop
	box.add_child(scroll)
	list_scroll = scroll
	list = VBoxContainer.new()
	list.name = "Rows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(list)
	box.add_child(_separator())
	lamps = Widgets.Lamps.new()
	lamps.name = "Lamps"
	box.add_child(lamps)
	issue_label = label(box, "", 14, UiKit.PAPER_DIM, true)
	issue_label.name = "Issue"
	issue_label.custom_minimum_size = Vector2(380, 20)

func _build_footer() -> void:
	footer.alignment = BoxContainer.ALIGNMENT_BEGIN
	footer.add_theme_constant_override("separation", 14)
	curve = Widgets.CurveChart.new()
	curve.name = "Curve"
	curve.custom_minimum_size = Vector2(240, 74)
	footer.add_child(curve)
	footer.move_child(curve, 0)
	# The statistics take the footer's free width and clip to it: a plain
	# Control does not pass its children's minimum width up, so the footer's
	# minimum width is the curve and the buttons only.
	stats_holder = Control.new()
	stats_holder.name = "Stats"
	stats_holder.clip_contents = true
	stats_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	footer.add_child(stats_holder)
	footer.move_child(stats_holder, 1)
	var stats = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 1)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.mouse_filter = Control.MOUSE_FILTER_PASS
	stats_holder.add_child(stats)
	stats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_column = stats
	# The holder is as tall as the column needs.
	stats.minimum_size_changed.connect(func(): stats_holder.custom_minimum_size.y = stats.get_combined_minimum_size().y)
	var top_line = HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 18)
	top_line.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(top_line)
	average_label = label(top_line, "", 15, UiKit.GOLD)
	average_label.add_theme_font_override("font", UiKit.title_font())
	color_counts = Widgets.ColorCounts.new()
	color_counts.name = "Colors"
	top_line.add_child(color_counts)
	kinds_label = label(stats, "", 14, UiKit.PAPER_DIM)
	slots_label = label(stats, "", 14, UiKit.PAPER_DIM)
	hint_label = label(stats, "", 13, UiKit.MUTED)
	for line in [kinds_label, slots_label, hint_label]:
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.mouse_filter = Control.MOUSE_FILTER_PASS
	stats_holder.custom_minimum_size.y = stats.get_combined_minimum_size().y
	save_button = button(footer, "", 20)
	save_button.name = "Save"
	save_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	save_button.pressed.connect(save)
	footer.move_child(save_button, 2)
	play_button = button(footer, "", 20)
	play_button.name = "Play"
	play_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(request_play)
	footer.move_child(play_button, 3)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_toast = PanelContainer.new()
	status_toast.name = "Toast"
	status_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_toast.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.05, 0.06, 0.94), UiKit.GOLD_DARK, 6, 1, 10.0))
	status_toast.visible = false
	add_child(status_toast)
	status_label = label(status_toast, "", 16, UiKit.JADE)
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

## A toggle chip in the filter rows.
func _chip(parent: Control, font_size: int) -> Button:
	var chip = button(parent, "", font_size)
	chip.toggle_mode = true
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(0, 34)
	chip.add_theme_color_override("icon_normal_color", UiKit.PAPER_DIM)
	chip.add_theme_color_override("icon_hover_color", UiKit.GOLD_BRIGHT)
	chip.add_theme_color_override("icon_pressed_color", UiKit.INK)
	chip.add_theme_color_override("icon_hover_pressed_color", UiKit.INK)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style: StyleBoxFlat = UiKit.theme().get_stylebox("pressed" if state.ends_with("pressed") else state, "Button").duplicate()
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		chip.add_theme_stylebox_override(state, style)
	return chip

func _separator() -> HSeparator:
	var line = HSeparator.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _divider() -> Control:
	var line = VSeparator.new()
	line.custom_minimum_size = Vector2(8, 30)
	line.add_theme_stylebox_override("separator", _vline())
	return line

func _vline() -> StyleBoxLine:
	var style = StyleBoxLine.new()
	style.color = Color(UiKit.GOLD_DARK, 0.7)
	style.vertical = true
	style.thickness = 1
	return style

## Card size and columns follow the collection's width.
func _layout_grid() -> void:
	var width = collection_scroll.size.x - 14.0
	if width <= 0.0:
		return
	var columns = clampi(int((width + GRID_GAP) / (138.0 + GRID_GAP)), 3, 9)
	var card_width = floorf((width - GRID_GAP * (columns - 1)) / columns)
	var card_size = Vector2(card_width, floorf(card_width * CARD_RATIO))
	grid.columns = columns
	for card in collection:
		if card.size != card_size:
			card.set_size_keep(card_size)
			card.custom_minimum_size = card_size
	empty_label.size = collection_zone.size
	_reveal_soon()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and panel != null:
		_place()
		_place_status.call_deferred()
	elif what == NOTIFICATION_DRAG_BEGIN:
		_hover_card = ""
		_hide_preview()

# --- Collection ------------------------------------------------------------------------

## Every hero and card a deck may hold, in catalog order (heroes first, then
## colour, kind and cost; items by slot and price).
func eligible_cards() -> Array:
	return CatalogDialog.definitions(library).filter(func(card_id):
		var kind = str(library.definition(card_id).get("kind", ""))
		if kind == "hero":
			return library.hero_deckable(card_id)
		return library.main_deckable(card_id) or library.item_deckable(card_id))

## The filter kind of a card: hero, creep, spell, improvement or its item slot.
func kind_of(card_id: String) -> String:
	var definition = library.definition(card_id)
	var kind = str(definition.get("kind", ""))
	return str(definition.get("slot", "")) if kind == "item" else kind

func set_color_filter(key: String) -> void:
	filter_color = key if key in COLOR_FILTERS else "all"
	apply_filters()

func set_kind_filter(key: String) -> void:
	filter_kind = "" if filter_kind == key else key
	apply_filters()

func set_cost_filter(cost: int) -> void:
	filter_cost = 0 if filter_cost == cost else cost
	apply_filters()

func set_search(text: String) -> void:
	search_field.text = text
	apply_filters()

func matches(card_id: String) -> bool:
	if filter_color != "all" and CatalogDialog.filter_of(card_id) != filter_color:
		return false
	if not filter_kind.is_empty() and kind_of(card_id) != filter_kind \
			and not (filter_kind == "item" and str(library.definition(card_id).get("kind", "")) == "item"):
		return false
	if filter_cost > 0:
		var definition = library.definition(card_id)
		if str(definition.get("kind", "")) not in MAIN_GROUPS:
			return false
		var cost = int(definition.get("cost", 0))
		if (filter_cost < 8 and cost != filter_cost) or (filter_cost == 8 and cost < 8):
			return false
	var query = search_field.text.strip_edges().to_lower() if search_field != null else ""
	if not query.is_empty():
		if not _search_cache.has(card_id):
			_search_cache[card_id] = (Library.loc(card_id) + "\n" + Library.loc(card_id, "text") + "\n" + Library.loc(card_id, "ability_name")).to_lower()
		for word in query.split(" ", false):
			if _search_cache[card_id].find(word) == -1:
				return false
	return true

func apply_filters() -> void:
	var shown = 0
	for card in collection:
		card.visible = matches(card.card_id)
		shown += int(card.visible)
	for key in color_buttons:
		color_buttons[key].set_pressed_no_signal(key == filter_color)
	for key in kind_buttons:
		kind_buttons[key].set_pressed_no_signal(key == filter_kind)
	for cost in cost_buttons:
		cost_buttons[cost].set_pressed_no_signal(cost == filter_cost)
	count_label.text = UiKit.t("CATALOG_COUNT", {"n": shown})
	empty_label.visible = shown == 0
	empty_label.size = collection_zone.size
	_reveal_soon()

## Cards in (or near) the visible part of the collection draw their faces.
func _reveal_visible() -> void:
	if collection_scroll == null or not collection_scroll.is_inside_tree():
		return
	var area = collection_scroll.get_global_rect().grow(collection_scroll.size.y * 0.5)
	for card in collection:
		if card.visible and not card.revealed and card.get_global_rect().intersects(area):
			card.revealed = true

## After the grid has been laid out again (next frame).
func _reveal_soon() -> void:
	if is_inside_tree() and not get_tree().process_frame.is_connected(_reveal_visible):
		get_tree().process_frame.connect(_reveal_visible, CONNECT_ONE_SHOT)

## The collection cards that pass the filters.
func shown_cards() -> Array:
	return collection.filter(func(card): return card.visible).map(func(card): return card.card_id)

func collection_card(card_id: String) -> Control:
	for card in collection:
		if card.card_id == card_id:
			return card
	return null

# --- Editing ---------------------------------------------------------------------------

func add_card(card_id: String) -> bool:
	var hero = str(library.definition(card_id).get("kind", "")) == "hero"
	if hero and DeckModel.hero_count(deck) >= DeckModel.SLOTS and card_id not in deck.heroes:
		show_status(UiKit.t("DECKB_HEROES_FULL"), true)
		return false
	var added = false
	if hero and pending_slot >= 0 and str(deck.heroes[pending_slot]).is_empty() and card_id not in deck.heroes:
		added = DeckModel.place_hero(deck, card_id, pending_slot, library)
	else:
		added = DeckModel.add(deck, card_id, library)
	if added:
		if hero:
			_set_pending_slot(-1)
		_rebuild()
	return added

## An empty hero slot was clicked: show the heroes; the next hero clicked
## fills that slot. Clicking it again cancels.
func choose_slot(slot: int) -> void:
	if slot < 0 or slot >= DeckModel.SLOTS or not str(deck.heroes[slot]).is_empty():
		return
	if pending_slot == slot:
		_set_pending_slot(-1)
		return
	_set_pending_slot(slot)
	# Heroes have no mana cost: the cost filter would hide them all.
	filter_kind = "hero"
	filter_cost = 0
	apply_filters()
	collection_scroll.scroll_vertical = 0
	show_status(UiKit.t("DECKB_PICK_HERO", {"n": DeckCode.turn_of_slot(slot)}))

func _set_pending_slot(slot: int) -> void:
	pending_slot = slot
	for index in range(hero_slots.size()):
		hero_slots[index].waiting = index == slot

func remove_card(card_id: String) -> bool:
	var removed = DeckModel.remove(deck, card_id, library)
	if removed:
		_hide_preview()
		_rebuild()
	return removed

func remove_hero(slot: int) -> bool:
	if pending_slot != -1:
		_set_pending_slot(-1)
	var removed = DeckModel.remove_hero(deck, slot, library)
	if removed:
		_rebuild()
	return removed

## A hero dragged onto `slot`: from the collection it takes the slot, from
## another slot the two swap.
func _slot_drop(slot: int, data: Dictionary) -> void:
	var source = str(data.get(Widgets.DRAG_KEY, ""))
	if source == "slot":
		DeckModel.move_hero(deck, int(data.get("slot", -1)), slot)
	elif source == "collection":
		DeckModel.place_hero(deck, str(data.get("card", "")), slot, library)
	_set_pending_slot(-1)
	_rebuild()

func _deck_accepts(data) -> bool:
	return Widgets.is_drag(data, ["collection"])

func _deck_drop(data) -> void:
	add_card(str(data.get("card", "")))

func _collection_drop(data) -> void:
	if str(data.get(Widgets.DRAG_KEY, "")) == "slot":
		remove_hero(int(data.get("slot", -1)))
	else:
		remove_card(str(data.get("card", "")))

func inspect(card_id: String) -> void:
	_hide_preview()
	inspector.show_card(card_id)

## A preset chosen in "Start from a preset": a deck with heroes or cards
## asks first (the same kind of question as leaving with unsaved changes).
func _template_chosen(index: int) -> void:
	template_button.select(0)
	var presets = library.presets()
	if index < 1 or index > presets.size():
		return
	var preset_id = str(presets[index - 1].id)
	if not _has_cards():
		use_template(preset_id)
		return
	var box = _prompt()
	box.setup(UiKit.t("DECKB_TEMPLATE_TITLE"), UiKit.t("DECKB_TEMPLATE_BODY", {"name": Library.preset_text(preset_id)}),
		UiKit.t("DECKB_TEMPLATE_REPLACE"), UiKit.t("BTN_CANCEL"))
	box.confirmed.connect(func(_text):
		box.cancel()
		use_template(preset_id))

## Replaces the deck's heroes and cards with a preset's.
func use_template(preset_id: String) -> void:
	var preset: Dictionary = library.preset(preset_id)
	if preset.is_empty():
		return
	_set_pending_slot(-1)
	deck.heroes = preset.heroes.duplicate()
	deck.cards = preset.cards.duplicate()
	deck.items = preset.items.duplicate()
	DeckModel.repair(deck, library)
	var preset_name = Library.preset_text(str(preset.id))
	if deck.name.is_empty() or deck.name == UiKit.t("DECKLIST_NEW_NAME"):
		deck.name = DeckStore.clean_name(UiKit.t("DECKLIST_COPY_NAME", {"name": preset_name}))
		name_field.text = deck.name
	show_status(UiKit.t("DECKB_TEMPLATE_DONE", {"name": preset_name}))
	_rebuild()

# --- Codes ----------------------------------------------------------------------------------

## The deck's code (Valve's ArtifactDeckCode format).
func code() -> String:
	return DeckCode.encode(deck, library)

## Copies the deck's code to the clipboard and shows it.
func export_code() -> String:
	var text = code()
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(text)
	var box = _prompt()
	box.setup(UiKit.t("DECKCODE_EXPORT_TITLE"), UiKit.t("DECKCODE_COPIED"), "", UiKit.t("BTN_CLOSE"), text)
	box.field.editable = false
	return text

## Asks for a code (prefilled from the clipboard when it holds one).
func open_import() -> Control:
	var clipboard = DisplayServer.clipboard_get() if DisplayServer.get_name() != "headless" else ""
	var box = _prompt()
	box.setup(UiKit.t("DECKCODE_IMPORT_TITLE"), UiKit.t("DECKCODE_IMPORT_HINT"), UiKit.t("DECKCODE_IMPORT"), UiKit.t("BTN_CANCEL"),
		DeckCode.extract(clipboard), "ADC…", UiKit.t("DECKCODE_PASTE"))
	box.extra_pressed.connect(func():
		if DisplayServer.get_name() != "headless":
			box.field.text = DisplayServer.clipboard_get())
	box.confirmed.connect(func(text):
		var result = import_code(text)
		if result.ok:
			box.cancel()
		else:
			box.show_error(EventText.error_text(result)))
	return box

## Replaces the deck's heroes and cards with a code's (and its name, when the
## code has one). Returns the decode result.
func import_code(text: String) -> Dictionary:
	var result = DeckCode.decode(text, library)
	if not result.ok:
		return result
	_set_pending_slot(-1)
	deck.heroes = result.deck.heroes
	deck.cards = result.deck.cards
	deck.items = result.deck.items
	DeckModel.repair(deck, library)
	var imported_name = DeckStore.clean_name(str(result.deck.name))
	if not imported_name.is_empty():
		deck.name = imported_name
		name_field.text = imported_name
	show_status(UiKit.t("DECKCODE_IMPORTED", {"name": _display_name()}))
	_rebuild()
	return result

func _prompt() -> Control:
	if prompt != null and is_instance_valid(prompt):
		UiKit.discard(prompt)
	prompt = Widgets.Prompt.new()
	prompt.name = "Prompt"
	add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return prompt

# --- Saving, playing, leaving -----------------------------------------------------------------

func save() -> Dictionary:
	if deck.name.is_empty():
		deck.name = DeckStore.clean_name(UiKit.t("DECKLIST_NEW_NAME"))
		name_field.text = deck.name
	var result = DeckStore.save(deck)
	if not result.ok:
		show_status(EventText.error_text(result), true)
		return result
	deck = result.deck
	is_new = false
	_saved_snapshot = _snapshot()
	show_status(UiKit.t("DECKB_SAVED", {"name": _display_name()}))
	saved.emit(deck.duplicate(true))
	_update_state()
	return result

## Saves (when needed) and asks to play the deck; only a legal deck plays.
func request_play() -> void:
	if not issues.is_empty():
		return
	if dirty() and not save().ok:
		return
	_force_close = true
	play_requested.emit(deck.duplicate(true))

func dirty() -> bool:
	return is_new or _snapshot() != _saved_snapshot

func _snapshot() -> String:
	return JSON.stringify([deck.get("name", ""), Library.canonical_deck(deck)])

## Back: unsaved changes ask first.
func close() -> void:
	if dirty() and not _force_close and _has_content():
		var box = _prompt()
		box.setup(UiKit.t("DECKB_DISCARD_TITLE"), UiKit.t("DECKB_DISCARD_BODY"), UiKit.t("DECKB_DISCARD"), UiKit.t("BTN_CANCEL"))
		box.confirmed.connect(func(_text):
			_force_close = true
			close())
		return
	back_requested.emit(str(deck.get("id", "")) if not is_new else "")
	super()

func _has_content() -> bool:
	return _has_cards() or not is_new

## The deck holds a hero, a card or an item.
func _has_cards() -> bool:
	return DeckModel.hero_count(deck) > 0 or not deck.cards.is_empty() or not deck.items.is_empty()

func _unhandled_key_input(event: InputEvent) -> void:
	if prompt != null and is_instance_valid(prompt) and prompt.is_inside_tree():
		return
	if inspector != null and inspector.visible:
		if event.is_pressed() and event is InputEventKey and event.keycode == KEY_ESCAPE:
			inspector.close()
			get_viewport().set_input_as_handled()
		return
	super(event)

## Shows a short message as a toast over the bottom of the collection for
## four seconds, then fades it out and clears it.
func show_status(text: String, warning: bool = false) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", UiKit.DAMAGE if warning else UiKit.JADE)
	status_toast.modulate.a = 1.0
	status_toast.visible = not text.is_empty()
	_place_status()
	# Again once the label has wrapped at its width.
	_place_status.call_deferred()
	if _status_tween != null:
		_status_tween.kill()
	if is_inside_tree() and not text.is_empty():
		_status_tween = create_tween()
		_status_tween.tween_interval(4.0)
		_status_tween.tween_property(status_toast, "modulate:a", 0.0, 0.8)
		_status_tween.tween_callback(clear_status)

func clear_status() -> void:
	status_label.text = ""
	status_toast.visible = false

## Centres the toast near the bottom of the collection, at most as wide as
## the collection (longer messages wrap inside the toast).
func _place_status() -> void:
	if status_toast == null or not status_toast.visible or collection_zone == null or not is_inside_tree():
		return
	var zone: Rect2 = collection_zone.get_global_rect()
	zone.position -= get_global_rect().position
	var room = maxf(200.0, zone.size.x - 60.0)
	var text_width = status_label.get_theme_font("font").get_string_size(status_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		status_label.get_theme_font_size("font_size")).x
	var wrap = text_width + 4.0 > room - 20.0
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	status_label.custom_minimum_size.x = room - 20.0 if wrap else 0.0
	status_toast.reset_size()
	status_toast.size = status_toast.get_combined_minimum_size()
	status_toast.position = Vector2(zone.get_center().x - status_toast.size.x * 0.5, zone.end.y - status_toast.size.y - 14.0)

func _display_name() -> String:
	return deck.name if not str(deck.get("name", "")).is_empty() else UiKit.t("DECK_UNNAMED")

# --- Redraw ----------------------------------------------------------------------------------

## A near-opaque backdrop: the deck screens stand on their own (the menu or
## board behind would show through the panel).
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.012, 0.016, 0.95))

func refresh_text() -> void:
	super()
	_search_cache.clear()
	close_button.text = UiKit.t("BTN_BACK")
	name_field.placeholder_text = UiKit.t("DECKB_NAME_PLACEHOLDER")
	if name_field.text != deck.name:
		name_field.text = deck.name
	search_field.placeholder_text = UiKit.t("DECKB_SEARCH")
	var labels = CatalogDialog.FACTION_LABELS if Library.current_skin() == "three_kingdoms" else CatalogDialog.CLASSIC_LABELS
	for key in color_buttons:
		var chip: Button = color_buttons[key]
		chip.text = UiKit.t(labels[key])
		chip.icon = _color_icon(key)
		chip.add_theme_constant_override("icon_max_width", 20)
		# Emblems and colour dots keep their own colours in every state.
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			chip.add_theme_color_override(state, Color.WHITE)
	for key in kind_buttons:
		kind_buttons[key].tooltip_text = UiKit.t(KIND_KEYS[key])
	for cost in cost_buttons:
		cost_buttons[cost].tooltip_text = UiKit.t("DECKB_COST_TOOLTIP", {"n": str(cost) if cost < 8 else "8+"})
	template_button.clear()
	template_button.add_item(UiKit.t("DECKB_TEMPLATE"))
	for preset in library.presets():
		template_button.add_item(Library.preset_text(str(preset.id)))
	template_button.select(0)
	import_button.text = UiKit.t("DECKLIST_IMPORT")
	export_button.text = UiKit.t("DECKLIST_EXPORT")
	save_button.text = UiKit.t("DECKB_SAVE")
	play_button.text = UiKit.t("DECKLIST_PLAY")
	hint_label.text = UiKit.t("DECKB_HINT")
	hint_label.tooltip_text = hint_label.text
	empty_label.text = UiKit.t("DECKB_NO_MATCHES")
	for index in range(round_labels.size()):
		round_labels[index].text = UiKit.t("DECKB_ROUND", {"n": index + 1})
	for card in collection:
		card.refresh()
	if inspector != null:
		inspector.refresh_text()
	_rebuild()
	apply_filters()

## A small icon for a colour chip: the faction emblem (Three Kingdoms skin)
## or a colour dot.
func _color_icon(key: String) -> Texture2D:
	if key == "all":
		return null
	if Library.current_skin() == "three_kingdoms":
		var faction = {"red": "shu", "green": "wu", "blue": "wei", "black": "qun"}.get(key, "")
		var emblem = UiKit.faction_emblem(faction) if not faction.is_empty() else null
		if emblem != null:
			return emblem
	return _dot(UiKit.card_color(key if key != "neutral" else "neutral").lightened(0.15))

static func _dot(color: Color) -> Texture2D:
	var key = "dot|" + color.to_html()
	if _icons.has(key):
		return _icons[key]
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var distance = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			var alpha = clampf(6.5 - distance, 0.0, 1.0)
			var rim = clampf(7.5 - distance, 0.0, 1.0) - alpha
			image.set_pixel(x, y, Color(color, alpha) if alpha > 0.0 else Color(UiKit.GOLD, rim))
	var result = ImageTexture.create_from_image(image)
	_icons[key] = result
	return result

func _rebuild() -> void:
	issues = library.deck_issues(deck)
	for index in range(hero_slots.size()):
		hero_slots[index].set_hero(str(deck.heroes[index]))
	heroes_label.text = UiKit.t("DECKB_HEROES_COUNT", {"n": DeckModel.hero_count(deck)})
	_rebuild_list()
	var codes = issues.map(func(issue): return str(issue.code))
	var met: Array = []
	var texts: Array = []
	for requirement in REQUIREMENTS:
		texts.append(UiKit.t(requirement[0]))
		met.append(not requirement[1].any(func(code): return code in codes))
	lamps.set_lamps(texts, met)
	if issues.is_empty():
		issue_label.text = UiKit.t("DECKLIST_VALID")
		issue_label.add_theme_color_override("font_color", Color("6fcf73"))
	else:
		issue_label.text = EventText.error_text(issues[0])
		issue_label.add_theme_color_override("font_color", Color("e0796d"))
	var numbers = DeckModel.stats(deck, library)
	curve.set_curve(numbers.curve)
	color_counts.set_counts(numbers.colors)
	average_label.text = UiKit.t("DECKB_AVERAGE", {"n": "%.1f" % float(numbers.average)})
	kinds_label.text = UiKit.t("DECKB_KIND_COUNTS", {"creeps": numbers.kinds.creep, "spells": numbers.kinds.spell, "improvements": numbers.kinds.improvement})
	slots_label.text = UiKit.t("DECKB_SLOT_COUNTS", {"weapon": numbers.slots.weapon, "armor": numbers.slots.armor, "accessory": numbers.slots.accessory})
	kinds_label.tooltip_text = kinds_label.text
	slots_label.tooltip_text = slots_label.text
	for card in collection:
		var hero = str(library.definition(card.card_id).get("kind", "")) == "hero"
		var copies = DeckModel.count_of(deck, card.card_id)
		card.set_count(copies, 1 if hero else DeckModel.MAX_COPIES, copies == 0 if hero else DeckModel.can_add(deck, card.card_id, library))
	_update_state()

func _update_state() -> void:
	if play_button == null:
		return
	play_button.disabled = not issues.is_empty()
	play_button.tooltip_text = "" if issues.is_empty() else EventText.error_text(issues[0])
	save_button.text = UiKit.t("DECKB_SAVE") + (" •" if dirty() else "")
	save_button.tooltip_text = UiKit.t("DECKB_UNSAVED") if dirty() else ""

func _rebuild_list() -> void:
	_hide_preview()
	for child in list.get_children():
		UiKit.discard(child)
	rows.clear()
	var owners = DeckModel.signatures(deck, library)
	_section(UiKit.t("DECKB_MAIN_COUNT", {"n": DeckModel.main_count(deck)}), DeckModel.main_count(deck) >= 40)
	var groups: Dictionary = {}
	for card_id in deck.cards:
		var kind = str(library.get_card(card_id).get("kind", ""))
		if not groups.has(kind):
			groups[kind] = []
		groups[kind].append(card_id)
	if deck.cards.is_empty():
		_hint(UiKit.t("DECKB_EMPTY_MAIN"))
	for kind in MAIN_GROUPS:
		_group(kind, groups.get(kind, []), deck.cards, owners, "cost")
	_section(UiKit.t("DECKB_ITEMS_COUNT", {"n": DeckModel.item_count(deck)}), DeckModel.item_count(deck) >= 9)
	var slots: Dictionary = {}
	for card_id in deck.items:
		var slot = str(library.get_card(card_id).get("slot", ""))
		if not slots.has(slot):
			slots[slot] = []
		slots[slot].append(card_id)
	if deck.items.is_empty():
		_hint(UiKit.t("DECKB_EMPTY_ITEMS"))
	for slot in ITEM_GROUPS:
		_group(slot, slots.get(slot, []), deck.items, owners, "price")

func _section(text: String, complete: bool) -> void:
	var heading = label(list, text, 17, Color("8fd18f") if complete else UiKit.GOLD_BRIGHT)
	heading.add_theme_font_override("font", UiKit.title_font())
	heading.custom_minimum_size.y = 28
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

func _hint(text: String) -> void:
	var line = label(list, text, 14, UiKit.MUTED, true)
	line.custom_minimum_size = Vector2(300, 24)

func _group(kind: String, ids: Array, counts: Dictionary, owners: Dictionary, order: String) -> void:
	if ids.is_empty():
		return
	var total = 0
	for card_id in ids:
		total += int(counts[card_id])
	var heading = label(list, "%s · %d" % [UiKit.t("DECKB_GROUP_" + kind.to_upper()), total], 14, UiKit.GOLD)
	heading.custom_minimum_size.y = 22
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ids.sort_custom(func(a, b):
		var first = int(library.get_card(a).get(order, 0))
		var second = int(library.get_card(b).get(order, 0))
		if first != second:
			return first < second
		return Library.loc(a).naturalnocasecmp_to(Library.loc(b)) < 0)
	for card_id in ids:
		var row = Widgets.DeckRow.new()
		row.name = "Row_" + card_id
		row.accept_drop = _deck_accepts
		row.drop = _deck_drop
		list.add_child(row)
		row.setup(card_id, int(counts[card_id]), owners.has(card_id), DeckModel.can_add(deck, card_id, library), str(owners.get(card_id, "")))
		row.add_requested.connect(add_card)
		row.remove_requested.connect(remove_card)
		row.inspect_requested.connect(inspect)
		row.hover_changed.connect(_row_hover)
		rows[card_id] = row

## Hovering a row shows its card beside the deck panel.
func _row_hover(card_id: String, row: Control, inside: bool) -> void:
	if not inside or row == null or not is_instance_valid(row) or (inspector != null and inspector.visible) or get_viewport().gui_is_dragging():
		_hide_preview()
		return
	preview.setup(card_id)
	var rect = row.get_global_rect()
	var origin = get_global_rect().position
	var y = clampf(rect.get_center().y - preview.size.y * 0.5, 10.0, size.y - preview.size.y - 10.0)
	preview.position = Vector2(deck_panel.get_global_rect().position.x - origin.x - preview.size.x - 14.0, y)
	preview.visible = true

func _hide_preview() -> void:
	if preview != null:
		preview.visible = false

## Hovering a collection card shows it enlarged beside it after a pause
## (its rules text is small in the grid).
func _collection_hover(card_id: String, inside: bool) -> void:
	if inside:
		_hover_card = card_id
		if _hover_timer != null and is_inside_tree():
			_hover_timer.start(0.4)
	elif _hover_card == card_id:
		_hover_card = ""
		if _hover_timer != null:
			_hover_timer.stop()
		_hide_preview()

func _show_collection_preview() -> void:
	var card = collection_card(_hover_card) if not _hover_card.is_empty() else null
	var prompt_open = prompt != null and is_instance_valid(prompt) and prompt.is_inside_tree()
	if card == null or not card.is_visible_in_tree() or get_viewport().gui_is_dragging() or (inspector != null and inspector.visible) or prompt_open:
		return
	preview.setup(_hover_card)
	var rect: Rect2 = card.get_global_rect()
	var origin = get_global_rect().position
	var on_left = rect.get_center().x < collection_zone.get_global_rect().get_center().x
	var x = rect.end.x + 12.0 if on_left else rect.position.x - preview.size.x - 12.0
	var y = clampf(rect.get_center().y - preview.size.y * 0.5, 10.0, size.y - preview.size.y - 10.0)
	preview.position = Vector2(x, y) - origin
	preview.visible = true
