extends "res://scripts/ui/modal_panel.gd"
## Decks: the player's own decks (DeckStore, user://decks/) and the preset
## decks in one list. The selected deck shows its heroes by deploy round, its
## curve and lists, and whether it can be played (else the first rule it
## breaks). Own decks: Edit, Duplicate, Rename, Delete, Copy code, Play.
## Presets are read-only: Edit a copy, Copy code, Play. New deck and Import
## code start new decks (an imported code is saved as a new deck at once).

signal edit_requested(deck: Dictionary, new_deck: bool)
## `entry` is a preset id or an own deck dictionary.
signal play_requested(entry)

const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const InspectOverlay = preload("res://scripts/ui/inspect_overlay.gd")
const DeckCode = preload("res://scripts/core/deck_code.gd")
const DeckStore = preload("res://scripts/core/deck_store.gd")
const DeckModel = preload("res://scripts/core/deck_model.gd")
const Widgets = preload("res://scripts/ui/deck_widgets.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const HERO_SIZE = Vector2(112, 163)

var library = Library.new()
## Own decks as stored (DeckStore.list order).
var decks: Array = []
## The selected entry: {"kind": "custom" | "preset", "id"}.
var selected: Dictionary = {}
var list: VBoxContainer
var list_scroll: ScrollContainer
var entry_buttons: Dictionary = {}
var new_button: Button
var import_button: Button
var name_label: Label
var status_label: Label
var description_label: Label
var hero_box: HBoxContainer
var round_labels: Array = []
var hero_rows: Array = []
var summary_label: Label
var kinds_label: Label
var color_counts: Control
var curve: Control
var main_list: RichTextLabel
var item_list: RichTextLabel
var actions: Dictionary = {}
var notice_label: Label
var inspector: Control
var prompt: Control
var _group: ButtonGroup
## Validity dots for the list, by colour.
static var _dots: Dictionary = {}

func _init() -> void:
	super()
	title_key = "DECKLIST_TITLE"
	panel_size = Vector2(1280, 820)

## Selects deck `id` (an own deck id or a preset id) when the dialog opens.
func setup(select_id: String = "") -> void:
	if not select_id.is_empty():
		selected = {"kind": "custom" if DeckStore.valid_id(select_id) and library.preset(select_id).is_empty() else "preset", "id": select_id}

func build() -> void:
	var row = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	left.add_child(tools)
	new_button = button(tools, "", 17)
	new_button.name = "NewDeck"
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_button.pressed.connect(new_deck)
	import_button = button(tools, "", 17)
	import_button.name = "ImportCode"
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.pressed.connect(open_import)
	var frame = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.3), Color(UiKit.GOLD_DARK, 0.6), 6, 1, 6.0))
	left.add_child(frame)
	var scroll = ScrollContainer.new()
	scroll.name = "DeckScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	list_scroll = scroll
	list = VBoxContainer.new()
	list.name = "Decks"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	var title_row = HBoxContainer.new()
	right.add_child(title_row)
	name_label = label(title_row, "", 30, UiKit.GOLD_BRIGHT)
	name_label.name = "DeckName"
	name_label.add_theme_font_override("font", UiKit.title_font())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label = label(title_row, "", 16, UiKit.JADE)
	status_label.name = "Validity"
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	description_label = label(right, "", 15, UiKit.PAPER_DIM, true)
	description_label.custom_minimum_size.y = 22
	hero_box = HBoxContainer.new()
	hero_box.name = "Heroes"
	hero_box.add_theme_constant_override("separation", 14)
	right.add_child(hero_box)
	for group in [3, 1, 1]:
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		hero_box.add_child(column)
		var round_label = label(column, "", 13, UiKit.GOLD)
		round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		round_labels.append(round_label)
		var cards = HBoxContainer.new()
		cards.add_theme_constant_override("separation", 6)
		column.add_child(cards)
		hero_rows.append(cards)
	var info = HBoxContainer.new()
	info.add_theme_constant_override("separation", 18)
	right.add_child(info)
	curve = Widgets.CurveChart.new()
	curve.custom_minimum_size = Vector2(230, 70)
	info.add_child(curve)
	var counts = VBoxContainer.new()
	counts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(counts)
	summary_label = label(counts, "", 17, UiKit.GOLD)
	summary_label.add_theme_font_override("font", UiKit.title_font())
	kinds_label = label(counts, "", 14, UiKit.PAPER_DIM)
	color_counts = Widgets.ColorCounts.new()
	counts.add_child(color_counts)
	var lists = HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists.add_theme_constant_override("separation", 18)
	right.add_child(lists)
	main_list = _rich(lists)
	item_list = _rich(lists)
	var action_row = HBoxContainer.new()
	action_row.name = "Actions"
	action_row.add_theme_constant_override("separation", 8)
	right.add_child(action_row)
	for key in ["edit", "duplicate", "rename", "delete", "export"]:
		var action = button(action_row, "", 17)
		action.name = key.capitalize()
		action.pressed.connect(_action.bind(key))
		actions[key] = action
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(spacer)
	var play = button(action_row, "", 20)
	play.name = "Play"
	play.pressed.connect(_action.bind("play"))
	actions["play"] = play
	notice_label = label(footer, "", 15, UiKit.JADE)
	notice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.move_child(notice_label, 0)
	inspector = InspectOverlay.new()
	inspector.name = "Inspector"
	add_child(inspector)
	inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reload()

func _rich(parent: Control) -> RichTextLabel:
	var text = RichTextLabel.new()
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.bbcode_enabled = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(200, 80)
	text.add_theme_font_size_override("normal_font_size", 15)
	parent.add_child(text)
	return text

## Reads the store again and rebuilds the list.
func reload() -> void:
	decks = DeckStore.list()
	if selected.is_empty() or (selected.kind == "custom" and _own(selected.id).is_empty()):
		selected = {"kind": "custom", "id": decks[0].id} if not decks.is_empty() else {"kind": "preset", "id": str(library.presets()[0].id)}
	_rebuild_list()
	_show_selected()
	_scroll_to_selected.call_deferred()

## Scrolls the list to the selected entry (deferred: the list is laid out by
## then, and it may have been rebuilt meanwhile).
func _scroll_to_selected() -> void:
	var shown = entry_buttons.get("%s:%s" % [selected.get("kind", ""), selected.get("id", "")])
	if shown != null and is_instance_valid(shown) and list_scroll.is_ancestor_of(shown):
		list_scroll.ensure_control_visible(shown)

func _own(id: String) -> Dictionary:
	for deck in decks:
		if deck.id == id:
			return deck
	return {}

## The selected deck as a deck dictionary (an own deck or a preset).
func selected_deck() -> Dictionary:
	if selected.get("kind", "") == "custom":
		return _own(str(selected.id))
	return library.preset(str(selected.get("id", "")))

## What playing the selection passes on: an own deck or a preset id.
func selected_entry():
	return selected_deck() if selected.get("kind", "") == "custom" else str(selected.get("id", ""))

func select(kind: String, id: String) -> void:
	selected = {"kind": kind, "id": id}
	for key in entry_buttons:
		entry_buttons[key].set_pressed_no_signal(key == kind + ":" + id)
	_show_selected()

func _rebuild_list() -> void:
	for child in list.get_children():
		UiKit.discard(child)
	entry_buttons.clear()
	_group = ButtonGroup.new()
	_heading(UiKit.t("DECKLIST_MINE"))
	if decks.is_empty():
		var hint = label(list, UiKit.t("DECKLIST_EMPTY"), 14, UiKit.MUTED, true)
		hint.custom_minimum_size = Vector2(280, 40)
	for deck in decks:
		var valid = library.validate_preset(deck).ok
		_entry("custom", str(deck.id), _name_of(deck), valid, deck.get("heroes", []))
	_heading(UiKit.t("DECKLIST_PRESETS"))
	for preset in library.presets():
		_entry("preset", str(preset.id), Library.preset_text(str(preset.id)), true, preset.get("heroes", []))

func _heading(text: String) -> void:
	var heading = label(list, text, 17, UiKit.GOLD)
	heading.add_theme_font_override("font", UiKit.title_font())
	heading.custom_minimum_size.y = 30
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

func _entry(kind: String, id: String, text: String, valid: bool, heroes: Array = []) -> void:
	var entry = button(list, text, 16)
	entry.name = "%s_%s" % [kind.capitalize(), id]
	entry.toggle_mode = true
	entry.button_group = _group
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.clip_text = true
	entry.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	entry.custom_minimum_size = Vector2(260, 36)
	entry.icon = _dot(Color("6fcf73") if valid else Color("d0493c")) if kind == "custom" else null
	entry.add_theme_constant_override("icon_max_width", 14)
	entry.add_theme_stylebox_override("normal", UiKit.box(Color(0.07, 0.07, 0.08, 0.6), Color(0, 0, 0, 0), 4, 0, 8.0))
	entry.button_pressed = selected.get("kind", "") == kind and str(selected.get("id", "")) == id
	entry.pressed.connect(select.bind(kind, id))
	entry_buttons[kind + ":" + id] = entry
	# The deck's factions (colours in the classic skin) at the row's right end.
	var marks = HBoxContainer.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.add_theme_constant_override("separation", 2)
	marks.alignment = BoxContainer.ALIGNMENT_END
	marks.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	marks.offset_left = -92
	marks.offset_right = -8
	entry.add_child(marks)
	var colors: Array = []
	for hero_id in heroes:
		var color = str(Library.raw_definition(str(hero_id)).get("color", ""))
		if not color.is_empty() and color not in colors:
			colors.append(color)
	for color in colors:
		var mark = TextureRect.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.custom_minimum_size = Vector2(20, 20)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var faction = {"red": "shu", "green": "wu", "blue": "wei", "black": "qun"}.get(color, "")
		mark.texture = UiKit.faction_emblem(faction) if Library.current_skin() == "three_kingdoms" and not faction.is_empty() else _dot(UiKit.card_color(color).lightened(0.2))
		marks.add_child(mark)
	# Long names stop short of the marks.
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style = entry.get_theme_stylebox("pressed" if state == "hover_pressed" else state).duplicate()
		style.content_margin_right = 8 + 22 * colors.size()
		entry.add_theme_stylebox_override(state, style)

static func _dot(color: Color) -> Texture2D:
	var key = color.to_html()
	if _dots.has(key):
		return _dots[key]
	var image = Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for y in range(14):
		for x in range(14):
			var distance = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(7, 7))
			image.set_pixel(x, y, Color(color, clampf(5.5 - distance, 0.0, 1.0)))
	_dots[key] = ImageTexture.create_from_image(image)
	return _dots[key]

func _name_of(deck: Dictionary) -> String:
	var name = DeckStore.clean_name(str(deck.get("name", "")))
	return name if not name.is_empty() else UiKit.t("DECK_UNNAMED")

func _show_selected() -> void:
	var deck = selected_deck()
	var custom = selected.get("kind", "") == "custom"
	name_label.text = _name_of(deck) if custom else Library.preset_text(str(selected.get("id", "")))
	var validation = library.validate_preset(deck) if not deck.is_empty() else {"ok": false, "code": "deck_store_missing"}
	status_label.text = UiKit.t("DECKLIST_VALID") if validation.ok else ""
	status_label.add_theme_color_override("font_color", Color("6fcf73"))
	if custom:
		description_label.text = UiKit.t("DECK_CUSTOM") if validation.ok else UiKit.t("DECKLIST_INVALID", {"reason": EventText.error_text(validation)})
		description_label.add_theme_color_override("font_color", Color("e0796d") if not validation.ok else UiKit.PAPER_DIM)
	else:
		description_label.text = Library.preset_text(str(selected.get("id", "")), "description")
		description_label.add_theme_color_override("font_color", UiKit.PAPER_DIM)
	for row in hero_rows:
		for child in row.get_children():
			UiKit.discard(child)
	var heroes: Array = deck.get("heroes", [])
	for index in range(5):
		var hero_id = str(heroes[index]) if index < heroes.size() else ""
		var target: HBoxContainer = hero_rows[0 if index < 3 else index - 2]
		if hero_id.is_empty():
			var empty = Panel.new()
			empty.custom_minimum_size = HERO_SIZE
			empty.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.3), Color(UiKit.GOLD_DARK, 0.6), 6, 1, 0.0))
			target.add_child(empty)
			continue
		var card = CardView.new()
		card.setup(hero_id)
		card.set_size_keep(HERO_SIZE)
		card.custom_minimum_size = HERO_SIZE
		card.tooltip_text = Library.loc(hero_id)
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				inspector.show_card(hero_id))
		target.add_child(card)
	var numbers = DeckModel.stats(DeckModel.normalize(deck.duplicate(true)), library)
	curve.set_curve(numbers.curve)
	color_counts.set_counts(numbers.colors)
	summary_label.text = UiKit.t("DECKLIST_SUMMARY", {"main": numbers.main, "items": numbers.items})
	kinds_label.text = UiKit.t("DECKB_KIND_COUNTS", {"creeps": numbers.kinds.creep, "spells": numbers.kinds.spell, "improvements": numbers.kinds.improvement}) \
		+ "\n" + UiKit.t("DECKB_AVERAGE", {"n": "%.1f" % float(numbers.average)})
	main_list.text = _lines(deck.get("cards", {}), UiKit.t("DECKS_MAIN", {"n": numbers.main}), "cost")
	item_list.text = _lines(deck.get("items", {}), UiKit.t("DECKS_ITEMS", {"n": numbers.items}), "price")
	actions.edit.text = UiKit.t("DECKLIST_EDIT" if custom else "DECKLIST_EDIT_COPY")
	actions.duplicate.visible = custom
	actions.rename.visible = custom
	actions.delete.visible = custom
	actions.play.disabled = not validation.ok
	actions.play.tooltip_text = "" if validation.ok else EventText.error_text(validation)
	actions.export.disabled = deck.is_empty()

## A card list in BBCode: a heading, then "n × name" sorted by cost (or price).
func _lines(counts: Dictionary, heading: String, order: String) -> String:
	var ids: Array = counts.keys()
	ids.sort_custom(func(a, b):
		var first = int(library.definition(str(a)).get(order, 0))
		var second = int(library.definition(str(b)).get(order, 0))
		if first != second:
			return first < second
		return Library.loc(str(a)).naturalnocasecmp_to(Library.loc(str(b))) < 0)
	var lines: Array = ["[color=#d8b06a]%s[/color]" % heading]
	for card_id in ids:
		lines.append(_escape(UiKit.t("DECKS_LINE", {"n": int(counts[card_id]), "card": Library.loc(str(card_id))})))
	return "\n".join(lines)

static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

# --- Actions -------------------------------------------------------------------------

func _action(key: String) -> void:
	var deck = selected_deck()
	var custom = selected.get("kind", "") == "custom"
	match key:
		"edit":
			if custom:
				edit_requested.emit(deck.duplicate(true), false)
			else:
				var copy = DeckStore.copy_of(deck, DeckStore.unique_name(UiKit.t("DECKLIST_COPY_NAME", {"name": Library.preset_text(str(selected.id))}), decks))
				edit_requested.emit(copy, true)
		"duplicate":
			duplicate_selected()
		"rename":
			open_rename()
		"delete":
			open_delete()
		"export":
			export_selected()
		"play":
			if library.validate_preset(deck).ok:
				play_requested.emit(selected_entry())

func new_deck() -> void:
	edit_requested.emit(DeckStore.blank(DeckStore.unique_name(UiKit.t("DECKLIST_NEW_NAME"), decks)), true)

## Saves a copy of the selected own deck and selects it.
func duplicate_selected() -> Dictionary:
	var deck = selected_deck()
	var copy = DeckStore.copy_of(deck, DeckStore.unique_name(UiKit.t("DECKLIST_COPY_NAME", {"name": _name_of(deck)}), decks))
	var result = DeckStore.save(copy)
	if result.ok:
		selected = {"kind": "custom", "id": result.deck.id}
		reload()
	else:
		show_notice(EventText.error_text(result), true)
	return result

func open_rename() -> Control:
	var box = _prompt()
	var deck = selected_deck()
	box.setup(UiKit.t("DECKLIST_RENAME_TITLE"), "", UiKit.t("BTN_OK"), UiKit.t("BTN_CANCEL"), _name_of(deck), UiKit.t("DECKB_NAME_PLACEHOLDER"))
	box.field.max_length = DeckStore.MAX_NAME_CHARS
	box.confirmed.connect(func(text):
		var result = rename_selected(text)
		if result.ok:
			box.cancel()
		else:
			box.show_error(EventText.error_text(result)))
	return box

func rename_selected(text: String) -> Dictionary:
	var deck = selected_deck().duplicate(true)
	var name = DeckStore.clean_name(text)
	if name.is_empty():
		return {"ok": false, "code": "deck_store_invalid", "args": {}, "error": "Empty name."}
	deck.name = name
	var result = DeckStore.save(deck)
	if result.ok:
		reload()
	return result

func open_delete() -> Control:
	var box = _prompt()
	var deck = selected_deck()
	box.setup(UiKit.t("DECKLIST_DELETE_TITLE"), UiKit.t("DECKLIST_DELETE_BODY", {"name": _name_of(deck)}), UiKit.t("DECKLIST_DELETE"), UiKit.t("BTN_CANCEL"))
	box.confirmed.connect(func(_text):
		delete_selected()
		box.cancel())
	return box

func delete_selected() -> Dictionary:
	var deck = selected_deck()
	var result = DeckStore.delete(str(deck.get("id", "")))
	if result.ok:
		show_notice(UiKit.t("DECKLIST_DELETED", {"name": _name_of(deck)}))
		selected = {}
		reload()
	else:
		show_notice(EventText.error_text(result), true)
	return result

## Copies the selected deck's code to the clipboard and shows it.
func export_selected() -> String:
	var deck = selected_deck()
	var text = DeckCode.encode(deck, library)
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(text)
	var box = _prompt()
	box.setup(UiKit.t("DECKCODE_EXPORT_TITLE"), UiKit.t("DECKCODE_COPIED"), "", UiKit.t("BTN_CLOSE"), text)
	box.field.editable = false
	return text

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

## Saves a code's deck as a new own deck and selects it.
func import_code(text: String) -> Dictionary:
	var decoded = DeckCode.decode(text, library)
	if not decoded.ok:
		return decoded
	var deck = DeckStore.blank()
	deck.heroes = decoded.deck.heroes
	deck.cards = decoded.deck.cards
	deck.items = decoded.deck.items
	DeckModel.repair(deck, library)
	var base = DeckStore.clean_name(str(decoded.deck.name))
	deck.name = DeckStore.unique_name(base if not base.is_empty() else UiKit.t("DECKLIST_NEW_NAME"), decks)
	var result = DeckStore.save(deck)
	if result.ok:
		selected = {"kind": "custom", "id": result.deck.id}
		reload()
		show_notice(UiKit.t("DECKCODE_IMPORTED", {"name": result.deck.name}))
	return result

func _prompt() -> Control:
	if prompt != null and is_instance_valid(prompt):
		UiKit.discard(prompt)
	prompt = Widgets.Prompt.new()
	prompt.name = "Prompt"
	add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return prompt

func show_notice(text: String, warning: bool = false) -> void:
	notice_label.text = text
	notice_label.add_theme_color_override("font_color", UiKit.DAMAGE if warning else UiKit.JADE)

func _unhandled_key_input(event: InputEvent) -> void:
	if prompt != null and is_instance_valid(prompt) and prompt.is_inside_tree():
		return
	if inspector != null and inspector.visible:
		if event.is_pressed() and event is InputEventKey and event.keycode == KEY_ESCAPE:
			inspector.close()
			get_viewport().set_input_as_handled()
		return
	super(event)

## A near-opaque backdrop: the deck screens stand on their own (the menu or
## board behind would show through the panel).
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.012, 0.016, 0.95))

func refresh_text() -> void:
	super()
	new_button.text = UiKit.t("DECKLIST_NEW")
	import_button.text = UiKit.t("DECKLIST_IMPORT")
	for key in actions:
		actions[key].text = UiKit.t({"edit": "DECKLIST_EDIT", "duplicate": "DECKLIST_DUPLICATE", "rename": "DECKLIST_RENAME",
			"delete": "DECKLIST_DELETE", "export": "DECKLIST_EXPORT", "play": "DECKLIST_PLAY"}[key])
	for index in range(round_labels.size()):
		round_labels[index].text = UiKit.t("DECKB_ROUND", {"n": index + 1})
	if inspector != null:
		inspector.refresh_text()
	_rebuild_list()
	_show_selected()
