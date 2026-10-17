extends Node
## Owns the authoritative match: the engine, the bot, the play mode (AI,
## local hot-seat, Steam online), replays and the Steam bridge. Views read
## view()/actions() and send commands through act(); they redraw when
## state_changed fires. Nothing here draws.
##
## Online, the two players meet in a room (the lobby): each picks a deck and
## gets ready; when both are ready the host counts down ROOM_COUNTDOWN_MS and
## starts the match. After a result both players get ready again for a
## rematch (a deck may change in between). The host owns the room state and
## sends it to the guest (protocol 10); either player can leave the room at
## any time, and leaving a running match concedes it.

signal state_changed(view: Dictionary, actions: Array)
signal notice_changed(text: String)
signal match_started
signal steam_status_changed(text: String)
## Online: the opponent dropped mid-match (true) or came back / it ended (false).
signal online_paused(paused: bool)
## Online: the session is over (host left, Steam closed, we left); the views
## leave the room.
signal online_ended(text: String)
## Online: a join started from an overlay invite or a launch argument.
signal online_join_started
signal connection_changed(info: Dictionary)
## Guest: the host answered our deck ({"ok", "code", "args"}).
signal own_deck_answered(result: Dictionary)
## Online: there is a room to show (the host's lobby was created, or the
## guest's handshake completed).
signal room_opened
## Online: something in the room changed (readiness, decks, the countdown,
## the phase, who is there).
signal room_changed
## Host: the guest left the room ("" when its name is unknown).
signal opponent_left(name: String)

const MatchEngine = preload("res://scripts/core/match_engine.gd")
const Bot = preload("res://scripts/ai/heuristic_bot.gd")
const SteamBridge = preload("res://scripts/network/steam_bridge.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const DeckCode = preload("res://scripts/core/deck_code.gd")
const MODE_AI = 0
const MODE_LOCAL = 1
const MODE_ONLINE = 2
const BOT_DELAY = 0.6
const REPLAY_DIR = "user://replays"
## Seconds the host waits before "claim victory" is offered after a drop.
const CLAIM_GRACE = 30.0
## Both players ready: the match starts this long after (either may still
## cancel), on the bridge clock.
const ROOM_COUNTDOWN_MS = 3000
## Host: the guest plays this preset while its deck is missing or invalid
## (unless the host's opponent choice is a preset). Only start_match() called
## directly (tools, tests) can reach it: a guest gets ready only with a deck
## the host accepted.
const FALLBACK_DECK = "green_assault"
## Online views show the opponent's deck as this "preset": neither player
## learns the other's deck list or preset (only the heroes, as in Classic).
const HIDDEN_DECK = "hidden"

var engine = MatchEngine.new()
var bot = Bot.new()
var steam_bridge: Node
var bot_timer: Timer
var mode: int = MODE_AI
var local_player: int = 0
var current_seed: int = 10414
## One deck per seat: a preset id or a player's own deck (DeckStore entry,
## {id, name, heroes, cards, items}). Seat 0 is this player's deck in every
## mode (online it is the deck a guest sends to the host); seat 1 is the AI's
## or the second local player's deck.
var deck_selections: Array = ["starter", "green_assault"]
## Card data for deck codes and validation (shared, read-only).
var library = MatchEngine.Library.new()
## The deck entries of the shown match as this player chose them, by seat:
## deck_selections when the match started (a guest records its own deck when
## a new match's first state arrives). A deck picked mid-match applies from
## the next match, so names come from here, not from deck_selections.
var match_decks: Array = []
## Host: the guest's validated deck ({} while none is valid) and what became
## of the last one: "" (none yet), "ok" or "rejected".
var guest_deck: Dictionary = {}
var guest_deck_state: String = ""
## Host: the deck code behind guest_deck (a repeated code changes nothing).
var _guest_code: String = ""
## Guest: the host's last answer to our deck ({} until one arrives).
var own_deck_result: Dictionary = {}
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
## The room (online). Its phase: "none" (no lobby), "waiting" (the host's
## lobby has no guest), "room" (both there, no match yet), "match" (a match
## is undecided), "result" (the last match is decided). The host owns it; the
## guest mirrors the host's room packets.
var room_phase: String = "none"
## Readiness by seat: [host, guest].
var room_ready: Array = [false, false]
## Wins in this room by seat: [host, guest] (a new opponent starts at 0-0).
var room_series: Array = [0, 0]
## Guest: what the host made of our deck ("", "ok", "rejected", "missing").
var room_deck: String = ""
## The countdown runs (both ready).
var room_starting: bool = false
## Host: the bridge-clock time the countdown ends (-1 when none). Guest: when
## the countdown was first seen (for the seconds shown).
var _countdown_at: int = -1
## Host: the SteamID the last match was played against.
var last_opponent: int = 0
## A campaign match ({} otherwise), set by main.gd before it starts one and
## cleared by any other start: {"chapter_id", "enemy_commander", "par_rounds"}
## and, once decided, "result" (CampaignStore.record's answer). Views read it;
## the match itself is an ordinary match against the AI.
var campaign: Dictionary = {}

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
	steam_bridge.connection_changed.connect(func(info):
		connection_changed.emit(info)
		room_changed.emit())
	steam_bridge.deck_received.connect(_on_guest_deck)
	steam_bridge.deck_answered.connect(_on_deck_answered)
	steam_bridge.lobby_hosted.connect(_on_lobby_hosted)
	steam_bridge.ready_received.connect(_on_ready_received)
	steam_bridge.room_received.connect(_on_room_received)
	steam_bridge.bye_received.connect(_on_bye)
	steam_bridge.opponent_released.connect(_on_opponent_released)
	steam_bridge.ticked.connect(_room_tick)
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
## replace it (and the opponent is told the host left). Online, the room
## starts matches (both players ready); calling this directly is for tools
## and tests.
func start_match(new_mode: int = -1) -> Dictionary:
	var target = new_mode if new_mode >= 0 else mode
	if target != MODE_ONLINE:
		# Left while `mode` still names what was running (an online match
		# given up this way is conceded).
		_leave_lobby_for_offline()
	mode = target
	if mode == MODE_ONLINE and not steam_bridge.is_host:
		_set_notice(EventText.t("HINT_HOST_ONLY"))
		return {"ok": false, "code": "host_only"}
	bot_timer.stop()
	_set_waiting(false)
	var decks: Array = deck_selections
	if mode == MODE_ONLINE:
		# The guest sees the whole view; an unguessable seed keeps the host's
		# hand, deck order and future draws hidden. 53 bits survive JSON replays.
		current_seed = secure_seed()
		match_serial += 1
		# The guest plays the deck it sent (validated on arrival).
		decks = [deck_selections[0], guest_deck if not guest_deck.is_empty() else fallback_guest_deck()]
	else:
		current_seed += 1
	var result = engine.start(current_seed, decks)
	if not result.ok:
		_set_notice(EventText.error_text(result))
		return result
	match_decks = decks.duplicate(true)
	local_player = 0
	started = true
	_set_notice(EventText.t("HINT_DRAG_CARD"))
	match_started.emit()
	if mode == MODE_ONLINE:
		_send_online_state()
		# A new match while the bound guest is away waits for them too.
		_set_waiting(steam_bridge.bound_opponent != 0 and not steam_bridge.opponent_present)
		last_opponent = steam_bridge.bound_opponent
		room_phase = "match"
		room_ready = [false, false]
		_cancel_countdown(false)
		_broadcast_room()
	_publish()
	return result

## A random match seed below 2^53 (exact in JSON replays) from the OS CSPRNG.
static func secure_seed() -> int:
	return Crypto.new().generate_random_bytes(8).decode_u64(0) & 0x1FFFFFFFFFFFFF

func _leave_lobby_for_offline() -> void:
	if int(steam_bridge.lobby_id) == 0:
		return
	# Leaving on purpose: a goodbye (conceding a running online match), then
	# the lobby is left a moment later. Online traffic is ignored meanwhile,
	# so it can never replace the offline match.
	if not steam_bridge.leaving():
		steam_bridge.leave_gracefully(_concede_on_leave(true))
	online_view.clear()
	online_actions.clear()
	_forget_online_decks()
	_reset_room("none")

## The guest's deck and our deck's answer belong to the lobby just left.
func _forget_online_decks() -> void:
	guest_deck = {}
	guest_deck_state = ""
	_guest_code = ""
	own_deck_result = {}

func is_guest() -> bool:
	return mode == MODE_ONLINE and not steam_bridge.is_host

## True while this player is in an online lobby (host or guest).
func in_room() -> bool:
	return steam_bridge.in_lobby()

## True while an online match is being played (not decided).
func online_match_running() -> bool:
	return mode == MODE_ONLINE and started and not is_finished()

func view() -> Dictionary:
	if is_guest() and not online_view.is_empty():
		return online_view
	if mode == MODE_ONLINE:
		return online_player_view(viewer())
	return engine.player_view(viewer())

## Online, a player's view with the opponent's deck hidden (HIDDEN_DECK): the
## heroes are public, the deck list and its preset are not.
func online_player_view(player: int) -> Dictionary:
	var result = engine.player_view(player)
	if result.get("players") is Array and result.players.size() == 2:
		result.players[1 - player]["preset"] = HIDDEN_DECK
	return result

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
	_note_result()
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
	match_decks = deck_selections.duplicate(true)
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
	if mode == MODE_ONLINE or steam_bridge.handshake_done:
		return steam_bridge.peer_name
	return ""

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

## Leaves the room. Leaving a running match concedes it (`concede`): the
## host records its own concession, a guest sends its concession with the
## goodbye. The other side is told (a "bye"); the views leave the room.
func leave_online(concede: bool = true) -> void:
	var in_lobby = int(steam_bridge.lobby_id) != 0
	var was_online = mode == MODE_ONLINE
	if in_lobby and not steam_bridge.leaving():
		steam_bridge.leave_gracefully(_concede_on_leave(concede))
	elif not in_lobby:
		steam_bridge.leave_by_user()
	_set_waiting(false)
	online_view.clear()
	online_actions.clear()
	_forget_online_decks()
	_reset_room("none")
	if was_online:
		mode = MODE_AI
		started = false
		bot_timer.stop()
	if was_online or in_lobby:
		online_ended.emit(EventText.t("STEAM_LEFT_LOBBY"))

## Leaving a running online match concedes it (`concede`): the host records
## its own concession and sends the result; a guest's concession goes with
## its goodbye (the return value says so).
func _concede_on_leave(concede: bool) -> bool:
	if not concede or not online_match_running():
		return false
	if steam_bridge.is_host:
		engine.apply_action(0, MatchEngine.CONCEDE)
		_send_online_state()
		_publish()
		return false
	return true

func _steam_status(message: String) -> void:
	var text = EventText.steam_status(steam_bridge.status_code, steam_bridge.status_args, message)
	_set_notice(text)
	steam_status_changed.emit(text)

## Handshake done. The host opens the room for a new guest (or resumes the
## match for a returning one); the guest sends its deck.
func _opponent_ready(rejoin: bool) -> void:
	if steam_bridge.is_host:
		if not rejoin:
			# A new guest: no deck known yet, a fresh series.
			guest_deck = {}
			guest_deck_state = ""
			_guest_code = ""
			room_series = [0, 0]
			room_ready = [false, false]
			_cancel_countdown(false)
			room_phase = "room"
		if online_match_running() and (rejoin or waiting_for_opponent):
			_set_waiting(false)
			_send_online_state()
			_publish()
		elif waiting_for_opponent:
			_set_waiting(false)
		_broadcast_room()
		if not rejoin:
			room_opened.emit()
		return
	steam_bridge.send_deck(own_deck_code())
	if waiting_for_opponent:
		_set_waiting(false)
	if not rejoin:
		_reset_room("room")
		room_opened.emit()
	room_changed.emit()

# --- The room ------------------------------------------------------------------

## Host: the lobby exists; the room waits for a guest.
func _on_lobby_hosted(_lobby_id: int) -> void:
	_reset_room("waiting")
	room_opened.emit()

func _reset_room(phase: String) -> void:
	room_phase = phase
	room_ready = [false, false]
	room_series = [0, 0]
	room_deck = ""
	room_starting = false
	_countdown_at = -1
	room_changed.emit()

## This player's seat in the room: 0 for the host, 1 for the guest.
func room_seat() -> int:
	return 0 if steam_bridge.is_host else 1

func my_ready() -> bool:
	return bool(room_ready[room_seat()])

func opponent_is_ready() -> bool:
	return bool(room_ready[1 - room_seat()])

## True when this player may get ready: both players are in the room, no
## match is running, and (for the guest) the host accepted our deck.
func can_ready() -> bool:
	return ready_block().is_empty()

## Why this player cannot get ready (an i18n key), or "" when it can.
func ready_block() -> String:
	if not steam_bridge.in_lobby():
		return "ROOM_NOT_IN_LOBBY"
	if not steam_bridge.handshake_done:
		return "ROOM_WAITING_SEAT"
	if not steam_bridge.opponent_present:
		return "ROOM_OPPONENT_AWAY"
	if room_phase not in ["room", "result"]:
		return "ROOM_MATCH_RUNNING"
	if not steam_bridge.is_host and not own_deck_result.get("ok", false):
		return "ROOM_READY_NEEDS_DECK"
	return ""

## Gets ready (or not) for the next match. The host decides: a guest's
## change shows at once and is confirmed by the host's next room packet.
func set_ready(value: bool) -> void:
	if value and not can_ready():
		return
	if steam_bridge.is_host:
		room_ready[0] = value
		if not value:
			_cancel_countdown(false)
		_maybe_countdown()
		_broadcast_room()
		return
	if steam_bridge.send_ready(value):
		room_ready[1] = value
		if not value:
			room_starting = false
		room_changed.emit()

## Seconds left before the match starts (0 when no countdown runs).
func countdown_left() -> int:
	if not room_starting or _countdown_at < 0:
		return 0
	var now = int(steam_bridge.clock.call())
	var remaining = (_countdown_at - now) if steam_bridge.is_host else ROOM_COUNTDOWN_MS - (now - _countdown_at)
	return maxi(1, int(ceil(remaining / 1000.0)))

## Host: the guest's readiness arrived (rate-limited by the bridge). It only
## counts in the room, after a result, and with a deck the host accepted;
## otherwise the guest is told the room as it stands.
func _on_ready_received(value: bool) -> void:
	if not steam_bridge.is_host:
		return
	var allowed = room_phase in ["room", "result"] and guest_deck_state == "ok"
	room_ready[1] = value and allowed
	if not room_ready[1]:
		_cancel_countdown(false)
	_maybe_countdown()
	_broadcast_room()

## Host: both ready with an accepted guest deck starts the countdown.
func _maybe_countdown() -> void:
	if not steam_bridge.is_host or room_starting:
		return
	if room_ready[0] and room_ready[1] and guest_deck_state == "ok" and room_phase in ["room", "result"]:
		room_starting = true
		_countdown_at = int(steam_bridge.clock.call()) + ROOM_COUNTDOWN_MS

func _cancel_countdown(broadcast: bool = true) -> void:
	if not room_starting and _countdown_at < 0:
		return
	room_starting = false
	_countdown_at = -1
	if broadcast:
		_broadcast_room()

## Every bridge poll in a lobby: the host starts the match when the
## countdown ends (still both ready, the guest still there).
func _room_tick(now: int) -> void:
	if not steam_bridge.is_host or not room_starting or _countdown_at < 0 or now < _countdown_at:
		return
	room_starting = false
	_countdown_at = -1
	if room_ready[0] and room_ready[1] and steam_bridge.handshake_done and steam_bridge.opponent_present:
		start_match(MODE_ONLINE)
	else:
		_broadcast_room()

## Host: the room as the guest may see it. Never a name, a deck or a hero.
func room_packet() -> Dictionary:
	return {"phase": room_phase if room_phase in SteamBridge.ROOM_PHASES else "room", "ready": [bool(room_ready[0]), bool(room_ready[1])],
		"deck": guest_deck_state if guest_deck_state in SteamBridge.ROOM_DECK_STATES else "",
		"starting": room_starting, "series": [clampi(int(room_series[0]), 0, 999), clampi(int(room_series[1]), 0, 999)],
		"serial": match_serial}

func _broadcast_room() -> void:
	if steam_bridge.is_host and steam_bridge.in_lobby():
		steam_bridge.send_room(room_packet())
	room_changed.emit()

## Guest: the host's room state.
func _on_room_received(room: Dictionary) -> void:
	if steam_bridge.is_host:
		return
	room_phase = str(room.phase)
	room_ready = room.ready.duplicate()
	room_deck = str(room.deck)
	room_series = room.series.duplicate()
	if room.starting and not room_starting:
		_countdown_at = int(steam_bridge.clock.call())
	room_starting = room.starting
	if not room_starting:
		_countdown_at = -1
	room_changed.emit()

## Host: a decided match ends the room's "match" phase and counts for the
## series.
func _note_result() -> void:
	if mode != MODE_ONLINE or not steam_bridge.is_host or room_phase != "match" or not is_finished():
		return
	room_phase = "result"
	var winner = int(engine.state.get("winner", -1))
	if winner == 0 or winner == 1:
		room_series[winner] = int(room_series[winner]) + 1
	_broadcast_room()

## Host: the guest said goodbye. Leaving a running match concedes it (the
## concession usually arrived just before); then the seat is free.
func _on_bye(conceded: bool) -> void:
	if not steam_bridge.is_host:
		return
	var gave_up = conceded
	if online_match_running():
		engine.apply_action(1, MatchEngine.CONCEDE)
		gave_up = true
		_set_waiting(false)
		_send_online_state()
		_publish()
	steam_bridge.release_opponent("opponent_conceded_left" if gave_up else "opponent_left_lobby")

## Host: the guest's seat is free (it left); the room waits for a new guest.
func _on_opponent_released(_code: String, name: String) -> void:
	guest_deck = {}
	guest_deck_state = ""
	_guest_code = ""
	_set_waiting(false)
	_reset_room("waiting")
	opponent_left.emit(name)

func _opponent_lost(reason: String) -> void:
	if online_match_running():
		_set_waiting(true)
	elif steam_bridge.is_host and reason in ["left", "disconnected"]:
		# Out of the lobby with no match to wait for: the seat is free again.
		steam_bridge.release_opponent("opponent_left_lobby")
	room_changed.emit()

func _session_ended(_code: String) -> void:
	var was_online = mode == MODE_ONLINE
	_set_waiting(false)
	online_view.clear()
	online_actions.clear()
	_forget_online_decks()
	_reset_room("none")
	if was_online:
		mode = MODE_AI
		started = false
		bot_timer.stop()
	online_ended.emit(steam_status_text())

# --- Decks -------------------------------------------------------------------

## The deck code of this player's deck (seat 0), "" when it has none. The
## code carries no name: the name is free text the player typed and the host
## does not need it to play.
func own_deck_code() -> String:
	var entry = library.resolve_deck(deck_selections[0]) if not deck_selections.is_empty() else {}
	if entry.is_empty():
		return ""
	var unnamed = entry.duplicate()
	unnamed["name"] = ""
	return DeckCode.encode(unnamed, library)

## Picks this player's deck (seat 0). A guest connected to a host sends it at
## once (the host decides whether it stays ready); the host uses it from its
## next match, and choosing another deck takes back its readiness.
func set_own_deck(entry) -> void:
	var before = deck_selections[0] if not deck_selections.is_empty() else null
	if deck_selections.is_empty():
		deck_selections = [entry, FALLBACK_DECK]
	else:
		deck_selections[0] = entry.duplicate(true) if entry is Dictionary else entry
	if not steam_bridge.is_host and steam_bridge.handshake_done:
		own_deck_result = {}
		steam_bridge.send_deck(own_deck_code())
		room_changed.emit()
	elif steam_bridge.is_host and steam_bridge.in_lobby():
		if before != deck_selections[0] and room_ready[0]:
			room_ready[0] = false
			_cancel_countdown(false)
		_broadcast_room()

## Display name of this player's deck (seat 0).
func own_deck_name() -> String:
	var entry = deck_selections[0] if not deck_selections.is_empty() else ""
	if entry is Dictionary:
		var name = DeckCode.clean_name(str(entry.get("name", "")))
		return name if not name.is_empty() else EventText.t("DECK_UNNAMED")
	return MatchEngine.Library.preset_text(str(entry))

## The five heroes of this player's deck (seat 0), for its own screens only.
func own_deck_heroes() -> Array:
	var entry = library.resolve_deck(deck_selections[0]) if not deck_selections.is_empty() else {}
	return entry.get("heroes", []).duplicate() if entry is Dictionary else []

## Host: the guest's deck when it has sent none or an invalid one.
func fallback_guest_deck() -> String:
	var choice = deck_selections[1] if deck_selections.size() > 1 else null
	if choice is String and not library.preset(choice).is_empty():
		return choice
	return FALLBACK_DECK

## Host: the guest's deck code arrived; it is decoded and validated here (the
## guest is never trusted) and answered with ok or the coded reason. Another
## deck takes back the guest's readiness; the room tells the guest either way.
func _on_guest_deck(code: String) -> void:
	var unchanged = code == _guest_code and guest_deck_state == "ok"
	var result = DeckCode.decode(code, library)
	if result.ok:
		var validation = library.validate_preset(result.deck)
		if validation.ok:
			guest_deck = result.deck
			# Never keep text the guest typed (its own client sends no name).
			guest_deck["name"] = ""
			guest_deck_state = "ok"
			_guest_code = code
			steam_bridge.answer_deck({"ok": true})
		else:
			result = validation
	if not result.ok:
		guest_deck = {}
		guest_deck_state = "rejected"
		_guest_code = ""
		steam_bridge.answer_deck(result)
	if not unchanged:
		room_ready[1] = false
		_cancel_countdown(false)
	_broadcast_room()

## Guest: the host's answer to our deck.
func _on_deck_answered(result: Dictionary) -> void:
	own_deck_result = result
	if result.get("ok", false):
		_set_notice(EventText.t("DECK_ONLINE_ACCEPTED"))
	else:
		_set_notice(EventText.t("DECK_ONLINE_REJECTED", {"reason": EventText.error_text(result)}))
	own_deck_answered.emit(result)
	room_changed.emit()

## The deck entry this player chose for seat `player` of the shown match
## (null for the online opponent, whose deck is not ours to know).
func local_deck_entry(player: int):
	var decks: Array = match_decks if started and not match_decks.is_empty() else deck_selections
	if mode == MODE_ONLINE:
		var own_seat = 0 if steam_bridge.is_host else 1
		return decks[0] if player == own_seat and not decks.is_empty() else null
	return decks[player] if player >= 0 and player < decks.size() else null

## Display name of player `player`'s deck in `shown`: a preset's name, an own
## deck's name (this player chose it), "Custom deck", or the hidden opponent.
func deck_name_in(shown: Dictionary, player: int) -> String:
	var players = shown.get("players", [])
	if not players is Array or player < 0 or player >= players.size():
		return ""
	var preset = str(players[player].get("preset", ""))
	if preset == HIDDEN_DECK:
		return EventText.t("DECK_HIDDEN")
	if preset != MatchEngine.CUSTOM_DECK:
		return MatchEngine.Library.preset_text(preset)
	var entry = local_deck_entry(player)
	# A preset with its heroes reordered (a campaign enemy) keeps the preset's name.
	if entry is Dictionary and not library.preset(str(entry.get("preset", ""))).is_empty():
		return MatchEngine.Library.preset_text(str(entry.preset))
	if entry is Dictionary and not DeckCode.clean_name(str(entry.get("name", ""))).is_empty():
		return DeckCode.clean_name(str(entry.name))
	# A guest's preset reaches the host as a deck code, so the state says
	# "custom"; this player knows which preset it was.
	if entry is String and not library.preset(entry).is_empty():
		return MatchEngine.Library.preset_text(entry)
	return EventText.t("DECK_CUSTOM")

func _set_waiting(value: bool) -> void:
	if value == waiting_for_opponent:
		return
	waiting_for_opponent = value
	waiting_since = Time.get_ticks_msec() / 1000.0
	online_paused.emit(value)

func _send_online_state() -> void:
	steam_bridge.send_match(online_player_view(1), engine.legal_actions(1), match_serial)

## Guest: a host snapshot. Only reaches us while we are in the host's lobby
## (starting an offline match leaves it first).
func _online_state(new_view: Dictionary, new_actions: Array, serial: int = 0) -> void:
	if steam_bridge.is_host:
		return
	# A new match (a rematch) is drawn from scratch, which also clears the
	# previous result screen.
	var first = mode != MODE_ONLINE or online_view.is_empty() or serial != match_serial
	mode = MODE_ONLINE
	match_serial = serial
	bot_timer.stop()
	online_view = new_view
	online_actions = new_actions
	started = true
	if int(new_view.get("winner", -1)) != -1:
		_set_waiting(false)
		if room_phase == "match":
			room_phase = "result"
			room_changed.emit()
	if first:
		# The host plays the deck we had sent when this match began; a deck
		# picked from now on applies from the next match.
		match_decks = [deck_selections[0] if not deck_selections.is_empty() else null]
		match_decks = match_decks.duplicate(true)
		if int(new_view.get("winner", -1)) == -1:
			room_phase = "match"
			room_ready = [false, false]
			room_starting = false
			_countdown_at = -1
		# The room already showed the connection and both names; the match
		# opens with the same first hint as the host's (never "Player 2").
		_set_notice(EventText.t("HINT_DRAG_CARD"))
		match_started.emit()
		room_changed.emit()
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
