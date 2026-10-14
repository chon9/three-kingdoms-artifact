extends "res://scripts/ui/modal_panel.gd"
## Deck selection: one preset per player with its description, five heroes
## and the main and item deck lists, all localized. Start launches the
## matchup; Browse opens the card catalog.

signal start_requested(decks: Array)
signal catalog_requested

const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")

var library = Library.new()
var choices: Array = ["starter", "green_assault"]
var selectors: Array = []
var columns: Array = []
var start_button: Button
var browse_button: Button
var summary: Label

func _init() -> void:
	super()
	title_key = "DECKS_TITLE"
	panel_size = Vector2(1180, 790)

func setup(current: Array) -> void:
	choices = current.duplicate()

func build() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	for side in range(2):
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		row.add_child(column)
		var heading = label(column, "", 20, UiKit.GOLD)
		heading.add_theme_font_override("font", UiKit.title_font())
		var selector = OptionButton.new()
		selector.name = "DeckSelector%d" % side
		selector.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		selector.add_theme_font_override("font", UiKit.title_font())
		selector.add_theme_font_size_override("font_size", 20)
		column.add_child(selector)
		selector.item_selected.connect(_choice_changed.bind(side))
		selectors.append(selector)
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
		columns.append({"heading": heading, "description": description, "heroes": heroes, "list": list})
	summary = label(body, "", 14, UiKit.MUTED, true)
	start_button = button(footer, "", 21)
	start_button.name = "Start"
	start_button.pressed.connect(func():
		start_requested.emit(choices.duplicate())
		close())
	footer.move_child(start_button, 0)
	browse_button = button(footer, "")
	browse_button.name = "Browse"
	browse_button.pressed.connect(func(): catalog_requested.emit())
	footer.move_child(browse_button, 0)

func refresh_text() -> void:
	super()
	var presets = library.presets()
	for side in range(2):
		var selector: OptionButton = selectors[side]
		selector.clear()
		var selected = 0
		for index in range(presets.size()):
			selector.add_item(Library.preset_text(presets[index].id))
			if presets[index].id == choices[side]:
				selected = index
		selector.select(selected)
		columns[side].heading.text = UiKit.t("DECKS_YOURS" if side == 0 else "DECKS_OPPONENT")
		_fill(side)
	summary.text = UiKit.t("DECKS_SUMMARY")
	start_button.text = UiKit.t("DECKS_START")
	browse_button.text = UiKit.t("DECKS_BROWSE")

func _choice_changed(index: int, side: int) -> void:
	choices[side] = library.presets()[index].id
	_fill(side)

func _fill(side: int) -> void:
	var column: Dictionary = columns[side]
	var preset = library.preset(str(choices[side]))
	column.description.text = Library.preset_text(str(choices[side]), "description")
	for child in column.heroes.get_children():
		UiKit.discard(child)
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
	for card_id in preset.get("cards", {}):
		lines.append(UiKit.t("DECKS_LINE", {"n": int(preset.cards[card_id]), "card": Library.loc(card_id)}))
	lines.append("\n[color=#d8b06a]%s[/color]" % UiKit.t("DECKS_ITEMS", {"n": item_count}))
	for card_id in preset.get("items", {}):
		lines.append(UiKit.t("DECKS_LINE", {"n": int(preset.items[card_id]), "card": Library.loc(card_id)}))
	column.list.text = "\n".join(lines)
