extends Control
## End of match: a calligraphy banner (Victory / Defeat / Draw) over an ink
## wash, the result line and the towers that fell, with Play again, Save
## replay, View board and Main menu.

signal action_requested(action: String)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const ACTIONS = ["again", "save", "board", "menu"]
const KEYS = {"again": "RESULT_PLAY_AGAIN", "save": "MENU_SAVE_REPLAY", "board": "BTN_VIEW_BOARD", "menu": "MENU_MAIN_MENU"}
## Decorative victory seal stamp ("win").
const SEAL_GLYPH = "胜"

var result_key: String = "RESULT_VICTORY"
var subtitle: String = ""
var detail: String = ""
var buttons: Dictionary = {}
var victory: bool = true
## Rebuilds [towers text, matchup text] in the current language (set by the
## match screen), so a language switch re-renders the result.
var text_source: Callable
var _winner: int = -1
var _hot_seat: bool = false
var _reveal: float = 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var row = HBoxContainer.new()
	row.name = "Buttons"
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	for action in ACTIONS:
		var button = Button.new()
		button.name = action.capitalize()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(170, 50)
		button.add_theme_font_override("font", UiKit.title_font())
		button.add_theme_font_size_override("font_size", 21)
		button.pressed.connect(func(): action_requested.emit(action))
		row.add_child(button)
		buttons[action] = button

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var row: Control = get_node("Buttons")
		row.size = row.get_combined_minimum_size()
		row.position = Vector2((size.x - row.size.x) * 0.5, size.y * 0.645)

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
	subtitle = matchup
	detail = towers_text
	visible = true
	refresh_text()
	_notification(NOTIFICATION_RESIZED)
	if not AnimationQueue.instant:
		_reveal = 0.0
		var tween = create_tween()
		tween.tween_method(func(value): _reveal = value; queue_redraw(), 0.0, 1.0, AnimationQueue.duration(0.7))

func refresh_text() -> void:
	for action in ACTIONS:
		buttons[action].text = UiKit.t(KEYS[action])
	if visible and text_source.is_valid():
		var texts: Array = text_source.call()
		detail = str(texts[0])
		subtitle = str(texts[1])
	if _hot_seat and _winner != -1 and _winner != 2:
		subtitle = UiKit.t("RESULT_PLAYER_WINS", {"player": UiKit.t("PLAYER_N", {"n": _winner + 1})})
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
	UiKit.draw_text(self, UiKit.body_font(), detail, Vector2(size.x * 0.5, size.y * 0.56), 18, Color(UiKit.PAPER_DIM, _reveal), size.x * 0.8, 2)
	if victory and result_key != "RESULT_DRAW":
		var title_width = UiKit.title_font().get_string_size(UiKit.t(result_key), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		UiKit.draw_seal(self, Vector2(size.x * 0.5 + maxf(240.0, title_width * 0.5 + 56.0), size.y * 0.33), 56.0, SEAL_GLYPH)
