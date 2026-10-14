extends "res://scripts/ui/modal_panel.gd"
## A yes/no question: `title_key` asks, `message_key` explains, and
## `confirm_key` labels the button that emits `confirmed`.

signal confirmed

var message_key: String = ""
var confirm_key: String = "BTN_CONFIRM"
var message_label: Label
var confirm_button: Button

func _init() -> void:
	super()
	panel_size = Vector2(560, 260)

func build() -> void:
	message_label = label(body, "", 17, UiKit.PAPER, true)
	confirm_button = button(footer, "")
	confirm_button.name = "Confirm"
	confirm_button.pressed.connect(func():
		confirmed.emit()
		close())
	footer.move_child(confirm_button, 0)

func refresh_text() -> void:
	super()
	close_button.text = UiKit.t("BTN_CANCEL")
	message_label.text = UiKit.t(message_key)
	confirm_button.text = UiKit.t(confirm_key)
