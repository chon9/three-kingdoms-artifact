extends Control
## A player's name plate on the right edge (opponent at the top, you at the
## bottom): name, gold, deck and hand counts. It glows while that player is
## acting. The opponent's plate also holds the in-match menu button.

signal menu_pressed

const UiKit = preload("res://scripts/ui/ui_kit.gd")

var own: bool = true
var player_name: String = ""
var gold: int = 0
var deck: int = 0
var hand: int = 0
var acting: bool = false
var show_menu: bool = false
## Online opponent link (SteamBridge.connection_info()); empty offline.
var connection: Dictionary = {}
var _menu_hover: bool = false

func _init() -> void:
	size = Vector2(380, 46)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_values(name_text: String, gold_value: int, deck_value: int, hand_value: int, is_acting: bool) -> void:
	player_name = name_text
	gold = gold_value
	deck = deck_value
	hand = hand_value
	acting = is_acting
	queue_redraw()

func set_connection(info: Dictionary) -> void:
	if info == connection:
		return
	connection = info
	var ping = int(info.get("ping", -1))
	tooltip_text = "" if info.is_empty() else UiKit.t("NET_TOOLTIP", {"state": UiKit.t("NET_" + str(info.get("level", "unknown")).to_upper()),
		"ping": UiKit.t("NET_PING", {"ms": ping}) if ping >= 0 else "-"})
	queue_redraw()

func menu_rect() -> Rect2:
	return Rect2(size.x - 44, 5, 36, 36)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and show_menu:
		var hover = menu_rect().has_point(event.position)
		if hover != _menu_hover:
			_menu_hover = hover
			queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if show_menu and menu_rect().has_point(event.position):
			menu_pressed.emit()
		accept_event()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var points = PackedVector2Array([Vector2(16, 0), size * Vector2(1, 0), size, Vector2(0, size.y), Vector2(0, 16)])
	draw_colored_polygon(points, Color(0.04, 0.045, 0.05, 0.86))
	var tint = UiKit.ALLY_TINT if own else UiKit.ENEMY_TINT
	draw_polyline(PackedVector2Array([Vector2(0, size.y), Vector2(0, 16), Vector2(16, 0), Vector2(size.x, 0)]), Color(UiKit.GOLD_DARK, 0.9), 2.0, true)
	if acting:
		UiKit.draw_hgradient(self, Rect2(0, 0, size.x * 0.5, size.y), Color(tint, 0.35), Color(tint, 0.0))
	var x = 18.0
	var center_y = size.y * 0.5
	UiKit.draw_icon(self, "pouch", Rect2(Vector2(x, center_y - 11), Vector2(22, 22)), UiKit.GOLD)
	UiKit.draw_text_left(self, UiKit.bold_font(), str(gold), Vector2(x + 26, center_y), 20, UiKit.GOLD_BRIGHT, -1.0, 2)
	x += 74.0
	UiKit.draw_icon(self, "cards_stack", Rect2(Vector2(x, center_y - 10), Vector2(20, 20)), UiKit.PAPER_DIM)
	UiKit.draw_text_left(self, UiKit.bold_font(), str(deck), Vector2(x + 24, center_y), 17, UiKit.PAPER, -1.0, 2)
	x += 62.0
	UiKit.draw_icon(self, "hand_card", Rect2(Vector2(x, center_y - 10), Vector2(20, 20)), UiKit.PAPER_DIM)
	UiKit.draw_text_left(self, UiKit.bold_font(), str(hand), Vector2(x + 24, center_y), 17, UiKit.PAPER, -1.0, 2)
	var name_right = size.x - (52.0 if show_menu else 14.0)
	var name_left = x + 56.0
	if not connection.is_empty():
		name_left = _draw_connection(Vector2(name_left, center_y)) + 8.0
	var font = UiKit.title_font()
	var font_size = UiKit.fit_size(font, player_name, name_right - name_left, 21, 12)
	var width = font.get_string_size(player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	UiKit.draw_text_left(self, font, player_name, Vector2(name_right - width, center_y), font_size, tint.lightened(0.45), -1.0, 2)
	if show_menu:
		var menu = menu_rect()
		UiKit.draw_round_rect(self, menu, Color(1, 1, 1, 0.12 if _menu_hover else 0.04), 4.0, Color(UiKit.GOLD, 0.6 if _menu_hover else 0.3), 1.0)
		for line in range(3):
			var y = menu.position.y + 11 + line * 7
			draw_line(Vector2(menu.position.x + 9, y), Vector2(menu.end.x - 9, y), UiKit.PAPER, 2.0)

## Signal bars (1-3 lit by quality, crossed out when lost) and the ping.
## Returns the right edge of what was drawn.
func _draw_connection(left_center: Vector2) -> float:
	var level = str(connection.get("level", "unknown"))
	var lit = {"good": 3, "fair": 2, "poor": 1}.get(level, 0)
	var color = {"good": UiKit.HEAL, "fair": UiKit.GOLD, "poor": UiKit.DAMAGE, "lost": UiKit.DAMAGE}.get(level, UiKit.MUTED)
	for bar in range(3):
		var height = 6.0 + bar * 5.0
		draw_rect(Rect2(left_center.x + bar * 6.0, left_center.y + 8.0 - height, 4.0, height), color if bar < lit else Color(UiKit.MUTED, 0.45))
	var right = left_center.x + 18.0
	if level == "lost":
		draw_line(Vector2(left_center.x - 1, left_center.y - 8), Vector2(right, left_center.y + 8), UiKit.DAMAGE, 2.0)
	var ping = int(connection.get("ping", -1))
	if ping >= 0 and level != "lost":
		var text = UiKit.t("NET_PING", {"ms": ping})
		UiKit.draw_text_left(self, UiKit.body_font(), text, Vector2(right + 5.0, left_center.y), 12, UiKit.PAPER_DIM, -1.0, 2)
		right += 5.0 + UiKit.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	return right
