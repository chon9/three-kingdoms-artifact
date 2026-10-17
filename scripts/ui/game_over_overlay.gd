extends Control
## End of match: a calligraphy banner (Victory / Defeat / Draw) over an ink
## wash, the result line and the towers that fell, the ways on, and a status
## line under them. Against the AI or hot-seat: Play again, Change deck, Save
## replay, View board, Main menu. Online: Rematch (ready for the next match,
## in the room), Change deck, View board, Save replay (the host's), Leave
## room; the status line says when the opponent wants a rematch or left. When
## the online session is over, only View board, Main menu and Find a lobby
## stay. A campaign tale: Continue the tale (after a win), Try again, Change
## army (after a defeat), View board and Back to the tales, with the seals
## the battle earned on the status line.

signal action_requested(action: String)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
## Every action, in the order they appear.
const ACTIONS = ["story_next", "again", "retry", "rematch", "room", "decks", "decks_brief", "save", "board", "leave", "menu", "steam", "campaign"]
const KEYS = {"again": "RESULT_PLAY_AGAIN", "rematch": "RESULT_REMATCH", "room": "RESULT_BACK_TO_ROOM",
	"decks": "RESULT_CHANGE_DECK", "save": "MENU_SAVE_REPLAY", "board": "BTN_VIEW_BOARD", "leave": "ROOM_BTN_LEAVE",
	"menu": "MENU_MAIN_MENU", "steam": "RESULT_FIND_LOBBY", "story_next": "RESULT_CAMPAIGN_CONTINUE", "retry": "RESULT_RETRY",
	"decks_brief": "RESULT_CHANGE_ARMY", "campaign": "RESULT_BACK_TO_CAMPAIGN"}
## The action sets.
const OFFLINE_ACTIONS = ["again", "decks", "save", "board", "menu"]
const ONLINE_ACTIONS = ["rematch", "decks", "save", "board", "leave"]
const CLOSED_ACTIONS = ["board", "menu", "steam"]
const CAMPAIGN_WIN_ACTIONS = ["story_next", "retry", "board", "campaign"]
const CAMPAIGN_LOSS_ACTIONS = ["retry", "decks_brief", "board", "campaign"]
## Decorative victory seal stamp ("win").
const SEAL_GLYPH = "胜"

var result_key: String = "RESULT_VICTORY"
var subtitle: String = ""
var detail: String = ""
var buttons: Dictionary = {}
## The actions shown, in order.
var actions: Array = OFFLINE_ACTIONS.duplicate()
## Actions shown but not available (with `disabled_hint` as their tooltip).
var disabled_actions: Array = []
var disabled_hint: String = "HINT_HOST_ONLY_RESULT"
## The line under the buttons ("" for none) and whether it calls for action.
var status: String = ""
var status_alert: bool = false
var victory: bool = true
## Rebuilds [towers text, matchup text] in the current language (set by the
## match screen), so a language switch re-renders the result.
var text_source: Callable
## The online session ended under this result (set_online_closed).
var closed: bool = false
var _winner: int = -1
var _hot_seat: bool = false
var _reveal: float = 1.0
var _row: HBoxContainer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_row = HBoxContainer.new()
	_row.name = "Buttons"
	_row.add_theme_constant_override("separation", 16)
	add_child(_row)
	for action in ACTIONS:
		var button = Button.new()
		button.name = action.capitalize()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(170, 50)
		button.add_theme_font_override("font", UiKit.title_font())
		button.add_theme_font_size_override("font_size", 21)
		button.pressed.connect(func(): action_requested.emit(action))
		_row.add_child(button)
		buttons[action] = button
	set_actions(OFFLINE_ACTIONS)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()

func _place() -> void:
	_row.size = _row.get_combined_minimum_size()
	_row.position = Vector2((size.x - _row.size.x) * 0.5, size.y * 0.645)

## Shows these actions, in this order.
func set_actions(list: Array) -> void:
	actions = list.duplicate()
	for action in ACTIONS:
		buttons[action].visible = action in actions
	for index in range(actions.size()):
		_row.move_child(buttons[actions[index]], index)
	refresh_text()
	_place()

## The status line under the buttons.
func set_status(text: String, alert: bool = false) -> void:
	status = text
	status_alert = alert
	queue_redraw()

## The online session is over: only the board, the menu and the lobby
## browser remain, with `text` saying why.
func set_online_closed(text: String) -> void:
	closed = true
	disabled_actions = []
	set_actions(CLOSED_ACTIONS)
	set_status(text)

## `winner` is the engine winner (0, 1 or 2 for a draw); `viewer` the local
## player; `hot_seat` names the winner instead of saying victory/defeat.
func show_result(winner: int, viewer: int, hot_seat: bool, towers_text: String, matchup: String = "") -> void:
	victory = winner == viewer or (hot_seat and winner != 2)
	if winner == 2:
		result_key = "RESULT_DRAW"
	elif hot_seat:
		result_key = "RESULT_VICTORY"
	else:
		result_key = "RESULT_VICTORY" if winner == viewer else "RESULT_DEFEAT"
	_winner = winner
	_hot_seat = hot_seat
	closed = false
	subtitle = matchup
	detail = towers_text
	visible = true
	refresh_text()
	_place()
	if not AnimationQueue.instant:
		_reveal = 0.0
		var tween = create_tween()
		tween.tween_method(func(value): _reveal = value; queue_redraw(), 0.0, 1.0, AnimationQueue.duration(0.7))

func refresh_text() -> void:
	for action in ACTIONS:
		buttons[action].text = UiKit.t(KEYS[action])
		buttons[action].disabled = action in disabled_actions
		buttons[action].tooltip_text = UiKit.t(disabled_hint) if action in disabled_actions else ""
	if visible and text_source.is_valid():
		var texts: Array = text_source.call()
		detail = str(texts[0])
		subtitle = str(texts[1])
	if _hot_seat and _winner != -1 and _winner != 2:
		subtitle = UiKit.t("RESULT_PLAYER_WINS", {"player": UiKit.t("PLAYER_N", {"n": _winner + 1})})
	_place()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.015, 0.8 * minf(1.0, _reveal * 2.0)))
	var splash = UiKit.tex("res://assets/art/ui/splash_victory.png" if victory else "res://assets/art/ui/splash_defeat.png")
	# The band runs down behind the buttons so they never float on the board.
	var band = Rect2(0, size.y * 0.2, size.x, size.y * 0.54)
	if splash != null:
		UiKit.draw_cover(self, splash, band, Vector2(0.5, 0.5), Color(1, 1, 1, 0.85 * _reveal))
	else:
		UiKit.draw_ink_wash(self, band, UiKit.CINNABAR if victory else Color("3a4a5a"), result_key, true)
	UiKit.draw_vgradient(self, Rect2(band.position, Vector2(band.size.x, band.size.y * 0.24)), Color(0.01, 0.01, 0.015, 0.9), Color(0, 0, 0, 0))
	UiKit.draw_vgradient(self, Rect2(band.position + Vector2(0, band.size.y * 0.62), Vector2(band.size.x, band.size.y * 0.38)), Color(0, 0, 0, 0), Color(0.01, 0.01, 0.015, 0.92))
	var color = UiKit.GOLD_BRIGHT if result_key != "RESULT_DEFEAT" else Color("c9d2dc")
	var title_size = int(120 * (0.8 + 0.2 * _reveal))
	UiKit.draw_text(self, UiKit.title_font(), UiKit.t(result_key), Vector2(size.x * 0.5, size.y * 0.37), title_size,
		Color(color, _reveal), -1.0, 8, Color(0.1, 0.02, 0.0, 0.8 * _reveal))
	UiKit.draw_text(self, UiKit.title_font(), subtitle, Vector2(size.x * 0.5, size.y * 0.5), 30, Color(UiKit.PAPER, _reveal), -1.0, 3)
	UiKit.draw_text(self, UiKit.body_font(), detail, Vector2(size.x * 0.5, size.y * 0.56), 18, Color(UiKit.PAPER, _reveal), size.x * 0.8, 4)
	if not status.is_empty():
		var y = _row.position.y + _row.size.y + 30.0
		UiKit.draw_text(self, UiKit.title_font(), status, Vector2(size.x * 0.5, y), 21,
			Color(UiKit.GOLD_BRIGHT if status_alert else UiKit.PAPER_DIM, _reveal), size.x * 0.8, 3)
	if victory and result_key != "RESULT_DRAW":
		var title_width = UiKit.title_font().get_string_size(UiKit.t(result_key), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		UiKit.draw_seal(self, Vector2(size.x * 0.5 + maxf(240.0, title_width * 0.5 + 56.0), size.y * 0.33), 56.0, SEAL_GLYPH)
