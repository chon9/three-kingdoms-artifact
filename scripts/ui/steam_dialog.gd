extends "res://scripts/ui/modal_panel.gd"
## Steam development lobbies (Spacewar 480): host a friends-only lobby, join
## by lobby id, invite friends, copy the id or leave. Without GodotSteam it
## explains the optional setup; offline play needs nothing extra.

var controller: Node
var status_label: Label
var host_button: Button
var lobby_input: LineEdit
var join_button: Button
var invite_button: Button
var lobby_label: Label
var copy_button: Button
var leave_button: Button
var docs_label: Label

func _init() -> void:
	super()
	title_key = "STEAM_TITLE"
	panel_size = Vector2(680, 500)

func setup(match_controller: Node) -> void:
	controller = match_controller

func build() -> void:
	status_label = label(body, "", 16, UiKit.PAPER_DIM, true)
	var bridge = controller.steam_bridge
	host_button = button(body, "")
	host_button.pressed.connect(func(): bridge.host_lobby())
	var join_row = HBoxContainer.new()
	body.add_child(join_row)
	lobby_input = LineEdit.new()
	lobby_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(lobby_input)
	join_button = button(join_row, "")
	join_button.pressed.connect(func(): bridge.join_lobby(lobby_input.text))
	invite_button = button(body, "")
	invite_button.pressed.connect(func(): bridge.invite_friends())
	lobby_label = label(body, "", 16, UiKit.GOLD)
	var lobby_row = HBoxContainer.new()
	body.add_child(lobby_row)
	copy_button = button(lobby_row, "")
	copy_button.pressed.connect(func(): DisplayServer.clipboard_set(str(bridge.lobby_id)))
	leave_button = button(lobby_row, "")
	leave_button.pressed.connect(func():
		controller.leave_online()
		refresh_text())
	docs_label = label(body, "", 14, UiKit.MUTED, true)
	controller.steam_status_changed.connect(func(_text): if is_inside_tree(): refresh_text())

func refresh_text() -> void:
	super()
	var bridge = controller.steam_bridge
	status_label.text = controller.steam_status_text()
	host_button.text = UiKit.t("STEAM_HOST")
	join_button.text = UiKit.t("STEAM_JOIN")
	invite_button.text = UiKit.t("STEAM_INVITE")
	copy_button.text = UiKit.t("STEAM_COPY_ID")
	leave_button.text = UiKit.t("STEAM_LEAVE")
	lobby_input.placeholder_text = UiKit.t("STEAM_LOBBY_PLACEHOLDER")
	docs_label.text = UiKit.t("STEAM_DOCS_HINT")
	var available = bridge.available
	var in_lobby = int(bridge.lobby_id) != 0
	for control in [host_button, lobby_input, join_button, invite_button]:
		control.visible = available
	invite_button.disabled = not in_lobby
	lobby_label.visible = in_lobby
	lobby_label.text = UiKit.t("STEAM_LOBBY", {"lobby": str(bridge.lobby_id)})
	copy_button.visible = in_lobby
	leave_button.visible = in_lobby
	docs_label.visible = not available
