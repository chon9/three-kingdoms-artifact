extends Control
## The match log drawer on the right edge: every structured engine event
## formatted in the current language (EventText), newest at the bottom.
## Toggle with the menu or the L key.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const WIDTH = 430.0

var title_label: Label
var text_box: RichTextLabel
var close_button: Button
var events: Array = []
## Returns the player names by player index in the current language (set by
## the match screen so the log matches the HUD).
var names_source: Callable

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var column = VBoxContainer.new()
	panel.add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	title_label = Label.new()
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_override("font", UiKit.title_font())
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", UiKit.GOLD_BRIGHT)
	header.add_child(title_label)
	close_button = Button.new()
	close_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	close_button.pressed.connect(func(): toggle(false))
	header.add_child(close_button)
	column.add_child(HSeparator.new())
	text_box = RichTextLabel.new()
	text_box.name = "Text"
	text_box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.scroll_following = true
	text_box.bbcode_enabled = true
	text_box.add_theme_font_size_override("normal_font_size", 15)
	column.add_child(text_box)

func set_events(new_events: Array) -> void:
	events = new_events
	if visible:
		refresh_text()

func refresh_text() -> void:
	title_label.text = UiKit.t("LOG_TITLE")
	close_button.text = UiKit.t("BTN_CLOSE")
	var lines: Array = []
	var names: Array = names_source.call() if names_source.is_valid() else []
	for event in events:
		var line = EventText.format(event, null, names)
		var key = str(event.get("k", ""))
		if key in ["combat", "lane_open", "shop_open", "deployment", "deployment_revealed", "match_start"]:
			line = "[color=#d8b06a]%s[/color]" % line
		elif key in ["death", "tower_fall", "ancient_fall"]:
			line = "[color=#e58a7a]%s[/color]" % line
		lines.append(line)
	text_box.text = "\n".join(lines) if not lines.is_empty() else UiKit.t("LOG_EMPTY")

func plain_text() -> String:
	return text_box.get_parsed_text()

func toggle(show: bool) -> void:
	visible = show
	if show:
		refresh_text()
		if not AnimationQueue.instant:
			var rest = position
			position.x += 60
			modulate.a = 0.0
			var tween = create_tween().set_parallel(true)
			tween.tween_property(self, "position", rest, AnimationQueue.duration(0.18))
			tween.tween_property(self, "modulate:a", 1.0, AnimationQueue.duration(0.18))
