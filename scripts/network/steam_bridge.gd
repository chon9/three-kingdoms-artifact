extends Node
## Optional GodotSteam adapter (GodotSteam 4.23 GDExtension, bundled in
## addons/godotsteam). Standard Godot must boot without it: every Steam call
## goes through `steam` (the Steam singleton, or a fake in tests/steam_test.gd)
## and failures leave offline play untouched.
##
## The host owns the rules; the guest receives only its own redacted view.
## Flow: the host creates a friends-only or public lobby and publishes lobby
## data (game tag, protocol, content hash, host name, status) and rich presence
## ("connect" = "+connect_lobby <id>"). A guest joins by pasted ID, overlay
## invite (join_requested), friends-list "Join game" (join_game_requested),
## launch argument "+connect_lobby <id>" or the lobby browser, then sends
## "hello" until the host answers "welcome" (or "reject" on a version mismatch
## or a taken seat). The host binds the seat to the guest's SteamID; only that
## account can rejoin. Both sides ping every HEARTBEAT_MS.
##
## Untrusted input: packets are size-, depth- and type-checked before use,
## display names come from Steam (not from packets) and are clamped, and the
## host answers repeated or rejected traffic with small, rate-limited replies.

## `message` is an English fallback; `status_code`/`status_args` identify the
## status for translation (i18n key STEAM_<CODE>).
signal status_changed(message: String)
## Guest: a new host snapshot. `match_serial` changes when the host starts a new match.
signal match_received(view: Dictionary, actions: Array, match_serial: int)
signal command_received(command: Dictionary, revision: int)
## Guest: the host did not apply our last command (stale or illegal).
signal command_rejected(revision: int)
## Lobby browser results: [{"id", "host", "status", "compatible"}].
signal lobbies_listed(lobbies: Array)
## A join started outside the dialog (overlay invite or launch argument).
signal join_started(lobby_id: int)
## The handshake completed. `rejoin` is true when the same opponent returns.
signal opponent_ready(rejoin: bool)
## The opponent left or stopped answering (left, disconnected, timeout).
signal opponent_lost(reason: String)
## The online session is over for good (host_left, kicked, steam_shutdown,
## version_mismatch, seat_taken). The lobby has already been left.
signal session_ended(code: String)
## Connection quality changed: see connection_info().
signal connection_changed(info: Dictionary)

const APP_ID = 480
const GAME_TAG = "sanguo_classic_revival"
## 6: hello/welcome/reject handshake with content hash, ping/pong heartbeat,
## concede command, numbers normalized on receipt.
const PROTOCOL = 6
const CHANNEL = 71
# Steam Networking Messages send flags (k_nSteamNetworkingSend_*).
const SEND_RELIABLE = 8
const SEND_AUTO_RESTART_BROKEN_SESSION = 32
const SEND_FLAGS = SEND_RELIABLE | SEND_AUTO_RESTART_BROKEN_SESSION
const MAX_PACKET_BYTES = 262144
# ELobbyType, ELobbyComparison, ELobbyDistanceFilter.
const LOBBY_FRIENDS_ONLY = 1
const LOBBY_PUBLIC = 2
const LOBBY_COMPARISON_EQUAL = 0
const LOBBY_DISTANCE_WORLDWIDE = 3
# EChatMemberStateChange flags from lobby_chat_update.
const CHAT_ENTERED = 1
const CHAT_LEFT = 2
const CHAT_DISCONNECTED = 4
const CHAT_KICKED = 8
const CHAT_BANNED = 16
const RESULT_OK = 1
# ESteamNetworkingConnectionState: only a connected session has real status.
const CONNECTION_CONNECTED = 3
# ESteamAPIInitResult (steamInitEx "status").
const INIT_NO_STEAM_CLIENT = 2
const INIT_VERSION_MISMATCH = 3
const HEARTBEAT_MS = 5000
const HELLO_RETRY_MS = 2000
const TIMEOUT_MS = 20000
## Host: at most one unsolicited snapshot resend per this many ms.
const RESEND_MS = 1000
## Host: a refused member's session is closed this long after the reject (so
## the reject itself is delivered first) and never accepted again.
const REFUSE_CLOSE_MS = 1500
## Lobby size; one extra slot while a seat is reserved for a returning guest,
## so a stranger occupying the free slot cannot lock the original guest out.
const LOBBY_MEMBERS = 2
const LOBBY_MEMBERS_RESERVED = 3
## Deepest JSON nesting accepted from the network (views need about 8).
const MAX_PACKET_DEPTH = 32
const MAX_NAME_CHARS = 32
const CONTENT_FILES = ["res://data/classic_cards.json", "res://data/locale/cards.json"]
const REQUIRED = ["steamInitEx", "run_callbacks", "getSteamID", "getPersonaName", "createLobby",
	"joinLobby", "leaveLobby", "setLobbyData", "getLobbyData", "getLobbyOwner", "getNumLobbyMembers",
	"getLobbyMemberByIndex", "sendMessageToUser", "receiveMessagesOnChannel", "acceptSessionWithUser",
	"closeSessionWithUser", "requestLobbyList", "addRequestLobbyListStringFilter"]
const SIGNALS = {"lobby_created": "_lobby_created", "lobby_joined": "_lobby_joined",
	"lobby_chat_update": "_lobby_changed", "lobby_match_list": "_lobby_list",
	"join_requested": "_join_requested", "join_game_requested": "_join_game_requested",
	"network_messages_session_request": "_session_requested",
	"network_messages_session_failed": "_session_failed", "steam_shutdown": "_steam_shutdown",
	"lobby_kicked": "_lobby_kicked", "steam_server_disconnected": "_steam_server_disconnected"}

var steam: Object
var available = false
var is_host = false
var lobby_id: int = 0
var lobby_public = false
## The connected opponent: the guest's SteamID on the host, the host's on the guest.
var peer_id: int = 0
var local_id: int = 0
## Guest: the lobby owner when we joined. Host: our own id.
var host_id: int = 0
## Host: the SteamID bound to seat 2 for this lobby; nobody else may take it.
var bound_opponent: int = 0
var handshake_done = false
var opponent_present = false
var peer_name: String = ""
var godotsteam_version: String = ""
var content_hash: String = ""
var status = "GodotSteam is not installed. Offline AI and local play are available."
var status_code = "not_installed"
var status_args: Dictionary = {}
var cached_match: Dictionary = {}
## Guest: the host's match serial from the last snapshot.
var match_serial: int = 0
var ping_ms: int = -1
var quality: float = -1.0
## Milliseconds clock; tests replace it to drive heartbeats and timeouts.
var clock: Callable = func() -> int: return Time.get_ticks_msec()
var _pending_join: int = 0
var _last_heard: int = 0
var _last_ping: int = 0
var _last_hello: int = -HELLO_RETRY_MS
var _last_welcome: int = -HELLO_RETRY_MS
var _last_resend: int = -RESEND_MS
## Host: refused SteamIDs -> time to close their session (0 once closed).
var _refused: Dictionary = {}

func _ready() -> void:
	content_hash = compute_content_hash()
	# Headless runs (tests, CI) and --no-steam never touch the Steam client.
	if DisplayServer.get_name() == "headless" or "--no-steam" in OS.get_cmdline_args() or "--no-steam" in OS.get_cmdline_user_args():
		_set_status("disabled", "Steam is turned off for this run. Offline play is available.")
		return
	if not Engine.has_singleton("Steam"):
		return
	attach(Engine.get_singleton("Steam"), Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args()))

## Initializes `steam_object` (the Steam singleton or a test fake). Returns true
## when Steam is usable. `launch_args` may hold "+connect_lobby <id>".
func attach(steam_object: Object, launch_args: Array = []) -> bool:
	steam = steam_object
	if content_hash.is_empty():
		content_hash = compute_content_hash()
	for method in REQUIRED:
		if not steam.has_method(method):
			_set_status("missing_method", "This GodotSteam build is missing %s. See docs/STEAM.md." % method, {"method": method})
			return false
	if steam.has_method("get_godotsteam_version"):
		godotsteam_version = str(steam.call("get_godotsteam_version"))
	# Current GodotSteam signature is app_id first, embed_callbacks second.
	# Callbacks run explicitly in poll().
	var result = steam.call("steamInitEx", APP_ID, false)
	if not result is Dictionary or int(result.get("status", -1)) != 0:
		# Known causes get their own localized text; Steam's English message
		# is only a detail for the rest.
		var init_status = int(result.get("status", -1)) if result is Dictionary else -1
		var reason = str(result.get("verbal", "")) if result is Dictionary else ""
		if init_status == INIT_NO_STEAM_CLIENT:
			_set_status("init_no_client", "Steam is not running or you are not signed in.", {"reason": reason})
		elif init_status == INIT_VERSION_MISMATCH:
			_set_status("init_version", "The Steam client is older than this GodotSteam build.", {"reason": reason})
		else:
			if reason.is_empty():
				reason = "status %d" % init_status
			_set_status("init_failed", "Steam could not initialize: " + reason, {"reason": reason})
		return false
	available = true
	local_id = int(steam.call("getSteamID"))
	for signal_name in SIGNALS:
		if steam.has_signal(signal_name) and not steam.is_connected(signal_name, Callable(self, SIGNALS[signal_name])):
			steam.connect(signal_name, Callable(self, SIGNALS[signal_name]))
	_set_status("connected", "Steam connected. Development App ID 480. Create or join a two-player lobby.", {"app_id": APP_ID})
	var args = launch_args.duplicate()
	if steam.has_method("getLaunchCommandLine"):
		args.append_array(str(steam.call("getLaunchCommandLine")).split(" ", false))
	_pending_join = lobby_from_args(args)
	return true

func _process(_delta: float) -> void:
	poll()

## Runs Steam callbacks, a pending launch join, received messages and the heartbeat.
func poll() -> void:
	if not available:
		return
	steam.call("run_callbacks")
	if _pending_join != 0 and available:
		var launch_lobby = _pending_join
		_pending_join = 0
		join_lobby_id(launch_lobby)
		join_started.emit(launch_lobby)
	if lobby_id == 0 or not available:
		return
	for message in steam.call("receiveMessagesOnChannel", CHANNEL, 32):
		var bytes = message.get("payload", PackedByteArray())
		if not bytes is PackedByteArray or bytes.size() > MAX_PACKET_BYTES:
			continue
		# JSON.parse (unlike JSON.parse_string) reports bad input without
		# logging an engine error per packet.
		var json = JSON.new()
		if json.parse(bytes.get_string_from_utf8()) == OK and json.data is Dictionary:
			_handle_packet(int(message.get("identity", 0)), json.data)
		if lobby_id == 0:
			return
	_tick(int(clock.call()))

# --- Pure helpers (unit tested) ----------------------------------------------

## A lobby ID from pasted text: digits, "+connect_lobby <id>" or a
## steam://joinlobby/<app>/<lobby>/... link. Returns 0 when there is none.
static func parse_lobby_id(text: String) -> int:
	var value = text.strip_edges()
	if value.is_valid_int():
		return maxi(int(value), 0)
	var tokens = value.replace("/", " ").replace("=", " ").split(" ", false)
	for index in range(tokens.size() - 1):
		if tokens[index] == "+connect_lobby" and tokens[index + 1].is_valid_int():
			return maxi(int(tokens[index + 1]), 0)
		if tokens[index] == "joinlobby" and index + 2 < tokens.size() and tokens[index + 2].is_valid_int():
			return maxi(int(tokens[index + 2]), 0)
	return 0

## The lobby named by "+connect_lobby <id>" in launch arguments, or 0.
static func lobby_from_args(args: Array) -> int:
	for index in range(args.size() - 1):
		if str(args[index]) == "+connect_lobby" and str(args[index + 1]).is_valid_int():
			return maxi(int(str(args[index + 1])), 0)
	return 0

## JSON turns every number into a float. Converts exact whole numbers back to
## int, recursively, so received views, actions and commands index and compare
## like local ones. Fractions, strings and keys are left alone.
static func normalize_numbers(value):
	match typeof(value):
		TYPE_FLOAT:
			if is_finite(value) and value == floorf(value) and absf(value) <= 9007199254740992.0:
				return int(value)
			return value
		TYPE_ARRAY:
			var items: Array = []
			for item in value:
				items.append(normalize_numbers(item))
			return items
		TYPE_DICTIONARY:
			var entries: Dictionary = {}
			for key in value:
				entries[key] = normalize_numbers(value[key])
			return entries
	return value

## Nesting depth of a decoded JSON value, counted without recursion and
## stopping once it exceeds `limit` (returns limit + 1 then).
static func nesting_depth(value, limit: int = MAX_PACKET_DEPTH) -> int:
	var deepest = 0
	var stack: Array = [[value, 0]]
	while not stack.is_empty():
		var entry = stack.pop_back()
		var depth: int = entry[1]
		if not (entry[0] is Array or entry[0] is Dictionary):
			continue
		depth += 1
		deepest = maxi(deepest, depth)
		if deepest > limit:
			return limit + 1
		for item in (entry[0] if entry[0] is Array else entry[0].values()):
			stack.append([item, depth])
	return deepest

## A display name safe to show: control characters removed, trimmed and
## clamped to MAX_NAME_CHARS.
static func clean_name(text: String) -> String:
	var result = ""
	for character in text:
		if character.unicode_at(0) >= 32 and character.unicode_at(0) != 127:
			result += character
	result = result.strip_edges()
	if result.length() > MAX_NAME_CHARS:
		result = result.substr(0, MAX_NAME_CHARS - 1).strip_edges() + "…"
	return result

## True when `value` has exactly the type and value of `expected` (network
## fields can hold any JSON type; mixed-type comparisons raise errors).
static func same(value, expected) -> bool:
	return typeof(value) == typeof(expected) and value == expected

## Short hash of the rules-relevant data and the protocol. Line endings are
## normalized so Windows (CRLF checkouts) and Linux builds agree.
static func compute_content_hash(files: Array = CONTENT_FILES, protocol: int = PROTOCOL) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for path in files:
		context.update(FileAccess.get_file_as_string(path).replace("\r", "").to_utf8_buffer())
	context.update(("protocol:%d" % protocol).to_utf8_buffer())
	return context.finish().hex_encode().substr(0, 16)

# --- Lobbies -------------------------------------------------------------------

func host_lobby(public: bool = false) -> void:
	if not available:
		return
	leave_lobby()
	is_host = true
	lobby_public = public
	steam.call("createLobby", LOBBY_PUBLIC if public else LOBBY_FRIENDS_ONLY, LOBBY_MEMBERS)
	_set_status("creating_lobby", "Creating a lobby…")

## Joins by pasted text (see parse_lobby_id).
func join_lobby(id_text: String) -> void:
	if not available:
		return
	var id = parse_lobby_id(id_text)
	if id <= 0:
		_set_status("invalid_lobby_id", "Enter a valid numeric Steam lobby ID.")
		return
	join_lobby_id(id)

func join_lobby_id(id: int) -> void:
	if not available or id <= 0:
		return
	leave_lobby()
	is_host = false
	steam.call("joinLobby", id)
	_set_status("joining_lobby", "Joining lobby…", {"lobby": str(id)})

func invite_friends() -> void:
	if available and lobby_id != 0 and steam.has_method("activateGameOverlayInviteDialog"):
		steam.call("activateGameOverlayInviteDialog", lobby_id)

## Searches public lobbies of this game worldwide; results arrive via lobbies_listed.
func request_lobby_list() -> bool:
	if not available:
		return false
	steam.call("addRequestLobbyListStringFilter", "game", GAME_TAG, LOBBY_COMPARISON_EQUAL)
	if steam.has_method("addRequestLobbyListDistanceFilter"):
		steam.call("addRequestLobbyListDistanceFilter", LOBBY_DISTANCE_WORLDWIDE)
	if steam.has_method("addRequestLobbyListFilterSlotsAvailable"):
		steam.call("addRequestLobbyListFilterSlotsAvailable", 1)
	if steam.has_method("addRequestLobbyListResultCountFilter"):
		steam.call("addRequestLobbyListResultCountFilter", 50)
	steam.call("requestLobbyList")
	_set_status("searching_lobbies", "Searching for public lobbies…")
	return true

## True while a lobby holds (or holds the seat of) a connected opponent;
## joining or hosting elsewhere would end that online match.
func in_session() -> bool:
	return lobby_id != 0 and handshake_done

## The player chose to leave: leaves the lobby and says so.
func leave_by_user() -> void:
	var was_in_lobby = lobby_id != 0
	leave_lobby()
	if available and was_in_lobby:
		_set_status("left_lobby", "You left the lobby.")

func leave_lobby() -> void:
	if available and lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
	for remote in [peer_id, bound_opponent] + _refused.keys():
		if available and remote != 0:
			steam.call("closeSessionWithUser", remote)
	_refused.clear()
	match_serial = 0
	_last_welcome = -HELLO_RETRY_MS
	_last_resend = -RESEND_MS
	if available and steam.has_method("clearRichPresence"):
		steam.call("clearRichPresence")
	lobby_id = 0
	peer_id = 0
	host_id = 0
	bound_opponent = 0
	handshake_done = false
	opponent_present = false
	peer_name = ""
	ping_ms = -1
	quality = -1.0
	cached_match.clear()
	is_host = false

## Ping, link quality and presence of the opponent:
## {"level": "good"|"fair"|"poor"|"lost"|"unknown", "ping": ms, "quality": 0..1 or -1}.
func connection_info() -> Dictionary:
	var level = "unknown"
	if handshake_done and not opponent_present:
		level = "lost"
	elif ping_ms >= 0:
		level = "good" if ping_ms < 120 else ("fair" if ping_ms < 250 else "poor")
		if quality >= 0.0 and quality < 0.8:
			level = "poor"
		elif quality >= 0.0 and quality < 0.95 and level == "good":
			level = "fair"
	return {"level": level, "ping": ping_ms, "quality": quality}

# --- Sending -------------------------------------------------------------------

## Host: sends the guest's view. `serial` identifies the match (a rematch
## gets a new one, so the guest resets its screen).
func send_match(view: Dictionary, actions: Array, serial: int = 0) -> void:
	if not is_host:
		return
	cached_match = {"kind": "state", "view": view, "actions": actions, "match": serial}
	if handshake_done and opponent_present:
		_send(cached_match)

## Host: the guest's command was not applied. Answers with a tiny notice and
## at most one snapshot per RESEND_MS, so invalid commands cannot make the
## host send far more than it receives.
func reject_command(revision: int) -> void:
	if not is_host or not handshake_done or not opponent_present:
		return
	_send({"kind": "nack", "revision": revision}, false)
	var now = int(clock.call())
	if now - _last_resend >= RESEND_MS:
		_last_resend = now
		_send(cached_match, false)

func send_command(command: Dictionary, revision: int) -> void:
	if not is_host and handshake_done and peer_id != 0:
		_send({"kind": "command", "command": command, "revision": revision})

func _send(packet: Dictionary, report: bool = true, target: int = -1) -> bool:
	var remote = peer_id if target == -1 else target
	if not available or remote == 0 or packet.is_empty():
		return false
	var envelope = packet.duplicate(true)
	envelope["protocol"] = PROTOCOL
	envelope["game"] = GAME_TAG
	var bytes = JSON.stringify(envelope).to_utf8_buffer()
	if bytes.size() > MAX_PACKET_BYTES:
		_set_status("snapshot_too_large", "Match snapshot is too large for the development transport.")
		return false
	var result = int(steam.call("sendMessageToUser", remote, bytes, SEND_FLAGS, CHANNEL))
	if result != RESULT_OK and report:
		_set_status("send_failed", "Steam send failed (%d). Check that your opponent is connected." % result, {"result": result})
	return result == RESULT_OK

func _send_hello() -> void:
	_last_hello = int(clock.call())
	_send({"kind": "hello", "content": content_hash, "godotsteam": godotsteam_version, "name": _local_name()}, false)

# --- Steam callbacks -------------------------------------------------------------

func _lobby_created(result: int, created_id: int) -> void:
	if result != RESULT_OK:
		is_host = false
		_set_status("create_failed", "Steam lobby creation failed (%d)." % result, {"result": result})
		return
	lobby_id = created_id
	is_host = true
	host_id = local_id
	for entry in [["game", GAME_TAG], ["protocol", str(PROTOCOL)], ["content", content_hash],
			["host", _local_name()], ["status", "waiting"], ["godotsteam", godotsteam_version]]:
		steam.call("setLobbyData", lobby_id, entry[0], entry[1])
	_set_presence()
	if lobby_public:
		_set_status("lobby_created", "Lobby %d created. Share its ID with a friend." % lobby_id, {"lobby": str(lobby_id)})
	else:
		# Friends-only lobbies never appear in the public lobby list.
		_set_status("lobby_created_friends", "Lobby %d created. Invite a friend or share its ID." % lobby_id, {"lobby": str(lobby_id)})

func _lobby_joined(joined_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if is_host:
		# The creator also enters its own lobby; lobby_created holds the details.
		if lobby_id == 0 and response == RESULT_OK:
			lobby_id = joined_id
		return
	if response != RESULT_OK:
		_set_status("join_failed", "Steam lobby join failed (%d)." % response, {"result": response})
		return
	lobby_id = joined_id
	if str(steam.call("getLobbyData", lobby_id, "game")) != GAME_TAG:
		leave_lobby()
		_set_status("incompatible_lobby", "This lobby belongs to another game or incompatible version.")
		return
	var host_protocol = str(steam.call("getLobbyData", lobby_id, "protocol"))
	var host_content = str(steam.call("getLobbyData", lobby_id, "content"))
	if host_protocol != str(PROTOCOL) or host_content != content_hash:
		_end_session("version_mismatch", {"host_protocol": host_protocol, "host_content": host_content,
			"protocol": str(PROTOCOL), "content": content_hash})
		return
	host_id = int(steam.call("getLobbyOwner", lobby_id))
	peer_id = host_id
	peer_name = _trusted_name(host_id, str(steam.call("getLobbyData", lobby_id, "host")))
	_set_presence()
	_set_status("joined_lobby", "Joined lobby %d. Contacting the host…" % lobby_id, {"lobby": str(lobby_id)})
	_send_hello()

func _lobby_changed(changed_lobby: int, changed_id: int, _actor_id: int, chat_state: int) -> void:
	if changed_lobby != lobby_id or lobby_id == 0:
		return
	# Our own removal arrives as lobby_kicked (we no longer get this callback).
	var gone = chat_state & (CHAT_LEFT | CHAT_DISCONNECTED | CHAT_KICKED | CHAT_BANNED) != 0
	if not gone:
		return
	if is_host:
		if changed_id == bound_opponent and opponent_present:
			_lose_opponent("disconnected" if chat_state & CHAT_DISCONNECTED != 0 else "left")
	elif changed_id == host_id:
		_end_session("host_left")

func _lobby_list(lobbies: Array) -> void:
	var result: Array = []
	for raw in lobbies:
		var id = int(raw)
		if id == 0 or id == lobby_id or str(steam.call("getLobbyData", id, "game")) != GAME_TAG:
			continue
		result.append({"id": id, "host": clean_name(str(steam.call("getLobbyData", id, "host"))),
			"status": str(steam.call("getLobbyData", id, "status")),
			"compatible": str(steam.call("getLobbyData", id, "protocol")) == str(PROTOCOL)
				and str(steam.call("getLobbyData", id, "content")) == content_hash})
	result.sort_custom(_lobby_before)
	_set_status("lobbies_found", "%d public lobbies found." % result.size(), {"n": result.size()})
	lobbies_listed.emit(result)

## Compatible lobbies first, then those waiting for a player.
static func _lobby_before(a: Dictionary, b: Dictionary) -> bool:
	if a.compatible != b.compatible:
		return a.compatible
	return a.status == "waiting" and b.status != "waiting"

## Overlay invite accepted while the game runs (GameLobbyJoinRequested_t).
func _join_requested(requested_lobby: int, _friend_id: int) -> void:
	_join_from_steam(requested_lobby)

## Friends-list "Join game" while the game runs (GameRichPresenceJoinRequested_t):
## `connect` is the host's rich presence "+connect_lobby <id>".
func _join_game_requested(_friend_id: int, connect: String) -> void:
	_join_from_steam(parse_lobby_id(connect))

func _join_from_steam(requested_lobby: int) -> void:
	if not available or requested_lobby <= 0 or requested_lobby == lobby_id:
		return
	if in_session():
		# Never drop a running online match silently; the player leaves first.
		_set_status("leave_first", "Leave the current lobby before joining another.")
		return
	join_lobby_id(requested_lobby)
	join_started.emit(requested_lobby)

## Accepts sessions from lobby members even before lobby_chat_update has
## told us who they are (the first hello can arrive first).
func _session_requested(remote_id: int) -> void:
	if remote_id == 0 or remote_id == local_id or _refused.has(remote_id):
		return
	if (is_host and _is_member(remote_id)) or (not is_host and remote_id == host_id and host_id != 0):
		steam.call("acceptSessionWithUser", remote_id)

func _session_failed(reason: int, remote_id: int, _connection_state: int, _debug_message: String) -> void:
	if remote_id == 0 or remote_id != peer_id:
		return
	_set_status("session_failed", "Connection to %s failed (%d). Retrying…" % [peer_name, reason],
		{"name": _display_name(), "reason": reason})
	connection_changed.emit(connection_info())

func _steam_shutdown() -> void:
	var had_lobby = lobby_id != 0
	leave_lobby()
	available = false
	_set_status("steam_shutdown", "Steam is shutting down. Online play has ended.")
	if had_lobby:
		session_ended.emit("steam_shutdown")

## We were removed from the lobby, usually because our Steam connection dropped.
func _lobby_kicked(kicked_lobby: int, _admin_id: int, due_to_disconnect: int) -> void:
	if lobby_id == 0 or kicked_lobby != lobby_id:
		return
	if due_to_disconnect != 0:
		_end_session("steam_disconnected")
	else:
		_end_session("kicked")

## Our connection to the Steam servers dropped: lobby membership (and with it
## the online match) is gone; Steam reconnects by itself for the next lobby.
func _steam_server_disconnected(_result: int) -> void:
	if lobby_id != 0:
		_end_session("steam_disconnected")

# --- Packets -------------------------------------------------------------------

func _handle_packet(sender: int, raw: Dictionary) -> void:
	# Cheap checks first: only lobby members, only this game, and on the host
	# only the bound guest (or a hello) get as far as normalization.
	if _refused.has(sender) or not same(raw.get("game"), GAME_TAG) or not _is_member(sender):
		return
	var kind = str(raw.get("kind", "")) if raw.get("kind") is String else ""
	if is_host:
		if kind != "hello" and (sender != bound_opponent or not handshake_done):
			return
	elif sender != host_id:
		return
	if nesting_depth(raw) > MAX_PACKET_DEPTH:
		return
	var packet: Dictionary = normalize_numbers(raw)
	if is_host:
		if kind == "hello":
			_host_hello(sender, packet)
			return
		if not same(packet.get("protocol"), PROTOCOL):
			return
	else:
		if kind == "reject":
			var reason = str(packet.get("reason", ""))
			_end_session("seat_taken" if reason == "seat_taken" else "version_mismatch",
				{"host_protocol": str(packet.get("host_protocol", "")), "host_content": str(packet.get("host_content", "")),
				"protocol": str(PROTOCOL), "content": content_hash})
			return
		if not same(packet.get("protocol"), PROTOCOL):
			return
	var now = int(clock.call())
	_last_heard = now
	if handshake_done and not opponent_present:
		# The opponent answers again after a timeout (the session restarted).
		opponent_present = true
		if is_host:
			_reserve_seat(false)
		_set_status("opponent_returned" if is_host else "connected_to_host", "Connected to %s." % peer_name, {"name": _display_name()})
		opponent_ready.emit(true)
		connection_changed.emit(connection_info())
	match kind:
		"welcome":
			if is_host:
				return
			var rejoin = same(packet.get("rejoin"), true)
			peer_name = _trusted_name(host_id, str(packet.get("name", "")) if packet.get("name") is String else peer_name)
			var first = not handshake_done
			handshake_done = true
			opponent_present = true
			_last_ping = now
			if first:
				_set_status("connected_to_host", "Connected to %s. You are Player 2." % peer_name, {"name": _display_name()})
				opponent_ready.emit(rejoin)
		"ping":
			var stamp = packet.get("t")
			_send({"kind": "pong", "t": stamp if stamp is int else 0}, false)
		"pong":
			var sent_at = packet.get("t")
			if sent_at is int and sent_at <= now:
				ping_ms = now - sent_at
				_update_quality()
		"command":
			var revision = packet.get("revision")
			if is_host and packet.get("command") is Dictionary and revision is int:
				command_received.emit(packet.command, revision)
		"nack":
			var rejected = packet.get("revision")
			if not is_host and handshake_done and rejected is int:
				command_rejected.emit(rejected)
		"state":
			if not is_host and handshake_done and packet.get("view") is Dictionary and packet.get("actions") is Array:
				if _valid_view(packet.view):
					var serial = packet.get("match")
					match_serial = serial if serial is int else 0
					match_received.emit(packet.view, packet.actions, match_serial)

func _host_hello(sender: int, packet: Dictionary) -> void:
	var name = _trusted_name(sender, str(packet.get("name", "")) if packet.get("name") is String else "")
	if not same(packet.get("protocol"), PROTOCOL) or str(packet.get("content", "")) != content_hash:
		_refuse(sender, {"kind": "reject", "reason": "version_mismatch", "host_protocol": PROTOCOL, "host_content": content_hash})
		_set_status("guest_version_mismatch", "%s has a different game version and was turned away." % name, {"name": name})
		return
	if bound_opponent != 0 and sender != bound_opponent:
		_refuse(sender, {"kind": "reject", "reason": "seat_taken"})
		_set_status("reserved_opponent", "This match is reserved for the original opponent.")
		return
	var now = int(clock.call())
	_last_heard = now
	if sender == bound_opponent and handshake_done and opponent_present:
		# A repeated hello (the welcome crossed it): answer again, at most
		# once per HELLO_RETRY_MS, nothing changed.
		if now - _last_welcome >= HELLO_RETRY_MS:
			_last_welcome = now
			_send({"kind": "welcome", "name": _local_name(), "rejoin": false})
			_send(cached_match)
		return
	var rejoin = bound_opponent == sender
	bound_opponent = sender
	peer_id = sender
	peer_name = name
	handshake_done = true
	opponent_present = true
	_last_ping = now
	_last_welcome = now
	_send({"kind": "welcome", "name": _local_name(), "rejoin": rejoin})
	_reserve_seat(false)
	_set_status("opponent_connected", "Connected to %s." % name, {"name": _display_name()})
	# The controller answers with a fresh snapshot (new match or resume).
	opponent_ready.emit(rejoin)
	connection_changed.emit(connection_info())

## Host: turns a lobby member away (one reject message), ignores everything
## else it sends and closes its session once the reject is on its way.
func _refuse(sender: int, reject: Dictionary) -> void:
	if _refused.has(sender):
		return
	_send(reject, false, sender)
	_refused[sender] = int(clock.call()) + REFUSE_CLOSE_MS

## Host: while the guest is away (reserved = true) the lobby shows
## "reconnecting" and has one spare slot so the guest can always get back in.
func _reserve_seat(reserved: bool) -> void:
	if lobby_id == 0:
		return
	steam.call("setLobbyData", lobby_id, "status", "reconnecting" if reserved else "playing")
	if steam.has_method("setLobbyMemberLimit"):
		steam.call("setLobbyMemberLimit", lobby_id, LOBBY_MEMBERS_RESERVED if reserved else LOBBY_MEMBERS)

func _tick(now: int) -> void:
	for refused_id in _refused:
		if _refused[refused_id] != 0 and now >= _refused[refused_id]:
			steam.call("closeSessionWithUser", refused_id)
			_refused[refused_id] = 0
	if peer_id == 0:
		return
	if not is_host and not handshake_done:
		if now - _last_hello >= HELLO_RETRY_MS:
			_send_hello()
		return
	if not handshake_done:
		return
	if now - _last_ping >= HEARTBEAT_MS:
		_last_ping = now
		_send({"kind": "ping", "t": now}, false)
		_update_quality()
	if opponent_present and now - _last_heard > TIMEOUT_MS:
		if is_host:
			_lose_opponent("timeout")
		else:
			opponent_present = false
			_set_status("host_timeout", "No reply from the host. Waiting…", {"seconds": TIMEOUT_MS / 1000})
			opponent_lost.emit("timeout")
			connection_changed.emit(connection_info())

## Reads ping and link quality from Steam, but only for a connected session
## (otherwise the status fields are not filled in).
func _update_quality() -> void:
	if peer_id != 0 and opponent_present and steam.has_method("getSessionConnectionInfo"):
		var info = steam.call("getSessionConnectionInfo", peer_id, false, true)
		if info is Dictionary and int(info.get("connection_state", 0)) == CONNECTION_CONNECTED:
			quality = clampf(float(info.get("local_quality", -1.0)), -1.0, 1.0)
			if ping_ms < 0 and int(info.get("ping", -1)) >= 0:
				ping_ms = int(info.get("ping", -1))
		else:
			quality = -1.0
	connection_changed.emit(connection_info())

func _lose_opponent(reason: String) -> void:
	opponent_present = false
	if peer_id != 0:
		steam.call("closeSessionWithUser", peer_id)
	_reserve_seat(true)
	var code = {"left": "opponent_left", "disconnected": "opponent_disconnected"}.get(reason, "opponent_timeout")
	_set_status(code, "%s is disconnected. Waiting for them to rejoin…" % peer_name,
		{"name": _display_name(), "seconds": TIMEOUT_MS / 1000})
	opponent_lost.emit(reason)
	connection_changed.emit(connection_info())

func _end_session(code: String, args: Dictionary = {}) -> void:
	leave_lobby()
	_set_status(code, "The online session has ended (%s)." % code, args)
	session_ended.emit(code)

# --- Membership and names ---------------------------------------------------------

func _is_member(steam_id: int) -> bool:
	if lobby_id == 0 or steam_id == 0 or not available:
		return false
	for index in range(int(steam.call("getNumLobbyMembers", lobby_id))):
		if int(steam.call("getLobbyMemberByIndex", lobby_id, index)) == steam_id:
			return true
	return false

func _local_name() -> String:
	return str(steam.call("getPersonaName")) if available else ""

## The name Steam knows for `steam_id` (persona names of lobby members are
## always available); the self-reported `claimed` name only as a fallback.
## Either way cleaned and clamped for display.
func _trusted_name(steam_id: int, claimed: String) -> String:
	if steam_id != 0 and available and steam.has_method("getFriendPersonaName"):
		var known = clean_name(str(steam.call("getFriendPersonaName", steam_id)))
		if not known.is_empty():
			return known
	return clean_name(claimed)

## The opponent's Steam name (falls back to the friend list, then to an id tail).
func _display_name() -> String:
	if not peer_name.is_empty():
		return peer_name
	if peer_id != 0 and available and steam.has_method("getFriendPersonaName"):
		var name = str(steam.call("getFriendPersonaName", peer_id))
		if not name.is_empty():
			return name
	return "#%d" % (peer_id % 100000) if peer_id != 0 else "?"

func _set_presence() -> void:
	if not steam.has_method("setRichPresence"):
		return
	# "connect" lets friends join from the Steam friends list; the
	# steam_display token must exist in the app's rich presence file (Spacewar
	# defines #Status_WaitingForMatch).
	steam.call("setRichPresence", "connect", "+connect_lobby %d" % lobby_id)
	steam.call("setRichPresence", "status", "Three Kingdoms: Three Lanes")
	steam.call("setRichPresence", "steam_display", "#Status_WaitingForMatch")
	steam.call("setRichPresence", "steam_player_group", str(lobby_id))
	steam.call("setRichPresence", "steam_player_group_size", "2")

func _valid_view(view: Dictionary) -> bool:
	# Basic envelope validation; the host is trusted for game state. Guest
	# commands still go through the engine's complete legality validation.
	return view.get("lanes") is Array and view.lanes.size() == 3 and view.get("players") is Array and view.players.size() == 2 and view.get("events") is Array and view.has("phase") and view.has("revision") and view.has("round") and view.has("lane") and view.has("active_player") and view.has("winner")

func _set_status(code: String, message: String, args: Dictionary = {}) -> void:
	status_code = code
	status_args = args
	status = message
	status_changed.emit(message)

func _exit_tree() -> void:
	leave_lobby()
