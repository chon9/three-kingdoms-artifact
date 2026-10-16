extends "res://scripts/ui/modal_panel.gd"
## Steam lobbies (development App ID 480, Spacewar): host a friends-only or
## public lobby, join by pasted ID or "+connect_lobby" link, browse public
## lobbies of this game, invite friends, copy the ID or leave. Without a
## working Steam client it explains why; offline play needs nothing extra.

signal deck_change_requested

var controller: Node
var status_label: Label
## The deck this player brings online (seat 0) and the host's answer to it.
var deck_row: HBoxContainer
var deck_label: Label
var deck_status: Label
var deck_button: Button
var host_row: HBoxContainer
var host_button: Button
var host_public_button: Button
var lobby_input: LineEdit
var join_button: Button
var lobby_label: Label
var lobby_row: HBoxContainer
var invite_button: Button
var copy_button: Button
var leave_button: Button
var browser_title: Label
var refresh_button: Button
var browser_hint: Label
var browser_list: VBoxContainer
var version_label: Label
var docs_label: Label
## Last lobby browser results (see SteamBridge.lobbies_listed).
var lobbies: Array = []
var searched: bool = false
var lobby_rows: Array = []

func _init() -> void:
	super()
	title_key = "STEAM_TITLE"
	panel_size = Vector2(760, 720)

func setup(match_controller: Node) -> void:
	controller = match_controller

func build() -> void:
	var bridge = controller.steam_bridge
	status_label = label(body, "", 16, UiKit.PAPER_DIM, true)
	status_label.name = "Status"
	deck_row = HBoxContainer.new()
	deck_row.name = "DeckRow"
	body.add_child(deck_row)
	deck_label = label(deck_row, "", 17, UiKit.GOLD_BRIGHT)
	deck_label.add_theme_font_override("font", UiKit.title_font())
	deck_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_label.clip_text = true
	deck_button = button(deck_row, "", 16)
	deck_button.name = "ChangeDeck"
	deck_button.pressed.connect(func(): deck_change_requested.emit())
	deck_status = label(body, "", 14, UiKit.MUTED, true)
	deck_status.name = "DeckStatus"
	host_row = HBoxContainer.new()
	body.add_child(host_row)
	host_button = button(host_row, "")
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_button.pressed.connect(func(): bridge.host_lobby(false))
	host_public_button = button(host_row, "")
	host_public_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_public_button.pressed.connect(func(): bridge.host_lobby(true))
	var join_row = HBoxContainer.new()
	body.add_child(join_row)
	lobby_input = LineEdit.new()
	lobby_input.name = "LobbyInput"
	lobby_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_input.text_submitted.connect(func(text):
		if int(bridge.lobby_id) == 0:
			bridge.join_lobby(text))
	join_row.add_child(lobby_input)
	join_button = button(join_row, "")
	join_button.pressed.connect(func(): bridge.join_lobby(lobby_input.text))
	lobby_label = label(body, "", 16, UiKit.GOLD)
	lobby_row = HBoxContainer.new()
	body.add_child(lobby_row)
	invite_button = button(lobby_row, "")
	invite_button.pressed.connect(func(): bridge.invite_friends())
	copy_button = button(lobby_row, "")
	copy_button.pressed.connect(func(): DisplayServer.clipboard_set(str(bridge.lobby_id)))
	leave_button = button(lobby_row, "")
	leave_button.pressed.connect(func():
		controller.leave_online()
		refresh_text())
	body.add_child(HSeparator.new())
	var browser_row = HBoxContainer.new()
	body.add_child(browser_row)
	browser_title = label(browser_row, "", 19, UiKit.GOLD_BRIGHT)
	browser_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_button = button(browser_row, "", 17)
	refresh_button.name = "Refresh"
	refresh_button.pressed.connect(refresh_lobbies)
	browser_hint = label(body, "", 14, UiKit.MUTED, true)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 120
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	browser_list = VBoxContainer.new()
	browser_list.name = "Lobbies"
	browser_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(browser_list)
	version_label = label(body, "", 13, UiKit.MUTED, true)
	docs_label = label(body, "", 14, UiKit.MUTED, true)
	controller.steam_status_changed.connect(_on_status)
	controller.own_deck_answered.connect(func(_result): _on_status(""))
	bridge.lobbies_listed.connect(_on_lobbies)

func _on_status(_text: String) -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		refresh_text()

func refresh_lobbies() -> void:
	searched = controller.steam_bridge.request_lobby_list() or searched

func _on_lobbies(found: Array) -> void:
	lobbies = found
	searched = true
	if is_inside_tree():
		_rebuild_lobbies()
		refresh_text()

func _rebuild_lobbies() -> void:
	for row in browser_list.get_children():
		UiKit.discard(row)
	lobby_rows.clear()
	for entry in lobbies:
		var row = HBoxContainer.new()
		browser_list.add_child(row)
		var text = label(row, "", 16, UiKit.PAPER if entry.compatible else UiKit.MUTED)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_text = true
		var join = button(row, "", 17)
		join.disabled = not can_join(entry, false)
		var lobby_id = int(entry.id)
		join.pressed.connect(func(): controller.steam_bridge.join_lobby_id(lobby_id))
		lobby_rows.append({"entry": entry, "label": text, "button": join})

func refresh_text() -> void:
	super()
	var bridge = controller.steam_bridge
	status_label.text = controller.steam_status_text()
	host_button.text = UiKit.t("STEAM_HOST")
	host_public_button.text = UiKit.t("STEAM_HOST_PUBLIC")
	join_button.text = UiKit.t("STEAM_JOIN")
	invite_button.text = UiKit.t("STEAM_INVITE")
	copy_button.text = UiKit.t("STEAM_COPY_ID")
	leave_button.text = UiKit.t("STEAM_LEAVE")
	lobby_input.placeholder_text = UiKit.t("STEAM_LOBBY_PLACEHOLDER")
	browser_title.text = UiKit.t("STEAM_BROWSER_TITLE")
	refresh_button.text = UiKit.t("STEAM_REFRESH")
	browser_hint.text = UiKit.t("STEAM_BROWSER_EMPTY") if searched and lobbies.is_empty() else UiKit.t("STEAM_BROWSER_HINT")
	for row in lobby_rows:
		var entry: Dictionary = row.entry
		var host_name = str(entry.host) if not str(entry.host).is_empty() else UiKit.t("STEAM_UNKNOWN_HOST")
		var state = UiKit.t("STEAM_LOBBY_INCOMPATIBLE") if not entry.compatible else lobby_status_text(str(entry.status))
		row.label.text = UiKit.t("STEAM_BROWSER_ROW", {"host": host_name, "status": state})
		row.button.text = UiKit.t("STEAM_JOIN")
		row.button.disabled = not can_join(entry, int(bridge.lobby_id) != 0)
	version_label.text = UiKit.t("STEAM_VERSION_INFO", {"version": bridge.godotsteam_version if not bridge.godotsteam_version.is_empty() else "-",
		"protocol": bridge.PROTOCOL, "content": bridge.content_hash.substr(0, 8)})
	docs_label.text = UiKit.t("STEAM_DOCS_HINT")
	deck_label.text = UiKit.t("STEAM_YOUR_DECK", {"name": controller.own_deck_name()})
	deck_button.text = UiKit.t("STEAM_CHANGE_DECK")
	deck_status.text = own_deck_status(controller)
	deck_status.visible = not deck_status.text.is_empty()
	var available = bridge.available
	var in_lobby = int(bridge.lobby_id) != 0
	for control in [host_row, lobby_input, join_button, browser_title, refresh_button, browser_hint, browser_list, deck_row]:
		control.visible = available
	join_button.get_parent().visible = available
	lobby_label.visible = in_lobby
	lobby_label.text = UiKit.t("STEAM_LOBBY", {"lobby": str(bridge.lobby_id)})
	lobby_row.visible = in_lobby
	invite_button.disabled = not in_lobby
	# Hosting or joining elsewhere would drop the current lobby (and its
	# match) without a word: the player leaves it first.
	var leave_hint = UiKit.t("STEAM_LEAVE_FIRST") if in_lobby else ""
	for control in [host_button, host_public_button, join_button]:
		control.disabled = in_lobby
		control.tooltip_text = leave_hint
	lobby_input.editable = not in_lobby
	docs_label.visible = not available

## What the host made of our deck (only while connected to a host as guest).
static func own_deck_status(match_controller: Node) -> String:
	var bridge = match_controller.steam_bridge
	if bridge.is_host or not bridge.handshake_done:
		return ""
	var result: Dictionary = match_controller.own_deck_result
	if result.is_empty():
		return UiKit.t("DECK_ONLINE_PENDING")
	if result.get("ok", false):
		return UiKit.t("DECK_ONLINE_ACCEPTED")
	return UiKit.t("DECK_ONLINE_REJECTED", {"reason": UiKit.EventText.error_text(result)})

## Join is offered only for lobbies of this build that wait for a player (a
## "reconnecting" lobby keeps its seat for the original opponent), and never
## while we are in a lobby ourselves.
static func can_join(entry: Dictionary, in_lobby: bool) -> bool:
	return not in_lobby and bool(entry.get("compatible", false)) and str(entry.get("status", "")) == "waiting"

static func lobby_status_text(state: String) -> String:
	match state:
		"waiting":
			return UiKit.t("STEAM_LOBBY_STATUS_WAITING")
		"playing":
			return UiKit.t("STEAM_LOBBY_STATUS_PLAYING")
		"reconnecting":
			return UiKit.t("STEAM_LOBBY_STATUS_RECONNECTING")
	return UiKit.t("STEAM_LOBBY_STATUS_WAITING")
