extends SceneTree
## Steam boundary tests without a Steam client. FakeSteam implements exactly
## the GodotSteam 4.23 methods and signals that scripts/network/steam_bridge.gd
## uses (same names, argument order and types; when the real extension is
## loaded the names, argument counts and enum values are cross-checked against
## ClassDB). FakeHub routes lobbies, lobby callbacks and Networking Messages
## between fake clients, so two real MatchControllers play an online match
## in-process: handshake, commands, disconnects, rejoin, concede.

const Bridge = preload("res://scripts/network/steam_bridge.gd")
const Controller = preload("res://scripts/game/match_controller.gd")
const MatchEngine = preload("res://scripts/core/match_engine.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const Settings = preload("res://scripts/core/game_settings.gd")
const HOST_ID = 76561198000000101
const GUEST_ID = 76561198000000202
const STRANGER_ID = 76561198000000303
var checks = 0
var failures: Array = []
var time = {"ms": 1000}
var nodes: Array = []
var hubs: Array = []

class FakeHub extends RefCounted:
	var clients: Dictionary = {}
	## id -> {"owner", "members", "data", "type", "max"}
	var lobbies: Dictionary = {}
	# Above 2^53: lobby ids must never travel through JSON numbers.
	var next_lobby: int = 109775241000000001
	var hold_chat_updates = false
	var held: Array = []
	var ignore_filters = false

	func add(id: int, persona: String) -> FakeSteam:
		var client = FakeSteam.new()
		client.hub = self
		client.id = id
		client.persona = persona
		clients[id] = client
		return client

	func create(owner: FakeSteam, lobby_type: int, max_members: int) -> void:
		var lobby = next_lobby
		next_lobby += 1
		lobbies[lobby] = {"owner": owner.id, "members": [owner.id], "data": {}, "type": lobby_type, "max": max_members}
		owner.queue("lobby_created", [1, lobby])
		owner.queue("lobby_joined", [lobby, 0, false, 1])

	func join(client: FakeSteam, lobby: int) -> void:
		if not lobbies.has(lobby):
			client.queue("lobby_joined", [lobby, 0, false, 2]) # DoesntExist
			return
		var entry = lobbies[lobby]
		if entry.members.size() >= entry.max:
			client.queue("lobby_joined", [lobby, 0, false, 4]) # Full
			return
		entry.members.append(client.id)
		client.queue("lobby_joined", [lobby, 0, false, 1])
		_notify(lobby, client.id, 1)

	func leave(client_id: int, lobby: int, state: int) -> void:
		if not lobbies.has(lobby) or client_id not in lobbies[lobby].members:
			return
		var entry = lobbies[lobby]
		entry.members.erase(client_id)
		if entry.members.is_empty():
			lobbies.erase(lobby)
			return
		if entry.owner == client_id:
			entry.owner = entry.members[0]
		_notify(lobby, client_id, state)

	## Simulates a crash: the client vanishes from its lobbies (state 4).
	func crash(client_id: int) -> void:
		for lobby in lobbies.keys():
			leave(client_id, lobby, 4)
		clients.erase(client_id)

	func _notify(lobby: int, changed: int, state: int) -> void:
		for member in lobbies[lobby].members:
			if member != changed and clients.has(member):
				if hold_chat_updates:
					held.append([clients[member], [lobby, changed, changed, state]])
				else:
					clients[member].queue("lobby_chat_update", [lobby, changed, changed, state])

	func release_chat_updates() -> void:
		for entry in held:
			entry[0].queue("lobby_chat_update", entry[1])
		held.clear()

	func deliver(from: FakeSteam, to_id: int, data: PackedByteArray, channel: int) -> void:
		if not clients.has(to_id):
			return
		var target: FakeSteam = clients[to_id]
		target.inbox.append({"payload": data, "identity": from.id, "channel": channel})
		if not target.sessions.has(from.id) and not target.requested.has(from.id):
			target.requested[from.id] = true
			target.queue("network_messages_session_request", [from.id])

	func search(client: FakeSteam) -> void:
		var found: Array = []
		for lobby in lobbies:
			var entry = lobbies[lobby]
			if entry.type != 2 or entry.members.size() >= entry.max:
				continue
			var matches = true
			for item in client.filters:
				if item[0] == "string" and entry.data.get(item[1], "") != item[2]:
					matches = false
			if matches or ignore_filters:
				found.append(lobby)
		client.last_filters = client.filters.duplicate()
		client.filters.clear()
		client.queue("lobby_match_list", [found])

class FakeSteam extends RefCounted:
	signal lobby_created(connect: int, lobby_id: int)
	signal lobby_joined(lobby: int, permissions: int, locked: bool, response: int)
	signal lobby_chat_update(lobby_id: int, changed_id: int, making_change_id: int, chat_state: int)
	signal lobby_match_list(lobbies: Array)
	signal join_requested(lobby_id: int, steam_id: int)
	signal network_messages_session_request(remote_steam_id: int)
	signal network_messages_session_failed(reason: int, remote_steam_id: int, connection_state: int, debug_message: String)
	signal steam_shutdown
	signal join_game_requested(user: int, connect: String)
	signal lobby_kicked(lobby_id: int, admin_id: int, due_to_disconnect: int)
	signal steam_server_disconnected(result: int)

	var hub: FakeHub
	var id: int = 0
	var persona: String = ""
	var init_status: int = 0
	var launch_line: String = ""
	var pending: Array = []
	var inbox: Array = []
	var sessions: Dictionary = {}
	var requested: Dictionary = {}
	var sent: Array = []
	var filters: Array = []
	var last_filters: Array = []
	var presence: Dictionary = {}
	var created_types: Array = []
	var invites: int = 0
	## ESteamNetworkingConnectionState reported for sessions (3 = connected).
	var session_state: int = 3

	func queue(signal_name: String, args: Array) -> void:
		pending.append([signal_name, args])

	func steamInitEx(_app_id: int = 0, _embed_callbacks: bool = false) -> Dictionary:
		return {"status": init_status, "verbal": "" if init_status == 0 else "Steam is not running."}
	func run_callbacks() -> void:
		var batch = pending
		pending = []
		for entry in batch:
			callv("emit_signal", [entry[0]] + entry[1])
	func get_godotsteam_version() -> String:
		return "4.23.1"
	func getSteamID() -> int:
		return id
	func getPersonaName() -> String:
		return persona
	func getFriendPersonaName(steam_id: int) -> String:
		return hub.clients[steam_id].persona if hub.clients.has(steam_id) else ""
	func getLaunchCommandLine() -> String:
		return launch_line
	func createLobby(lobby_type: int, max_members: int = 2) -> void:
		created_types.append(lobby_type)
		hub.create(self, lobby_type, max_members)
	func joinLobby(steam_lobby_id: int) -> void:
		hub.join(self, steam_lobby_id)
	func leaveLobby(steam_lobby_id: int) -> void:
		hub.leave(id, steam_lobby_id, 2)
	func setLobbyData(steam_lobby_id: int, key: String, value: String) -> bool:
		if not hub.lobbies.has(steam_lobby_id) or hub.lobbies[steam_lobby_id].owner != id:
			return false
		hub.lobbies[steam_lobby_id].data[key] = value
		return true
	func getLobbyData(steam_lobby_id: int, key: String) -> String:
		return str(hub.lobbies[steam_lobby_id].data.get(key, "")) if hub.lobbies.has(steam_lobby_id) else ""
	func getLobbyOwner(steam_lobby_id: int) -> int:
		return int(hub.lobbies[steam_lobby_id].owner) if hub.lobbies.has(steam_lobby_id) else 0
	func getNumLobbyMembers(steam_lobby_id: int) -> int:
		return hub.lobbies[steam_lobby_id].members.size() if hub.lobbies.has(steam_lobby_id) else 0
	func getLobbyMemberByIndex(steam_lobby_id: int, member: int) -> int:
		var members: Array = hub.lobbies[steam_lobby_id].members if hub.lobbies.has(steam_lobby_id) else []
		return int(members[member]) if member < members.size() else 0
	func activateGameOverlayInviteDialog(_lobby_id: int) -> void:
		invites += 1
	func requestLobbyList() -> void:
		hub.search(self)
	func addRequestLobbyListStringFilter(key_to_match: String, value_to_match: String, comparison_type: int) -> void:
		filters.append(["string", key_to_match, value_to_match, comparison_type])
	func addRequestLobbyListDistanceFilter(distance_filter: int) -> void:
		filters.append(["distance", distance_filter])
	func addRequestLobbyListFilterSlotsAvailable(slots_available: int) -> void:
		filters.append(["slots", slots_available])
	func addRequestLobbyListResultCountFilter(max_results: int) -> void:
		filters.append(["count", max_results])
	func setRichPresence(key: String, value: String) -> bool:
		presence[key] = value
		return true
	func clearRichPresence() -> void:
		presence.clear()
	func sendMessageToUser(remote_steam_id: int, data: PackedByteArray, flags: int, channel: int) -> int:
		sent.append({"remote": remote_steam_id, "data": data, "flags": flags, "channel": channel})
		sessions[remote_steam_id] = true # Sending opens our side of the session.
		hub.deliver(self, remote_steam_id, data, channel)
		return 1
	func receiveMessagesOnChannel(channel: int, max_messages: int) -> Array:
		var result: Array = []
		var keep: Array = []
		for message in inbox:
			if result.size() < max_messages and message.channel == channel and sessions.has(message.identity):
				result.append(message)
			else:
				keep.append(message)
		inbox = keep
		return result
	func acceptSessionWithUser(remote_steam_id: int) -> bool:
		sessions[remote_steam_id] = true
		return true
	func closeSessionWithUser(remote_steam_id: int) -> bool:
		sessions.erase(remote_steam_id)
		requested.erase(remote_steam_id)
		return true
	func getSessionConnectionInfo(_remote_steam_id: int, _get_connection: bool, _get_status: bool) -> Dictionary:
		# Like GodotSteam: the status fields are present (garbage) without a session.
		if session_state != 3:
			return {"connection_state": session_state, "ping": -7, "local_quality": 123.0, "remote_quality": 5.0}
		return {"connection_state": 3, "ping": 42, "local_quality": 1.0, "remote_quality": 1.0}
	func setLobbyMemberLimit(steam_lobby_id: int, max_members: int) -> bool:
		if not hub.lobbies.has(steam_lobby_id) or hub.lobbies[steam_lobby_id].owner != id:
			return false
		hub.lobbies[steam_lobby_id].max = max_members
		return true

	## Decoded packets this client sent to `remote` (all of them when 0).
	func packets_to(remote: int = 0) -> Array:
		var result: Array = []
		for entry in sent:
			if remote == 0 or entry.remote == remote:
				result.append(JSON.parse_string(entry.data.get_string_from_utf8()))
		return result

func _initialize() -> void:
	_run()

func _run() -> void:
	# Let the root enter the tree so added controllers get _ready().
	await process_frame
	Settings.set_locale("en", false)
	_test_helpers()
	_test_api_matches_godotsteam()
	_test_init_failures()
	_test_lobby_creation()
	_test_lobby_list()
	_test_command_line_join()
	_test_session_race_and_messages()
	_test_handshake_mismatch()
	_test_concede_engine()
	_test_online_match()
	_test_steam_events()
	_test_review_fixes()
	for node in nodes:
		if is_instance_valid(node):
			node.free()
	for hub in hubs:
		for client in hub.clients.values():
			client.hub = null
		hub.clients.clear()
	if failures.is_empty():
		print("PASS: %d Steam checks (fake GodotSteam 4.23 boundary: lobbies, browser, invites, launch join, handshake, race, normalization, heartbeat, disconnect/rejoin, seat binding, host leave, concede)." % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("%d failures in %d checks." % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _hub() -> FakeHub:
	var hub = FakeHub.new()
	hubs.append(hub)
	return hub

func _bridge(steam: FakeSteam, launch_args: Array = []) -> Node:
	var bridge = Bridge.new()
	nodes.append(bridge)
	bridge.clock = func() -> int: return int(time.ms)
	bridge.attach(steam, launch_args)
	return bridge

func _controller(steam: FakeSteam) -> Node:
	var controller = Controller.new()
	root.add_child(controller)
	nodes.append(controller)
	controller.claim_grace = 0.0
	controller.steam_bridge.clock = func() -> int: return int(time.ms)
	controller.steam_bridge.attach(steam)
	return controller

## Polls every bridge `rounds` times, advancing the fake clock 20 ms per round.
func _pump(bridges: Array, rounds: int = 6) -> void:
	for _round in range(rounds):
		time.ms += 20
		for bridge in bridges:
			if is_instance_valid(bridge):
				bridge.poll()

func _is_whole_float_free(value) -> bool:
	match typeof(value):
		TYPE_FLOAT:
			return value != floorf(value)
		TYPE_ARRAY:
			for item in value:
				if not _is_whole_float_free(item):
					return false
		TYPE_DICTIONARY:
			for key in value:
				if not _is_whole_float_free(value[key]):
					return false
	return true

# --- Pure helpers ------------------------------------------------------------------

func _test_helpers() -> void:
	_check(Bridge.parse_lobby_id("109775241000000001") == 109775241000000001, "Lobby id parses from digits without precision loss")
	_check(Bridge.parse_lobby_id("  +connect_lobby 109775241000000001 ") == 109775241000000001, "Lobby id parses from a +connect_lobby link")
	_check(Bridge.parse_lobby_id("steam://joinlobby/480/109775241000000001/76561198000000101") == 109775241000000001, "Lobby id parses from a steam://joinlobby link")
	_check(Bridge.parse_lobby_id("hello") == 0 and Bridge.parse_lobby_id("-5") == 0 and Bridge.parse_lobby_id("") == 0, "Invalid lobby text gives 0")
	_check(Bridge.lobby_from_args(["--path", ".", "+connect_lobby", "109775241000000002"]) == 109775241000000002, "Launch arguments name the lobby")
	_check(Bridge.lobby_from_args(["--path", "."]) == 0 and Bridge.lobby_from_args(["+connect_lobby"]) == 0 and Bridge.lobby_from_args(["+connect_lobby", "x"]) == 0, "Launch arguments without a lobby give 0")
	var normalized = Bridge.normalize_numbers({"a": 1.0, "b": [2.0, 2.5, "3", -4.0], "c": {"d": 0.0, "e": true, "f": null}, "big": 1.0e17})
	_check(typeof(normalized.a) == TYPE_INT and normalized.a == 1, "Whole floats become ints")
	_check(typeof(normalized.b[0]) == TYPE_INT and typeof(normalized.b[1]) == TYPE_FLOAT and typeof(normalized.b[2]) == TYPE_STRING and normalized.b[3] == -4 and typeof(normalized.b[3]) == TYPE_INT, "Arrays normalize element by element; fractions and strings stay")
	_check(typeof(normalized.c.d) == TYPE_INT and normalized.c.e == true and normalized.c.f == null, "Nested dictionaries normalize; bools and null stay")
	_check(typeof(normalized.big) == TYPE_FLOAT, "Floats beyond 2^53 stay floats (no silent precision loss)")
	var engine = MatchEngine.new()
	engine.start(31, ["starter", "green_assault"])
	var view = engine.player_view(1)
	var decoded = JSON.parse_string(JSON.stringify(view))
	_check(not _is_whole_float_free(decoded), "JSON really turns view integers into floats")
	var restored = Bridge.normalize_numbers(decoded)
	_check(_is_whole_float_free(restored) and var_to_str(restored) == var_to_str(view), "A normalized network view is identical to the local view, types included")
	var actions = Bridge.normalize_numbers(JSON.parse_string(JSON.stringify(engine.legal_actions(int(engine.state.active_player)))))
	var legal = engine.legal_actions(int(engine.state.active_player))
	_check(actions == legal and var_to_str(actions) == var_to_str(legal), "Normalized actions compare equal to legal actions")
	# Content hash: stable, protocol-sensitive and line-ending independent.
	var lf = "user://steam_test_lf.json"
	var crlf = "user://steam_test_crlf.json"
	FileAccess.open(lf, FileAccess.WRITE).store_string("{\n\"a\": 1\n}\n")
	FileAccess.open(crlf, FileAccess.WRITE).store_string("{\r\n\"a\": 1\r\n}\r\n")
	_check(Bridge.compute_content_hash([lf]) == Bridge.compute_content_hash([crlf]), "Content hash ignores CRLF vs LF checkouts")
	_check(Bridge.compute_content_hash([lf], 6) != Bridge.compute_content_hash([lf], 7), "Content hash changes with the protocol")
	_check(Bridge.compute_content_hash() == Bridge.compute_content_hash() and Bridge.compute_content_hash().length() == 16, "Content hash of the card data is stable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lf))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(crlf))

## With the real extension loaded, the fake and the bridge constants must match it.
func _test_api_matches_godotsteam() -> void:
	if not ClassDB.class_exists("Steam"):
		print("NOTE: GodotSteam is not loaded; skipping the ClassDB cross-check.")
		return
	var real_methods: Dictionary = {}
	for info in ClassDB.class_get_method_list("Steam", true):
		real_methods[info.name] = info.args.size()
	var real_signals: Dictionary = {}
	for info in ClassDB.class_get_signal_list("Steam", true):
		real_signals[info.name] = info.args.size()
	var fake = FakeSteam.new()
	var helper_methods = ["queue", "packets_to"]
	for info in fake.get_script().get_script_method_list():
		if info.name in helper_methods:
			continue
		_check(real_methods.has(info.name), "GodotSteam has method " + info.name)
		_check(real_methods.get(info.name, -1) == info.args.size(), "%s takes %d arguments in GodotSteam" % [info.name, info.args.size()])
	for info in fake.get_script().get_script_signal_list():
		_check(real_signals.get(info.name, -1) == info.args.size(), "GodotSteam signal %s has %d arguments" % [info.name, info.args.size()])
	for method in Bridge.REQUIRED:
		_check(real_methods.has(method), "Required method %s exists" % method)
	for signal_name in Bridge.SIGNALS:
		_check(real_signals.has(signal_name), "Connected signal %s exists" % signal_name)
	var constants = {"NETWORKING_SEND_RELIABLE": Bridge.SEND_RELIABLE,
		"NETWORKING_SEND_AUTORESTART_BROKEN_SESSION": Bridge.SEND_AUTO_RESTART_BROKEN_SESSION,
		"LOBBY_TYPE_FRIENDS_ONLY": Bridge.LOBBY_FRIENDS_ONLY, "LOBBY_TYPE_PUBLIC": Bridge.LOBBY_PUBLIC,
		"LOBBY_COMPARISON_EQUAL": Bridge.LOBBY_COMPARISON_EQUAL, "LOBBY_DISTANCE_FILTER_WORLDWIDE": Bridge.LOBBY_DISTANCE_WORLDWIDE,
		"CHAT_MEMBER_STATE_CHANGE_ENTERED": Bridge.CHAT_ENTERED, "CHAT_MEMBER_STATE_CHANGE_LEFT": Bridge.CHAT_LEFT,
		"CHAT_MEMBER_STATE_CHANGE_DISCONNECTED": Bridge.CHAT_DISCONNECTED, "CHAT_MEMBER_STATE_CHANGE_KICKED": Bridge.CHAT_KICKED,
		"CHAT_MEMBER_STATE_CHANGE_BANNED": Bridge.CHAT_BANNED, "CHAT_ROOM_ENTER_RESPONSE_SUCCESS": Bridge.RESULT_OK, "RESULT_OK": Bridge.RESULT_OK}
	for constant in constants:
		_check(ClassDB.class_has_integer_constant("Steam", constant) and ClassDB.class_get_integer_constant("Steam", constant) == constants[constant],
			"Bridge value for %s matches GodotSteam" % constant)

func _test_init_failures() -> void:
	var hub = _hub()
	var offline = hub.add(HOST_ID, "Offline")
	offline.init_status = 2
	var bridge = _bridge(offline)
	_check(not bridge.available and bridge.status_code == "init_no_client", "Steam init failure stays graceful and explains why")
	Settings.set_locale("zh_CN", false)
	var chinese = EventText.steam_status(bridge.status_code, bridge.status_args)
	_check(chinese.find("Steam is not running") == -1 and chinese.find("Steam") != -1 and chinese.find("登录") != -1, "No Steam client: the reason is localized, not Steam's English text (%s)" % chinese)
	Settings.set_locale("en", false)
	for spec in [[3, "init_version"], [1, "init_failed"]]:
		var other = hub.add(HOST_ID + spec[0] + 50, "Other")
		other.init_status = spec[0]
		var failed = _bridge(other)
		_check(not failed.available and failed.status_code == spec[1] and EventText.steam_status(failed.status_code, failed.status_args).find("{") == -1,
			"Init status %d is reported as %s with a filled message" % spec)
	bridge.host_lobby()
	bridge.join_lobby("123")
	_check(bridge.lobby_id == 0 and offline.created_types.is_empty(), "Lobby calls do nothing while Steam is unavailable")
	var incomplete = Bridge.new()
	nodes.append(incomplete)
	incomplete.attach(RefCounted.new())
	_check(not incomplete.available and incomplete.status_code == "missing_method", "A build without the required methods is reported")
	var headless = Bridge.new()
	root.add_child(headless)
	nodes.append(headless)
	_check(headless.status_code == "disabled" and not headless.available, "Headless runs never start the Steam client")
	_check(EventText.steam_status("disabled") != "STEAM_DISABLED", "The disabled status is translated")

# --- Lobbies -----------------------------------------------------------------------

func _test_lobby_creation() -> void:
	var hub = _hub()
	var steam = hub.add(HOST_ID, "Liu Bei")
	var bridge = _bridge(steam)
	_check(bridge.available and bridge.godotsteam_version == "4.23.1", "Fake Steam initializes and reports its GodotSteam version")
	bridge.host_lobby(false)
	_pump([bridge])
	var lobby = bridge.lobby_id
	_check(lobby != 0 and bridge.is_host and steam.created_types == [Bridge.LOBBY_FRIENDS_ONLY], "Friends-only lobby is created with type 1")
	var data: Dictionary = hub.lobbies[lobby].data
	_check(data.game == Bridge.GAME_TAG and data.protocol == str(Bridge.PROTOCOL) and data.content == bridge.content_hash and data.host == "Liu Bei" and data.status == "waiting",
		"Lobby data carries game tag, protocol, content hash, host name and status")
	_check(steam.presence.get("connect") == "+connect_lobby %d" % lobby and steam.presence.has("steam_display"), "Rich presence connect string lets friends join")
	bridge.invite_friends()
	_check(steam.invites == 1, "Invite opens the Steam overlay invite dialog")
	bridge.host_lobby(true)
	_pump([bridge])
	_check(steam.created_types.back() == Bridge.LOBBY_PUBLIC and bridge.lobby_id != lobby and not hub.lobbies.has(lobby), "Hosting again leaves the old lobby and creates a public one")
	bridge.leave_lobby()
	_check(steam.presence.is_empty() and bridge.lobby_id == 0, "Leaving clears rich presence")

func _test_lobby_list() -> void:
	var hub = _hub()
	var searcher_steam = hub.add(GUEST_ID, "Cao Cao")
	var searcher = _bridge(searcher_steam)
	var hosts: Dictionary = {}
	for spec in [["Sun Quan", true, "waiting", ""], ["Old Build", true, "waiting", "0000000000000000"], ["Friends Only", false, "waiting", ""],
			["Lu Bu", true, "reconnecting", ""]]:
		var steam = hub.add(HOST_ID + hosts.size() + 10, spec[0])
		var bridge = _bridge(steam)
		bridge.host_lobby(spec[1])
		_pump([bridge])
		if not spec[3].is_empty():
			hub.lobbies[bridge.lobby_id].data.content = spec[3]
		hub.lobbies[bridge.lobby_id].data.status = spec[2]
		hosts[spec[0]] = bridge
	# A full public lobby and a public lobby of another game.
	var full = hub.add(HOST_ID + 30, "Full")
	var full_bridge = _bridge(full)
	full_bridge.host_lobby(true)
	_pump([full_bridge])
	hub.lobbies[full_bridge.lobby_id].members.append(STRANGER_ID)
	var foreign = hub.add(HOST_ID + 31, "Spacewar")
	foreign.createLobby(2, 4)
	foreign.run_callbacks()
	var foreign_lobby = hub.next_lobby - 1
	hub.lobbies[foreign_lobby].data = {"game": "spacewar"}
	var listed: Array = []
	searcher.lobbies_listed.connect(func(found): listed.append(found))
	_check(searcher.request_lobby_list(), "Lobby search starts")
	var filters = searcher_steam.last_filters
	_check(["string", "game", Bridge.GAME_TAG, Bridge.LOBBY_COMPARISON_EQUAL] in filters and ["distance", Bridge.LOBBY_DISTANCE_WORLDWIDE] in filters and ["slots", 1] in filters,
		"Search filters on the game tag, worldwide distance and a free slot")
	_pump([searcher])
	_check(listed.size() == 1, "Lobby list arrives once")
	var found: Array = listed[0] if not listed.is_empty() else []
	var names = found.map(func(entry): return entry.host)
	_check(names == ["Sun Quan", "Lu Bu", "Old Build"], "Public lobbies of this game only, compatible and waiting first: %s" % [names])
	_check(found.size() == 3 and found[0].compatible and found[1].compatible and not found[2].compatible and found[1].status == "reconnecting", "Incompatible builds are listed but marked")
	_check(searcher.status_code == "lobbies_found" and int(searcher.status_args.n) == 3, "Search reports the number found")
	# A lobby that slips past Steam's filter is still dropped by the bridge.
	hub.ignore_filters = true
	listed.clear()
	searcher.request_lobby_list()
	_pump([searcher])
	_check(not listed.is_empty() and not listed[0].any(func(entry): return int(entry.id) == foreign_lobby), "Lobbies of other games are dropped even if Steam returns them")
	hub.ignore_filters = false
	# Joining from the list: the guest binds to that host.
	var target = hosts["Sun Quan"]
	searcher.join_lobby_id(target.lobby_id)
	_pump([searcher, target], 10)
	_check(target.handshake_done and target.bound_opponent == GUEST_ID and searcher.handshake_done, "Joining from the lobby list completes the handshake")

func _test_command_line_join() -> void:
	var hub = _hub()
	var host = _bridge(hub.add(HOST_ID, "Liu Bei"))
	host.host_lobby()
	_pump([host])
	var guest_steam = hub.add(GUEST_ID, "Cao Cao")
	var guest = _bridge(guest_steam, ["--path", ".", "+connect_lobby", str(host.lobby_id)])
	var started: Array = []
	guest.join_started.connect(func(lobby): started.append(lobby))
	_check(guest.lobby_id == 0 and started.is_empty(), "The launch join waits for the first poll (so the UI is connected)")
	_pump([guest, host], 10)
	_check(started == [host.lobby_id] and guest.lobby_id == host.lobby_id and guest.handshake_done, "+connect_lobby on the command line joins that lobby")
	# Same through Steam's own launch command line.
	var hub2 = _hub()
	var host2 = _bridge(hub2.add(HOST_ID, "Liu Bei"))
	host2.host_lobby()
	_pump([host2])
	var launched = hub2.add(GUEST_ID, "Cao Cao")
	launched.launch_line = "+connect_lobby %d" % host2.lobby_id
	var guest2 = _bridge(launched)
	_pump([guest2, host2], 10)
	_check(guest2.lobby_id == host2.lobby_id and host2.handshake_done, "getLaunchCommandLine's +connect_lobby joins too")

# --- Messages ------------------------------------------------------------------------

func _test_session_race_and_messages() -> void:
	var hub = _hub()
	var host_steam = hub.add(HOST_ID, "Liu Bei")
	var guest_steam = hub.add(GUEST_ID, "Cao Cao")
	var host = _bridge(host_steam)
	var guest = _bridge(guest_steam)
	host.host_lobby()
	_pump([host])
	var ready: Array = []
	host.opponent_ready.connect(func(rejoin): ready.append(rejoin))
	# The guest's hello (and Steam's session request) arrive before the host
	# hears about the new member from lobby_chat_update.
	hub.hold_chat_updates = true
	guest.join_lobby(str(host.lobby_id))
	_pump([guest], 2)
	_pump([host], 2)
	_check(host_steam.sessions.has(GUEST_ID), "Host accepts a session request from a lobby member before the chat update")
	_check(ready == [false] and host.bound_opponent == GUEST_ID and host.handshake_done, "The first hello is not lost in the race")
	hub.release_chat_updates()
	_pump([host, guest], 4)
	_check(ready == [false] and host.peer_id == GUEST_ID, "The late chat update changes nothing")
	_check(guest.handshake_done and guest.status_code == "connected_to_host" and guest.status_args.name == "Liu Bei", "Guest shows the host's persona name")
	_check(host.status_code == "opponent_connected" and host.status_args.name == "Cao Cao", "Host shows the guest's persona name")
	var hello: Dictionary = guest_steam.packets_to(HOST_ID)[0]
	_check(hello.kind == "hello" and hello.content == guest.content_hash and hello.godotsteam == "4.23.1" and int(hello.protocol) == Bridge.PROTOCOL, "Hello carries protocol, content hash and GodotSteam version")
	var all_sent = host_steam.sent + guest_steam.sent
	_check(not all_sent.is_empty() and all_sent.all(func(entry): return entry.flags == 40 and entry.channel == Bridge.CHANNEL), "Every message is reliable with auto-restart (8|32) on channel 71")
	# A session request from someone outside the lobby is ignored.
	host_steam.queue("network_messages_session_request", [STRANGER_ID])
	_pump([host], 1)
	_check(not host_steam.sessions.has(STRANGER_ID), "Sessions from non-members are not accepted")
	# Commands: normalized, only from the bound opponent, with protocol checks.
	var commands: Array = []
	host.command_received.connect(func(command, revision): commands.append([command, revision]))
	guest.send_command({"type": "play", "hand": 2, "target": 17}, 5)
	_pump([host], 1)
	_check(commands.size() == 1 and typeof(commands[0][0].hand) == TYPE_INT and typeof(commands[0][0].target) == TYPE_INT and typeof(commands[0][1]) == TYPE_INT, "Received commands have integer fields")
	var envelope = {"protocol": Bridge.PROTOCOL, "game": Bridge.GAME_TAG, "kind": "command", "command": {"type": "pass"}, "revision": 0}
	host._handle_packet(STRANGER_ID, envelope)
	var stale = envelope.duplicate(true)
	stale.protocol = 5
	host._handle_packet(GUEST_ID, stale)
	_check(commands.size() == 1, "Packets from outsiders or other protocols are ignored")
	# Heartbeat: ping every 5 s, the pong measures the round trip.
	time.ms += Bridge.HEARTBEAT_MS
	_pump([host, guest], 3)
	_check(host_steam.packets_to(GUEST_ID).any(func(packet): return packet.kind == "ping") and guest_steam.packets_to(HOST_ID).any(func(packet): return packet.kind == "pong"), "Heartbeat pings are answered")
	var info = host.connection_info()
	_check(host.ping_ms >= 0 and host.ping_ms <= 100 and info.level == "good" and info.quality == 1.0, "Connection quality comes from ping and session status: %s" % [info])
	# Session failure is reported, then the next send restarts the session.
	host_steam.queue("network_messages_session_failed", [4, GUEST_ID, 5, "timeout"])
	_pump([host], 1)
	_check(host.status_code == "session_failed" and host.status_args.name == "Cao Cao", "Session failures are reported with the opponent's name")
	# The host stops hearing the guest: timeout, then recovery when it answers.
	var lost: Array = []
	host.opponent_lost.connect(func(reason): lost.append(reason))
	for _step in range(6):
		time.ms += Bridge.HEARTBEAT_MS
		_pump([host], 1)
	_check(lost == ["timeout"] and not host.opponent_present and host.connection_info().level == "lost", "Silence beyond the timeout marks the opponent lost")
	_check(hub.lobbies[host.lobby_id].data.status == "reconnecting", "The lobby shows it waits for a player")
	time.ms += Bridge.HEARTBEAT_MS
	_pump([host, guest], 4)
	_check(host.opponent_present and ready == [false, true] and host.status_code == "opponent_returned", "The opponent's answer resumes the session")
	# steam_shutdown ends the session cleanly.
	var ended: Array = []
	guest.session_ended.connect(func(code): ended.append(code))
	guest_steam.queue("steam_shutdown", [])
	_pump([guest], 1)
	_check(ended == ["steam_shutdown"] and not guest.available and guest.lobby_id == 0, "steam_shutdown leaves the lobby and ends online play")

func _test_handshake_mismatch() -> void:
	var hub = _hub()
	var host_steam = hub.add(HOST_ID, "Liu Bei")
	var host = _bridge(host_steam)
	host.host_lobby()
	_pump([host])
	# Host side: an old client in the lobby says hello with other content.
	var old = hub.add(STRANGER_ID, "Old Build")
	old.joinLobby(host.lobby_id)
	old.run_callbacks()
	var hello = {"protocol": Bridge.PROTOCOL, "game": Bridge.GAME_TAG, "kind": "hello", "content": "0123456789abcdef", "name": "Old Build"}
	old.sendMessageToUser(HOST_ID, JSON.stringify(hello).to_utf8_buffer(), 40, Bridge.CHANNEL)
	var ready: Array = []
	host.opponent_ready.connect(func(rejoin): ready.append(rejoin))
	_pump([host], 2)
	var replies = host_steam.packets_to(STRANGER_ID)
	_check(replies.size() == 1 and replies[0].kind == "reject" and replies[0].reason == "version_mismatch" and replies[0].host_content == host.content_hash, "Host rejects a hello with a different content hash")
	_check(ready.is_empty() and host.bound_opponent == 0 and host.status_code == "guest_version_mismatch" and host.status_args.name == "Old Build", "The mismatched guest takes no seat and the host is told who")
	old.sendMessageToUser(HOST_ID, JSON.stringify(hello).to_utf8_buffer(), 40, Bridge.CHANNEL)
	_pump([host], 2)
	_check(host_steam.packets_to(STRANGER_ID).size() == 1, "A refused client gets one reject, not one per hello")
	old.leaveLobby(host.lobby_id)
	var older = hub.add(STRANGER_ID + 1, "Older Build")
	older.joinLobby(host.lobby_id)
	older.run_callbacks()
	var old_protocol = hello.duplicate(true)
	old_protocol.protocol = 5
	old_protocol.content = host.content_hash
	older.sendMessageToUser(HOST_ID, JSON.stringify(old_protocol).to_utf8_buffer(), 40, Bridge.CHANNEL)
	_pump([host], 2)
	var older_replies = host_steam.packets_to(STRANGER_ID + 1)
	_check(older_replies.size() == 1 and older_replies[0].reason == "version_mismatch" and host.bound_opponent == 0, "Host rejects an older protocol too")
	older.leaveLobby(host.lobby_id)
	# Guest side: the lobby data already shows a different build.
	var guest_steam = hub.add(GUEST_ID, "Cao Cao")
	var guest = _bridge(guest_steam)
	guest.content_hash = "ffffffffffffffff"
	var ended: Array = []
	guest.session_ended.connect(func(code): ended.append(code))
	guest.join_lobby(str(host.lobby_id))
	_pump([guest, host], 4)
	_check(ended == ["version_mismatch"] and guest.lobby_id == 0 and GUEST_ID not in hub.lobbies[host.lobby_id].members, "Guest refuses a lobby of another build and leaves it")
	_check(guest.status_args.host_content == host.content_hash and guest.status_args.content == "ffffffffffffffff", "The mismatch message shows both versions")
	var text = EventText.steam_status(guest.status_code, guest.status_args)
	_check(text.find(host.content_hash) != -1 and text.find("{") == -1, "Version mismatch is a filled, localized message")
	Settings.set_locale("zh_CN", false)
	_check(EventText.steam_status(guest.status_code, guest.status_args).find("版本") != -1, "The mismatch message is translated")
	Settings.set_locale("en", false)

# --- Concede -------------------------------------------------------------------------

func _test_concede_engine() -> void:
	for phase_seed in [[0, 41], [1, 42]]:
		var engine = MatchEngine.new()
		engine.start(phase_seed[1], ["starter", "green_assault"])
		var player = phase_seed[0]
		_check(MatchEngine.CONCEDE not in engine.legal_actions(player), "Concede is not a turn action (bots and turn logic ignore it)")
		_check(engine.can_concede(player) and engine.can_concede(1 - player), "Both players may concede at any time")
		var result = engine.apply_action(player, {"type": "concede"})
		_check(result.ok and engine.state.winner == 1 - player and engine.state.phase == "finished", "Conceding player %d makes the opponent win" % player)
		var keys = engine.state.events.slice(-2).map(func(event): return event.k)
		_check(keys == ["concede", "win"] and int(engine.state.events[-2].p) == player, "Concede is logged before the result")
		_check(not engine.apply_action(1 - player, {"type": "concede"}).ok and engine.legal_actions(1 - player).is_empty(), "A finished match cannot be conceded again")
		var replay = MatchEngine.new()
		_check(replay.load_replay(JSON.parse_string(JSON.stringify(engine.replay_data()))).ok and replay.state_digest() == engine.state_digest(), "A conceded match replays to the same state")
	# Mid-match, out of turn and in the shop.
	var engine = MatchEngine.new()
	engine.start(43, ["starter", "green_assault"])
	var waiting = 1 - int(engine.state.active_player)
	_check(engine.apply_action(waiting, {"type": "concede"}).ok, "The player who is not acting may concede")
	var shop = MatchEngine.new()
	shop.start(44, ["starter", "green_assault"])
	var guard = 0
	while shop.state.phase == "action" and guard < 50:
		shop.apply_action(int(shop.state.active_player), {"type": "pass"})
		guard += 1
	_check(shop.state.phase == "shop" and shop.apply_action(1, {"type": "concede"}).ok and shop.state.winner == 0, "Concede works in the shop phase")
	var fresh = MatchEngine.new()
	fresh.start(45, ["starter", "green_assault"])
	_check(not fresh.apply_action(0, {"type": "concede", "extra": 1}).ok and not fresh.apply_action(2, {"type": "concede"}).ok and fresh.state.winner == -1, "Concede with extra fields or a bad player is rejected")
	_check(EventText.format({"k": "concede", "p": 0}) == "Player 1 concedes.", "Concede event has display text")

# --- Two controllers online -----------------------------------------------------------

func _test_online_match() -> void:
	var hub = _hub()
	var host_steam = hub.add(HOST_ID, "Liu Bei")
	var guest_steam = hub.add(GUEST_ID, "Cao Cao")
	var host = _controller(host_steam)
	var guest = _controller(guest_steam)
	var joins: Array = []
	guest.online_join_started.connect(func(): joins.append(true))
	var host_pauses: Array = []
	host.online_paused.connect(func(paused): host_pauses.append(paused))
	host.steam_bridge.host_lobby()
	_pump([host.steam_bridge])
	var lobby = host.steam_bridge.lobby_id
	# Overlay invite: Steam reports join_requested while the game runs.
	guest_steam.queue("join_requested", [lobby, HOST_ID])
	_pump([guest.steam_bridge, host.steam_bridge], 10)
	_check(joins.size() == 1 and guest.steam_bridge.lobby_id == lobby, "An overlay invite joins the lobby and opens the online flow")
	_check(host.mode == Controller.MODE_ONLINE and host.started and guest.mode == Controller.MODE_ONLINE and guest.started, "The handshake starts the online match on both sides")
	_check(guest.opponent_name() == "Liu Bei" and host.opponent_name() == "Cao Cao", "Both sides know the opponent's persona name")
	var guest_view = guest.view()
	_check(_is_whole_float_free(guest_view) and guest_view.players[0].hand.is_empty() and not guest_view.players[1].hand.is_empty(), "Guest view is integer-typed and hides the host's hand")
	_check(int(guest_view.revision) == int(host.engine.state.revision), "Guest sees the host's current revision")
	# Play until the guest has acted at least once.
	var guest_moves = 0
	for _turn in range(12):
		if guest_moves >= 2 or host.is_finished():
			break
		var phase = str(host.engine.state.phase)
		if phase == "action" and int(host.engine.state.active_player) == 0:
			host.act(host.actions()[0])
		elif not guest.actions().is_empty():
			guest.act(guest.actions()[0])
			guest_moves += 1
		elif not host.actions().is_empty():
			host.act(_planning_choice(host.actions()))
		_pump([host.steam_bridge, guest.steam_bridge], 3)
	_check(guest_moves >= 2 and int(guest.view().revision) == int(host.engine.state.revision), "Guest commands apply on the host and the new state comes back")
	_check(host.engine.journal.any(func(entry): return entry.player == 1), "The host journal records the guest's moves")
	# The guest crashes: the host pauses, refuses moves and offers the win.
	hub.crash(GUEST_ID)
	_pump([host.steam_bridge], 2)
	_check(host.waiting_for_opponent and host_pauses == [true], "Opponent disconnect pauses the host")
	_check(host.steam_bridge.status_code == "opponent_disconnected" and host.steam_bridge.status_args.name == "Cao Cao", "Host is told who disconnected")
	var refused = host.act({"type": "pass"})
	_check(not refused.ok and refused.code == "waiting_opponent", "No moves while the opponent is away")
	_check(host.can_claim_win(), "The host can claim the win after the grace period")
	# A different account cannot take the seat.
	var stranger_steam = hub.add(STRANGER_ID, "Lu Bu")
	var stranger = _controller(stranger_steam)
	var stranger_end: Array = []
	stranger.steam_bridge.session_ended.connect(func(code): stranger_end.append(code))
	stranger.steam_bridge.join_lobby(str(lobby))
	_pump([stranger.steam_bridge, host.steam_bridge], 10)
	_check(stranger_end == ["seat_taken"] and stranger.steam_bridge.lobby_id == 0 and not stranger.started, "A different SteamID is refused the seat")
	_check(host.steam_bridge.bound_opponent == GUEST_ID and host.waiting_for_opponent, "The seat stays bound to the original guest")
	# The original account restarts the game and rejoins the same lobby.
	var revision = int(host.engine.state.revision)
	var back_steam = hub.add(GUEST_ID, "Cao Cao")
	var back = _controller(back_steam)
	back.steam_bridge.join_lobby(str(lobby))
	_pump([back.steam_bridge, host.steam_bridge], 10)
	_check(not host.waiting_for_opponent and host_pauses == [true, false], "The same SteamID resumes the match")
	_check(back.started and int(back.view().revision) == revision and int(host.engine.state.revision) == revision, "The returning guest gets the latest snapshot")
	_check(host.steam_bridge.status_code == "opponent_connected" or host.steam_bridge.status_code == "opponent_returned", "Host reports the reconnection")
	# Online concede from the guest, accepted whatever its revision.
	_check(back.can_concede(), "Guest may concede")
	back.online_view["revision"] = 0
	back.concede()
	_pump([back.steam_bridge, host.steam_bridge], 4)
	_check(host.engine.state.winner == 0 and int(back.view().winner) == 0, "Guest concession ends the match for the host")
	_check(host.engine.journal.back().command == {"type": "concede"} and host.engine.journal.back().player == 1, "The concession is in the replay journal")
	# New match, then the host claims the win after the guest drops.
	host.start_match(Controller.MODE_ONLINE)
	_pump([host.steam_bridge, back.steam_bridge], 4)
	_check(not back.is_finished() and int(back.view().revision) == int(host.engine.state.revision), "The host can start another online match")
	hub.crash(GUEST_ID)
	_pump([host.steam_bridge], 2)
	_check(host.claim_win().ok and host.engine.state.winner == 0 and not host.waiting_for_opponent, "Claiming the win records the absent player's concession")
	# Host concedes a fresh match; then the host leaves and the guest returns to the menu.
	var last_steam = hub.add(GUEST_ID, "Cao Cao")
	var last = _controller(last_steam)
	last.steam_bridge.join_lobby(str(lobby))
	_pump([last.steam_bridge, host.steam_bridge], 10)
	host.start_match(Controller.MODE_ONLINE)
	_pump([host.steam_bridge, last.steam_bridge], 4)
	_check(host.concede().ok and host.engine.state.winner == 1, "The host may concede")
	_pump([host.steam_bridge, last.steam_bridge], 4)
	_check(int(last.view().winner) == 1, "Guest sees the host's concession")
	host.start_match(Controller.MODE_ONLINE)
	_pump([host.steam_bridge, last.steam_bridge], 4)
	var ended: Array = []
	last.online_ended.connect(func(text): ended.append(text))
	host.leave_online()
	_check(host.mode == Controller.MODE_AI and not host.started, "Leaving ends the host's online match")
	_pump([last.steam_bridge], 2)
	_check(ended.size() == 1 and last.steam_bridge.status_code == "host_left" and ended[0] == EventText.steam_status("host_left"), "Guest is told the host left")
	_check(last.mode == Controller.MODE_AI and not last.started and last.steam_bridge.lobby_id == 0, "Guest leaves online mode and the lobby")

# --- Steam events and review fixes ------------------------------------------------------

## A host and a guest controller that completed the handshake in a new lobby.
func _online_pair(public: bool = false) -> Array:
	var hub = _hub()
	var host = _controller(hub.add(HOST_ID, "Liu Bei"))
	var guest = _controller(hub.add(GUEST_ID, "Cao Cao"))
	host.steam_bridge.host_lobby(public)
	_pump([host.steam_bridge])
	guest.steam_bridge.join_lobby(str(host.steam_bridge.lobby_id))
	_pump([guest.steam_bridge, host.steam_bridge], 10)
	return [hub, host, guest]

func _kinds(packets: Array, kind: String) -> int:
	return packets.filter(func(packet): return packet is Dictionary and packet.get("kind") == kind).size()

## A planning-phase move that always makes progress: the finishing action
## when it is legal, otherwise the first action (never a deployment re-plan
## or undeploy, which come last and could loop).
func _planning_choice(actions: Array) -> Dictionary:
	for action in actions:
		if str(action.get("type", "")).begins_with("finish"):
			return action
	return actions[0]

func _test_steam_events() -> void:
	# Friends-list "Join game" (GameRichPresenceJoinRequested_t) joins via the connect string.
	var hub = _hub()
	var host = _bridge(hub.add(HOST_ID, "Liu Bei"))
	host.host_lobby()
	_pump([host])
	var guest_steam = hub.add(GUEST_ID, "Cao Cao")
	var guest = _bridge(guest_steam)
	var started: Array = []
	guest.join_started.connect(func(lobby): started.append(lobby))
	guest_steam.queue("join_game_requested", [HOST_ID, host.steam.presence.get("connect", "")])
	_pump([guest, host], 10)
	_check(started == [host.lobby_id] and guest.lobby_id == host.lobby_id and guest.handshake_done, "Friends-list Join game joins the host's lobby")
	# An invite during a running online match does not drop it.
	var other = _bridge(hub.add(HOST_ID + 5, "Sun Quan"))
	other.host_lobby()
	_pump([other])
	guest_steam.queue("join_requested", [other.lobby_id, HOST_ID + 5])
	guest_steam.queue("join_game_requested", [HOST_ID + 5, "+connect_lobby %d" % other.lobby_id])
	_pump([guest], 1)
	_check(guest.lobby_id == host.lobby_id and started.size() == 1 and guest.status_code == "leave_first", "Invites during an online match ask to leave first instead of dropping it")
	# Kicked because Steam dropped us, kicked otherwise, Steam servers lost.
	var ended: Array = []
	guest.session_ended.connect(func(code): ended.append(code))
	guest_steam.queue("lobby_kicked", [host.lobby_id + 999, 0, 1])
	_pump([guest], 1)
	_check(ended.is_empty() and guest.lobby_id == host.lobby_id, "lobby_kicked for another lobby is ignored")
	guest_steam.queue("lobby_kicked", [host.lobby_id, 0, 1])
	_pump([guest], 1)
	_check(ended == ["steam_disconnected"] and guest.lobby_id == 0, "lobby_kicked due to a disconnect ends the session")
	_check(EventText.steam_status("steam_disconnected") != "STEAM_STEAM_DISCONNECTED", "The Steam-disconnected status is translated")
	guest.join_lobby_id(host.lobby_id)
	_pump([guest, host], 10)
	guest_steam.queue("lobby_kicked", [guest.lobby_id, HOST_ID, 0])
	_pump([guest], 1)
	_check(ended.back() == "kicked" and guest.lobby_id == 0, "A real kick ends the session as kicked")
	guest.join_lobby_id(host.lobby_id)
	_pump([guest, host], 10)
	guest_steam.queue("steam_server_disconnected", [3])
	_pump([guest], 1)
	_check(ended.back() == "steam_disconnected" and guest.lobby_id == 0 and guest.available, "Losing the Steam servers ends the online session (Steam stays usable)")
	guest_steam.queue("steam_server_disconnected", [3])
	_pump([guest], 1)
	_check(ended.size() == 3, "Losing the Steam servers outside a lobby changes nothing")
	# Link quality is only read from a connected session.
	host.quality = -1.0
	host.steam.session_state = 0
	host._update_quality()
	_check(host.quality == -1.0 and host.connection_info().quality == -1.0, "No session: quality is not read from uninitialized status fields")

func _test_review_fixes() -> void:
	# Untrusted-input helpers.
	_check(Bridge.nesting_depth({"a": [1, {"b": []}]}) == 4 and Bridge.nesting_depth(5) == 0, "Nesting depth counts containers")
	var deep: Array = []
	var cursor = deep
	for _level in range(500):
		var inner: Array = []
		cursor.append(inner)
		cursor = inner
	_check(Bridge.nesting_depth(deep) == Bridge.MAX_PACKET_DEPTH + 1, "Nesting depth stops early on deep input")
	_check(Bridge.clean_name("  Lu\nBu\t ") == "LuBu" and Bridge.clean_name("W".repeat(5000)).length() == Bridge.MAX_NAME_CHARS, "Names lose control characters and are clamped")
	_check(Bridge.same(6, 6) and not Bridge.same(6.0, 6) and not Bridge.same("6", 6), "Typed comparison never mixes types")
	var pair = _online_pair()
	var hub: FakeHub = pair[0]
	var host = pair[1]
	var guest = pair[2]
	var host_steam: FakeSteam = host.steam_bridge.steam
	var guest_steam: FakeSteam = guest.steam_bridge.steam
	var lobby = host.steam_bridge.lobby_id
	_check(host.mode == Controller.MODE_ONLINE and guest.mode == Controller.MODE_ONLINE, "Online pair connected")
	# Friends-only lobby text does not mention the public list.
	var friends_bridge = _bridge(hub.add(HOST_ID + 70, "Zhang Fei"))
	friends_bridge.host_lobby(false)
	_pump([friends_bridge])
	_check(friends_bridge.status_code == "lobby_created_friends" and EventText.steam_status("lobby_created_friends", {"lobby": "1"}).find("list") == -1, "Friends-only hosts are not told to wait in the lobby list")
	var public_bridge = _bridge(hub.add(HOST_ID + 71, "Guan Yu"))
	public_bridge.host_lobby(true)
	_pump([public_bridge])
	_check(public_bridge.status_code == "lobby_created", "Public hosts are told about the lobby list")
	# Seed: unguessable, different every online match, never in the guest view.
	var first_seed = int(host.current_seed)
	var guest_text = var_to_str(guest.view())
	_check(first_seed > 0 and first_seed < 9007199254740992 and guest_text.find(str(first_seed)) == -1, "The online seed is random below 2^53 and not in the guest view")
	host.start_match(Controller.MODE_ONLINE)
	_pump([host.steam_bridge, guest.steam_bridge], 4)
	_check(absi(int(host.current_seed) - first_seed) > 1000, "Consecutive online matches do not use consecutive seeds")
	var replay = MatchEngine.new()
	_check(replay.load_replay(JSON.parse_string(JSON.stringify(host.engine.replay_data()))).ok and replay.state_digest() == host.engine.state_digest(), "A 53-bit online seed survives a JSON replay")
	# Rematch: the guest's screen restarts (match_started) and its result clears.
	var guest_starts: Array = []
	guest.match_started.connect(func(): guest_starts.append(true))
	host.concede()
	_pump([host.steam_bridge, guest.steam_bridge], 4)
	_check(guest.is_finished() and guest_starts.is_empty(), "Guest sees the finished match")
	_check(not guest.save_replay("user://steam_test_guest.json").ok and not FileAccess.file_exists("user://steam_test_guest.json"), "The guest cannot save a replay of the host's match")
	host.start_match(Controller.MODE_ONLINE)
	_pump([host.steam_bridge, guest.steam_bridge], 4)
	_check(guest_starts.size() == 1 and not guest.is_finished() and int(guest.match_serial) == int(host.match_serial), "A rematch restarts the guest's screen")
	# Invalid commands: a tiny nack each, at most one snapshot per RESEND_MS.
	var rejected: Array = []
	guest.steam_bridge.command_rejected.connect(func(revision): rejected.append(revision))
	var before = host_steam.packets_to(GUEST_ID).size()
	for _attempt in range(20):
		guest.steam_bridge.send_command({"type": "play", "hand": 99}, int(guest.view().revision))
	_pump([host.steam_bridge], 1)
	var answers = host_steam.packets_to(GUEST_ID).slice(before)
	_check(_kinds(answers, "nack") == 20 and _kinds(answers, "state") == 1, "20 invalid commands get 20 nacks and one snapshot (%d states)" % _kinds(answers, "state"))
	_pump([guest.steam_bridge], 2)
	_check(rejected.size() == 20 and guest.notice == EventText.t("HINT_COMMAND_REJECTED"), "The guest is told its move was not applied")
	# Repeated hellos from the present guest: at most one welcome per retry interval.
	before = host_steam.packets_to(GUEST_ID).size()
	for _attempt in range(20):
		guest.steam_bridge._send_hello()
	_pump([host.steam_bridge], 1)
	answers = host_steam.packets_to(GUEST_ID).slice(before)
	_check(_kinds(answers, "welcome") <= 1 and _kinds(answers, "state") <= 1, "Replayed hellos are answered at most once per interval")
	# Malformed and deeply nested packets are dropped quietly.
	var commands: Array = []
	host.steam_bridge.command_received.connect(func(command, _revision): commands.append(command))
	for raw in ["{\"game\":5,\"kind\":\"command\"}", "not json", "{\"game\":\"%s\",\"protocol\":\"%d\",\"kind\":\"command\",\"command\":{},\"revision\":0}" % [Bridge.GAME_TAG, Bridge.PROTOCOL],
			"{\"game\":\"%s\",\"protocol\":%d,\"kind\":\"command\",\"revision\":0,\"command\":{\"x\":%s}}" % [Bridge.GAME_TAG, Bridge.PROTOCOL, "[".repeat(200) + "]".repeat(200)]]:
		guest_steam.sendMessageToUser(HOST_ID, raw.to_utf8_buffer(), 40, Bridge.CHANNEL)
	_pump([host.steam_bridge], 1)
	_check(commands.is_empty() and host.steam_bridge.bound_opponent == GUEST_ID, "Malformed, mistyped and deeply nested packets are dropped")
	# Shop and deployment: a guest command that is still legal is applied even
	# though a host move changed the revision first.
	var guard = 0
	while str(host.engine.state.phase) == "action" and guard < 120:
		guard += 1
		if int(host.engine.state.active_player) == 0:
			host.act({"type": "pass"})
		else:
			guest.act({"type": "pass"})
		_pump([host.steam_bridge, guest.steam_bridge], 3)
	var phase = str(host.engine.state.phase)
	_check(phase in ["shop", "deployment"], "Online match reached a planning phase (%s)" % phase)
	var guest_choice: Dictionary = {}
	for action in guest.actions():
		if not str(action.get("type", "")).begins_with("finish"):
			guest_choice = action
			break
	if guest_choice.is_empty() and not guest.actions().is_empty():
		guest_choice = guest.actions()[0]
	var host_choice: Dictionary = {}
	for action in host.actions():
		if not str(action.get("type", "")).begins_with("finish"):
			host_choice = action
			break
	if host_choice.is_empty() and not host.actions().is_empty():
		host_choice = host.actions()[0]
	var stale_revision = int(guest.view().revision)
	if not host_choice.is_empty():
		host.act(host_choice)
	_check(int(host.engine.state.revision) != stale_revision and int(guest.view().revision) == stale_revision, "The host moved first; the guest still shows the old revision")
	var journal_size = host.engine.journal.size()
	guest.act(guest_choice)
	_pump([host.steam_bridge, guest.steam_bridge], 3)
	_check(host.engine.journal.size() == journal_size + 1 and host.engine.journal.back().player == 1 and host.engine.journal.back().command == guest_choice,
		"Simultaneous planning: the guest's %s is applied, not dropped" % str(guest_choice.get("type", "")))
	# The guest drops: the lobby keeps a spare slot for it.
	var host_pauses: Array = []
	host.online_paused.connect(func(paused): host_pauses.append(paused))
	hub.crash(GUEST_ID)
	_pump([host.steam_bridge], 2)
	_check(host.waiting_for_opponent and hub.lobbies[lobby].max == Bridge.LOBBY_MEMBERS_RESERVED and hub.lobbies[lobby].data.status == "reconnecting",
		"While the seat is reserved the lobby has a spare slot and says reconnecting")
	# A stranger squats in the free slot and keeps sending hellos; the guest still gets back in.
	var squatter = hub.add(STRANGER_ID, "Lu Bu")
	squatter.joinLobby(lobby)
	squatter.run_callbacks()
	var hello = {"protocol": Bridge.PROTOCOL, "game": Bridge.GAME_TAG, "kind": "hello", "content": host.steam_bridge.content_hash,
		"name": "Steam Support [b]VERIFIED[/b]" + "W".repeat(5000)}
	for _attempt in range(5):
		squatter.sendMessageToUser(HOST_ID, JSON.stringify(hello).to_utf8_buffer(), 40, Bridge.CHANNEL)
	_pump([host.steam_bridge], 2)
	_check(_kinds(host_steam.packets_to(STRANGER_ID), "reject") == 1 and host.steam_bridge.bound_opponent == GUEST_ID, "The squatter gets one reject and no seat")
	time.ms += Bridge.REFUSE_CLOSE_MS
	_pump([host.steam_bridge], 1)
	_check(not host_steam.sessions.has(STRANGER_ID), "The refused member's session is closed after the reject")
	squatter.sendMessageToUser(HOST_ID, JSON.stringify(hello).to_utf8_buffer(), 40, Bridge.CHANNEL)
	_pump([host.steam_bridge], 2)
	_check(not host_steam.sessions.has(STRANGER_ID) and _kinds(host_steam.packets_to(STRANGER_ID), "reject") == 1, "A refused member is never accepted again")
	var back = _controller(hub.add(GUEST_ID, "Cao Cao"))
	back.steam_bridge.join_lobby(str(lobby))
	_pump([back.steam_bridge, host.steam_bridge], 10)
	_check(back.steam_bridge.handshake_done and not host.waiting_for_opponent and STRANGER_ID in hub.lobbies[lobby].members, "The original guest rejoins although a stranger holds the free slot")
	_check(hub.lobbies[lobby].max == Bridge.LOBBY_MEMBERS and hub.lobbies[lobby].data.status == "playing", "Back to two slots and playing once the guest returns")
	# The host concedes while the guest is away: the result replaces the pause.
	hub.crash(GUEST_ID)
	_pump([host.steam_bridge], 2)
	_check(host.waiting_for_opponent, "Host waits again")
	_check(host.concede().ok and not host.waiting_for_opponent and host_pauses.back() == false, "Conceding while the opponent is away removes the pause")
	# Display names come from Steam, not from what the other side claims.
	var liar = _hub()
	var liar_host = _bridge(liar.add(HOST_ID, "Liu Bei"))
	liar_host.host_lobby()
	_pump([liar_host])
	var liar_steam = liar.add(GUEST_ID, "RealGuest")
	liar_steam.joinLobby(liar_host.lobby_id)
	liar_steam.run_callbacks()
	liar_steam.sendMessageToUser(HOST_ID, JSON.stringify(hello).to_utf8_buffer(), 40, Bridge.CHANNEL)
	_pump([liar_host], 2)
	_check(liar_host.peer_name == "RealGuest" and liar_host.status_args.name == "RealGuest", "The opponent's name is its Steam persona, not the hello's claim")
	# Starting an offline match leaves the lobby; online traffic can no longer replace it.
	var pair2 = _online_pair()
	var host2 = pair2[1]
	var guest2 = pair2[2]
	guest2.start_match(Controller.MODE_AI)
	_check(guest2.mode == Controller.MODE_AI and guest2.steam_bridge.lobby_id == 0 and guest2.steam_bridge.status_code == "left_lobby", "A guest starting an AI match leaves the lobby first")
	_pump([host2.steam_bridge, guest2.steam_bridge], 4)
	host2.start_match(Controller.MODE_ONLINE)
	_pump([host2.steam_bridge, guest2.steam_bridge], 4)
	_check(guest2.mode == Controller.MODE_AI and guest2.started, "Host traffic does not replace the guest's AI match")
	var pair3 = _online_pair()
	var host3 = pair3[1]
	var guest3 = pair3[2]
	var guest3_ended: Array = []
	guest3.online_ended.connect(func(text): guest3_ended.append(text))
	host3.start_match(Controller.MODE_AI)
	_pump([host3.steam_bridge, guest3.steam_bridge], 3)
	_check(host3.mode == Controller.MODE_AI and host3.steam_bridge.lobby_id == 0 and guest3_ended.size() == 1 and guest3.steam_bridge.status_code == "host_left",
		"A host starting an AI match leaves the lobby and the guest is told")
	# Leaving by hand says so in the Steam dialog.
	var pair4 = _online_pair()
	pair4[1].leave_online()
	_check(pair4[1].steam_bridge.status_code == "left_lobby" and pair4[1].steam_status_text() == EventText.steam_status("left_lobby"), "Leaving shows 'You left the lobby'")
