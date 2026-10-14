extends Node
## Owns the authoritative match: the engine, the bot, the play mode (AI,
## local hot-seat, Steam online), replays and the Steam bridge. Views read
## view()/actions() and send commands through act(); they redraw when
## state_changed fires. Nothing here draws.

signal state_changed(view: Dictionary, actions: Array)
signal notice_changed(text: String)
signal match_started
signal steam_status_changed(text: String)

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const SteamBridge = preload("res://scripts/network/steam_bridge.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const MODE_AI = 0
const MODE_LOCAL = 1
const MODE_ONLINE = 2
const BOT_DELAY = 0.6
const REPLAY_DIR = "user://replays"

var engine = MatchEngine.new()
var bot = Bot.new()
var steam_bridge: Node
var bot_timer: Timer
var mode: int = MODE_AI
var local_player: int = 0
var current_seed: int = 10414
var deck_selections: Array = ["starter", "green_assault"]
var online_view: Dictionary = {}
var online_actions: Array = []
var notice: String = ""
var started: bool = false
## Returns true while the UI is still animating; the bot waits for it.
var ui_busy: Callable = func() -> bool: return false

func _ready() -> void:
	steam_bridge = SteamBridge.new()
	steam_bridge.name = "SteamBridge"
	add_child(steam_bridge)
	steam_bridge.status_changed.connect(_steam_status)
	steam_bridge.match_received.connect(_online_state)
	steam_bridge.command_received.connect(_online_command)
	bot_timer = Timer.new()
	bot_timer.name = "BotTimer"
	bot_timer.one_shot = true
	bot_timer.wait_time = BOT_DELAY
	bot_timer.timeout.connect(_bot_step)
	add_child(bot_timer)

# --- Match lifecycle ---------------------------------------------------------

## Starts a fresh match in `new_mode` with the current deck selections.
func start_match(new_mode: int = -1) -> Dictionary:
	if new_mode >= 0:
		mode = new_mode
	if mode == MODE_ONLINE and not steam_bridge.is_host:
		_set_notice(EventText.t("HINT_HOST_ONLY"))
		return {"ok": false, "code": "host_only"}
	bot_timer.stop()
	current_seed += 1
	var result = engine.start(current_seed, deck_selections)
	if not result.ok:
		_set_notice(EventText.error_text(result))
		return result
	local_player = 0
	started = true
	_set_notice(EventText.t("HINT_DRAG_CARD"))
	match_started.emit()
	if mode == MODE_ONLINE:
		_send_online_state()
	_publish()
	return result

func is_guest() -> bool:
	return mode == MODE_ONLINE and not steam_bridge.is_host

func view() -> Dictionary:
	if is_guest() and not online_view.is_empty():
		return online_view
	return engine.player_view(viewer())

## The player whose perspective is shown. Hot-seat follows the acting player
## in the action phase and the planning player in shop and deployment.
func viewer(state: Dictionary = {}) -> int:
	if mode == MODE_ONLINE:
		return 0 if steam_bridge.is_host else 1
	if mode == MODE_LOCAL:
		var source = state if not state.is_empty() else engine.state
		if source.get("phase", "") == "action":
			return int(source.active_player)
		return local_player
	return 0

func actions() -> Array:
	if is_guest():
		return online_actions
	return engine.legal_actions(viewer())

func is_finished() -> bool:
	var current = view()
	return not current.is_empty() and int(current.get("winner", -1)) != -1

## Applies `command` for the viewing player. Returns the engine result.
func act(command: Dictionary) -> Dictionary:
	if is_guest():
		steam_bridge.send_command(command, int(online_view.get("revision", 0)))
		return {"ok": true, "pending": true}
	var player = viewer()
	var result = engine.apply_action(player, command)
	if not result.ok:
		_set_notice(EventText.error_text(result))
		return result
	if mode == MODE_LOCAL and command.type in ["finish_shop", "finish_deployment"]:
		local_player = 1 - local_player
	if mode == MODE_ONLINE:
		_send_online_state()
	_publish()
	return result

func _publish() -> void:
	state_changed.emit(view(), actions())
	schedule_bot()

## Re-sends the current state to the views (after fixtures or tools edit it).
func refresh() -> void:
	_publish()

# --- Bot ---------------------------------------------------------------------

func schedule_bot() -> void:
	if mode == MODE_AI and started and not engine.legal_actions(1).is_empty():
		bot_timer.start(BOT_DELAY)

func _bot_step() -> void:
	if mode != MODE_AI or not started:
		return
	if ui_busy.call():
		bot_timer.start(0.15)
		return
	var command = bot.choose_action(engine, 1)
	if command.is_empty():
		return
	var result = engine.apply_action(1, command)
	if not result.ok:
		push_warning("Bot action rejected: %s" % result.get("code", ""))
		return
	_publish()

# --- Replays -----------------------------------------------------------------

func save_replay(path: String = "") -> Dictionary:
	if path.is_empty():
		path = "%s/match_%d_%d.json" % [REPLAY_DIR, current_seed, int(engine.state.get("revision", 0))]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var message = EventText.t("REPLAY_SAVE_FAILED", {"error": error_string(FileAccess.get_open_error())})
		_set_notice(message)
		return {"ok": false, "message": message}
	file.store_string(JSON.stringify(engine.replay_data(), "\t"))
	file.close()
	_set_notice(EventText.t("REPLAY_SAVED", {"path": ProjectSettings.globalize_path(path)}))
	return {"ok": true, "path": path}

## Restores a replay and continues it in local two-player mode.
func load_replay(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var candidate = MatchEngine.new()
	var result = candidate.load_replay(parsed) if parsed is Dictionary else {"ok": false, "code": "replay_invalid_json", "args": {}, "error": "Invalid JSON replay."}
	if not result.ok:
		_set_notice(EventText.error_text(result))
		return result
	bot_timer.stop()
	engine = candidate
	current_seed = int(parsed.seed)
	deck_selections = parsed.decks.duplicate()
	local_player = 0
	mode = MODE_LOCAL
	started = true
	_set_notice(EventText.t("REPLAY_RESTORED", {"n": int(engine.state.revision)}))
	match_started.emit()
	_publish()
	return result

## Saved replays, newest first: [{"path", "name", "modified"}].
static func list_replays() -> Array:
	var result: Array = []
	var directory = DirAccess.open(REPLAY_DIR)
	if directory == null:
		return result
	for file_name in directory.get_files():
		if file_name.ends_with(".json"):
			var path = REPLAY_DIR + "/" + file_name
			result.append({"path": path, "name": file_name.get_basename(), "modified": FileAccess.get_modified_time(path)})
	result.sort_custom(func(a, b): return a.modified > b.modified)
	return result

# --- Steam -------------------------------------------------------------------

func steam_status_text() -> String:
	return EventText.steam_status(steam_bridge.status_code, steam_bridge.status_args, steam_bridge.status)

func leave_online() -> void:
	steam_bridge.leave_lobby()
	mode = MODE_AI
	online_view.clear()
	online_actions.clear()
	start_match(MODE_AI)

func _steam_status(message: String) -> void:
	var text = EventText.steam_status(steam_bridge.status_code, steam_bridge.status_args, message)
	_set_notice(text)
	steam_status_changed.emit(text)
	if steam_bridge.lobby_id != 0 and steam_bridge.is_host and mode != MODE_ONLINE and steam_bridge.peer_id != 0:
		mode = MODE_ONLINE
		bot_timer.stop()
		start_match(MODE_ONLINE)

func _send_online_state() -> void:
	steam_bridge.send_match(engine.player_view(1), engine.legal_actions(1))

func _online_state(new_view: Dictionary, new_actions: Array) -> void:
	var first = mode != MODE_ONLINE or online_view.is_empty()
	mode = MODE_ONLINE
	bot_timer.stop()
	online_view = new_view
	online_actions = new_actions
	started = true
	if first:
		_set_notice(EventText.t("HINT_CONNECTED_GUEST"))
		match_started.emit()
	state_changed.emit(online_view, online_actions)

func _online_command(command: Dictionary, revision: int) -> void:
	if not steam_bridge.is_host or mode != MODE_ONLINE:
		return
	if revision == int(engine.state.revision):
		var result = engine.apply_action(1, command)
		if result.ok:
			_send_online_state()
			_publish()
			return
	_send_online_state()

func _set_notice(text: String) -> void:
	notice = text
	notice_changed.emit(text)
