extends "res://scripts/ui/modal_panel.gd"
## Before a campaign battle: the tale's title and era, its objective, your
## army against the enemy, the tale's cast note (who in the two armies is a
## borrowed player; the map shows its note on history and the novel), and
## the three seals with those already earned. Your army is
## the tale's own (a preset), another army the tale suggests, or one of your
## own legal decks; the enemy is the tale's preset with its commander and
## its five heroes in the order they deploy. Begin battle starts the match
## against the AI; Hear the tale plays the story again; Back (or Esc)
## returns. The army is remembered per tale (CampaignStore deck choices); a
## remembered own deck that is gone or no longer legal gives way to the
## tale's army, and the briefing says so.

## The army chosen: a preset id or an own deck (DeckStore entry).
signal begin_requested(entry)
signal story_requested

const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const DeckStore = preload("res://scripts/core/deck_store.gd")
const DeckModel = preload("res://scripts/core/deck_model.gd")
const CampaignData = preload("res://scripts/core/campaign_data.gd")
const CampaignStore = preload("res://scripts/core/campaign_store.gd")
const HERO_CARD = Vector2(92, 134)

var chapter_id: String = ""
var library = Library.new()
## The army chosen (a preset id or an own deck).
var choice = ""
## Per selector item: a preset id, an own deck, or null (the separator).
var entries: Array = []
## Your legal own decks.
var own_decks: Array = []
## A note about the army ("" for none), as an i18n key.
var notice_key: String = ""
var selector: OptionButton
var begin_button: Button
var story_button: Button
var labels: Dictionary = {}
var your_heroes: HBoxContainer
var enemy_heroes: HBoxContainer
var seal_labels: Array = []

func _init() -> void:
	super()
	panel_size = Vector2(1180, 600)

func setup(new_chapter: String) -> void:
	chapter_id = new_chapter

func build() -> void:
	own_decks = DeckStore.list().filter(func(deck): return library.validate_preset(deck).ok)
	choice = _remembered_choice()
	var objective_row = HBoxContainer.new()
	objective_row.add_theme_constant_override("separation", 10)
	body.add_child(objective_row)
	labels.objective_caption = _caption(objective_row, 18)
	labels.objective = label(objective_row, "", 17, UiKit.PAPER, true)
	labels.objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.fate = label(body, "", 15, UiKit.CINNABAR.lightened(0.35), true)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var yours = _column(row)
	labels.your_heading = _caption(yours, 20)
	selector = OptionButton.new()
	selector.name = "ArmySelector"
	selector.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	selector.add_theme_font_override("font", UiKit.title_font())
	selector.add_theme_font_size_override("font_size", 19)
	selector.clip_text = true
	selector.fit_to_longest_item = false
	selector.item_selected.connect(_on_selected)
	yours.add_child(selector)
	your_heroes = _hero_row(yours)
	labels.your_description = label(yours, "", 15, UiKit.PAPER_DIM, true)
	labels.your_description.custom_minimum_size.y = 44
	var seal = VsSeal.new()
	seal.custom_minimum_size = Vector2(96, 0)
	row.add_child(seal)
	var enemy = _column(row)
	labels.enemy_heading = _caption(enemy, 20)
	labels.enemy_name = label(enemy, "", 22, UiKit.PAPER)
	labels.enemy_name.add_theme_font_override("font", UiKit.title_font())
	labels.enemy_name.custom_minimum_size.y = 40
	enemy_heroes = _hero_row(enemy)
	labels.commander = label(enemy, "", 15, UiKit.GOLD)
	labels.enemy_description = label(enemy, "", 15, UiKit.PAPER_DIM, true)
	labels.enemy_description.custom_minimum_size.y = 44
	labels.cast = label(body, "", 14, UiKit.MUTED.lightened(0.15), true)
	body.add_child(HSeparator.new())
	var seals_row = HBoxContainer.new()
	seals_row.add_theme_constant_override("separation", 26)
	body.add_child(seals_row)
	labels.seals_caption = _caption(seals_row, 18)
	for index in range(CampaignData.SEAL_BITS.size()):
		seal_labels.append(label(seals_row, "", 17, UiKit.PAPER_DIM))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seals_row.add_child(spacer)
	labels.record = label(seals_row, "", 15, UiKit.PAPER_DIM)
	labels.notice = label(body, "", 14, UiKit.GOLD, true)
	story_button = button(footer, "", 18)
	story_button.name = "Story"
	story_button.pressed.connect(func():
		story_requested.emit()
		close())
	footer.move_child(story_button, 0)
	begin_button = button(footer, "", 22)
	begin_button.name = "Begin"
	begin_button.custom_minimum_size = Vector2(200, 52)
	begin_button.pressed.connect(begin)

func _column(parent: Control) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	return column

func _caption(parent: Control, font_size: int) -> Label:
	var caption = label(parent, "", font_size, UiKit.GOLD)
	caption.add_theme_font_override("font", UiKit.title_font())
	return caption

func _hero_row(parent: Control) -> HBoxContainer:
	var heroes = HBoxContainer.new()
	heroes.add_theme_constant_override("separation", 6)
	heroes.custom_minimum_size.y = HERO_CARD.y + 8.0
	parent.add_child(heroes)
	return heroes

## The army remembered for this tale, if it is still offered (else the
## tale's own army; a lost own deck leaves a note).
func _remembered_choice():
	var script_deck = CampaignData.player_default(chapter_id)
	var remembered = CampaignStore.deck_choice(chapter_id)
	if remembered.begins_with("preset:"):
		var preset_id = remembered.substr(7)
		if preset_id in _offered_presets():
			return preset_id
	elif remembered.begins_with("own:"):
		var deck_id = remembered.substr(4)
		for deck in own_decks:
			if str(deck.get("id", "")) == deck_id:
				return deck
		notice_key = "CAMPAIGN_DECK_INVALID"
	return script_deck

## The tale's own army and the others it suggests (known presets only).
func _offered_presets() -> Array:
	var offered: Array = [CampaignData.player_default(chapter_id)]
	for preset_id in CampaignData.player_alternatives(chapter_id):
		if not library.preset(preset_id).is_empty() and preset_id not in offered:
			offered.append(preset_id)
	return offered

## Starts the battle with the army chosen (remembered for this tale).
func begin() -> void:
	var value = "preset:" + str(choice) if choice is String else "own:" + str(choice.get("id", ""))
	CampaignStore.set_deck_choice(chapter_id, value)
	begin_requested.emit(choice.duplicate(true) if choice is Dictionary else choice)
	close()

## Picks the army at selector item `index` (tests, and the selector).
func choose(index: int) -> void:
	selector.select(index)
	_on_selected(index)

func _on_selected(index: int) -> void:
	if index < 0 or index >= entries.size() or entries[index] == null:
		return
	choice = entries[index]
	notice_key = ""
	_fill_yours()
	_refresh_notice()

func refresh_text() -> void:
	super()
	var era = CampaignData.chapter_text(chapter_id, "era")
	title_label.text = CampaignData.title(chapter_id) + ("  ·  " + era if not era.is_empty() else "")
	close_button.text = UiKit.t("BTN_BACK")
	story_button.text = UiKit.t("CAMPAIGN_STORY_AGAIN")
	begin_button.text = UiKit.t("CAMPAIGN_BEGIN")
	labels.objective_caption.text = UiKit.t("CAMPAIGN_OBJECTIVE")
	labels.objective.text = CampaignData.chapter_text(chapter_id, "objective")
	labels.fate.text = UiKit.t("CAMPAIGN_DEFY_FATE") if CampaignData.defy_fate(chapter_id) else ""
	labels.fate.visible = CampaignData.defy_fate(chapter_id)
	var cast = CampaignData.chapter_text(chapter_id, "cast_note")
	labels.cast.text = UiKit.t("CAMPAIGN_CAST_NOTE", {"note": cast}) if not cast.is_empty() else ""
	labels.cast.visible = not cast.is_empty()
	labels.your_heading.text = UiKit.t("CAMPAIGN_YOUR_ARMY")
	labels.enemy_heading.text = UiKit.t("CAMPAIGN_ENEMY")
	labels.seals_caption.text = UiKit.t("CAMPAIGN_SEALS")
	var earned = CampaignStore.seals(chapter_id)
	var names = CampaignData.seal_names(CampaignData.par_rounds(chapter_id))
	for index in range(seal_labels.size()):
		var lit = earned & CampaignData.SEAL_BITS[index]
		seal_labels[index].text = ("● " if lit else "○ ") + str(names[index])
		seal_labels[index].add_theme_color_override("font_color", UiKit.GOLD_BRIGHT if lit else UiKit.PAPER_DIM)
	labels.record.text = _record()
	_fill_selector()
	_fill_yours()
	_fill_enemy()
	_refresh_notice()

func _record() -> String:
	var fought = CampaignStore.attempts(chapter_id)
	if fought == 0:
		return UiKit.t("CAMPAIGN_NOT_FOUGHT")
	var text = UiKit.t_n("CAMPAIGN_FOUGHT_N", fought)
	var best = CampaignStore.best_rounds(chapter_id)
	if CampaignStore.is_won(chapter_id) and best > 0:
		text += "  ·  " + UiKit.t("CAMPAIGN_BEST_ROUNDS", {"n": best})
	return text

func _refresh_notice() -> void:
	var text = UiKit.t(notice_key) if not notice_key.is_empty() else ""
	if own_decks.is_empty():
		text = (text + " " if not text.is_empty() else "") + UiKit.t("CAMPAIGN_NO_OWN_DECK")
	labels.notice.text = text
	labels.notice.visible = not text.is_empty()

## The tale's army, the others it suggests, then "My decks".
func _fill_selector() -> void:
	selector.clear()
	entries = []
	var selected = 0
	var offered = _offered_presets()
	for index in range(offered.size()):
		var preset_id: String = offered[index]
		var key = "CAMPAIGN_SCRIPT_DECK" if index == 0 else "CAMPAIGN_ALT_DECK"
		selector.add_item(UiKit.t(key, {"deck": Library.preset_text(preset_id)}))
		if choice is String and choice == preset_id:
			selected = entries.size()
		entries.append(preset_id)
	if not own_decks.is_empty():
		selector.add_separator(UiKit.t("DECKLIST_MINE"))
		entries.append(null)
		for deck in own_decks:
			var name = DeckStore.clean_name(str(deck.get("name", "")))
			selector.add_item(name if not name.is_empty() else UiKit.t("DECK_UNNAMED"))
			if choice is Dictionary and str(deck.get("id", "")) == str(choice.get("id", "")):
				selected = entries.size()
			entries.append(deck)
	selector.select(selected)
	choice = entries[selected]

func _fill_yours() -> void:
	var deck: Dictionary = library.resolve_deck(choice)
	if choice is Dictionary:
		var counts = DeckModel.stats(DeckModel.normalize(choice.duplicate(true)), library)
		labels.your_description.text = UiKit.t("DECK_CUSTOM") + " · " + UiKit.t("DECKLIST_SUMMARY", {"main": counts.main, "items": counts.items})
	else:
		labels.your_description.text = Library.preset_text(str(choice), "description")
	_fill_heroes(your_heroes, deck.get("heroes", []), "")

func _fill_enemy() -> void:
	var preset_id = CampaignData.enemy_preset(chapter_id)
	var commander = CampaignData.enemy_commander(chapter_id)
	labels.enemy_name.text = Library.preset_text(preset_id)
	labels.commander.text = UiKit.t("CAMPAIGN_COMMANDER", {"name": Library.loc(commander)})
	labels.enemy_description.text = Library.preset_text(preset_id, "description")
	_fill_heroes(enemy_heroes, CampaignData.enemy_heroes(chapter_id, library), commander)

## Five hero cards in deploy order; `lead` (the commander) is marked.
func _fill_heroes(row: HBoxContainer, heroes: Array, lead: String) -> void:
	for child in row.get_children():
		UiKit.discard(child)
	for hero_id in heroes:
		var card = CardView.new()
		card.setup(str(hero_id))
		card.set_size_keep(HERO_CARD)
		card.custom_minimum_size = HERO_CARD
		card.selected = str(hero_id) == lead and not lead.is_empty()
		card.tooltip_text = Library.loc(str(hero_id)) + "\n" + Library.loc(str(hero_id), "text")
		row.add_child(card)

## The seal between the two armies.
class VsSeal:
	extends Control

	func _draw() -> void:
		var center = Vector2(size.x * 0.5, minf(size.y * 0.42, 150.0))
		draw_arc(center, 40.0, 0.0, TAU, 64, Color(UiKit.GOLD, 0.55), 2.0, true)
		var side = 56.0
		var seal = Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
		UiKit.draw_round_rect(self, seal, UiKit.CINNABAR, side * 0.12)
		UiKit.draw_round_rect(self, seal.grow(-side * 0.09), Color.TRANSPARENT, side * 0.08, Color(UiKit.PAPER, 0.75), maxf(1.0, side * 0.05))
		UiKit.draw_text(self, UiKit.kai_font(), UiKit.t("VERSUS_SEAL"), center, int(side * 0.46), UiKit.PAPER, side * 0.78)
