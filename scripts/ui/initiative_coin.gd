extends Control
## The big initiative coin in the bottom-right socket. Glowing means you hold
## initiative and may act; clicking it passes. In the shop and deployment it
## is the "done" button. The caption under it says what a click does and who
## holds initiative.

signal pressed

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const RADIUS = 66.0
## Least gap between a caption and the right edge of the parent.
const EDGE_MARGIN = 8.0
## Height of the hint under the caption plate (up to two lines).
const SUB_HEIGHT = 38.0
## Bottom of the lowest caption line (coin centre, plate, hint): the parent
## keeps whatever sits below the coin clear of it.
const CAPTION_BOTTOM = RADIUS + 14.0 + RADIUS + 26.0 + 19.0 + SUB_HEIGHT

var lit: bool = false
var enabled: bool = false
var caption: String = ""
var sub_caption: String = ""
## Glyph on the coin face (令 "command" by default).
var glyph: String = "令"
var _hover: bool = false
var _spin: float = 0.0
var _press: float = 0.0
var _sub_text: TextParagraph
var _sub_key: String = ""

func _init() -> void:
	size = Vector2(190, 200)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())

func set_state(is_lit: bool, is_enabled: bool, caption_text: String, sub_text: String = "") -> void:
	lit = is_lit
	enabled = is_enabled
	caption = caption_text
	sub_caption = sub_text
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	queue_redraw()

func center() -> Vector2:
	return Vector2(size.x * 0.5, RADIUS + 14.0)

func _process(delta: float) -> void:
	_spin = fmod(_spin + delta * (0.9 if lit else 0.2), TAU)
	if _press > 0.0:
		_press = maxf(0.0, _press - delta * 4.0)
	if lit or _press > 0.0:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if enabled and Vector2(event.position).distance_to(center()) <= RADIUS + 10.0:
			_press = 1.0
			pressed.emit()
		accept_event()

func _draw() -> void:
	var c = center()
	var squash = 1.0 - _press * 0.06
	# Socket.
	draw_circle(c + Vector2(0, 6), RADIUS + 13.0, Color(0, 0, 0, 0.55))
	draw_circle(c, RADIUS + 12.0, Color(0.22, 0.21, 0.2))
	draw_arc(c, RADIUS + 12.0, 0.0, TAU, 64, Color(0.48, 0.45, 0.4), 2.0, true)
	draw_circle(c, RADIUS + 5.0, Color(0.07, 0.07, 0.08))
	if lit:
		var light = UiKit.particle("light_01")
		for ring in range(3):
			var radius = RADIUS * (1.55 + ring * 0.12) + sin(_spin * 2.0 + ring) * 4.0
			if light != null:
				draw_set_transform(c, _spin * (1.0 if ring % 2 == 0 else -0.7), Vector2.ONE)
				draw_texture_rect(light, Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0), false, Color(1.0, 0.82, 0.4, 0.22 - ring * 0.05))
				draw_set_transform(Vector2.ZERO)
		draw_arc(c, RADIUS + 3.0, 0.0, TAU, 64, Color(1.0, 0.85, 0.45, 0.85), 4.0, true)
	var radius_now = RADIUS * squash
	var face = Color("c99a3d") if lit else Color("6d6250")
	var face_dark = Color("8a6420") if lit else Color("4a4237")
	if _hover and enabled:
		face = face.lightened(0.12)
	# Coin body: rim, bevel and face.
	draw_circle(c, radius_now, face_dark)
	draw_circle(c, radius_now - 5.0, face)
	for ring in range(6):
		draw_circle(c + Vector2(-ring * 1.4, -ring * 1.6), radius_now * (0.82 - ring * 0.06), Color(face.lightened(0.05 + ring * 0.035), 0.32))
	draw_arc(c, radius_now - 9.0, 0.0, TAU, 64, Color(face_dark, 0.9), 2.0, true)
	draw_arc(c, radius_now - 14.0, 0.0, TAU, 64, Color(1, 1, 1, 0.12), 1.0, true)
	# Lattice notches around the rim.
	for notch in range(16):
		var angle = TAU * notch / 16.0 + _spin * 0.05
		var outer = c + Vector2(cos(angle), sin(angle)) * (radius_now - 2.0)
		var inner = c + Vector2(cos(angle), sin(angle)) * (radius_now - 8.0)
		draw_line(inner, outer, Color(face_dark.darkened(0.2), 0.8), 2.0, true)
	var token = UiKit.tex("res://assets/art/ui/initiative_token.png")
	if token != null:
		draw_texture_rect(token, Rect2(c - Vector2(radius_now, radius_now) * 0.82, Vector2(radius_now, radius_now) * 1.64), false,
			Color.WHITE if lit else Color(0.6, 0.6, 0.6))
	else:
		UiKit.draw_text(self, UiKit.title_font(), glyph, c + Vector2(1.5, 3), int(radius_now * 0.95), Color(0.25, 0.14, 0.03, 0.7))
		UiKit.draw_text(self, UiKit.title_font(), glyph, c, int(radius_now * 0.95), Color("fff0c4") if lit else Color("cbbfa8"))
	draw_arc(c, radius_now - 2.0, PI * 1.05, PI * 1.75, 24, Color(1, 1, 1, 0.35 if lit else 0.15), 3.0, true)
	# Captions.
	var rects = caption_rects()
	if rects.has("plate"):
		var plate: Rect2 = rects.plate
		UiKit.draw_round_rect(self, plate, Color(0.06, 0.06, 0.07, 0.88), 15.0, Color(UiKit.GOLD, 0.8) if enabled else Color(1, 1, 1, 0.15), 1.0)
		UiKit.draw_text(self, UiKit.title_font(), caption, plate.get_center(), 21, UiKit.GOLD_BRIGHT if enabled else UiKit.PAPER_DIM)
	if rects.has("hint"):
		var origin: Vector2 = rects.hint.position
		_sub_text.draw_outline(get_canvas_item(), origin, 2, Color(0, 0, 0, 0.85))
		_sub_text.draw(get_canvas_item(), origin, UiKit.PAPER_DIM)

## Local rectangles of the caption plate ("plate") and the hint under it
## ("hint"), each present only when shown. Both stay clear of the parent's
## right edge.
func caption_rects() -> Dictionary:
	var rects = {}
	var c = center()
	var caption_y = c.y + RADIUS + 26.0
	var right_limit = get_parent_area_size().x - position.x - EDGE_MARGIN
	if not caption.is_empty():
		var width = UiKit.title_font().get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 26.0
		rects.plate = Rect2(Vector2(minf(c.x - width * 0.5, right_limit - width), caption_y - 15.0), Vector2(width, 30.0))
	if not sub_caption.is_empty():
		# Up to two centred lines under the caption plate.
		var width = size.x + 40.0
		var key = "%s|%s" % [sub_caption, TranslationServer.get_locale()]
		# A caption that needs two lines is split evenly (no one-word last line).
		var full = UiKit.body_font().get_string_size(sub_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		if full > width:
			width = minf(width, full * 0.56 + 16.0)
		if key != _sub_key:
			_sub_key = key
			_sub_text = UiKit.fit_paragraph(sub_caption, UiKit.body_font(), Vector2(width, SUB_HEIGHT), 14, 11)
		rects.hint = Rect2(Vector2(minf(c.x - width * 0.5, right_limit - width), caption_y + 19.0), Vector2(width, _sub_text.get_size().y))
	return rects
