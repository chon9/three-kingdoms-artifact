extends Control
## Card history: a strip of small tiles hanging under the lane overview HUD,
## newest on the left, as Classic showed the last action as a mini card on the
## HUD. Each tile is a played card, an activated ability, a combat, a pass, a
## shop visit or the result: the card's portrait, a bar in its player's colour
## (yours jade, the opponent's red), the lane letter and, for a targeted play,
## the target's portrait in the corner. Rules that separate tiles mark a new
## lane (a thin gold rule) or a new round (a rule and "R3").
##
## Hovering a tile shows the card large with what happened (the play and the
## effects it caused, from the same text as the log); a click opens the full
## log at that event; a right-click inspects the card; the wheel pages back.
##
## Privacy: the rail reads only the shown player's view (the events after
## player_view's private-field filter and that player's own purchases). The
## opponent's purchases never name the item, exactly as the log shows them.

signal log_requested(event_id: int)
signal inspect_requested(card_id: String)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const EventText = preload("res://scripts/core/event_text.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
const HEIGHT = 50.0
const TILE = Vector2(40, 42)
const PASS_W = 14.0
const GAP = 4.0
const LANE_RULE = 9.0
const ROUND_RULE = 30.0
const LOG_BUTTON = Vector2(30, 36)
## Effects listed under a tile's headline in its hover card, at most.
const MAX_LINES = 6
## Events that start a tile; every other event until the next boundary
## belongs to the tile before it.
const HEADLINES = ["play", "ability", "combat", "buy", "pass", "concede", "win", "draw"]
## Events that end a tile's effects (the next lane, the shop, a deployment).
const BOUNDARIES = ["lane_open", "shop_open", "deployment", "deployment_placed", "deployment_revealed", "match_start"]

## Tile models, oldest first (see build_tiles).
var tiles: Array = []
var viewer: int = 0
var events: Array = []
## Absolute id of the first event in `events` (event_seq - events.size()).
var base_id: int = 0
## Tiles of events newer than this id are not shown yet (their animation has
## not played); -1 shows everything.
var reveal_limit: int = -1
## Your purchases by event id, learned while they were in your view (the view
## forgets them at the next shop).
var own_items: Dictionary = {}
## Third-person player names for the hover text (the log's names).
var names_source: Callable
## The board (its zoom fades the rail in the overview).
var board: Control
## Newest tiles skipped by the wheel.
var scroll: int = 0
var hovered_id: int = -1
## Tile rects drawn last: [[Rect2, tile index]].
var _rects: Array = []
var _log_rect: Rect2
var _more_rect: Rect2
var _newest_id: int = -1
var _arrive: float = 1.0
var _glow: float = 0.0
var preview: PreviewCard

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(534, HEIGHT)
	preview = PreviewCard.new()
	preview.name = "Preview"
	preview.visible = false
	add_child(preview)

## Forgets everything (a new match, or another player's point of view).
func clear() -> void:
	tiles = []
	events = []
	own_items = {}
	reveal_limit = -1
	scroll = 0
	hovered_id = -1
	_newest_id = -1
	preview.visible = false
	queue_redraw()

## Rebuilds the tiles from `view` as `new_viewer` sees it.
func refresh(view: Dictionary, new_viewer: int) -> void:
	if new_viewer != viewer:
		own_items = {}
		scroll = 0
	viewer = new_viewer
	events = view.get("events", [])
	base_id = int(view.get("event_seq", 0)) - events.size()
	_learn_own_items(view)
	tiles = build_tiles(events, view, viewer, base_id, own_items)
	_after_change()

## Shows tiles up to event id `limit` (the event whose animation is playing);
## -1 shows every tile.
func reveal(limit: int) -> void:
	if reveal_limit == limit:
		return
	reveal_limit = limit
	_after_change()

func _after_change() -> void:
	var newest = _visible_tiles()
	var newest_id = int(newest.back().id) if not newest.is_empty() else -1
	if newest_id != _newest_id:
		if _newest_id != -1 and newest_id > _newest_id and not AnimationQueue.instant:
			_arrive = 0.0
			_glow = 1.0
		_newest_id = newest_id
	if hovered_id != -1 and _tile_by_id(hovered_id).is_empty():
		_set_hovered(-1)
	queue_redraw()

## The tiles shown now (revealed), oldest first.
func _visible_tiles() -> Array:
	if reveal_limit < 0:
		return tiles
	return tiles.filter(func(tile): return int(tile.id) <= reveal_limit)

func _tile_by_id(id: int) -> Dictionary:
	for tile in tiles:
		if int(tile.id) == id:
			return tile
	return {}

## Your own purchases in the shown view: `bought` lists them in order since the
## last shop opened, so the k-th own buy event after it is bought[k]. With
## that shop's opening already out of the event window the order is unknown,
## and nothing is learned (earlier lessons stay).
func _learn_own_items(view: Dictionary) -> void:
	var players = view.get("players", [])
	if not players is Array or viewer < 0 or viewer >= players.size():
		return
	var bought: Array = players[viewer].get("bought", [])
	var start = -1
	for index in range(events.size() - 1, -1, -1):
		if str(events[index].get("k", "")) == "shop_open":
			start = index
			break
	if start == -1:
		return
	var k = 0
	for index in range(start, events.size()):
		var event: Dictionary = events[index]
		if str(event.get("k", "")) == "buy" and int(event.get("p", -1)) == viewer:
			if k < bought.size():
				own_items[base_id + index] = str(bought[k])
			k += 1

# --- Tile models (pure, tested) ---------------------------------------------------

## The lane each event happened in (-1 in the shop and deployment), walking
## back from the end: a combat names its lane, a lane_open separates a lane
## from the one before, the shop follows the right lane and a deployment
## starts the shop phase's end. No engine change is needed (the events keep
## their shape, so state digests and replays are untouched).
static func event_lanes(event_list: Array, view: Dictionary) -> Array:
	var lanes: Array = []
	lanes.resize(event_list.size())
	var phase = str(view.get("phase", ""))
	var current = int(view.get("lane", 0)) if phase in ["action", "finished"] else -1
	for index in range(event_list.size() - 1, -1, -1):
		var event: Dictionary = event_list[index]
		match str(event.get("k", "")):
			"combat":
				current = int(event.get("lane", 0))
				lanes[index] = current
			"lane_open":
				lanes[index] = int(event.get("lane", 0))
				current = int(event.get("lane", 0)) - 1
			"shop_open":
				lanes[index] = -1
				current = 2
			"deployment", "deployment_placed", "deployment_revealed", "match_start":
				lanes[index] = -1
				current = -1
			_:
				lanes[index] = current
	return lanes

## The round of each event: the shown round, less the deployments after it.
static func event_rounds(event_list: Array, view: Dictionary) -> Array:
	var rounds: Array = []
	rounds.resize(event_list.size())
	var current = int(view.get("round", 1))
	for index in range(event_list.size() - 1, -1, -1):
		rounds[index] = current
		if str(event_list[index].get("k", "")) == "deployment":
			current -= 1
	return rounds

## Tile models, oldest first: {"id" (the event's absolute id), "kind" (play,
## ability, combat, buy, pass, end), "p", "card", "target_card", "lane",
## "round", "index" (in `event_list`), "lines" (indices of the events it
## caused), and per kind "count"/"gold" (buys), "damage" ([yours, theirs]) and
## "fall" ("tower", "ancient" or "") for combat, "end" (win, draw, concede).
## The opponent's purchases merge into one tile per shop and never carry a
## card; your own carry the item when `own` (event id -> card) knows it.
static func build_tiles(event_list: Array, view: Dictionary, shown_viewer: int, first_id: int, own: Dictionary = {}) -> Array:
	var lanes = event_lanes(event_list, view)
	var rounds = event_rounds(event_list, view)
	var result: Array = []
	var open: Dictionary = {}
	for index in range(event_list.size()):
		var event: Dictionary = event_list[index]
		var key = str(event.get("k", ""))
		if key in BOUNDARIES:
			open = {}
			continue
		if key not in HEADLINES:
			if not open.is_empty():
				open.lines.append(index)
				if key in ["tower_fall", "ancient_fall"] and str(open.kind) == "combat":
					open.fall = "ancient" if key == "ancient_fall" or str(open.fall) == "ancient" else "tower"
			continue
		var player = int(event.get("p", -1))
		var last: Dictionary = result.back() if not result.is_empty() else {}
		# The opponent's purchases in one shop share a tile (how many, for how
		# much); the result after a concession joins the concession's tile.
		if key == "buy" and player != shown_viewer and str(last.get("kind", "")) == "buy" and int(last.p) == player \
				and int(last.round) == int(rounds[index]) and int(lanes[index]) == -1:
			last.count = int(last.count) + 1
			last.gold = int(last.gold) + int(event.get("gold", 0))
			last.lines.append(index)
			open = last
			continue
		if key in ["win", "draw"] and str(last.get("end", "")) == "concede":
			last.lines.append(index)
			continue
		var tile = {"id": first_id + index, "kind": key, "p": player, "card": "", "target_card": "",
			"lane": int(lanes[index]), "round": int(rounds[index]), "index": index, "lines": []}
		if key == "play":
			tile.card = str(event.get("card", ""))
			tile.target_card = str(event.get("target_card", ""))
		elif key == "ability":
			tile.card = str(event.get("card", ""))
		elif key == "combat":
			var damage: Array = event.get("damage", [0, 0])
			var dealt = [int(damage[0]), int(damage[1])] if damage.size() == 2 else [0, 0]
			tile.damage = [dealt[clampi(shown_viewer, 0, 1)], dealt[1 - clampi(shown_viewer, 0, 1)]]
			tile.fall = ""
			tile.p = -1
		elif key == "buy":
			tile.count = 1
			tile.gold = int(event.get("gold", 0))
			if player == shown_viewer:
				tile.card = str(own.get(first_id + index, ""))
		elif key in ["concede", "win", "draw"]:
			tile.kind = "end"
			tile.end = key
		result.append(tile)
		open = {} if key == "pass" else tile
	return result

# --- Input --------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(_tile_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				scroll = clampi(scroll + 1, 0, maxi(0, _visible_tiles().size() - 1))
				queue_redraw()
			MOUSE_BUTTON_WHEEL_DOWN:
				scroll = maxi(0, scroll - 1)
				queue_redraw()
			MOUSE_BUTTON_LEFT:
				if _log_rect.has_point(event.position):
					log_requested.emit(-1)
				elif _more_rect.has_point(event.position):
					scroll = clampi(scroll + 4, 0, maxi(0, _visible_tiles().size() - 1))
					queue_redraw()
				else:
					var id = _tile_at(event.position)
					if id != -1:
						log_requested.emit(id)
			MOUSE_BUTTON_RIGHT:
				var tile = _tile_by_id(_tile_at(event.position))
				if not str(tile.get("card", "")).is_empty():
					inspect_requested.emit(str(tile.card))
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hovered(-1)

func _get_tooltip(at_position: Vector2) -> String:
	return UiKit.t("HISTORY_OPEN_LOG") if _log_rect.has_point(at_position) else ""

func _tile_at(point: Vector2) -> int:
	for entry in _rects:
		if entry[0].has_point(point):
			return int(entry[1])
	return -1

func _set_hovered(id: int) -> void:
	if id == hovered_id:
		return
	hovered_id = id
	queue_redraw()
	var tile = _tile_by_id(id)
	if tile.is_empty():
		preview.visible = false
		return
	var rect = Rect2()
	for entry in _rects:
		if int(entry[1]) == id:
			rect = entry[0]
	preview.show_tile(tile, _headline(tile), _detail_lines(tile), _footer(tile))
	var parent_width = get_parent_area_size().x if get_parent() != null else size.x
	var x = clampf(rect.position.x - 12.0, 4.0 - position.x, parent_width - position.x - preview.size.x - 8.0)
	preview.position = Vector2(x, HEIGHT + 6.0)

## Hover text (also the test facade).
func hover_text(id: int) -> String:
	var tile = _tile_by_id(id)
	if tile.is_empty():
		return ""
	return "\n".join([_headline(tile)] + _detail_lines(tile) + [_footer(tile)])

func _names() -> Array:
	return names_source.call() if names_source.is_valid() else []

func _headline(tile: Dictionary) -> String:
	var event: Dictionary = events[int(tile.index)] if int(tile.index) < events.size() else {}
	if str(tile.kind) == "buy":
		var names = _names()
		var player = str(names[int(tile.p)]) if int(tile.p) < names.size() and not str(names[int(tile.p)]).is_empty() else UiKit.t("PLAYER_N", {"n": int(tile.p) + 1})
		if int(tile.p) == viewer and not str(tile.card).is_empty():
			return EventText.format(event, null, names) + " " + UiKit.t("HISTORY_BOUGHT_ITEM", {"card": Library.loc(str(tile.card))})
		if int(tile.count) > 1:
			return UiKit.t("HISTORY_BUY_HIDDEN", {"player": player, "n": int(tile.count), "gold": int(tile.gold)})
		return EventText.format(event, null, names)
	return EventText.format(event, null, _names())

func _detail_lines(tile: Dictionary) -> Array:
	var out: Array = []
	var names = _names()
	for index in tile.get("lines", []):
		if out.size() >= MAX_LINES:
			out.append(UiKit.t("HISTORY_MORE_LINES", {"n": tile.lines.size() - MAX_LINES}))
			break
		if int(index) < events.size():
			out.append(EventText.format(events[int(index)], null, names))
	return out

func _footer(tile: Dictionary) -> String:
	var round_text = UiKit.t("ROUND_N", {"n": int(tile.round)})
	if int(tile.lane) < 0:
		return UiKit.t("HISTORY_FOOTER", {"lane": UiKit.t("PHASE_SHOP") if str(tile.kind) == "buy" else UiKit.t("PHASE_DEPLOYMENT"), "round": round_text})
	return UiKit.t("HISTORY_FOOTER", {"lane": EventText.lane_name(int(tile.lane)), "round": round_text})

func refresh_text() -> void:
	if hovered_id != -1:
		var id = hovered_id
		hovered_id = -1
		_set_hovered(id)
	queue_redraw()

# --- Drawing ------------------------------------------------------------------------

func _process(delta: float) -> void:
	var fade = 1.0
	if board != null:
		# The overview needs the room under the HUD: the rail fades out.
		fade = clampf(1.0 - float(board.zoom) * 2.0, 0.0, 1.0)
	if not is_equal_approx(modulate.a, fade):
		modulate.a = fade
		mouse_filter = Control.MOUSE_FILTER_STOP if fade > 0.5 else Control.MOUSE_FILTER_IGNORE
		if fade <= 0.5:
			_set_hovered(-1)
	if _arrive < 1.0 or _glow > 0.0:
		_arrive = minf(1.0, _arrive + delta / maxf(0.01, AnimationQueue.duration(0.18)))
		_glow = maxf(0.0, _glow - delta / 1.5)
		queue_redraw()

func _draw() -> void:
	_rects = []
	var area = Rect2(Vector2.ZERO, size)
	UiKit.draw_round_rect(self, area, Color(UiKit.INK_PANEL, 0.82), 6.0, Color(UiKit.GOLD_DARK, 0.9), 1.0)
	_log_rect = Rect2(Vector2(size.x - LOG_BUTTON.x - 6.0, (size.y - LOG_BUTTON.y) * 0.5), LOG_BUTTON)
	_draw_log_button(_log_rect)
	var shown = _visible_tiles()
	if shown.is_empty():
		UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("HISTORY_EMPTY"), Vector2(12, size.y * 0.5), 13, UiKit.MUTED, size.x - 60.0)
		_more_rect = Rect2()
		return
	var right_limit = _log_rect.position.x - 6.0
	var x = 6.0
	var count = shown.size()
	var first = clampi(count - 1 - scroll, 0, count - 1)
	_more_rect = Rect2()
	for order in range(first, -1, -1):
		var tile: Dictionary = shown[order]
		var width = PASS_W if str(tile.kind) == "pass" else TILE.x
		if order != first:
			var newer: Dictionary = shown[order + 1]
			if int(newer.round) != int(tile.round):
				x = _draw_round_rule(x, int(newer.round))
			elif int(newer.lane) != int(tile.lane):
				x = _draw_lane_rule(x)
		# Room for this tile and, when older ones remain, the "+N" chip.
		var needs_more = order > 0
		if x + width > right_limit - (26.0 if needs_more else 0.0):
			var hidden = order + 1
			_more_rect = Rect2(Vector2(x, (size.y - 22.0) * 0.5), Vector2(minf(24.0, right_limit - x), 22.0))
			UiKit.draw_round_rect(self, _more_rect, Color(0.16, 0.16, 0.17), 4.0, Color(1, 1, 1, 0.3), 1.0)
			UiKit.draw_text(self, UiKit.bold_font(), UiKit.t("HISTORY_MORE", {"n": hidden}), _more_rect.get_center(), 11, UiKit.PAPER, _more_rect.size.x - 2.0)
			break
		var rect = Rect2(Vector2(x, (size.y - TILE.y) * 0.5), Vector2(width, TILE.y))
		if order == count - 1 and _arrive < 1.0:
			# The newest tile slides in from the left.
			rect.position.x -= (1.0 - _arrive) * 18.0
		_draw_tile(rect, tile, order == count - 1, int(tile.id) == hovered_id)
		_rects.append([rect, int(tile.id)])
		x += width + GAP

func _draw_lane_rule(x: float) -> float:
	var center = x + LANE_RULE * 0.5 - GAP * 0.5
	draw_line(Vector2(center, 8), Vector2(center, size.y - 8), Color(UiKit.GOLD, 0.55), 2.0)
	return x + LANE_RULE

## A round rule with its label ("R3", "第3回合"), as wide as the label needs.
func _draw_round_rule(x: float, round_number: int) -> float:
	var text = UiKit.t("HISTORY_ROUND", {"n": round_number})
	var width = maxf(ROUND_RULE, UiKit.bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0)
	var center = x + width * 0.5 - GAP * 0.5
	draw_line(Vector2(center, 5), Vector2(center, 15), Color(UiKit.GOLD, 0.8), 2.0)
	draw_line(Vector2(center, size.y - 15), Vector2(center, size.y - 5), Color(UiKit.GOLD, 0.8), 2.0)
	UiKit.draw_text(self, UiKit.bold_font(), text, Vector2(center, size.y * 0.5), 11, UiKit.GOLD_BRIGHT)
	return x + width

func _draw_log_button(rect: Rect2) -> void:
	UiKit.draw_round_rect(self, rect, Color(0.1, 0.1, 0.11), 4.0, Color(UiKit.GOLD, 0.6), 1.0)
	UiKit.draw_icon(self, "book_open", Rect2(rect.get_center() - Vector2(10, 10), Vector2(20, 20)), UiKit.PAPER)

func _draw_tile(rect: Rect2, tile: Dictionary, newest: bool, hovered: bool) -> void:
	var player = int(tile.get("p", -1))
	var tint = UiKit.ALLY_TINT if player == viewer else (UiKit.ENEMY_TINT if player >= 0 else UiKit.GOLD_DARK)
	UiKit.draw_round_rect(self, rect, Color(0.07, 0.07, 0.08), 4.0)
	var face = Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 8))
	match str(tile.kind):
		"play", "ability":
			if not CardArt.draw_portrait(self, face, str(tile.card)):
				UiKit.draw_text(self, UiKit.title_font(), Library.loc(str(tile.card)).left(1), face.get_center(), 18, UiKit.PAPER)
			if str(tile.kind) == "ability":
				# The active-ability ring in the corner.
				var spot = Vector2(rect.end.x - 9.0, rect.end.y - 15.0)
				UiKit.draw_disc(self, spot, 7.0, Color(0.1, 0.1, 0.12), UiKit.GOLD_BRIGHT, 1.5)
				draw_arc(spot, 3.5, PI * 0.2, PI * 1.8, 10, UiKit.GOLD_BRIGHT, 1.5, true)
			elif not str(tile.target_card).is_empty():
				var mini = Rect2(Vector2(rect.end.x - 17.0, rect.end.y - 24.0), Vector2(15, 18))
				UiKit.draw_round_rect(self, mini.grow(1.5), UiKit.TARGET, 2.0)
				if not CardArt.draw_portrait(self, mini, str(tile.target_card)):
					draw_rect(mini, Color(0.2, 0.2, 0.22))
		"combat":
			UiKit.draw_vgradient(self, face, Color(0.2, 0.12, 0.08), Color(0.1, 0.06, 0.05))
			UiKit.draw_icon(self, "sword", Rect2(face.get_center() - Vector2(10, 14), Vector2(20, 20)), Color(UiKit.PAPER, 0.35))
			var damage: Array = tile.get("damage", [0, 0])
			UiKit.draw_text(self, UiKit.bold_font(), str(int(damage[0])), Vector2(face.position.x + face.size.x * 0.28, face.end.y - 9.0), 13,
				UiKit.ALLY_TINT.lightened(0.35), -1.0, 2)
			UiKit.draw_text(self, UiKit.bold_font(), str(int(damage[1])), Vector2(face.position.x + face.size.x * 0.74, face.end.y - 9.0), 13,
				UiKit.ENEMY_TINT.lightened(0.3), -1.0, 2)
			if str(tile.get("fall", "")) == "ancient":
				UiKit.draw_icon(self, "skull", Rect2(face.get_center() - Vector2(9, 15), Vector2(18, 18)), UiKit.DAMAGE)
		"buy":
			if not str(tile.card).is_empty():
				if not CardArt.draw_portrait(self, face, str(tile.card)):
					UiKit.draw_text(self, UiKit.title_font(), Library.loc(str(tile.card)).left(1), face.get_center(), 18, UiKit.PAPER)
			else:
				# Hidden purchases: a card back, how many and what they cost.
				CardView.draw_card_back(self, face.grow(-1.0))
				draw_rect(Rect2(face.position.x, face.end.y - 14.0, face.size.x, 14.0), Color(0, 0, 0, 0.6))
				UiKit.draw_text(self, UiKit.bold_font(), "?×%d" % int(tile.count), Vector2(face.get_center().x, face.end.y - 7.0), 11, UiKit.GOLD_BRIGHT)
		"pass":
			UiKit.draw_round_rect(self, face, Color(tint, 0.28), 3.0)
			var c = face.get_center()
			for offset in [-3.5, 2.0]:
				draw_polyline(PackedVector2Array([Vector2(c.x + offset - 2.5, c.y - 5.0), Vector2(c.x + offset + 2.0, c.y),
					Vector2(c.x + offset - 2.5, c.y + 5.0)]), UiKit.PAPER, 1.6, true)
		"end":
			UiKit.draw_round_rect(self, face, Color(0.18, 0.13, 0.05), 3.0)
			var icon = "flag_triangle" if str(tile.get("end", "")) == "concede" else ("crown_a" if str(tile.get("end", "")) == "win" else "shield")
			UiKit.draw_icon(self, icon, Rect2(face.get_center() - Vector2(11, 11), Vector2(22, 22)), UiKit.GOLD_BRIGHT)
	# The player's bar and the lane letter.
	draw_rect(Rect2(rect.position.x + 2.0, rect.end.y - 6.0, rect.size.x - 4.0, 4.0), tint)
	if int(tile.lane) >= 0 and str(tile.kind) != "pass":
		var letter = UiKit.t(["LANE_LEFT_SHORT", "LANE_MIDDLE_SHORT", "LANE_RIGHT_SHORT"][clampi(int(tile.lane), 0, 2)]).left(1)
		var box = Rect2(rect.position + Vector2(2, 2), Vector2(12, 12))
		draw_rect(box, Color(0, 0, 0, 0.75))
		UiKit.draw_text(self, UiKit.bold_font(), letter, box.get_center(), 10, UiKit.PAPER)
	var frame = UiKit.GOLD_DARK
	if str(tile.kind) == "end":
		frame = UiKit.GOLD_BRIGHT
	elif str(tile.kind) == "combat" and not str(tile.get("fall", "")).is_empty():
		frame = UiKit.DAMAGE
	if hovered:
		frame = UiKit.TARGET
	UiKit.draw_round_rect(self, rect, Color.TRANSPARENT, 4.0, frame, 1.5 if hovered else 1.0)
	if newest and _glow > 0.0:
		UiKit.draw_glow(self, rect, 4.0, UiKit.GOLD_BRIGHT, _glow)
	elif newest:
		UiKit.draw_round_rect(self, rect.grow(1.0), Color.TRANSPARENT, 5.0, Color(UiKit.GOLD_BRIGHT, 0.85), 1.0)

## The hover card: the card large beside what happened, under the rail.
class PreviewCard:
	extends PanelContainer
	const UiKit = preload("res://scripts/ui/ui_kit.gd")
	const CardView = preload("res://scripts/ui/card_view.gd")
	const WIDTH = 236.0
	var card: Control
	var headline: Label
	var details: Label
	var footer: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.045, 0.05, 0.96), UiKit.GOLD_DARK, 6, 1, 10.0))
		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		add_child(row)
		card = CardView.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.set_size_keep(Vector2(100, 146))
		card.custom_minimum_size = Vector2(100, 146)
		row.add_child(card)
		var column = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.custom_minimum_size.x = WIDTH
		column.add_theme_constant_override("separation", 4)
		row.add_child(column)
		headline = _label(column, 15, UiKit.PAPER)
		headline.add_theme_font_override("font", UiKit.bold_font())
		details = _label(column, 13, UiKit.PAPER_DIM)
		footer = _label(column, 12, UiKit.GOLD)

	func _label(parent: Control, font_size: int, color: Color) -> Label:
		var result = Label.new()
		result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		result.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.custom_minimum_size.x = WIDTH
		result.add_theme_font_size_override("font_size", font_size)
		result.add_theme_color_override("font_color", color)
		parent.add_child(result)
		return result

	func show_tile(tile: Dictionary, title: String, lines: Array, foot: String) -> void:
		var card_id = str(tile.get("card", ""))
		card.visible = not card_id.is_empty()
		if card.visible:
			card.setup(card_id)
		headline.text = title
		details.text = "\n".join(lines)
		details.visible = not lines.is_empty()
		footer.text = foot
		visible = true
		reset_size()
