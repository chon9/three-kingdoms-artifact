extends Control
## Right-click (or press and hold) on any card or unit: a large card face
## with its full localized text and, for units on the board, the live stats,
## equipment, statuses with their durations, keywords, modifications with
## their sources, granted text and every ability with its cooldown
## (EFFECT_SYSTEM_SPEC.md §8.8). Items and improvements on the board show
## their ability, cooldown and charges. Any click or Esc closes it.

signal closed

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const CARD_SIZE = Vector2(392, 571)
const STATUSES = ["stun", "silence", "disarm", "death_shield"]

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

## Shows `id`; `unit_model` is the board's display model for live units, or
## {"object": instance, "kind": "item" | "improvement"} for an item or an
## improvement on the board.
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
				line += "  ·  " + UiKit.t_n("HUD_COOLDOWN", cooldown)
			details.append(line)
	var object: Dictionary = live.get("object", {})
	if not object.is_empty():
		# An item or improvement on the board: its ability, cooldown and charges.
		if Library.has_active(card_id):
			details.append(_ability_line(card_id, UiKit.t("CARD_ACTIVE_ABILITY"), int(object.get("cd", 0))))
		if int(object.get("charges", 0)) > 0 or definition.has("charges"):
			details.append(UiKit.t("CARD_CHARGES", {"n": int(object.get("charges", 0))}))
		_append_granted(details, object.get("mods", []))
	if not unit.is_empty():
		var items: Array = []
		for slot in ["weapon", "armor", "accessory"]:
			if unit.get("items", {}).has(slot):
				items.append(Library.loc(str(unit.items[slot])))
		if not items.is_empty():
			details.append(UiKit.t("CARD_EQUIPPED", {"items": UiKit.t("LIST_SEPARATOR").join(items)}))
		# Statuses with their durations, derived keywords, and every
		# modification with its source and duration (spec §8.8).
		var statuses: Array = []
		for badge in live.get("badges", []):
			if str(badge.get("k", "")) in STATUSES:
				var label = EventText.keyword_name(str(badge.k))
				var until = str(badge.get("until", ""))
				statuses.append(label if until.is_empty() else UiKit.t("CARD_STATUS_LINE", {"status": label,
					"duration": EventText.t(EventText.DURATION_KEYS.get(until, "EV_UNTIL_ROUND"))}))
		if not statuses.is_empty():
			details.append(UiKit.t("CARD_STATUSES", {"list": UiKit.t("LIST_SEPARATOR").join(statuses)}))
		var keywords: Array = []
		for keyword in live.get("keywords", {}):
			var value = int(live.keywords[keyword])
			var label = EventText.keyword_name(str(keyword))
			keywords.append(label if keyword not in ["siege", "cleave", "retaliate", "regeneration", "bonus_hero", "bonus_tower"] else "%s %d" % [label, value])
		if not keywords.is_empty():
			details.append(UiKit.t("CARD_KEYWORDS", {"list": UiKit.t("LIST_SEPARATOR").join(keywords)}))
		var effects: Array = []
		for entry in live.get("mods", []):
			if not str(entry.get("ab", "")).is_empty() and entry.get("st", {}).is_empty() and entry.get("kw", {}).is_empty():
				continue  # Only a granted ability: listed under "Granted".
			var source = Library.loc(str(entry.get("src", ""))) if not str(entry.get("src", "")).is_empty() else EventText.t("EV_AN_EFFECT")
			var changes = EventText.changes(entry)
			if str(entry.get("k", "")) == "modify":
				effects.append(UiKit.t("CARD_EFFECT_PERMANENT", {"card": source, "changes": changes}))
			else:
				effects.append(UiKit.t("CARD_EFFECT_TEMPORARY", {"card": source, "changes": changes,
					"duration": EventText.t(EventText.DURATION_KEYS.get(str(entry.get("d", "round")), "EV_UNTIL_ROUND"))}))
		if not effects.is_empty():
			details.append(UiKit.t("CARD_EFFECTS", {"list": UiKit.t("LIST_SEPARATOR").join(effects)}))
		_append_granted(details, live.get("mods", []))
		# The abilities of its items.
		for entry in live.get("abilities", []):
			if int(entry.get("source", -1)) != int(unit.get("uid", -2)):
				details.append(_ability_line(str(entry.card), Library.loc(str(entry.card)), int(entry.get("cd", 0))))
		# What each badge on the card means (BADGE_* in ui.csv).
		for badge in live.get("badges", []):
			details.append(UiKit.t_n("BADGE_" + str(badge.get("k", "")).to_upper(), int(badge.get("v", 1))))
		if int(live.get("damage", 0)) > 0:
			details.append(UiKit.t("HUD_INCOMING_DAMAGE", {"n": int(live.damage)}) + ("  " + UiKit.t("HUD_WILL_DIE") if live.get("dies", false) else ""))
	detail_label.text = "\n".join(details)
	detail_label.visible = not details.is_empty()
	hint_label.text = UiKit.t("HINT_CLOSE_INSPECT")

## "<label>: <ability name>  ·  Ready" (or the rounds left).
func _ability_line(source_card: String, label: String, cooldown: int) -> String:
	var line = UiKit.t("CARD_ABILITY_LINE", {"label": label, "ability": EventText.ability_name(source_card)})
	return line + "  ·  " + (UiKit.t_n("HUD_COOLDOWN", cooldown) if cooldown > 0 else UiKit.t("HUD_READY"))

## Granted abilities ("<card>#<index>" in modification entries) with their
## text; the same text granted several times (Stonehall's growth after each
## combat) is listed once with its count.
func _append_granted(details: Array, mods: Array) -> void:
	var order: Array = []
	var counts: Dictionary = {}
	for entry in mods:
		var ability = str(entry.get("ab", ""))
		if ability.is_empty():
			continue
		if not counts.has(ability):
			order.append(ability)
		counts[ability] = int(counts.get(ability, 0)) + 1
	var granted: Array = []
	for ability in order:
		var text = granted_text(ability)
		granted.append(text if int(counts[ability]) == 1 else "%s ×%d" % [text, int(counts[ability])])
	if not granted.is_empty():
		details.append(UiKit.t("CARD_GRANTED", {"list": "\n".join(granted)}))

## The text of granted ability "<card>#<index>" (Library.loc(card, "grant_<index>")),
## or the granting card's name when it has none.
static func granted_text(ability: String) -> String:
	var parts = ability.split("#")
	var card_id = parts[0]
	var text = Library.loc(card_id, "grant_%d" % (int(parts[1]) if parts.size() > 1 else 0))
	return text if not text.is_empty() else Library.loc(card_id)

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
