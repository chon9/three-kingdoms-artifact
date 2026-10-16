extends RefCounted
## Building blocks of the deck screens (deck_list_dialog.gd and
## deck_builder_dialog.gd), drawn in the game's ink, paper and gold:
##   Prompt          an in-dialog question, text field or message (rename,
##                   delete, import and export codes, leaving unsaved changes)
##   CollectionCard  a card face in the builder's collection with its count
##                   in the deck; click or drag adds, right-click inspects
##   HeroSlot        a hero slot of a deploy round; drag heroes between slots
##   DeckRow         a deck list row: cost, name, copies, - and +
##   CurveChart      the mana curve, stacked by card kind
##   Lamps           the deck requirements, red or green
##   ColorCounts     heroes and cards per colour (faction)
##   DropZone        a drop target that hands drags to a callable (and
##                   DropScroll, the same for a scroll area)
## Drags carry {DRAG_KEY: "collection" | "slot" | "row", "card": id[, "slot": n]}.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const DRAG_KEY = "deck_drag"
## Mana curve bar colours by kind: creeps, spells, improvements.
const KIND_COLORS = [Color("b0623e"), Color("4f8fb3"), Color("8a7a4e")]
const LAMP_ON = Color("6fcf73")
const LAMP_OFF = Color("d0493c")

## True when `data` is a deck drag of one of `kinds`.
static func is_drag(data, kinds: Array) -> bool:
	return data is Dictionary and str(data.get(DRAG_KEY, "")) in kinds

# --- Prompt ------------------------------------------------------------------------

## A question over the dialog: title, message, an optional text field, an
## error line and buttons. Esc cancels, Enter confirms.
class Prompt:
	extends Control
	signal confirmed(text: String)
	signal cancelled
	signal extra_pressed

	var panel: PanelContainer
	var title_label: Label
	var message_label: Label
	var field: LineEdit
	var error_label: Label
	var confirm_button: Button
	var cancel_button: Button
	var extra_button: Button
	var width: float = 640.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiKit.box(Color("15161a"), UiKit.GOLD, 6, 1, 20.0))
		add_child(panel)
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		panel.add_child(column)
		title_label = _label(column, 26, UiKit.GOLD_BRIGHT)
		title_label.add_theme_font_override("font", UiKit.title_font())
		message_label = _label(column, 16, UiKit.PAPER_DIM)
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		field = LineEdit.new()
		field.name = "Field"
		field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		field.add_theme_font_size_override("font_size", 17)
		field.text_submitted.connect(func(_text): _confirm())
		column.add_child(field)
		error_label = _label(column, 15, UiKit.DAMAGE)
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Wrapping labels measure their height at their width: refit the panel
		# whenever its content's minimum size changes (an error appears, the
		# labels reflow at their real width), so it never stays stretched.
		panel.minimum_size_changed.connect(_queue_place)
		var row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		extra_button = DeckWidgetsButtons.make(row, "")
		extra_button.name = "Extra"
		extra_button.pressed.connect(func(): extra_pressed.emit())
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		cancel_button = DeckWidgetsButtons.make(row, "")
		cancel_button.name = "Cancel"
		cancel_button.pressed.connect(cancel)
		confirm_button = DeckWidgetsButtons.make(row, "")
		confirm_button.name = "Confirm"
		confirm_button.pressed.connect(_confirm)

	func _label(parent: Control, font_size: int, color: Color) -> Label:
		var label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
		parent.add_child(label)
		return label

	## Fills the prompt. An empty `confirm_text` hides that button; a null
	## `field_text` hides the field; an empty `extra_text` hides the extra button.
	func setup(title: String, message: String, confirm_text: String, cancel_text: String, field_text = null,
			placeholder: String = "", extra_text: String = "") -> void:
		title_label.text = title
		message_label.text = message
		message_label.visible = not message.is_empty()
		field.visible = field_text != null
		field.text = str(field_text) if field_text != null else ""
		field.placeholder_text = placeholder
		confirm_button.text = confirm_text
		confirm_button.visible = not confirm_text.is_empty()
		cancel_button.text = cancel_text
		extra_button.text = extra_text
		extra_button.visible = not extra_text.is_empty()
		error_label.text = ""
		error_label.visible = false
		_place.call_deferred()
		if field.visible:
			_focus_field.call_deferred()

	## (Deferred: the prompt may already be gone again, e.g. closed at once.)
	func _focus_field() -> void:
		if is_inside_tree() and field.is_visible_in_tree():
			field.grab_focus()
			field.select_all()

	func show_error(text: String) -> void:
		error_label.text = text
		error_label.visible = not text.is_empty()
		_place.call_deferred()

	func _confirm() -> void:
		if confirm_button.visible:
			confirmed.emit(field.text)

	func cancel() -> void:
		cancelled.emit()
		UiKit.discard(self)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_place()

	var _place_queued: bool = false

	func _queue_place() -> void:
		if not _place_queued:
			_place_queued = true
			_place.call_deferred()

	func _place() -> void:
		_place_queued = false
		if not is_inside_tree():
			return
		var panel_width = minf(width, size.x - 40.0)
		# The wrapping labels get the panel's inner width up front (the panel's
		# content margin is 20 on each side): without a width Godot measures
		# them one word per line, very tall.
		var inner = maxf(80.0, panel_width - 40.0)
		message_label.custom_minimum_size.x = inner
		error_label.custom_minimum_size.x = inner
		panel.custom_minimum_size = Vector2(panel_width, 0)
		panel.size = Vector2(panel_width, 0)
		panel.position = ((size - panel.size) * 0.5).max(Vector2.ZERO)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.01, 0.55))

	func _unhandled_key_input(event: InputEvent) -> void:
		if event.is_pressed() and event is InputEventKey and event.keycode == KEY_ESCAPE:
			var viewport = get_viewport()
			cancel()
			viewport.set_input_as_handled()

	func _gui_input(event: InputEvent) -> void:
		# Clicks outside the panel do nothing (the question stays open).
		if event is InputEventMouseButton:
			accept_event()

## Button factory shared by the inner classes (they cannot reach the outer
## script's static functions).
class DeckWidgetsButtons:
	static func make(parent: Control, text: String, font_size: int = 18) -> Button:
		var result = Button.new()
		result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		result.text = text
		result.add_theme_font_override("font", UiKit.title_font())
		result.add_theme_font_size_override("font_size", font_size)
		parent.add_child(result)
		return result

# --- Collection card -----------------------------------------------------------------

## A card face in the collection with a badge for its copies in the deck.
## A click adds a copy, a drag carries it to the deck, a right-click
## inspects it. Cards at their limit are dimmed and cannot be dragged.
class CollectionCard:
	extends "res://scripts/ui/card_view.gd"
	signal add_requested(card_id: String)
	signal inspect_requested(card_id: String)
	signal hover_changed(card_id: String, inside: bool)

	var count: int = 0
	var limit: int = 3
	var addable: bool = true
	## False until the card first scrolls into view: until then it draws a
	## plain frame, so opening the builder does not decode every card's art.
	var revealed: bool = false:
		set(value):
			if revealed != value:
				revealed = value
				queue_redraw()
	## Drops on a card (a deck row or hero dragged back) go to the collection.
	var accept_drop: Callable
	var drop: Callable
	var _pressed: bool = false

	func _init() -> void:
		super()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			hovered = true
			hover_changed.emit(card_id, true)
			queue_redraw())
		mouse_exited.connect(func():
			hovered = false
			hover_changed.emit(card_id, false)
			queue_redraw())

	func set_count(copies: int, maximum: int, can_add: bool) -> void:
		# (Always rewritten: the language may have changed.)
		tooltip_text = UiKit.t("DECKB_IN_DECK", {"n": copies}) if copies > 0 else ""
		if copies == count and maximum == limit and can_add == addable:
			return
		count = copies
		limit = maximum
		addable = can_add
		dimmed = not can_add
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_pressed = true
				elif _pressed:
					_pressed = false
					if Rect2(Vector2.ZERO, size).has_point(event.position):
						add_requested.emit(card_id)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				inspect_requested.emit(card_id)
				accept_event()

	func _notification(what: int) -> void:
		# (CardView's own _notification runs too: notifications reach every
		# script of the inheritance chain.)
		if what == NOTIFICATION_DRAG_BEGIN or what == NOTIFICATION_MOUSE_EXIT:
			_pressed = false

	func _get_drag_data(_at_position: Vector2):
		if not addable:
			return null
		_pressed = false
		set_drag_preview(DeckWidgetsStatic.preview(card_id, size))
		return {DRAG_KEY: "collection", "card": card_id}

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		return accept_drop.is_valid() and accept_drop.call(data)

	func _drop_data(_at_position: Vector2, data) -> void:
		if drop.is_valid():
			drop.call(data)

	func _draw() -> void:
		var s = size.x / BASE.x
		if not revealed:
			var frame = UiKit.card_color(str(definition.get("color", "neutral")))
			UiKit.draw_round_rect(self, Rect2(Vector2.ZERO, size), Color("1b1917"), 9.0 * s, frame.darkened(0.25), maxf(1.0, 2.0 * s))
			draw_rect(Rect2(Vector2(2, 2) * s, Vector2(size.x - 4.0 * s, 32.0 * s)), Color(frame, 0.85))
			return
		super()
		if count <= 0:
			return
		var center = badge_center()
		var radius = maxf(11.0, 15.0 * s)
		var full = count >= limit
		UiKit.draw_disc(self, center, radius, Color("17351f") if full else Color("2a1d0e"), LAMP_ON if full else UiKit.GOLD_BRIGHT, maxf(1.5, 2.0 * s))
		if limit == 1:
			# A hero in the deck: a check mark.
			var points = PackedVector2Array([center + Vector2(-0.45, 0.02) * radius, center + Vector2(-0.12, 0.36) * radius,
				center + Vector2(0.48, -0.34) * radius])
			draw_polyline(points, UiKit.PAPER, maxf(2.0, radius * 0.22), true)
		else:
			UiKit.draw_text(self, UiKit.bold_font(), "%d" % count, center, int(radius * 1.15), UiKit.PAPER, -1.0, 1)

	## The copies badge sits on the art's right edge, below the title strip
	## (so it never covers the card's name) and, on heroes and creeps, below
	## the faction emblem in the art's top-right corner.
	func badge_center() -> Vector2:
		var s = size.x / BASE.x
		var layout = _layout()
		var below = 46.0 if layout.stat_bar else 18.0
		return Vector2(size.x - 17.0 * s, layout.art.position.y + below * s)

## Static helpers for the inner classes.
class DeckWidgetsStatic:
	## A drag preview: a card face of `card_size` centred on the cursor.
	static func preview(card_id: String, card_size: Vector2) -> Control:
		var holder = Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card = CardView.new()
		card.setup(card_id)
		card.set_size_keep(card_size)
		card.position = -card_size * 0.5
		card.rotation = deg_to_rad(-3.0)
		card.modulate = Color(1, 1, 1, 0.92)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(card)
		return holder

# --- Hero slot --------------------------------------------------------------------------

## One of the five hero slots. Shows the hero's art, name and colour; an empty
## slot invites a drop. Heroes drag between slots (swapping) and out of the
## deck; a hero dragged from the collection lands in the slot it is dropped on.
class HeroSlot:
	extends Control
	signal dropped(slot: int, data: Dictionary)
	signal remove_requested(slot: int)
	signal inspect_requested(card_id: String)
	## A left click on an empty slot: the builder shows the heroes and the
	## next hero clicked fills this slot.
	signal empty_clicked(slot: int)

	var slot: int = 0
	var hero_id: String = ""
	var _name_key: String = ""
	var _name_text: TextParagraph
	## Other cards dropped on a slot join the deck like drops on the panel.
	var fallback_accept: Callable
	var fallback_drop: Callable
	var drop_hover: bool = false
	## This empty slot waits for the next hero clicked in the collection.
	var waiting: bool = false:
		set(value):
			if waiting != value:
				waiting = value
				queue_redraw()
	var _hover: bool = false
	var remove_button: Button

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(68, 98)
		mouse_entered.connect(func():
			_hover = true
			_update_remove()
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			_update_remove()
			queue_redraw())
		remove_button = Button.new()
		remove_button.name = "Remove"
		remove_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		remove_button.text = "×"
		remove_button.focus_mode = Control.FOCUS_NONE
		remove_button.add_theme_font_size_override("font_size", 14)
		remove_button.add_theme_stylebox_override("normal", UiKit.box(Color(0.1, 0.05, 0.04, 0.92), UiKit.CINNABAR, 9, 1, 0.0))
		remove_button.add_theme_stylebox_override("hover", UiKit.box(UiKit.CINNABAR, UiKit.GOLD_BRIGHT, 9, 1, 0.0))
		remove_button.add_theme_stylebox_override("pressed", UiKit.box(UiKit.CINNABAR, UiKit.GOLD_BRIGHT, 9, 1, 0.0))
		remove_button.size = Vector2(20, 20)
		remove_button.visible = false
		remove_button.pressed.connect(func(): remove_requested.emit(slot))
		add_child(remove_button)

	func set_hero(id: String) -> void:
		hero_id = id
		tooltip_text = Library.loc(id) if not id.is_empty() else UiKit.t("DECKB_SLOT_EMPTY")
		remove_button.tooltip_text = UiKit.t("DECKB_REMOVE_HERO")
		mouse_default_cursor_shape = Control.CURSOR_DRAG if not id.is_empty() else Control.CURSOR_POINTING_HAND
		_update_remove()
		queue_redraw()

	func _update_remove() -> void:
		remove_button.visible = not hero_id.is_empty() and _hover
		remove_button.position = Vector2(size.x - 22, 2)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_update_remove()
		elif what == NOTIFICATION_DRAG_END:
			drop_hover = false
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not hero_id.is_empty():
			inspect_requested.emit(hero_id)
			accept_event()
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hero_id.is_empty() \
				and Rect2(Vector2.ZERO, size).has_point(event.position):
			empty_clicked.emit(slot)
			accept_event()

	func _get_drag_data(_at_position: Vector2):
		if hero_id.is_empty():
			return null
		set_drag_preview(DeckWidgetsStatic.preview(hero_id, Vector2(120, 175)))
		return {DRAG_KEY: "slot", "slot": slot, "card": hero_id}

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		var ok = _takes_hero(data)
		if ok != drop_hover:
			drop_hover = ok
			queue_redraw()
		return ok or (fallback_accept.is_valid() and fallback_accept.call(data))

	func _takes_hero(data) -> bool:
		return data is Dictionary and (str(data.get(DRAG_KEY, "")) == "slot"
			or (str(data.get(DRAG_KEY, "")) == "collection" and str(Library.raw_definition(str(data.get("card", ""))).get("kind", "")) == "hero"))

	func _drop_data(_at_position: Vector2, data) -> void:
		drop_hover = false
		queue_redraw()
		if _takes_hero(data):
			dropped.emit(slot, data)
		elif fallback_drop.is_valid():
			fallback_drop.call(data)

	func _draw() -> void:
		var rect = Rect2(Vector2.ZERO, size)
		var radius = 6.0
		if hero_id.is_empty():
			var lit = drop_hover or waiting or _hover
			UiKit.draw_round_rect(self, rect, Color(UiKit.GOLD, 0.12) if waiting else Color(0.0, 0.0, 0.0, 0.35), radius)
			_dashed(rect.grow(-2.0), UiKit.GOLD_BRIGHT if waiting else (UiKit.GOLD if lit else Color(UiKit.GOLD_DARK, 0.9)))
			var center = rect.get_center() + Vector2(0, -8)
			UiKit.draw_disc(self, center, 13.0, Color(0.08, 0.07, 0.06), UiKit.GOLD if lit else UiKit.GOLD_DARK, 1.5)
			draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), UiKit.GOLD, 2.0)
			draw_line(center + Vector2(0, -6), center + Vector2(0, 6), UiKit.GOLD, 2.0)
			UiKit.draw_text(self, UiKit.body_font(), UiKit.t("DECKB_SLOT_EMPTY"), Vector2(size.x * 0.5, size.y - 16), 12, UiKit.MUTED, size.x - 6)
			return
		var definition = Library.raw_definition(hero_id)
		var color = UiKit.card_color(str(definition.get("color", "neutral")))
		draw_colored_polygon(UiKit.round_rect_points(rect.grow(1.0), radius + 1.0), Color(0, 0, 0, 0.5))
		var art = Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var points = UiKit.round_rect_points(art, radius - 1.0)
		var entry = CardArt.art(hero_id)
		if not entry.is_empty():
			UiKit.draw_cover_polygon(self, points, art, entry.texture, Vector2(0.5, 0.22), Color.WHITE, entry.region)
		else:
			CardArt.draw_placeholder(self, art, hero_id, true)
		var band = Rect2(Vector2(2, size.y - 30), Vector2(size.x - 4, 28))
		UiKit.draw_vgradient(self, Rect2(Vector2(2, size.y - 48), Vector2(size.x - 4, 18)), Color(0, 0, 0, 0), Color(0, 0, 0, 0.7))
		draw_rect(band, Color(0, 0, 0, 0.74))
		draw_rect(Rect2(Vector2(2, size.y - 31), Vector2(size.x - 4, 2)), color.lightened(0.15))
		# Long names (the classic skin) wrap onto two lines rather than shrink.
		var name = Library.loc(hero_id)
		var key = "%s|%s|%s" % [name, band.size, TranslationServer.get_locale()]
		if key != _name_key:
			_name_key = key
			_name_text = UiKit.fit_paragraph(name, UiKit.title_font(), band.size - Vector2(6, 2), 13, 9)
		var text_size = _name_text.get_size()
		_name_text.draw(get_canvas_item(), Vector2(band.position.x + 3, band.get_center().y - text_size.y * 0.5), UiKit.PAPER)
		UiKit.draw_card_emblem(self, hero_id, Vector2(size.x - 13, 13), 18.0)
		var border = UiKit.GOLD_BRIGHT if drop_hover or _hover else color.lightened(0.2)
		UiKit.draw_round_rect(self, rect, Color.TRANSPARENT, radius, border, 2.0 if drop_hover else 1.5)

	func _dashed(rect: Rect2, color: Color) -> void:
		var points = UiKit.round_rect_points(rect, 5.0, 3)
		points.append(points[0])
		var dash = 6.0
		var gap = 4.0
		for index in range(points.size() - 1):
			var start: Vector2 = points[index]
			var end: Vector2 = points[index + 1]
			var length = start.distance_to(end)
			var travelled = 0.0
			while travelled < length:
				var a = start.lerp(end, travelled / length)
				var b = start.lerp(end, minf(travelled + dash, length) / length)
				draw_line(a, b, color, 1.5, true)
				travelled += dash + gap

# --- Deck row ---------------------------------------------------------------------------

## One card of the deck list: cost gem (price coin for items), colour stripe,
## name, copies and - / + buttons. A signature card shows a lock instead of
## the buttons. Rows drag out of the deck (one copy) and right-click inspects.
class DeckRow:
	extends Control
	signal add_requested(card_id: String)
	signal remove_requested(card_id: String)
	signal inspect_requested(card_id: String)
	signal hover_changed(card_id: String, row: Control, inside: bool)

	const HEIGHT = 30.0
	var card_id: String = ""
	var count: int = 0
	var locked: bool = false
	var can_add: bool = true
	var owner_hero: String = ""
	var accept_drop: Callable
	var drop: Callable
	var minus: Button
	var plus: Button
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(200, HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_entered.connect(func():
			_hover = true
			hover_changed.emit(card_id, self, true)
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			hover_changed.emit(card_id, self, false)
			queue_redraw())
		minus = _small("−")
		minus.name = "Minus"
		minus.pressed.connect(func(): remove_requested.emit(card_id))
		plus = _small("+")
		plus.name = "Plus"
		plus.pressed.connect(func(): add_requested.emit(card_id))

	func _small(text: String) -> Button:
		var button = Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = text
		button.focus_mode = Control.FOCUS_NONE
		# Drops over a button still reach the row.
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.add_theme_font_override("font", UiKit.bold_font())
		button.add_theme_font_size_override("font_size", 15)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var fill = {"normal": Color(0.1, 0.1, 0.11), "hover": Color("2b261d"), "pressed": UiKit.GOLD, "disabled": Color(0.07, 0.07, 0.08)}[state]
			var border = {"normal": Color(UiKit.GOLD_DARK, 0.8), "hover": UiKit.GOLD, "pressed": UiKit.GOLD_BRIGHT, "disabled": Color(0.2, 0.2, 0.2)}[state]
			button.add_theme_stylebox_override(state, UiKit.box(fill, border, 4, 1, 0.0))
		button.size = Vector2(22, 22)
		add_child(button)
		return button

	func setup(id: String, copies: int, is_locked: bool, addable: bool, hero: String = "") -> void:
		card_id = id
		count = copies
		locked = is_locked
		can_add = addable
		owner_hero = hero
		minus.visible = not locked
		plus.visible = not locked
		plus.disabled = not addable
		minus.tooltip_text = UiKit.t("DECKB_REMOVE_ONE")
		plus.tooltip_text = UiKit.t("DECKB_ADD_ONE")
		tooltip_text = UiKit.t("DECKB_LOCKED", {"hero": Library.loc(hero)}) if locked else ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_DRAG
		_place_buttons()
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_place_buttons()

	func _place_buttons() -> void:
		plus.position = Vector2(size.x - 26, (HEIGHT - 22) * 0.5)
		minus.position = Vector2(size.x - 52, (HEIGHT - 22) * 0.5)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			inspect_requested.emit(card_id)
			accept_event()

	func _get_drag_data(_at_position: Vector2):
		if locked:
			return null
		set_drag_preview(DeckWidgetsStatic.preview(card_id, Vector2(120, 175)))
		return {DRAG_KEY: "row", "card": card_id}

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		return accept_drop.is_valid() and accept_drop.call(data)

	func _drop_data(_at_position: Vector2, data) -> void:
		if drop.is_valid():
			drop.call(data)

	func _draw() -> void:
		var definition = Library.raw_definition(card_id)
		var kind = str(definition.get("kind", ""))
		var rect = Rect2(Vector2.ZERO, Vector2(size.x, HEIGHT))
		var color = UiKit.card_color(str(definition.get("color", "neutral")))
		UiKit.draw_hgradient(self, rect.grow_individual(0, -1, 0, -1), Color(color.darkened(0.45), 0.85), Color(0.06, 0.06, 0.07, 0.6))
		if _hover:
			draw_rect(rect, Color(1, 1, 1, 0.06))
		draw_rect(Rect2(0, 1, 4, HEIGHT - 2), color.lightened(0.15))
		var gem = Vector2(19, HEIGHT * 0.5)
		if kind == "item":
			UiKit.draw_disc(self, gem, 11.0, Color("b98a2e"), UiKit.GOLD_BRIGHT, 1.5)
			UiKit.draw_text(self, UiKit.bold_font(), str(int(definition.get("price", 0))), gem, 12, Color("2a1a08"))
		else:
			UiKit.draw_disc(self, gem, 11.0, Color("1d2430"), UiKit.GOLD, 1.5)
			UiKit.draw_text(self, UiKit.bold_font(), str(int(definition.get("cost", 0))), gem, 13, UiKit.PAPER)
		var right = size.x - (14.0 if locked else 60.0)
		var count_text = "×%d" % count
		var count_width = UiKit.bold_font().get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var name_right = right - count_width - 10.0
		var name_left = 36.0
		if locked:
			UiKit.draw_icon(self, "lock_closed", Rect2(Vector2(name_left, HEIGHT * 0.5 - 7), Vector2(14, 14)), UiKit.GOLD)
			name_left += 18.0
		UiKit.draw_text_left(self, UiKit.body_font(), Library.loc(card_id), Vector2(name_left, HEIGHT * 0.5), 15,
			UiKit.GOLD_BRIGHT if locked else UiKit.PAPER, name_right - name_left)
		UiKit.draw_text_left(self, UiKit.bold_font(), count_text, Vector2(right - count_width, HEIGHT * 0.5), 15,
			UiKit.GOLD if count >= 3 else UiKit.PAPER_DIM)

# --- Charts ------------------------------------------------------------------------------

## The main deck's mana curve: one bar per cost 1-7 and 8+, stacked by kind
## (creeps, spells, improvements), with counts above and costs below.
class CurveChart:
	extends Control
	var curve: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(250, 78)

	func set_curve(values: Array) -> void:
		curve = values
		queue_redraw()

	func _draw() -> void:
		var buckets = 8
		var label_h = 16.0
		var top_pad = 16.0
		var gap = 6.0
		var bar_w = (size.x - gap * (buckets - 1)) / buckets
		var tallest = 1
		for bucket in curve:
			tallest = maxi(tallest, int(bucket[0]) + int(bucket[1]) + int(bucket[2]))
		var usable = size.y - label_h - top_pad
		for index in range(buckets):
			var x = index * (bar_w + gap)
			var base_y = size.y - label_h
			draw_rect(Rect2(Vector2(x, top_pad), Vector2(bar_w, usable)), Color(1, 1, 1, 0.035))
			var values: Array = curve[index] if index < curve.size() else [0, 0, 0]
			var y = base_y
			var total = 0
			for kind in range(3):
				var amount = int(values[kind])
				if amount <= 0:
					continue
				var height = usable * float(amount) / float(tallest)
				draw_rect(Rect2(Vector2(x, y - height), Vector2(bar_w, height)), KIND_COLORS[kind])
				draw_rect(Rect2(Vector2(x, y - height), Vector2(bar_w, 1.5)), Color(1, 1, 1, 0.25))
				y -= height
				total += amount
			draw_line(Vector2(x, base_y), Vector2(x + bar_w, base_y), Color(UiKit.GOLD_DARK, 0.9), 1.0)
			if total > 0:
				UiKit.draw_text(self, UiKit.bold_font(), str(total), Vector2(x + bar_w * 0.5, y - 8), 13, UiKit.PAPER)
			UiKit.draw_text(self, UiKit.bold_font(), str(index + 1) if index < buckets - 1 else "8+", Vector2(x + bar_w * 0.5, size.y - label_h * 0.5),
				13, UiKit.GOLD)

## The deck requirements as lamps (green when met) with short labels, wrapped
## over as many rows as the width needs.
class Lamps:
	extends Control
	var labels: Array = []
	var states: Array = []
	const ROW_H = 22.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_lamps(texts: Array, met: Array) -> void:
		labels = texts
		states = met
		_resize()
		queue_redraw()

	func _resize() -> void:
		var rows = _layout(size.x if size.x > 0 else 380.0).size()
		custom_minimum_size = Vector2(0, maxf(1, rows) * ROW_H)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_resize()
			queue_redraw()

	## Lamp indexes per row for `width`.
	func _layout(width: float) -> Array:
		var rows: Array = [[]]
		var x = 0.0
		for index in range(labels.size()):
			var item_w = 22.0 + UiKit.body_font().get_string_size(str(labels[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14.0
			if x + item_w > width and not rows.back().is_empty():
				rows.append([])
				x = 0.0
			rows.back().append(index)
			x += item_w
		return rows

	func _draw() -> void:
		var rows = _layout(size.x)
		for row_index in range(rows.size()):
			var x = 0.0
			for index in rows[row_index]:
				var met = index < states.size() and states[index]
				var center = Vector2(x + 8, row_index * ROW_H + ROW_H * 0.5)
				draw_circle(center, 7.0, Color(LAMP_ON if met else LAMP_OFF, 0.25))
				draw_circle(center, 5.0, LAMP_ON if met else LAMP_OFF)
				draw_circle(center + Vector2(-1.5, -1.5), 1.8, Color(1, 1, 1, 0.5))
				var text = str(labels[index])
				UiKit.draw_text_left(self, UiKit.body_font(), text, Vector2(x + 20, center.y), 14, UiKit.PAPER if met else UiKit.PAPER_DIM)
				x += 22.0 + UiKit.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14.0


## Heroes and main deck cards per colour: the faction emblem (Three Kingdoms
## skin) or a colour dot, a crown with the heroes and a card stack with the
## cards, for each colour the deck uses. When the full form does not fit its
## width (four or five colours beside the average cost) it turns compact: the
## emblem and the card count only (the heroes show in their slots; the
## tooltip lists both). Its minimum width is the compact form's.
class ColorCounts:
	extends Control
	const ORDER = ["red", "green", "blue", "black", "neutral"]
	const FACTIONS = {"red": "shu", "green": "wu", "blue": "wei", "black": "qun"}
	const FACTION_KEYS = {"red": "FACTION_SHU", "green": "FACTION_WU", "blue": "FACTION_WEI", "black": "FACTION_QUN", "neutral": "FACTION_NEUTRAL"}
	const COLOR_KEYS = {"red": "COLOR_RED", "green": "COLOR_GREEN", "blue": "COLOR_BLUE", "black": "COLOR_BLACK", "neutral": "COLOR_NEUTRAL"}
	const FONT_SIZE = 14
	const GAP = 22.0
	const COMPACT_GAP = 12.0
	var counts: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(0, 24)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func set_counts(colors: Dictionary) -> void:
		counts = colors
		custom_minimum_size.x = layout_width(true)
		var keys = FACTION_KEYS if Library.current_skin() == "three_kingdoms" else COLOR_KEYS
		var lines: Array = []
		for color in _entries():
			lines.append(UiKit.t("DECKB_COLOR_TIP", {"name": UiKit.t(keys[color]), "heroes": int(counts[color].heroes),
				"cards": int(counts[color].cards)}))
		tooltip_text = "\n".join(lines)
		queue_redraw()

	func _entries() -> Array:
		return ORDER.filter(func(color): return counts.has(color) and int(counts[color].heroes) + int(counts[color].cards) > 0)

	func _number_width(value: int) -> float:
		return UiKit.bold_font().get_string_size(str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x

	## Width of one colour's entry, without the gap after it.
	func _entry_width(color: String, compact: bool) -> float:
		var entry: Dictionary = counts[color]
		if compact:
			return 26.0 + _number_width(int(entry.cards))
		return 27.0 + 16.0 + _number_width(int(entry.heroes)) + 9.0 + 16.0 + _number_width(int(entry.cards))

	## The width all entries need in the full or the compact form.
	func layout_width(compact: bool) -> float:
		var total = 0.0
		var entries = _entries()
		for index in range(entries.size()):
			total += _entry_width(entries[index], compact) + (0.0 if index == entries.size() - 1 else (COMPACT_GAP if compact else GAP))
		return ceilf(total)

	## True when the entries are drawn in the compact form.
	func is_compact() -> bool:
		return size.x + 0.5 < layout_width(false)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var compact = is_compact()
		var x = 0.0
		var mid = size.y * 0.5
		for color in _entries():
			var entry: Dictionary = counts[color]
			var emblem = UiKit.faction_emblem(FACTIONS.get(color, "")) if Library.current_skin() == "three_kingdoms" and FACTIONS.has(color) else null
			if emblem != null:
				draw_texture_rect(emblem, Rect2(Vector2(x, mid - 11), Vector2(22, 22)), false)
			else:
				draw_circle(Vector2(x + 11, mid), 8.0, UiKit.GOLD_DARK)
				draw_circle(Vector2(x + 11, mid), 6.5, UiKit.card_color(color).lightened(0.15))
			if compact:
				x += 26.0
				UiKit.draw_text_left(self, UiKit.bold_font(), str(int(entry.cards)), Vector2(x, mid), FONT_SIZE, UiKit.PAPER)
				x += _number_width(int(entry.cards)) + COMPACT_GAP
				continue
			x += 27.0
			UiKit.draw_icon(self, "crown_a", Rect2(Vector2(x, mid - 7), Vector2(14, 14)), UiKit.GOLD)
			x += 16.0
			UiKit.draw_text_left(self, UiKit.bold_font(), str(int(entry.heroes)), Vector2(x, mid), FONT_SIZE, UiKit.PAPER)
			x += _number_width(int(entry.heroes)) + 9.0
			UiKit.draw_icon(self, "cards_stack", Rect2(Vector2(x, mid - 7), Vector2(14, 14)), UiKit.GOLD)
			x += 16.0
			UiKit.draw_text_left(self, UiKit.bold_font(), str(int(entry.cards)), Vector2(x, mid), FONT_SIZE, UiKit.PAPER)
			x += _number_width(int(entry.cards)) + GAP

# --- Drop zone ------------------------------------------------------------------------------

## A container that accepts drags through callables (the deck panel accepts
## collection cards, the collection accepts rows and slots to remove them).
class DropZone:
	extends PanelContainer
	var accept_drop: Callable
	var drop: Callable
	## The drag under way could land here (shown for the whole drag).
	var hint: bool = false:
		set(value):
			if hint != value:
				hint = value
				queue_redraw()
	## A drag is over the zone itself.
	var highlight: bool = false:
		set(value):
			if highlight != value:
				highlight = value
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		var ok = accept_drop.is_valid() and accept_drop.call(data)
		highlight = ok
		return ok

	func _drop_data(_at_position: Vector2, data) -> void:
		highlight = false
		if drop.is_valid():
			drop.call(data)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_BEGIN:
			hint = accept_drop.is_valid() and accept_drop.call(get_viewport().gui_get_drag_data())
		elif what == NOTIFICATION_DRAG_END:
			hint = false
			highlight = false
		elif what == NOTIFICATION_MOUSE_EXIT:
			highlight = false

	func _draw() -> void:
		if hint or highlight:
			var strength = 1.0 if highlight else 0.6
			UiKit.draw_round_rect(self, Rect2(Vector2.ZERO, size).grow(-1.0), Color(UiKit.GOLD, 0.07 * strength), 6.0,
				Color(UiKit.GOLD_BRIGHT, 0.9 * strength), 2.0)

## A scroll container that accepts drags like a DropZone (drops land on the
## scroll area between rows).
class DropScroll:
	extends ScrollContainer
	var accept_drop: Callable
	var drop: Callable

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		return accept_drop.is_valid() and accept_drop.call(data)

	func _drop_data(_at_position: Vector2, data) -> void:
		if drop.is_valid():
			drop.call(data)
