extends Control
## Local hot-seat privacy screen: an opaque ink-wash curtain shown whenever
## the device must pass to the other player, so neither player sees the
## other's hand. The next player confirms to continue.

signal confirmed

const UiKit = preload("res://scripts/ui/ui_kit.gd")

var player: int = 0
var button: Button

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	button = Button.new()
	button.name = "Continue"
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.custom_minimum_size = Vector2(320, 58)
	button.add_theme_font_override("font", UiKit.title_font())
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(confirm)
	add_child(button)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		button.size = button.get_combined_minimum_size()
		button.position = Vector2((size.x - button.size.x) * 0.5, size.y * 0.62)

func show_for(next_player: int) -> void:
	player = next_player
	visible = true
	refresh_text()
	button.grab_focus.call_deferred()

func refresh_text() -> void:
	button.text = UiKit.t("HOTSEAT_CONTINUE", {"player": UiKit.t("PLAYER_N", {"n": player + 1})})
	_notification(NOTIFICATION_RESIZED)
	queue_redraw()

func confirm() -> void:
	if visible:
		visible = false
		confirmed.emit()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	UiKit.draw_ink_wash(self, rect, Color("3a3a44"), "pass_device_%d" % player, true)
	draw_rect(rect, Color(0, 0, 0, 0.35))
	var name_text = UiKit.t("PLAYER_N", {"n": player + 1})
	UiKit.draw_text(self, UiKit.title_font(), UiKit.t("HOTSEAT_PASS_TITLE", {"player": name_text}), Vector2(size.x * 0.5, size.y * 0.38), 54, UiKit.GOLD_BRIGHT, size.x * 0.9, 5)
	UiKit.draw_text(self, UiKit.body_font(), UiKit.t("HOTSEAT_PASS_HINT"), Vector2(size.x * 0.5, size.y * 0.48), 20, UiKit.PAPER_DIM, size.x * 0.8, 2)
	UiKit.draw_seal(self, Vector2(size.x * 0.5, size.y * 0.25), 64.0, str(player + 1))
