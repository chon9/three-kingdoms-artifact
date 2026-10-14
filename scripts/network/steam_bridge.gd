extends Node
## Optional GodotSteam adapter. Standard Godot must boot without this extension.
## The host owns the rules; guests receive only their own redacted observation.

signal status_changed(message: String)
signal match_received(view: Dictionary, actions: Array)
signal command_received(command: Dictionary, revision: int)

const APP_ID = 480
const GAME_TAG = "classic_revival_classic_v4"
const PROTOCOL = 4
const CHANNEL = 71
const RELIABLE = 8
const MAX_PACKET_BYTES = 262144
var steam: Object
var available = false
var is_host = false
var lobby_id: int = 0
var peer_id: int = 0
var local_id: int = 0
var bound_opponent: int = 0
var status = "GodotSteam is not installed. Offline AI and local play are available."
var cached_match: Dictionary = {}

func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	var required = ["steamInitEx", "run_callbacks", "getSteamID", "createLobby", "joinLobby",
		"sendMessageToUser", "receiveMessagesOnChannel", "acceptSessionWithUser"]
	for method in required:
		if not steam.has_method(method):
			_set_status("This GodotSteam build is missing %s. See docs/STEAM.md." % method)
			return
	# Current GodotSteam signature is app_id first, embed_callbacks second.
	# We run callbacks explicitly in _process.
	var result = steam.call("steamInitEx", APP_ID, false)
	if int(result.get("status", -1)) != 0:
		_set_status("Steam could not initialize: " + str(result.get("verbal", "Start Steam and try again.")))
		return
	available = true
	local_id = int(steam.call("getSteamID"))
	steam.connect("lobby_created", _lobby_created)
	steam.connect("lobby_joined", _lobby_joined)
	steam.connect("lobby_chat_update", _lobby_changed)
	steam.connect("network_messages_session_request", _session_requested)
	_set_status("Steam connected. Development App ID 480. Create or join a two-player lobby.")

func _process(_delta: float) -> void:
	if not available:
		return
	steam.call("run_callbacks")
	if lobby_id == 0:
		return
	var messages = steam.call("receiveMessagesOnChannel", CHANNEL, 16)
	for message in messages:
		var bytes = message.get("payload", PackedByteArray())
		if not bytes is PackedByteArray or bytes.size() > MAX_PACKET_BYTES:
			continue
		var decoded = JSON.parse_string(bytes.get_string_from_utf8())
		if decoded is Dictionary:
			_handle_packet(int(message.get("identity", 0)), decoded)

func host_lobby() -> void:
	if available:
		leave_lobby()
		is_host = true
		steam.call("createLobby", 1, 2) # Friends-only, two members.
		_set_status("Creating a friends-only lobby…")

func join_lobby(id_text: String) -> void:
	if not available:
		return
	if not id_text.is_valid_int() or int(id_text) <= 0:
		_set_status("Enter a valid numeric Steam lobby ID.")
		return
	leave_lobby()
	is_host = false
	steam.call("joinLobby", int(id_text))
	_set_status("Joining lobby…")

func invite_friends() -> void:
	if available and lobby_id != 0:
		steam.call("activateGameOverlayInviteDialog", lobby_id)

func leave_lobby() -> void:
	if available and lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
	if available and peer_id != 0:
		steam.call("closeSessionWithUser", peer_id)
	lobby_id = 0
	peer_id = 0
	bound_opponent = 0
	cached_match.clear()
	is_host = false

func send_match(view: Dictionary, actions: Array) -> void:
	if not is_host:
		return
	cached_match = {"kind": "state", "view": view, "actions": actions}
	_send(cached_match)

func send_command(command: Dictionary, revision: int) -> void:
	if not is_host and peer_id != 0:
		_send({"kind": "command", "command": command, "revision": revision})

func _send(packet: Dictionary) -> void:
	if not available or peer_id == 0:
		return
	var envelope = packet.duplicate(true)
	envelope["protocol"] = PROTOCOL
	envelope["game"] = GAME_TAG
	var bytes = JSON.stringify(envelope).to_utf8_buffer()
	if bytes.size() > MAX_PACKET_BYTES:
		_set_status("Match snapshot is too large for the development transport.")
		return
	var result = int(steam.call("sendMessageToUser", peer_id, bytes, RELIABLE, CHANNEL))
	if result != 1:
		_set_status("Steam send failed (%d). Check that your opponent is connected." % result)

func _lobby_created(result: int, created_id: int) -> void:
	if result != 1:
		_set_status("Steam lobby creation failed (%d)." % result)
		return
	lobby_id = created_id
	is_host = true
	steam.call("setLobbyData", lobby_id, "game", GAME_TAG)
	steam.call("setLobbyData", lobby_id, "protocol", str(PROTOCOL))
	_set_status("Lobby %d created. Share its ID with a friend." % lobby_id)

func _lobby_joined(joined_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		_set_status("Steam lobby join failed (%d)." % response)
		return
	lobby_id = joined_id
	if not is_host:
		if steam.call("getLobbyData", lobby_id, "game") != GAME_TAG or steam.call("getLobbyData", lobby_id, "protocol") != str(PROTOCOL):
			leave_lobby()
			_set_status("This lobby belongs to another game or incompatible version.")
			return
	_refresh_peer()

func _lobby_changed(changed_lobby: int, _changed_id: int, _actor_id: int, _chat_state: int) -> void:
	if changed_lobby == lobby_id:
		_refresh_peer()

func _refresh_peer() -> void:
	peer_id = 0
	for index in range(int(steam.call("getNumLobbyMembers", lobby_id))):
		var member = int(steam.call("getLobbyMemberByIndex", lobby_id, index))
		if member != local_id:
			if bound_opponent != 0 and bound_opponent != member:
				_set_status("This match is reserved for the original opponent. Create a new lobby for another player.")
				return
			peer_id = member
			bound_opponent = member
	if peer_id == 0:
		_set_status("Lobby %d: waiting for your opponent." % lobby_id)
		return
	if not is_host and int(steam.call("getLobbyOwner", lobby_id)) != peer_id:
		_set_status("The original host is unavailable. Host migration is not supported yet.")
		return
	_set_status("Lobby %d: opponent connected." % lobby_id)
	if is_host:
		_send(cached_match)
	else:
		_send({"kind": "hello"})

func _is_member(steam_id: int) -> bool:
	if lobby_id == 0 or steam_id == 0:
		return false
	for index in range(int(steam.call("getNumLobbyMembers", lobby_id))):
		if int(steam.call("getLobbyMemberByIndex", lobby_id, index)) == steam_id:
			return true
	return false

func _session_requested(remote_id: int) -> void:
	if remote_id == peer_id and _is_member(remote_id):
		steam.call("acceptSessionWithUser", remote_id)

func _handle_packet(sender: int, packet: Dictionary) -> void:
	if sender != peer_id or not _is_member(sender):
		return
	if packet.get("protocol") != PROTOCOL or packet.get("game") != GAME_TAG:
		return
	match packet.get("kind", ""):
		"hello":
			if is_host and not cached_match.is_empty():
				_send(cached_match)
		"command":
			var revision = packet.get("revision")
			if is_host and packet.get("command") is Dictionary and (revision is float or revision is int):
				command_received.emit(packet.command, int(packet.revision))
		"state":
			if not is_host and packet.get("view") is Dictionary and packet.get("actions") is Array:
				var view = packet.view
				if _valid_view(view):
					match_received.emit(view, packet.actions)

func _valid_view(view: Dictionary) -> bool:
	# Basic envelope validation; the host is trusted for game state. Guest
	# commands still go through the engine's complete legality validation.
	return view.get("lanes") is Array and view.lanes.size() == 3 and view.get("players") is Array and view.players.size() == 2 and view.get("events") is Array and view.has("phase") and view.has("revision") and view.has("round") and view.has("lane") and view.has("active_player") and view.has("winner")

func _set_status(message: String) -> void:
	status = message
	status_changed.emit(message)

func _exit_tree() -> void:
	leave_lobby()
