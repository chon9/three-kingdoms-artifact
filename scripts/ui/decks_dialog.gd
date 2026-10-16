extends "res://scripts/ui/modal_panel.gd"
## Deck selection: one deck per player, a preset or one of the player's own
## legal decks (DeckStore; listed under the presets), with the emblems of its
## factions, its description, five heroes and the main and item deck lists,
## all localized. Start launches the matchup; Browse opens the card catalog;
## My decks opens the deck list and builder.
##
## Guest mode (an online guest): one column, the deck this player sends to
## the host ("Use this deck online"). A host in an online match also gets one
## column: the guest brings its own deck.

## `mode`: MatchController.MODE_AI, MODE_LOCAL (or MODE_ONLINE for a host).
signal start_requested(decks: Array, mode: int)
signal catalog_requested
signal manage_requested
## Guest mode: the deck chosen to send to the host (a preset id or an own deck).
signal own_deck_chosen(entry)

const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const DeckStore = preload("res://scripts/core/deck_store.gd")
const DeckModel = preload("res://scripts/core/deck_model.gd")
## Play modes offered offline (MatchController.MODE_AI and MODE_LOCAL).
const MODES = [[0, "MODE_AI"], [1, "MODE_LOCAL"]]
const MODE_ONLINE = 2

var library = Library.new()
## Per side: a preset id or an own deck dictionary.
var choices: Array = ["starter", "green_assault"]
var guest: bool = false
## The mode Start plays in; online (a host) it stays online.
var mode: int = 0
var mode_buttons: Dictionary = {}
var selectors: Array = []
var columns: Array = []
var start_button: Button
var browse_button: Button
var manage_button: Button
var summary: Label
## Per side, the entry behind each selector item (null for a separator).
var option_entries: Array = []
## Own decks that are legal (offered under the presets).
var own_decks: Array = []

func _init() -> void:
	super()
	title_key = "DECKS_TITLE"
	panel_size = Vector2(1180, 790)

## `current`: the decks of both seats; `guest_mode`: only this player's deck
## (seat 0) is chosen, for an online match against a host.
func setup(current: Array, guest_mode: bool = false, play_mode: int = 0) -> void:
	choices = current.duplicate(true)
	mode = play_mode
	while choices.size() < 2:
		choices.append("green_assault")
	guest = guest_mode
	if single_column():
		title_key = "DECKS_GUEST_TITLE"
		panel_size = Vector2(760, 790)

func build() -> void:
	own_decks = DeckStore.list().filter(func(deck): return library.validate_preset(deck).ok)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	for side in range(1 if single_column() else 2):
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		row.add_child(column)
		# The heading shares its row with the deck's faction emblems.
		var heading_row = HBoxContainer.new()
		heading_row.add_theme_constant_override("separation", 6)
		column.add_child(heading_row)
		var heading = label(heading_row, "", 20, UiKit.GOLD)
		heading.add_theme_font_override("font", UiKit.title_font())
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var emblems = HBoxContainer.new()
		emblems.add_theme_constant_override("separation", 4)
		heading_row.add_child(emblems)
		var selector = OptionButton.new()
		selector.name = "DeckSelector%d" % side
		selector.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		selector.add_theme_font_override("font", UiKit.title_font())
		selector.add_theme_font_size_override("font_size", 20)
		selector.clip_text = true
		selector.fit_to_longest_item = false
		column.add_child(selector)
		selector.item_selected.connect(_choice_changed.bind(side))
		selectors.append(selector)
		option_entries.append([])
		var description = label(column, "", 15, UiKit.PAPER_DIM, true)
		description.custom_minimum_size.y = 44
		var heroes = HBoxContainer.new()
		heroes.add_theme_constant_override("separation", 6)
		column.add_child(heroes)
		var list = RichTextLabel.new()
		list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.custom_minimum_size = Vector2(480, 160)
		list.bbcode_enabled = true
		list.add_theme_font_size_override("normal_font_size", 15)
		column.add_child(list)
		columns.append({"heading": heading, "emblems": emblems, "description": description, "heroes": heroes, "list": list})
	summary = label(body, "", 14, UiKit.MUTED, true)
	start_button = button(footer, "", 21)
	start_button.name = "Start"
	start_button.pressed.connect(func():
		if guest:
			own_deck_chosen.emit(_copy(choices[0]))
		else:
			start_requested.emit(choices.map(_copy), mode)
		close())
	footer.move_child(start_button, 0)
	if not guest and mode != MODE_ONLINE:
		var modes = ButtonGroup.new()
		for entry in MODES:
			var choice = button(footer, "", 17)
			choice.name = "Mode%d" % entry[0]
			choice.toggle_mode = true
			choice.button_group = modes
			choice.button_pressed = entry[0] == mode
			choice.pressed.connect(func(): mode = entry[0])
			footer.move_child(choice, 0)
			mode_buttons[entry[0]] = choice
	browse_button = button(footer, "")
	browse_button.name = "Browse"
	browse_button.pressed.connect(func(): catalog_requested.emit())
	footer.move_child(browse_button, 0)
	manage_button = button(footer, "")
	manage_button.name = "Manage"
	manage_button.pressed.connect(func(): manage_requested.emit())
	footer.move_child(manage_button, 0)

## Only this player's deck is chosen (an online guest, or an online host).
func single_column() -> bool:
	return guest or mode == MODE_ONLINE

static func _copy(entry):
	return entry.duplicate(true) if entry is Dictionary else entry

func refresh_text() -> void:
	super()
	for side in range(selectors.size()):
		_fill_selector(side)
		columns[side].heading.text = UiKit.t("DECKS_YOURS" if side == 0 else "DECKS_OPPONENT")
		_fill(side)
	summary.text = UiKit.t("DECKS_GUEST_NOTE") if guest else UiKit.t("DECKS_SUMMARY") + " " + UiKit.t("DECKS_CUSTOM_SUMMARY")
	start_button.text = UiKit.t("DECKS_GUEST_USE" if guest else "DECKS_START")
	browse_button.text = UiKit.t("DECKS_BROWSE")
	manage_button.text = UiKit.t("DECKS_MANAGE")
	for entry in MODES:
		if mode_buttons.has(entry[0]):
			mode_buttons[entry[0]].text = UiKit.t(entry[1])
	browse_button.visible = not guest

## Presets first (their indexes are the preset order), then "My decks".
func _fill_selector(side: int) -> void:
	var selector: OptionButton = selectors[side]
	selector.clear()
	var entries: Array = []
	var selected = 0
	for preset in library.presets():
		selector.add_item(Library.preset_text(str(preset.id)))
		if choices[side] is String and str(preset.id) == choices[side]:
			selected = entries.size()
		entries.append(str(preset.id))
	var own: Array = own_decks.duplicate()
	var current = choices[side]
	if current is Dictionary and library.validate_preset(current).ok and not own.any(func(deck): return deck.id == current.get("id", "")):
		own.push_front(current)
	if not own.is_empty():
		selector.add_separator(UiKit.t("DECKLIST_MINE"))
		entries.append(null)
		for deck in own:
			selector.add_item(DeckStore.clean_name(str(deck.get("name", ""))) if not str(deck.get("name", "")).is_empty() else UiKit.t("DECK_UNNAMED"))
			if current is Dictionary and str(deck.get("id", "")) == str(current.get("id", "")):
				selected = entries.size()
			entries.append(deck)
	option_entries[side] = entries
	selector.select(selected)
	# A deck that is no longer offered (deleted, now illegal, an unknown
	# preset) gives way to the selected entry.
	# An own deck is shown as stored now (it may have been edited since).
	var offered = choices[side] is String and not library.preset(choices[side]).is_empty()
	if not offered:
		choices[side] = entries[selected]

func _choice_changed(index: int, side: int) -> void:
	var entries: Array = option_entries[side]
	if index < 0 or index >= entries.size() or entries[index] == null:
		return
	choices[side] = entries[index]
	_fill(side)

func _fill(side: int) -> void:
	var column: Dictionary = columns[side]
	var choice = choices[side]
	var preset = library.resolve_deck(choice)
	if choice is Dictionary:
		var counts = DeckModel.stats(DeckModel.normalize(choice.duplicate(true)), library)
		column.description.text = UiKit.t("DECK_CUSTOM") + " · " + UiKit.t("DECKLIST_SUMMARY", {"main": counts.main, "items": counts.items})
	else:
		column.description.text = Library.preset_text(str(choice), "description")
	for child in column.heroes.get_children():
		UiKit.discard(child)
	for child in column.emblems.get_children():
		UiKit.discard(child)
	# The factions the deck's heroes fight for, as emblems (Three Kingdoms skin).
	var factions: Array = []
	for hero_id in preset.get("heroes", []):
		var faction = Library.faction(str(hero_id))
		if faction not in factions and UiKit.faction_emblem(faction) != null and Library.current_skin() == "three_kingdoms":
			factions.append(faction)
	for faction in factions:
		var emblem = TextureRect.new()
		emblem.texture = UiKit.faction_emblem(faction)
		emblem.custom_minimum_size = Vector2(30, 30)
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblem.tooltip_text = UiKit.t("FACTION_" + faction.to_upper())
		column.emblems.add_child(emblem)
	for hero_id in preset.get("heroes", []):
		var card = CardView.new()
		card.setup(str(hero_id))
		card.set_size_keep(Vector2(92, 134))
		card.custom_minimum_size = Vector2(92, 134)
		card.tooltip_text = Library.loc(str(hero_id)) + "\n" + Library.loc(str(hero_id), "text")
		column.heroes.add_child(card)
	var main_count = 0
	for card_id in preset.get("cards", {}):
		main_count += int(preset.cards[card_id])
	var item_count = 0
	for card_id in preset.get("items", {}):
		item_count += int(preset.items[card_id])
	var lines: Array = ["[color=#d8b06a]%s[/color]" % UiKit.t("DECKS_MAIN", {"n": main_count})]
	for card_id in _ordered(preset.get("cards", {}), "cost"):
		lines.append(_escape(UiKit.t("DECKS_LINE", {"n": int(preset.cards[card_id]), "card": Library.loc(card_id)})))
	lines.append("\n[color=#d8b06a]%s[/color]" % UiKit.t("DECKS_ITEMS", {"n": item_count}))
	for card_id in _ordered(preset.get("items", {}), "price"):
		lines.append(_escape(UiKit.t("DECKS_LINE", {"n": int(preset.items[card_id]), "card": Library.loc(card_id)})))
	column.list.text = "\n".join(lines)

## Card ids of a list by mana cost (items: price), then name.
func _ordered(counts: Dictionary, order: String) -> Array:
	var ids: Array = counts.keys().map(func(card_id): return str(card_id))
	ids.sort_custom(func(a, b):
		var first = int(library.definition(a).get(order, 0))
		var second = int(library.definition(b).get(order, 0))
		if first != second:
			return first < second
		return Library.loc(a).naturalnocasecmp_to(Library.loc(b)) < 0)
	return ids

static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
