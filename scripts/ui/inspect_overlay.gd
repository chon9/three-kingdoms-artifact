extends Control
## Right-click (or press and hold) on any card or unit: a large card face
## with its full localized text and, for units on the board, the live stats,
## equipment, status and ability cooldown. Any click or Esc closes it.

signal closed

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const CARD_SIZE = Vector2(392, 571)

var card: Control
var panel: PanelContainer
var title_label: Label
var kind_label: Label
var text_label: Label
var detail_label: Label
var hint_label: Label
var card_id: String = ""
var live: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	card = CardView.new()
	card.set_size_keep(CARD_SIZE)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	title_label = _label(column, 38, UiKit.GOLD_BRIGHT, UiKit.title_font())
	kind_label = _label(column, 17, UiKit.PAPER_DIM, null)
	column.add_child(HSeparator.new())
	text_label = _label(column, 21, UiKit.PAPER, null)
	detail_label = _label(column, 18, UiKit.PAPER_DIM, null)
	hint_label = _label(column, 14, UiKit.MUTED, null)

func _label(parent: Control, font_size: int, color: Color, font: Font) -> Label:
	var label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 420
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font != null:
		label.add_theme_font_override("font", font)
	parent.add_child(label)
	return label

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()

func _place() -> void:
	var total = CARD_SIZE.x + 40.0 + 470.0
	var left = (size.x - total) * 0.5
	card.position = Vector2(left, (size.y - CARD_SIZE.y) * 0.5 - 20.0)
	panel.position = Vector2(left + CARD_SIZE.x + 40.0, card.position.y + 30.0)
	panel.size = Vector2(470, 0)

## Shows `id`; `unit_model` is the board's display model for live units.
func show_card(id: String, unit_model: Dictionary = {}) -> void:
	card_id = id
	live = unit_model
	visible = true
	_place()
	refresh_text()
	if not AnimationQueue.instant:
		card.scale = Vector2(0.85, 0.85)
		modulate.a = 0.0
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "scale", Vector2.ONE, AnimationQueue.duration(0.18))
		tween.tween_property(self, "modulate:a", 1.0, AnimationQueue.duration(0.14))

func refresh_text() -> void:
	if card_id.is_empty():
		return
	var definition = Library.raw_definition(card_id)
	var unit: Dictionary = live.get("unit", {})
	var values: Dictionary = {}
	if not unit.is_empty():
		values = {"attack": int(live.get("attack", 0)), "armor": int(live.get("armor", 0)),
			"health": int(live.get("health", 0)), "max_health": int(live.get("max_health", 0)), "items": unit.get("items", {})}
	card.setup(card_id, values)
	card.set_size_keep(CARD_SIZE)
	title_label.text = Library.loc(card_id)
	var kind = str(definition.get("kind", "spell"))
	var parts: Array = [UiKit.t("KIND_" + kind.to_upper())]
	var color = str(definition.get("color", "neutral"))
	if Library.current_skin() == "three_kingdoms" and Library.faction(card_id) != "neutral":
		parts.append(UiKit.t("FACTION_" + Library.faction(card_id).to_upper()))
	elif color not in ["neutral", "item"]:
		parts.append(UiKit.t("COLOR_" + color.to_upper()))
	if kind in ["spell", "creep", "improvement"]:
		parts.append(UiKit.t("CARD_COST", {"n": int(definition.get("cost", 0))}))
	if kind == "item":
		parts.append(UiKit.t("CARD_PRICE", {"n": int(definition.get("price", 0))}))
		if definition.has("slot"):
			parts.append(UiKit.t("SLOT_" + str(definition.slot).to_upper()))
		elif definition.get("consumable", false):
			parts.append(UiKit.t("SLOT_CONSUMABLE"))
	if definition.get("cross_lane", false):
		parts.append(UiKit.t("CARD_CROSS_LANE"))
	kind_label.text = "  ·  ".join(parts)
	text_label.text = Library.loc(card_id, "text")
	var details: Array = []
	if kind in ["hero", "creep"]:
		var attack = int(live.get("attack", definition.get("attack", 0)))
		var armor = int(live.get("armor", definition.get("armor", 0)))
		var health = int(live.get("health", definition.get("health", 0)))
		details.append(UiKit.t("STAT_LINE", {"attack": attack, "armor": armor, "health": health}))
	if kind == "hero":
		var signature = str(definition.get("signature", ""))
		if not signature.is_empty():
			details.append(UiKit.t("CARD_SIGNATURE", {"card": Library.loc(signature)}))
		var ability = Library.loc(card_id, "ability_name")
		if Library.has_active(card_id):
			var cooldown = int(unit.get("cooldown", 0))
			var line = UiKit.t("CARD_ABILITY_LINE", {"label": UiKit.t("CARD_ACTIVE_ABILITY"), "ability": ability})
			if cooldown > 0:
				line += "  ·  " + UiKit.t("HUD_COOLDOWN", {"n": cooldown})
			details.append(line)
	if not unit.is_empty():
		var items: Array = []
		for slot in ["weapon", "armor", "accessory"]:
			if unit.get("items", {}).has(slot):
				items.append(Library.loc(str(unit.items[slot])))
		if not items.is_empty():
			details.append(UiKit.t("CARD_EQUIPPED", {"items": UiKit.t("LIST_SEPARATOR").join(items)}))
		if unit.get("silenced", false):
			details.append(UiKit.t("HUD_SILENCED"))
		# Derived keywords and every modification with its source and
		# duration (spec §8.8).
		var keywords: Array = []
		for keyword in live.get("keywords", {}):
			var value = int(live.keywords[keyword])
			var label = EventText.keyword_name(str(keyword))
			keywords.append(label if keyword not in ["siege", "cleave", "retaliate", "regeneration", "bonus_hero", "bonus_tower"] else "%s %d" % [label, value])
		if not keywords.is_empty():
			details.append(UiKit.t("CARD_KEYWORDS", {"list": UiKit.t("LIST_SEPARATOR").join(keywords)}))
		var effects: Array = []
		for entry in live.get("mods", []):
			var source = Library.loc(str(entry.get("src", ""))) if not str(entry.get("src", "")).is_empty() else EventText.t("EV_AN_EFFECT")
			var changes = EventText.changes(entry)
			if str(entry.get("k", "")) == "modify":
				effects.append(UiKit.t("CARD_EFFECT_PERMANENT", {"card": source, "changes": changes}))
			else:
				effects.append(UiKit.t("CARD_EFFECT_TEMPORARY", {"card": source, "changes": changes,
					"duration": EventText.t(EventText.DURATION_KEYS.get(str(entry.get("d", "round")), "EV_UNTIL_ROUND"))}))
		if not effects.is_empty():
			details.append(UiKit.t("CARD_EFFECTS", {"list": UiKit.t("LIST_SEPARATOR").join(effects)}))
		if int(live.get("damage", 0)) > 0:
			details.append(UiKit.t("HUD_INCOMING_DAMAGE", {"n": int(live.damage)}) + ("  " + UiKit.t("HUD_WILL_DIE") if live.get("dies", false) else ""))
	detail_label.text = "\n".join(details)
	detail_label.visible = not details.is_empty()
	hint_label.text = UiKit.t("HINT_CLOSE_INSPECT")

func close() -> void:
	if visible:
		visible = false
		closed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.015, 0.78))
