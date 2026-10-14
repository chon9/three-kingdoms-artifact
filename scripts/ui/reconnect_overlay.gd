extends Control
## Online pause: the opponent (or, for the guest, the host) stopped answering.
## Shows how long we have waited, with Keep waiting (collapses to a slim bar
## so the board stays readable), Claim victory (host only, after the grace
## period) and Leave match.

signal action_requested(action: String)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ACTIONS = ["wait", "claim", "leave"]

var controller: Node
var collapsed: bool = false
var panel: PanelContainer
var title_label: Label
var waiting_label: Label
var hint_label: Label
var buttons: Dictionary = {}
var bar: PanelContainer
var bar_label: Label
var options_button: Button
var _tick: float = 0.0

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", UiKit.box(UiKit.INK_PANEL, UiKit.GOLD_DARK, 10, 2, 22.0))
	add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	title_label = _label(column, 30, UiKit.GOLD_BRIGHT)
	title_label.add_theme_font_override("font", UiKit.title_font())
	waiting_label = _label(column, 18, UiKit.PAPER)
	hint_label = _label(column, 15, UiKit.MUTED)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for action in ACTIONS:
		var entry = _button(row, 19)
		entry.name = action.capitalize()
		entry.custom_minimum_size = Vector2(170, 46)
		entry.pressed.connect(_on_action.bind(action))
		buttons[action] = entry
	bar = PanelContainer.new()
	bar.name = "Bar"
	bar.add_theme_stylebox_override("panel", UiKit.box(Color(0.02, 0.02, 0.03, 0.85), UiKit.GOLD_DARK, 8, 1, 10.0))
	add_child(bar)
	var bar_row = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 12)
	bar.add_child(bar_row)
	bar_label = _label(bar_row, 16, UiKit.PAPER)
	bar_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	options_button = _button(bar_row, 16)
	options_button.pressed.connect(func(): set_collapsed(false))

func _label(parent: Control, font_size: int, color: Color) -> Label:
	var result = Label.new()
	result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = 260
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result

func _button(parent: Control, font_size: int) -> Button:
	var result = Button.new()
	result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	result.add_theme_font_override("font", UiKit.title_font())
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	return result

## Shows (expanded) or hides the overlay.
func set_waiting(value: bool) -> void:
	visible = value
	collapsed = false
	_apply_collapse()
	refresh_text()

func set_collapsed(value: bool) -> void:
	collapsed = value
	_apply_collapse()
	refresh_text()

func _apply_collapse() -> void:
	panel.visible = not collapsed
	bar.visible = collapsed
	# Collapsed, the board underneath stays readable (but the controller still
	# refuses moves until the opponent is back).
	mouse_filter = Control.MOUSE_FILTER_IGNORE if collapsed else Control.MOUSE_FILTER_STOP
	queue_redraw()
	_place()

func _on_action(action: String) -> void:
	if action == "wait":
		set_collapsed(true)
	action_requested.emit(action)

func refresh_text() -> void:
	if controller == null:
		return
	var host = controller.steam_bridge.is_host
	var name = controller.opponent_name()
	if name.is_empty():
		name = UiKit.t("PLAYER_OPPONENT")
	var seconds = int(controller.waiting_seconds())
	var time = "%d:%02d" % [seconds / 60, seconds % 60]
	title_label.text = UiKit.t("RECONNECT_TITLE_OPPONENT" if host else "RECONNECT_TITLE_HOST")
	waiting_label.text = UiKit.t("RECONNECT_WAITING", {"name": name, "time": time})
	hint_label.text = UiKit.t("RECONNECT_HINT_HOST" if host else "RECONNECT_HINT_GUEST")
	buttons.wait.text = UiKit.t("RECONNECT_KEEP_WAITING")
	buttons.leave.text = UiKit.t("RECONNECT_LEAVE")
	buttons.claim.visible = host
	var remaining = int(ceil(controller.claim_grace - controller.waiting_seconds()))
	buttons.claim.disabled = not controller.can_claim_win()
	buttons.claim.text = UiKit.t("RECONNECT_CLAIM_WIN") if remaining <= 0 else UiKit.t("RECONNECT_CLAIM_IN", {"n": remaining})
	bar_label.text = waiting_label.text
	options_button.text = UiKit.t("RECONNECT_OPTIONS")
	_place.call_deferred()

func _process(delta: float) -> void:
	if not visible:
		return
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		refresh_text()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()

func _place() -> void:
	if panel == null:
		return
	# Wrapped labels report their height for their current width, so give
	# them the final width before measuring (else the first show is too tall).
	var width = minf(620.0, size.x - 40.0)
	var inner = width - panel.get_theme_stylebox("panel").get_minimum_size().x
	for wrapped in [title_label, waiting_label, hint_label]:
		wrapped.custom_minimum_size.x = maxf(260.0, inner)
		wrapped.size.x = maxf(260.0, inner)
	panel.size = Vector2(width, 0)
	panel.size = panel.get_combined_minimum_size().max(Vector2(width, 0))
	panel.position = ((size - panel.size) * 0.5).max(Vector2.ZERO)
	bar.size = bar.get_combined_minimum_size()
	bar.position = Vector2((size.x - bar.size.x) * 0.5, 64.0)

func _draw() -> void:
	if not collapsed:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.01, 0.55))
