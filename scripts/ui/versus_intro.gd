extends Control
## The match intro, after Classic's match-load screen: the two armies' five
## heroes face each other, the opponent's row above and yours below, each
## player's name plate (Steam avatar and name online) beside its row, and a
## seal stamped between them. Then the board takes over. A click, Space,
## Enter or Esc skips it. It only shows public information: the heroes come
## from the match view's rosters (public, as in Classic), never deck lists or
## deck names.
##
## Timeline (scaled by the animation speed): the backdrop fades in, the plates
## slide in, the heroes are dealt in pairs, the seal stamps with a bell, a
## hold with "Click to continue", then everything fades out (3.75 s in all).

signal finished

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
## A name plate's smallest size; beside the rows it widens into the free
## margin up to PLATE_MAX_WIDTH (long Steam names), and a name that still
## does not fit is cut with an ellipsis.
const PLATE = Vector2(240, 96)
const PLATE_MAX_WIDTH = 340.0
## Gap between a plate and its row of heroes.
const PLATE_GAP = 28.0
const DEAL_START = 0.35
const DEAL_STEP = 0.12
const DEAL_TIME = 0.3
const STAMP_AT = 1.25
const HINT_AT = 2.0
const OUT_AT = 3.4
const OUT_TIME = 0.35
const SKIP_TIME = 0.15

## {"top": side, "bottom": side}; a side is {"name", "steam_id", "heroes"
## (five card ids), "caption"}.
var info: Dictionary = {}
var steam_bridge: Node
var sfx: Node
var playing: bool = false
var _t: float = 0.0
var _out_at: float = OUT_AT
var _out_time: float = OUT_TIME
## CardViews per row: [top, bottom].
var _cards: Array = [[], []]
## Each card's resting [position, rotation].
var _rest: Array = [[], []]
var _plates: Array = [Rect2(), Rect2()]
var _plates_beside: bool = true
var _dealt: int = -1
var _stamped: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)

## Plays the intro for `new_info` and returns when it is over (or skipped).
func play(new_info: Dictionary) -> void:
	if playing:
		abort()
	info = new_info
	_clear_cards()
	for row in range(2):
		var side: Dictionary = info.get("top" if row == 0 else "bottom", {})
		for hero_id in side.get("heroes", []):
			var card = CardView.new()
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.setup(str(hero_id))
			card.modulate.a = 0.0
			add_child(card)
			_cards[row].append(card)
	_t = 0.0
	_out_at = OUT_AT
	_out_time = OUT_TIME
	_dealt = -1
	_stamped = false
	playing = true
	visible = true
	_layout()
	_update()
	set_process(true)
	if steam_bridge != null and steam_bridge.has_signal("profile_changed") and not steam_bridge.profile_changed.is_connected(_on_profile):
		steam_bridge.profile_changed.connect(_on_profile)
	await finished

## Ends the intro at once (a click, a key, a new match).
func skip() -> void:
	if not playing:
		return
	if _t < _out_at:
		_out_at = _t
		_out_time = SKIP_TIME

## Stops without the fade (the match was reset under it).
func abort() -> void:
	if playing:
		_finish()

func _finish() -> void:
	playing = false
	visible = false
	set_process(false)
	_clear_cards()
	finished.emit()

func _clear_cards() -> void:
	for row in _cards:
		for card in row:
			UiKit.discard(card)
	_cards = [[], []]
	_rest = [[], []]

func _exit_tree() -> void:
	# The queue awaiting the intro must never hang (the cards go with this
	# node: no child is removed while it leaves the tree).
	if playing:
		playing = false
		set_process(false)
		finished.emit()

func _on_profile(_steam_id: int) -> void:
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and playing:
		_layout()
		_update()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip()
		accept_event()

func _process(delta: float) -> void:
	_t += delta * maxf(0.1, AnimationQueue.speed)
	_update()
	if _t >= _out_at + _out_time:
		_finish()

## Card size scale for the window height (153x223 at 900 px).
func card_scale() -> float:
	return clampf(size.y / 900.0, 0.7, 1.1) * 0.85

func _layout() -> void:
	var s = card_scale()
	var card_size = CardView.BASE * s
	var gap = 18.0 * s
	var row_width = card_size.x * 5.0 + gap * 4.0
	var left = (size.x - row_width) * 0.5
	var centers = [size.y * 0.245, size.y * 0.705]
	_rest = [[], []]
	for row in range(2):
		for index in range(_cards[row].size()):
			var card: Control = _cards[row][index]
			card.set_size_keep(card_size)
			var x = left + index * (card_size.x + gap)
			var y = centers[row] - card_size.y * 0.5
			# The middle card stands out, away from the centre, and the outer
			# ones lean a little (a flat nod to Classic's tilted rows).
			if index == 2:
				y += -14.0 * s if row == 0 else 14.0 * s
			var lean = [-2.0, -1.0, 0.0, 1.0, 2.0][index] * (1.0 if row == 0 else -1.0)
			_rest[row].append([Vector2(x, y), deg_to_rad(lean)])
	_plates_beside = left - PLATE_GAP - PLATE.x >= 16.0
	if _plates_beside:
		var plate = Vector2(clampf(left - PLATE_GAP - 16.0, PLATE.x, PLATE_MAX_WIDTH), PLATE.y)
		_plates = [Rect2(Vector2(left - PLATE_GAP - plate.x, centers[0] - card_size.y * 0.5 + 6.0), plate),
			Rect2(Vector2(left + row_width + PLATE_GAP, centers[1] + card_size.y * 0.5 - plate.y - 6.0), plate)]
	else:
		var plate = Vector2(minf(PLATE_MAX_WIDTH, row_width * 0.5 - 12.0), PLATE.y)
		_plates = [Rect2(Vector2(left, maxf(8.0, centers[0] - card_size.y * 0.5 - plate.y - 14.0)), plate),
			Rect2(Vector2(left + row_width - plate.x, minf(size.y - plate.y - 8.0, centers[1] + card_size.y * 0.5 + 14.0)), plate)]

func _ease(value: float) -> float:
	var x = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

## The whole intro's opacity (the fade in and out).
func _alpha() -> float:
	var fade_in = clampf(_t / 0.25, 0.0, 1.0)
	var fade_out = 1.0 - clampf((_t - _out_at) / maxf(0.01, _out_time), 0.0, 1.0)
	return minf(fade_in, fade_out)

func _update() -> void:
	var alpha = _alpha()
	for row in range(2):
		for index in range(_cards[row].size()):
			if index >= _rest[row].size():
				continue
			var card: Control = _cards[row][index]
			var progress = _ease((_t - (DEAL_START + DEAL_STEP * index)) / DEAL_TIME)
			var rest: Array = _rest[row][index]
			var offset = Vector2(0, -40.0 if row == 0 else 40.0) * (1.0 - progress)
			card.position = rest[0] + offset
			card.rotation = rest[1]
			card.scale = Vector2.ONE * (0.9 + 0.1 * progress)
			card.modulate.a = progress * alpha
			if progress > 0.0 and index > _dealt and row == 1:
				_dealt = index
				if sfx != null and index % 2 == 0 and _t < _out_at:
					sfx.play("switch-a")
	if not _stamped and _t >= STAMP_AT and _t < _out_at:
		_stamped = true
		if sfx != null:
			sfx.play("versus")
	queue_redraw()

func _draw() -> void:
	var alpha = _alpha()
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.012, 0.012, 0.02, 0.97 * alpha))
	var art = UiKit.ui_art("board_overview")
	if art != null:
		UiKit.draw_cover(self, art, rect, Vector2(0.5, 0.5), Color(0.24, 0.22, 0.24, 0.85 * alpha))
	UiKit.draw_vgradient(self, Rect2(0, 0, size.x, size.y * 0.3), Color(0, 0, 0, 0.7 * alpha), Color(0, 0, 0, 0))
	UiKit.draw_vgradient(self, Rect2(0, size.y * 0.7, size.x, size.y * 0.3), Color(0, 0, 0, 0), Color(0, 0, 0, 0.75 * alpha))
	_draw_web(alpha)
	_draw_centre(alpha)
	for row in range(2):
		_draw_plate(row, alpha)
	if _t >= HINT_AT:
		var hint_alpha = clampf((_t - HINT_AT) / 0.4, 0.0, 1.0) * alpha
		UiKit.draw_text(self, UiKit.body_font(), UiKit.t("VERSUS_CONTINUE"), Vector2(size.x * 0.5, size.y - 34.0), 16,
			Color(UiKit.PAPER, 0.62 * hint_alpha), -1.0, 2)

## Faint gold lines of a war map behind the rows.
func _draw_web(alpha: float) -> void:
	var c = size * 0.5
	var color = Color(UiKit.GOLD, 0.1 * alpha)
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y)]:
		draw_line(c, corner, color, 1.0, true)
	for radius in [120.0, 250.0, 420.0]:
		draw_arc(c, radius * card_scale() / 0.85, 0.0, TAU, 96, Color(UiKit.GOLD, 0.06 * alpha), 1.0, true)

## The ring and the seal between the rows.
func _draw_centre(alpha: float) -> void:
	var c = Vector2(size.x * 0.5, size.y * 0.475)
	var s = card_scale() / 0.85
	var stamp = clampf((_t - STAMP_AT) / 0.2, 0.0, 1.0)
	var glow = clampf(1.0 - (_t - STAMP_AT) / 0.8, 0.0, 1.0) if _t >= STAMP_AT else 0.0
	var ring_alpha = clampf(_t / 0.6, 0.0, 1.0) * alpha
	var radius = 74.0 * s
	draw_circle(c, radius + 30.0 * glow, Color(UiKit.GOLD_BRIGHT, 0.12 * glow * alpha))
	draw_arc(c, radius, 0.0, TAU, 96, Color(UiKit.GOLD, 0.75 * ring_alpha), 2.5, true)
	draw_arc(c, radius + 9.0 * s, 0.0, TAU, 96, Color(UiKit.GOLD, 0.3 * ring_alpha), 1.0, true)
	# Three faint lines, a triangle inside the ring.
	var points = PackedVector2Array()
	for index in range(4):
		var angle = -PI * 0.5 + TAU * index / 3.0
		points.append(c + Vector2(cos(angle), sin(angle)) * radius * 0.92)
	draw_polyline(points, Color(UiKit.GOLD_BRIGHT, 0.32 * ring_alpha), 1.5, true)
	if _t < STAMP_AT:
		return
	var seal_size = 96.0 * s * (1.6 - 0.6 * _ease(stamp))
	var seal_alpha = minf(1.0, stamp * 2.0) * alpha
	var seal = Rect2(c - Vector2(seal_size, seal_size) * 0.5, Vector2(seal_size, seal_size))
	UiKit.draw_round_rect(self, seal, Color(UiKit.CINNABAR, seal_alpha), seal_size * 0.12)
	UiKit.draw_round_rect(self, seal.grow(-seal_size * 0.09), Color.TRANSPARENT, seal_size * 0.08, Color(UiKit.PAPER, 0.75 * seal_alpha), maxf(1.0, seal_size * 0.05))
	UiKit.draw_text(self, UiKit.kai_font(), UiKit.t("VERSUS_SEAL"), c, int(seal_size * 0.46), Color(UiKit.PAPER, seal_alpha), seal_size * 0.78)

## The plate's name area at rest, in this control (row 0 top, 1 bottom).
func name_box(row: int) -> Rect2:
	if row < 0 or row >= _plates.size():
		return Rect2()
	var plate: Rect2 = _plates[row]
	var text_left = plate.position.x + 16.0 + 64.0 + 14.0
	return Rect2(Vector2(text_left, plate.position.y + 24.0), Vector2(plate.end.x - text_left - 12.0, 32.0))

## The name as the plate draws it: [text, font size] (shrunk, then elided).
static func plate_name(text: String, width: float) -> Array:
	var font = UiKit.title_font()
	var fitted = UiKit.fit_size(font, text, width, 26, maxi(8, int(26 * 0.55)))
	return [UiKit.elide(font, text, width, fitted), fitted]

## A player's name plate: avatar, name and caption, sliding in from its side.
func _draw_plate(row: int, alpha: float) -> void:
	var side: Dictionary = info.get("top" if row == 0 else "bottom", {})
	if side.is_empty() or row >= _plates.size():
		return
	var progress = _ease((_t - 0.15) / 0.35)
	var plate: Rect2 = _plates[row]
	var direction = -1.0 if (row == 0) == _plates_beside else 1.0
	plate.position.x += direction * 60.0 * (1.0 - progress)
	var plate_alpha = progress * alpha
	UiKit.draw_round_rect(self, plate, Color(UiKit.INK_PANEL, 0.9 * plate_alpha), 6.0, Color(UiKit.GOLD_DARK, 0.9 * plate_alpha), 1.0)
	var avatar_rect = Rect2(plate.position + Vector2(16, 16), Vector2(64, 64))
	var heroes: Array = side.get("heroes", [])
	draw_avatar(self, avatar_rect, steam_bridge, int(side.get("steam_id", 0)), str(side.get("name", "")), plate_alpha,
		str(heroes[0]) if not heroes.is_empty() else "")
	var text_left = avatar_rect.end.x + 14.0
	var width = plate.end.x - text_left - 12.0
	# draw_text_left shrinks a long name, then cuts it with an ellipsis: it
	# never leaves the plate.
	UiKit.draw_text_left(self, UiKit.title_font(), str(side.get("name", "")), Vector2(text_left, plate.position.y + 40.0), 26,
		Color(UiKit.PAPER, plate_alpha), width, 3)
	var caption = str(side.get("caption", ""))
	if not caption.is_empty() and caption != str(side.get("name", "")):
		var tint = UiKit.ENEMY_TINT if row == 0 else UiKit.ALLY_TINT
		UiKit.draw_text_left(self, UiKit.body_font(), caption, Vector2(text_left, plate.position.y + 72.0), 15,
			Color(tint.lightened(0.35), plate_alpha), width, 2)

## A player's picture: the Steam avatar when there is one, otherwise the
## portrait of `fallback_card` (the army's first hero, public), otherwise a
## seal with the first character of the name. Shared with the room screen.
static func draw_avatar(canvas: CanvasItem, rect: Rect2, bridge: Node, steam_id: int, player_name: String, alpha: float = 1.0,
		fallback_card: String = "") -> void:
	var texture: Texture2D = null
	if bridge != null and steam_id != 0 and bridge.has_method("avatar"):
		texture = bridge.avatar(steam_id, rect.size.x > 72.0)
	UiKit.draw_round_rect(canvas, rect.grow(2.0), Color(0, 0, 0, 0.6 * alpha), 6.0, Color(UiKit.GOLD_DARK, alpha), 1.5)
	if texture != null:
		canvas.draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))
		return
	if not fallback_card.is_empty():
		var entry: Dictionary = CardArt.art(fallback_card)
		if entry.has("texture"):
			# The portrait crop of CardArt.draw_portrait, faded with the plate.
			var region: Rect2 = entry.region
			var side = region.size.x * 0.5
			var face = Rect2(region.position + Vector2((region.size.x - side) * 0.5, region.size.y * 0.1), Vector2(side, side))
			UiKit.draw_cover(canvas, entry.texture, rect, Vector2(0.5, 0.5), Color(1, 1, 1, alpha), face)
			return
	UiKit.draw_vgradient(canvas, rect, Color(0.2, 0.17, 0.14, alpha), Color(0.1, 0.08, 0.07, alpha))
	var initial = player_name.strip_edges().left(1).to_upper() if not player_name.strip_edges().is_empty() else "?"
	var seal = rect.size.x * 0.62
	UiKit.draw_round_rect(canvas, Rect2(rect.get_center() - Vector2(seal, seal) * 0.5, Vector2(seal, seal)), Color(UiKit.CINNABAR, alpha), seal * 0.12)
	UiKit.draw_text(canvas, UiKit.kai_font(), initial, rect.get_center(), int(seal * 0.62), Color(UiKit.PAPER, alpha))

func refresh_text() -> void:
	queue_redraw()

## The intro's content for a match view, from public information only: each
## seat's five heroes (its roster, in deployment order), names and Steam ids.
## Bottom is you (online: your seat; against the AI: seat 0), or Player 1 in
## hot-seat play; deck names never appear.
static func versus_info(view: Dictionary, viewer: int, mode: int, names: Dictionary) -> Dictionary:
	var players = view.get("players", [])
	if not players is Array or players.size() != 2:
		return {}
	var hot_seat = mode == 1
	var bottom_seat = 0 if hot_seat else clampi(viewer, 0, 1)
	var result: Dictionary = {}
	for key in ["top", "bottom"]:
		var seat = bottom_seat if key == "bottom" else 1 - bottom_seat
		var heroes: Array = []
		var roster = players[seat].get("roster", [])
		if roster is Array:
			for hero in roster.slice(0, 5):
				if hero is Dictionary:
					heroes.append(str(hero.get("card", "")))
		var entry: Dictionary = names.get(key, {})
		result[key] = {"seat": seat, "heroes": heroes, "name": str(entry.get("name", "")),
			"steam_id": int(entry.get("steam_id", 0)), "caption": str(entry.get("caption", ""))}
	return result
