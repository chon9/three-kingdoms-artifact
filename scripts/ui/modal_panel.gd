extends Control
## Base for in-game dialogs: a dimmed backdrop, a centred ink panel with a
## Kai title, a body container and a footer row. Subclasses fill `body` in
## build() and re-localize in refresh_text(). Esc or Close dismisses it.

signal closed

const UiKit = preload("res://scripts/ui/ui_kit.gd")

var panel: PanelContainer
var title_label: Label
var body: VBoxContainer
var footer: HBoxContainer
var close_button: Button
var title_key: String = ""
var panel_size: Vector2 = Vector2(760, 560)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.name = "Panel"
	add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	title_label = Label.new()
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_label.add_theme_font_override("font", UiKit.title_font())
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", UiKit.GOLD_BRIGHT)
	column.add_child(title_label)
	column.add_child(HSeparator.new())
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	footer = HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	close_button = button(footer, "")
	close_button.name = "Close"
	close_button.pressed.connect(close)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build()
	refresh_text()
	_place()

## Subclasses add their content here.
func build() -> void:
	pass

## Subclasses re-localize their content here (call super first).
func refresh_text() -> void:
	title_label.text = UiKit.t(title_key)
	close_button.text = UiKit.t("BTN_CLOSE")
	# Text length changes with the language: refit once the labels update.
	_place.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and panel != null:
		_place()

func _place() -> void:
	if not is_inside_tree():
		return
	var target = Vector2(minf(panel_size.x, size.x - 40.0), minf(panel_size.y, size.y - 40.0))
	panel.custom_minimum_size = target
	# Setting the size shrinks the panel back to the larger of the target and
	# its content (which may need more room in one language than another);
	# centre the size it actually takes.
	panel.size = target
	panel.position = ((size - panel.size) * 0.5).max(Vector2.ZERO)

func close() -> void:
	closed.emit()
	UiKit.discard(self)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventKey and event.keycode == KEY_ESCAPE:
		var viewport = get_viewport()
		close()
		viewport.set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.01, 0.62))

# --- Builders ----------------------------------------------------------------

static func button(parent: Control, text: String, font_size: int = 19) -> Button:
	var result = Button.new()
	result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	result.text = text
	result.add_theme_font_override("font", UiKit.title_font())
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	return result

static func label(parent: Control, text: String, font_size: int = 17, color: Color = UiKit.PAPER, wrap: bool = false) -> Label:
	var result = Label.new()
	result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if wrap:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.custom_minimum_size.x = 200
	parent.add_child(result)
	return result
