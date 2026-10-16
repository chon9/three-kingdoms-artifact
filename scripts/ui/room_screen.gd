extends Control
## The online room: both players' seats side by side (the host on the left,
## as on both screens), each with the Steam avatar and name, the connection,
## the deck and whether that player is ready, a seal between them, the
## series in this room and what happens next. Your own seat shows your deck
## (its name and five heroes) with Change deck; the opponent's seat only says
## whether a deck is chosen, never which (deck lists stay private; the heroes
## are revealed when the match starts). With both players ready the match
## starts after a short countdown that either can cancel. The host's empty
## seat offers Invite and Copy lobby ID while it waits.

signal action_requested(action: String)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const VersusIntro = preload("res://scripts/ui/versus_intro.gd")
const SEAT = Vector2(460, 432)
const SEAT_GAP = 150.0
## The seats' top edge in a 900 px tall window (taller windows centre them).
const TOP = 168.0
## Buttons: name -> i18n key (ready's text follows the state).
const BUTTONS = {"ready": "ROOM_BTN_READY", "deck": "STEAM_CHANGE_DECK", "leave": "ROOM_BTN_LEAVE", "menu": "MENU_MAIN_MENU",
	"invite": "STEAM_INVITE", "copy": "STEAM_COPY_ID"}

var controller: Node
var buttons: Dictionary = {}
## A passing message ("Cao Cao left the room.") and how long it stays.
var notice: String = ""
var _notice_time: float = 0.0
var _time: float = 0.0
var _redraw: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	for action in BUTTONS:
		var button = Button.new()
		button.name = action.capitalize()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.add_theme_font_override("font", UiKit.title_font())
		button.add_theme_font_size_override("font_size", 26 if action == "ready" else 18)
		button.pressed.connect(_on_pressed.bind(action))
		add_child(button)
		buttons[action] = button
	buttons.ready.custom_minimum_size = Vector2(240, 60)

func bind(match_controller: Node) -> void:
	controller = match_controller
	controller.room_changed.connect(refresh)
	controller.steam_status_changed.connect(func(_text): refresh())
	controller.opponent_left.connect(_on_opponent_left)
	controller.own_deck_answered.connect(func(_result): refresh())
	controller.steam_bridge.profile_changed.connect(func(_steam_id): queue_redraw())

func _on_pressed(action: String) -> void:
	match action:
		"ready":
			controller.set_ready(not controller.my_ready())
		"invite":
			controller.steam_bridge.invite_friends()
		"copy":
			DisplayServer.clipboard_set(str(controller.steam_bridge.lobby_id))
			show_notice(UiKit.t("ROOM_ID_COPIED"))
	action_requested.emit(action)

func _on_opponent_left(name: String) -> void:
	show_notice(UiKit.t("ROOM_OPPONENT_LEFT", {"name": name if not name.is_empty() else UiKit.t("PLAYER_OPPONENT")}))

## A message under the seats for a few seconds.
func show_notice(text: String, seconds: float = 5.0) -> void:
	notice = text
	_notice_time = seconds
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		refresh()

func _process(delta: float) -> void:
	# A passing notice expires whether or not the room is on screen.
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0:
			notice = ""
	if not visible:
		return
	_time += delta
	# The spinner and the countdown move: redraw a few times a second.
	_redraw -= delta
	if _redraw <= 0.0:
		_redraw = 0.05
		if controller != null and controller.room_starting:
			_refresh_ready()
		queue_redraw()

func refresh_text() -> void:
	refresh()

## Re-reads the room and redraws.
func refresh() -> void:
	if controller == null:
		return
	for action in buttons:
		buttons[action].text = UiKit.t(BUTTONS[action])
	_refresh_ready()
	var bridge = controller.steam_bridge
	var host = bridge.is_host
	var empty = host and not bridge.handshake_done
	buttons.invite.visible = host and empty
	buttons.copy.visible = host
	buttons.deck.visible = true
	buttons.deck.disabled = controller.room_starting
	_layout()
	queue_redraw()

func _refresh_ready() -> void:
	var button: Button = buttons.ready
	var ready = controller.my_ready()
	button.text = UiKit.t("ROOM_BTN_UNREADY" if ready else "ROOM_BTN_READY")
	var block = controller.ready_block()
	button.disabled = not ready and not block.is_empty()
	button.tooltip_text = UiKit.t(block) if not ready and not block.is_empty() else ""

# --- Layout ------------------------------------------------------------------------

## The seats' top edge.
func seats_top() -> float:
	return TOP + maxf(0.0, (size.y - 900.0) * 0.5)

## The two seat rects: [host, guest].
func seat_rects() -> Array:
	var width = SEAT.x * 2.0 + SEAT_GAP
	var left = (size.x - width) * 0.5
	var top = seats_top()
	return [Rect2(Vector2(left, top), SEAT), Rect2(Vector2(left + SEAT.x + SEAT_GAP, top), SEAT)]

func _layout() -> void:
	if controller == null:
		return
	var seats = seat_rects()
	var right = seats[1].end.x
	var left = seats[0].position.x
	for action in buttons:
		var button: Button = buttons[action]
		button.size = button.get_combined_minimum_size()
	var bottom = size.y - 92.0
	buttons.ready.position = Vector2(right - buttons.ready.size.x, bottom)
	buttons.leave.position = Vector2(left, bottom + (buttons.ready.size.y - buttons.leave.size.y) * 0.5)
	buttons.menu.position = Vector2(buttons.leave.position.x + buttons.leave.size.x + 12.0, buttons.leave.position.y)
	var own: Rect2 = seats[controller.room_seat()]
	buttons.deck.position = Vector2(own.end.x - buttons.deck.size.x - 22.0, own.position.y + 196.0)
	var bridge = controller.steam_bridge
	if bridge.is_host and not bridge.handshake_done:
		# The empty seat holds the ways to bring a friend in.
		var guest: Rect2 = seats[1]
		var pair = buttons.invite.size.x + 12.0 + buttons.copy.size.x
		buttons.invite.position = Vector2(guest.get_center().x - pair * 0.5, guest.position.y + 300.0)
		buttons.copy.position = Vector2(buttons.invite.position.x + buttons.invite.size.x + 12.0, buttons.invite.position.y)
	else:
		buttons.copy.position = Vector2(right - buttons.copy.size.x, seats[0].position.y - 74.0)

# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.015, 0.016, 0.022))
	var art = UiKit.ui_art("board_overview")
	if art != null:
		UiKit.draw_cover(self, art, rect, Vector2(0.5, 0.5), Color(0.3, 0.27, 0.27, 0.8))
	UiKit.draw_vgradient(self, Rect2(0, 0, size.x, size.y * 0.35), Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.1))
	UiKit.draw_vgradient(self, Rect2(0, size.y * 0.6, size.x, size.y * 0.4), Color(0, 0, 0, 0.1), Color(0, 0, 0, 0.8))
	if controller == null:
		return
	var bridge = controller.steam_bridge
	var seats = seat_rects()
	_draw_header(seats, bridge)
	for seat in range(2):
		if seat == 1 and bridge.is_host and not bridge.handshake_done:
			_draw_empty_seat(seats[1], bridge)
		else:
			_draw_seat(seats[seat], seat)
	_draw_seal(Vector2(size.x * 0.5, seats[0].get_center().y - 20.0))
	var y = seats[0].end.y + 30.0
	var series: Array = controller.room_series
	if int(series[0]) + int(series[1]) > 0:
		var names = [_seat_name(0), _seat_name(1)]
		UiKit.draw_text(self, UiKit.title_font(), UiKit.t("ROOM_SERIES", {"a": names[0], "x": int(series[0]), "y": int(series[1]), "b": names[1]}),
			Vector2(size.x * 0.5, y), 20, UiKit.PAPER, seats[1].end.x - seats[0].position.x, 2)
	var status = status_text()
	var starting = controller.room_starting
	UiKit.draw_text(self, UiKit.title_font(), status, Vector2(size.x * 0.5, y + 46.0), 24 if starting else 19,
		UiKit.GOLD_BRIGHT if starting else UiKit.PAPER_DIM, seats[1].end.x - seats[0].position.x, 3)

func _draw_header(seats: Array, bridge: Node) -> void:
	var left = seats[0].position.x
	var y = seats[0].position.y - 54.0
	# The host's room says what kind it is; a guest is in the host's room.
	var title = UiKit.t("ROOM_TITLE", {"type": UiKit.t("ROOM_TYPE_PUBLIC" if bridge.lobby_public else "ROOM_TYPE_FRIENDS")})
	if not bridge.is_host:
		title = UiKit.t("ROOM_TITLE_GUEST", {"name": _seat_name(0)})
	UiKit.draw_text_left(self, UiKit.title_font(), title, Vector2(left, y), 34, UiKit.GOLD_BRIGHT, seats[1].end.x - left - 420.0, 4)
	if bridge.lobby_id != 0:
		var id_text = UiKit.t("STEAM_LOBBY", {"lobby": str(bridge.lobby_id)})
		var right = buttons.copy.position.x - 14.0 if buttons.copy.visible and buttons.copy.position.y < seats[0].position.y else seats[1].end.x
		var width = UiKit.body_font().get_string_size(id_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		UiKit.draw_text_left(self, UiKit.body_font(), id_text, Vector2(right - width, y), 15, UiKit.MUTED, -1.0, 2)

## The seat's player name ("" when unknown).
func _seat_name(seat: int) -> String:
	var bridge = controller.steam_bridge
	var mine = seat == controller.room_seat()
	var name = bridge.local_name() if mine else controller.opponent_name()
	if name.is_empty():
		name = UiKit.t("PLAYER_YOU") if mine else UiKit.t("PLAYER_OPPONENT")
	return name

func _seat_id(seat: int) -> int:
	var bridge = controller.steam_bridge
	return int(bridge.local_id) if seat == controller.room_seat() else int(bridge.peer_id)

func _draw_seat(rect: Rect2, seat: int) -> void:
	var bridge = controller.steam_bridge
	var mine = seat == controller.room_seat()
	var ready = bool(controller.room_ready[seat])
	UiKit.draw_round_rect(self, rect, Color(UiKit.INK_PANEL, 0.92), 8.0, Color(UiKit.GOLD_BRIGHT if mine else UiKit.GOLD_DARK, 0.95), 2.0 if mine else 1.0)
	if ready:
		UiKit.draw_glow(self, rect, 8.0, UiKit.JADE, 0.7)
	var avatar = Rect2(rect.position + Vector2(24, 24), Vector2(120, 120))
	var name = _seat_name(seat)
	# Without a Steam avatar your seat shows your army's first hero; the
	# opponent's deck is private, so theirs shows a seal.
	var heroes: Array = controller.own_deck_heroes() if mine else []
	VersusIntro.draw_avatar(self, avatar, bridge, _seat_id(seat), name, 1.0, str(heroes[0]) if not heroes.is_empty() else "")
	var text_left = avatar.end.x + 20.0
	var text_width = rect.end.x - text_left - 20.0
	UiKit.draw_text_left(self, UiKit.title_font(), name, Vector2(text_left, rect.position.y + 50.0), 28, UiKit.PAPER, text_width, 3)
	if mine:
		UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("ROOM_YOU_TAG"), Vector2(text_left, rect.position.y + 84.0), 15, UiKit.GOLD, -1.0, 2)
	UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("ROOM_HOST_SEAT" if seat == 0 else "ROOM_GUEST_SEAT"),
		Vector2(text_left, rect.position.y + 110.0), 15, UiKit.PAPER_DIM, text_width, 2)
	_draw_link(Vector2(text_left, rect.position.y + 136.0), mine, text_width)
	draw_line(Vector2(rect.position.x + 22, rect.position.y + 168), Vector2(rect.end.x - 22, rect.position.y + 168), Color(UiKit.GOLD_DARK, 0.7), 1.0)
	UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("ROOM_DECK_CAPTION"), Vector2(rect.position.x + 24, rect.position.y + 190.0), 14, UiKit.MUTED, -1.0, 2)
	if mine:
		_draw_own_deck(rect)
	else:
		_draw_opponent_deck(rect, seat)
	_draw_ready_status(rect, ready, mine)

## Whether the seat's player is ready: a status mark (a jade check, or an
## empty ring) and a word, drawn as a label, never a button (the Ready
## button is the one under the seats). An opponent who is ready after a
## result also gets a "Wants a rematch" tag at the right.
func _draw_ready_status(rect: Rect2, ready: bool, mine: bool) -> void:
	var center_y = rect.end.y - 40.0
	var left = rect.position.x + 24.0
	var mark = Vector2(left + 14.0, center_y)
	var font = UiKit.title_font()
	var text = UiKit.t("ROOM_READY" if ready else "ROOM_NOT_READY")
	var text_size = 20
	var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	if ready:
		var pill = Rect2(Vector2(left - 6.0, center_y - 18.0), Vector2(text_width + 56.0, 36.0))
		UiKit.draw_round_rect(self, pill, Color(UiKit.JADE, 0.22), 18.0)
		draw_circle(mark, 11.0, UiKit.JADE)
		draw_polyline(PackedVector2Array([mark + Vector2(-5, 0), mark + Vector2(-1.5, 4), mark + Vector2(5.5, -4.5)]), UiKit.PAPER, 2.5, true)
		UiKit.draw_text_left(self, font, text, Vector2(left + 34.0, center_y), text_size, UiKit.JADE.lightened(0.5), -1.0, 2)
	else:
		draw_arc(mark, 10.0, 0.0, TAU, 32, Color(UiKit.MUTED, 0.9), 2.0, true)
		UiKit.draw_text_left(self, font, text, Vector2(left + 34.0, center_y), text_size, UiKit.MUTED, -1.0, 2)
	if ready and not mine and controller.room_phase == "result":
		var chip_text = UiKit.t("ROOM_WANTS_REMATCH")
		var chip_width = UiKit.body_font().get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20.0
		var chip = Rect2(Vector2(rect.end.x - 24.0 - chip_width, center_y - 13.0), Vector2(chip_width, 26.0))
		UiKit.draw_round_rect(self, chip, Color(UiKit.CINNABAR, 0.85), 13.0)
		UiKit.draw_text(self, UiKit.body_font(), chip_text, chip.get_center(), 14, UiKit.PAPER)

## Your link: always fine; the opponent's: signal bars and ping, or lost.
func _draw_link(left_center: Vector2, mine: bool, width: float) -> void:
	var bridge = controller.steam_bridge
	if mine:
		draw_circle(left_center + Vector2(5, 0), 5.0, UiKit.HEAL)
		UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("ROOM_CONNECTED"), left_center + Vector2(16, 0), 14, UiKit.PAPER_DIM, width - 16.0, 2)
		return
	var info: Dictionary = bridge.connection_info()
	var level = str(info.get("level", "unknown"))
	var lit = {"good": 3, "fair": 2, "poor": 1}.get(level, 0)
	var color = {"good": UiKit.HEAL, "fair": UiKit.GOLD, "poor": UiKit.DAMAGE, "lost": UiKit.DAMAGE}.get(level, UiKit.MUTED)
	for bar in range(3):
		var height = 5.0 + bar * 4.0
		draw_rect(Rect2(left_center.x + bar * 6.0, left_center.y + 7.0 - height, 4.0, height), color if bar < lit else Color(UiKit.MUTED, 0.45))
	var ping = int(info.get("ping", -1))
	var text = UiKit.t("NET_" + level.to_upper())
	if level == "lost":
		text = UiKit.t("ROOM_LINK_LOST")
	elif ping >= 0:
		text = UiKit.t("NET_PING", {"ms": ping}) + " · " + text
	UiKit.draw_text_left(self, UiKit.body_font(), text, left_center + Vector2(24, 0), 14, UiKit.PAPER_DIM, width - 24.0, 2)

## Your deck: its name, its five heroes and (as guest) the host's answer.
func _draw_own_deck(rect: Rect2) -> void:
	var name_width = buttons.deck.position.x - rect.position.x - 34.0
	UiKit.draw_text_left(self, UiKit.title_font(), controller.own_deck_name(), Vector2(rect.position.x + 24, rect.position.y + 218.0), 22,
		UiKit.GOLD_BRIGHT, name_width, 2)
	var heroes: Array = controller.own_deck_heroes()
	var chip = Vector2(56, 76)
	var x = rect.position.x + 24.0
	for hero_id in heroes.slice(0, 5):
		var frame = Rect2(Vector2(x, rect.position.y + 246.0), chip)
		var color = UiKit.card_color(str(Library.raw_definition(str(hero_id)).get("color", "neutral")))
		UiKit.draw_round_rect(self, frame, color, 4.0)
		if not CardArt.draw_portrait(self, frame.grow(-2.0), str(hero_id)):
			UiKit.draw_text(self, UiKit.title_font(), Library.loc(str(hero_id)).left(1), frame.get_center(), 20, UiKit.PAPER)
		UiKit.draw_round_rect(self, frame, Color.TRANSPARENT, 4.0, color.lightened(0.35), 1.0)
		x += chip.x + 8.0
	var answer = own_deck_answer()
	if not answer.is_empty():
		var accepted = controller.own_deck_result.get("ok", false)
		UiKit.draw_text_left(self, UiKit.body_font(), answer, Vector2(rect.position.x + 24, rect.position.y + 340.0), 14,
			UiKit.HEAL if accepted else UiKit.PAPER_DIM, rect.size.x - 48.0, 2)

## The host's answer to the guest's deck, as the guest's seat shows it.
func own_deck_answer() -> String:
	var bridge = controller.steam_bridge
	if bridge.is_host or not bridge.handshake_done:
		return ""
	var result: Dictionary = controller.own_deck_result
	if result.is_empty():
		return UiKit.t("DECK_ONLINE_PENDING")
	if result.get("ok", false):
		return UiKit.t("ROOM_DECK_ACCEPTED")
	return UiKit.t("DECK_ONLINE_REJECTED", {"reason": UiKit.EventText.error_text(result)})

## The opponent's deck: chosen or not, never which.
func _draw_opponent_deck(rect: Rect2, seat: int) -> void:
	var key = opponent_deck_key(seat)
	var color = UiKit.HEAL if key == "ROOM_DECK_CHOSEN" else UiKit.PAPER_DIM
	UiKit.draw_text_left(self, UiKit.title_font(), UiKit.t(key), Vector2(rect.position.x + 24, rect.position.y + 218.0), 20, color,
		rect.size.x - 48.0, 2)
	UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("ROOM_DECK_PRIVATE"), Vector2(rect.position.x + 24, rect.position.y + 250.0), 14,
		UiKit.MUTED, rect.size.x - 48.0, 2)

## What the opponent's seat says about its deck (an i18n key).
func opponent_deck_key(seat: int) -> String:
	if seat == 0:
		# The host always has its deck.
		return "ROOM_DECK_CHOSEN"
	match str(controller.guest_deck_state):
		"ok":
			return "ROOM_DECK_CHOSEN"
		"rejected":
			return "ROOM_DECK_REJECTED"
		"missing":
			return "ROOM_DECK_MISSING"
	return "ROOM_DECK_CHOOSING"

## The host's empty seat: a dashed frame, a spinner and the ways to invite.
func _draw_empty_seat(rect: Rect2, bridge: Node) -> void:
	UiKit.draw_round_rect(self, rect, Color(0, 0, 0, 0.35), 8.0)
	var dash = 14.0
	for side in [[rect.position, Vector2(rect.end.x, rect.position.y)], [Vector2(rect.end.x, rect.position.y), rect.end],
			[rect.end, Vector2(rect.position.x, rect.end.y)], [Vector2(rect.position.x, rect.end.y), rect.position]]:
		var from: Vector2 = side[0]
		var to: Vector2 = side[1]
		var length = from.distance_to(to)
		var steps = int(length / (dash * 2.0))
		for step in range(steps):
			var a = from.lerp(to, (step * dash * 2.0) / length)
			var b = from.lerp(to, (step * dash * 2.0 + dash) / length)
			draw_line(a, b, Color(UiKit.GOLD, 0.5), 1.5)
	var center = rect.get_center() + Vector2(0, -90)
	var spin = _time * 2.6
	draw_arc(center, 30.0, spin, spin + PI * 1.4, 32, Color(UiKit.GOLD_BRIGHT, 0.85), 3.0, true)
	draw_arc(center, 30.0, spin + PI * 1.6, spin + PI * 1.8, 8, Color(UiKit.GOLD, 0.4), 3.0, true)
	UiKit.draw_text(self, UiKit.title_font(), UiKit.t("ROOM_WAITING_SEAT"), rect.get_center() + Vector2(0, -20), 24, UiKit.PAPER, rect.size.x - 40.0, 2)
	var hint_key = "ROOM_EMPTY_HINT_PUBLIC" if bridge.lobby_public else "ROOM_EMPTY_HINT_FRIENDS"
	var hint = UiKit.paragraph(UiKit.t(hint_key), UiKit.body_font(), 15, rect.size.x - 60.0)
	hint.draw(get_canvas_item(), Vector2(rect.position.x + 30.0, rect.get_center().y + 14.0), UiKit.PAPER_DIM)

## The seal between the seats.
func _draw_seal(center: Vector2) -> void:
	draw_arc(center, 58.0, 0.0, TAU, 72, Color(UiKit.GOLD, 0.55), 2.0, true)
	var size_value = 78.0
	var seal = Rect2(center - Vector2(size_value, size_value) * 0.5, Vector2(size_value, size_value))
	UiKit.draw_round_rect(self, seal, UiKit.CINNABAR, size_value * 0.12)
	UiKit.draw_round_rect(self, seal.grow(-size_value * 0.09), Color.TRANSPARENT, size_value * 0.08, Color(UiKit.PAPER, 0.75), maxf(1.0, size_value * 0.05))
	UiKit.draw_text(self, UiKit.kai_font(), UiKit.t("VERSUS_SEAL"), center, int(size_value * 0.46), UiKit.PAPER, size_value * 0.78)

## The line under the seats: the countdown, what the room waits for, or a
## passing notice.
func status_text() -> String:
	var bridge = controller.steam_bridge
	if controller.room_starting:
		return UiKit.t("ROOM_STARTING", {"n": controller.countdown_left()})
	if not notice.is_empty():
		return notice
	if bridge.leaving():
		return UiKit.t("STEAM_LEAVING_LOBBY")
	if bridge.is_host and not bridge.handshake_done:
		return UiKit.t("ROOM_WAITING_OPPONENT")
	var opponent = _seat_name(1 - controller.room_seat())
	if not bridge.opponent_present:
		return UiKit.t("ROOM_OPPONENT_NOT_RESPONDING", {"name": opponent})
	if controller.room_phase == "match":
		return UiKit.t("ROOM_MATCH_RUNNING")
	if not controller.my_ready():
		var block = controller.ready_block()
		if block == "ROOM_READY_NEEDS_DECK":
			return UiKit.t(block)
		return UiKit.t("ROOM_WAIT_YOU")
	return UiKit.t("ROOM_WAIT_OPPONENT", {"name": opponent})
