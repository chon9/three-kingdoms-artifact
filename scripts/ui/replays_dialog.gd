extends "res://scripts/ui/modal_panel.gd"
## Saved replays (user://replays), newest first, plus a file browser for
## replays stored elsewhere. Loading restores the match in local two-player
## mode for inspection and continuation.

signal load_requested(path: String)

const MatchController = preload("res://scripts/game/match_controller.gd")

var list: VBoxContainer
var empty_label: Label
var browse_button: Button
var file_dialog: FileDialog
var entries: Array = []

func _init() -> void:
	super()
	title_key = "REPLAYS_TITLE"
	panel_size = Vector2(760, 600)

func build() -> void:
	empty_label = label(body, "", 16, UiKit.MUTED, true)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in MatchController.list_replays():
		var row = HBoxContainer.new()
		list.add_child(row)
		var name_label = label(row, str(entry.name), 16, UiKit.PAPER)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var date = Time.get_datetime_string_from_unix_time(int(entry.modified), true)
		label(row, date, 14, UiKit.MUTED)
		var load_button = button(row, "", 17)
		load_button.pressed.connect(func():
			load_requested.emit(str(entry.path))
			close())
		entries.append(load_button)
	browse_button = button(footer, "")
	browse_button.pressed.connect(_browse)
	footer.move_child(browse_button, 0)

func refresh_text() -> void:
	super()
	empty_label.text = UiKit.t("REPLAYS_EMPTY") if entries.is_empty() else UiKit.t("REPLAYS_HINT")
	for load_button in entries:
		load_button.text = UiKit.t("REPLAYS_LOAD")
	browse_button.text = UiKit.t("REPLAYS_BROWSE")

func _browse() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.json ; " + UiKit.t("REPLAY_FILTER")])
	file_dialog.current_dir = ProjectSettings.globalize_path(MatchController.REPLAY_DIR)
	file_dialog.file_selected.connect(func(path):
		load_requested.emit(path)
		close())
	file_dialog.close_requested.connect(file_dialog.queue_free)
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.7)
