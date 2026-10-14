extends Node
## Owns the authoritative match: the engine, the bot, the play mode (AI,
## local hot-seat, Steam online), replays and the Steam bridge. Views read
## view()/actions() and send commands through act(); they redraw when
## state_changed fires. Nothing here draws.

signal state_changed(view: Dictionary, actions: Array)
signal notice_changed(text: String)
signal match_started
signal steam_status_changed(text: String)
## Online: the opponent dropped mid-match (true) or came back / it ended (false).
signal online_paused(paused: bool)
## Online: the session is over (host left, Steam closed, ...); show the menu.
signal online_ended(text: String)
## Online: a join started from an overlay invite or a launch argument.
signal online_join_started
signal connection_changed(info: Dictionary)

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const SteamBridge = preload("res://scripts/network/steam_bridge.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const MODE_AI = 0
const MODE_LOCAL = 1
const MODE_ONLINE = 2
const BOT_DELAY = 0.6
const REPLAY_DIR = "user://replays"
## Seconds the host waits before "claim victory" is offered after a drop.
const CLAIM_GRACE = 30.0

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
## Host: increases with every online match so the guest can tell a rematch.
## Guest: the serial of the match shown.
var match_serial: int = 0
var notice: String = ""
var started: bool = false
## Online: the opponent is gone and the match waits for them.
var waiting_for_opponent: bool = false
var waiting_since: float = 0.0
var claim_grace: float = CLAIM_GRACE
## Returns true while the UI is still animating; the bot waits for it.
var ui_busy: Callable = func() -> bool: return false

func _ready() -> void:
	steam_bridge = SteamBridge.new()
	steam_bridge.name = "SteamBridge"
	# Connected before add_child so the first status (set in _ready) arrives.
	steam_bridge.status_changed.connect(_steam_status)
	steam_bridge.match_received.connect(_online_state)
	steam_bridge.command_received.connect(_online_command)
	steam_bridge.command_rejected.connect(func(_revision): _set_notice(EventText.t("HINT_COMMAND_REJECTED")))
	steam_bridge.opponent_ready.connect(_opponent_ready)
	steam_bridge.opponent_lost.connect(_opponent_lost)
	steam_bridge.session_ended.connect(_session_ended)
	steam_bridge.join_started.connect(func(_lobby): online_join_started.emit())
	steam_bridge.connection_changed.connect(func(info): connection_changed.emit(info))
	add_child(steam_bridge)
	bot_timer = Timer.new()
	bot_timer.name = "BotTimer"
	bot_timer.one_shot = true
	bot_timer.wait_time = BOT_DELAY
	bot_timer.timeout.connect(_bot_step)
	add_child(bot_timer)

# --- Match lifecycle ---------------------------------------------------------

## Starts a fresh match in `new_mode` with the current deck selections.
## An offline match leaves any Steam lobby first, so online traffic can never
## replace it (and the opponent is told the host left).
func start_match(new_mode: int = -1) -> Dictionary:
	if new_mode >= 0:
		mode = new_mode
	if mode == MODE_ONLINE and not steam_bridge.is_host:
		_set_notice(EventText.t("HINT_HOST_ONLY"))
		return {"ok": false, "code": "host_only"}
	if mode != MODE_ONLINE:
		_leave_lobby_for_offline()
	bot_timer.stop()
	_set_waiting(false)
	if mode == MODE_ONLINE:
		# The guest sees the whole view; an unguessable seed keeps the host's
		# hand, deck order and future draws hidden. 53 bits survive JSON replays.
		current_seed = secure_seed()
		match_serial += 1
	else:
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
		# A new match while the bound guest is away waits for them too.
		_set_waiting(steam_bridge.bound_opponent != 0 and not steam_bridge.opponent_present)
	_publish()
	return result

## A random match seed below 2^53 (exact in JSON replays) from the OS CSPRNG.
static func secure_seed() -> int:
	return Crypto.new().generate_random_bytes(8).decode_u64(0) & 0x1FFFFFFFFFFFFF

func _leave_lobby_for_offline() -> void:
	if int(steam_bridge.lobby_id) == 0:
		return
	steam_bridge.leave_by_user()
	online_view.clear()
	online_actions.clear()

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
	if waiting_for_opponent and command != MatchEngine.CONCEDE:
		_set_notice(EventText.t("HINT_WAITING_RECONNECT"))
		return {"ok": false, "code": "waiting_opponent"}
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
		if is_finished():
			# Conceding while the opponent is away: the result replaces the pause.
			_set_waiting(false)
	_publish()
	return result

## True while the shown player may concede (any phase of an undecided match).
func can_concede() -> bool:
	if not started or is_finished():
		return false
	if is_guest():
		return steam_bridge.handshake_done and steam_bridge.opponent_present
	return engine.can_concede(viewer())

## The viewing player concedes; the opponent wins. Online guests ask the host.
func concede() -> Dictionary:
	if not can_concede():
		return {"ok": false, "code": "illegal_action"}
	return act(MatchEngine.CONCEDE)

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
	if is_guest():
		# The guest never holds the online match (only the host's redacted views).
		_set_notice(EventText.t("REPLAY_HOST_ONLY"))
		return {"ok": false, "code": "host_only"}
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
	_leave_lobby_for_offline()
	_set_waiting(false)
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

## The opponent's display name in online play ("" when unknown).
func opponent_name() -> String:
	return steam_bridge.peer_name if mode == MODE_ONLINE else ""

## Seconds since the opponent dropped (0 when not waiting).
func waiting_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0 - waiting_since if waiting_for_opponent else 0.0

## The host may claim the win once the opponent has been gone for claim_grace.
func can_claim_win() -> bool:
	return waiting_for_opponent and steam_bridge.is_host and mode == MODE_ONLINE and not is_finished() and waiting_seconds() >= claim_grace

## Host: the absent opponent forfeits (recorded as their concession).
func claim_win() -> Dictionary:
	if not can_claim_win():
		return {"ok": false, "code": "illegal_action"}
	var result = engine.apply_action(1, MatchEngine.CONCEDE)
	if result.ok:
		_set_waiting(false)
		_send_online_state()
		_publish()
	return result

## Leaves the lobby. An online match ends and the views return to the menu.
func leave_online() -> void:
	var was_online = mode == MODE_ONLINE
	steam_bridge.leave_by_user()
	_set_waiting(false)
	online_view.clear()
	online_actions.clear()
	if was_online:
		mode = MODE_AI
		started = false
		bot_timer.stop()
		online_ended.emit(EventText.t("STEAM_LEFT_LOBBY"))

func _steam_status(message: String) -> void:
	var text = EventText.steam_status(steam_bridge.status_code, steam_bridge.status_args, message)
	_set_notice(text)
	steam_status_changed.emit(text)

## Handshake done. The host starts a match, or resumes it for a returning guest.
func _opponent_ready(rejoin: bool) -> void:
	if steam_bridge.is_host:
		if mode == MODE_ONLINE and started and (rejoin or waiting_for_opponent):
			_set_waiting(false)
			_send_online_state()
			_publish()
			return
		bot_timer.stop()
		start_match(MODE_ONLINE)
	elif waiting_for_opponent:
		_set_waiting(false)

func _opponent_lost(_reason: String) -> void:
	if mode == MODE_ONLINE and started and not is_finished():
		_set_waiting(true)

func _session_ended(_code: String) -> void:
	var was_online = mode == MODE_ONLINE
	_set_waiting(false)
	online_view.clear()
	online_actions.clear()
	if was_online:
		mode = MODE_AI
		started = false
		bot_timer.stop()
	online_ended.emit(steam_status_text())

func _set_waiting(value: bool) -> void:
	if value == waiting_for_opponent:
		return
	waiting_for_opponent = value
	waiting_since = Time.get_ticks_msec() / 1000.0
	online_paused.emit(value)

func _send_online_state() -> void:
	steam_bridge.send_match(engine.player_view(1), engine.legal_actions(1), match_serial)

## Guest: a host snapshot. Only reaches us while we are in the host's lobby
## (starting an offline match leaves it first).
func _online_state(new_view: Dictionary, new_actions: Array, serial: int = 0) -> void:
	if steam_bridge.is_host:
		return
	# A new match (host pressed Play again) is drawn from scratch, which also
	# clears the previous result screen.
	var first = mode != MODE_ONLINE or online_view.is_empty() or serial != match_serial
	mode = MODE_ONLINE
	match_serial = serial
	bot_timer.stop()
	online_view = new_view
	online_actions = new_actions
	started = true
	if int(new_view.get("winner", -1)) != -1:
		_set_waiting(false)
	if first:
		_set_notice(EventText.t("HINT_CONNECTED_GUEST"))
		match_started.emit()
	state_changed.emit(online_view, online_actions)

func _online_command(command: Dictionary, revision: int) -> void:
	if not steam_bridge.is_host or mode != MODE_ONLINE or not started:
		return
	# Conceding is valid at any revision. In the action phase everything else
	# must be current. In shop and deployment both players plan at once and
	# the host's own purchases or deployments bump the revision without
	# touching the guest's hand, shop or plans, so a command that is still
	# legal for the guest is applied whatever its revision.
	var planning = str(engine.state.phase) in ["shop", "deployment"] and command in engine.legal_actions(1)
	if revision == int(engine.state.revision) or planning or command == MatchEngine.CONCEDE:
		var result = engine.apply_action(1, command)
		if result.ok:
			_send_online_state()
			_publish()
			return
	steam_bridge.reject_command(revision)

func _set_notice(text: String) -> void:
	notice = text
	notice_changed.emit(text)
