extends Control
## The campaign map, "The Storyteller's Tales" (说书·三国演义): the tales of
## one book (act) at a time, laid out left to right like scrolls on the
## storyteller's table and joined by an ink trail, over a soft copy of the
## chosen tale's painting. A tab per book; a book opens when the book before
## it is finished. Each tale's card shows its painting, its number, year and
## title, and how it stands: locked (fogged, a padlock, "？？？"), new (a
## "新" seal), lost so far (its defeats), or won (gold rim, a "胜" seal and
## its three seals). Under the cards the chosen tale's title, era, teaser and
## objective, the enemy army with its commander and five heroes, and the
## record, with Listen (the story, then the battle briefing) and Fight (the
## briefing at once). Won tales stay open to replay. After the last tale the
## Epilogue opens.
##
## Keys: Left / Right move between tales (across books), Up / Down change
## the book, Enter or Space listens, Esc goes back. A locked tale cannot be
## chosen; clicking it says what opens it.

signal action_requested(action: String, chapter_id: String)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Library = preload("res://scripts/core/card_library.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const CampaignData = preload("res://scripts/core/campaign_data.gd")
const CampaignStore = preload("res://scripts/core/campaign_store.gd")
const StoryPanel = preload("res://scripts/ui/story_panel.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
## A tale's card at a 900 px tall window.
const CARD = Vector2(196, 300)
const CARD_GAP = 24.0
## Seconds the unlock animation of a newly opened tale takes.
const UNLOCK_TIME = 1.3
## Decorative seal glyphs (in both languages, like the result's 胜).
const SEAL_NEW = "新"
const SEAL_WON = "胜"
const BUTTONS = {"back": "BTN_BACK", "listen": "CAMPAIGN_LISTEN", "fight": "CAMPAIGN_FIGHT", "epilogue": "CAMPAIGN_EPILOGUE"}

## Card data for the enemy armies (shared, read-only).
var library = Library.new()
## The book shown and the tale chosen ("" when the book is still locked).
var act_id: String = ""
var selected: String = ""
var cards: Array = []
var tabs: Array = []
var buttons: Dictionary = {}
## True while something above the map owns the keyboard (a dialog, a story).
var input_blocked: Callable = func() -> bool: return false
## The app's sound effects (main.gd sets it), or null.
var sfx: Node
## A passing message over the trail ("A new tale: …") and how long it stays.
var notice: String = ""
var _notice_time: float = 0.0
## The tale opening right now: {"chapter", "t"} ({} when none).
var _unlock: Dictionary = {}
var _detail: Rect2
var _trail_y: float = 0.0
var _cards_top: float = 0.0
var _scale: float = 1.0
## The backdrop crossfades from the previous tale's painting.
var _backdrop: String = ""
var _backdrop_from: String = ""
var _backdrop_fade: float = 1.0
## The note on history and the novel: 14 px at a 900 px tall window, never
## under 12 px before it is cut.
const NOTE_SIZE = 14.0
const NOTE_MIN_SIZE = 12.0
## How the chosen tale's note was last laid out: {"chapter", "lines" (its
## wrapped lines), "visible" (the lines shown), "text", "rect"}; {} when none.
var note_fit: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	for action in BUTTONS:
		var button = Button.new()
		button.name = action.capitalize()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.add_theme_font_override("font", UiKit.title_font())
		button.add_theme_font_size_override("font_size", 22 if action == "listen" else 18)
		# Keys belong to the map (arrows move between tales), not to buttons.
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_button.bind(action))
		add_child(button)
		buttons[action] = button
	buttons.listen.custom_minimum_size = Vector2(210, 54)
	buttons.fight.custom_minimum_size = Vector2(150, 54)
	buttons.back.custom_minimum_size = Vector2(110, 42)
	for act_key in CampaignData.act_ids():
		var tab = ActTab.new()
		tab.name = "Tab_" + act_key
		tab.act_id = act_key
		tab.pressed.connect(func(): _on_tab(act_key))
		add_child(tab)
		tabs.append(tab)

## Shows the map with `select_id` chosen (default: the tale last chosen, or
## the furthest open one); `unlocked` names a tale that just opened (its
## card opens before the player's eyes).
func open(select_id: String = "", unlocked: String = "") -> void:
	var target = select_id
	if not CampaignData.has_chapter(target) or not CampaignStore.is_unlocked(target):
		target = CampaignStore.last_chapter()
	if not CampaignData.has_chapter(target) or not CampaignStore.is_unlocked(target):
		target = CampaignStore.furthest_chapter()
	_unlock = {}
	notice = ""
	_notice_time = 0.0
	show_act(CampaignData.act_of(target), target)
	if not unlocked.is_empty():
		play_unlock(unlocked)

## Shows book `new_act`, choosing `select_id` when it is open there (default:
## its first open tale not won yet, else its last open one).
func show_act(new_act: String, select_id: String = "") -> void:
	if new_act.is_empty() or CampaignData.act(new_act).is_empty():
		new_act = CampaignData.act_ids()[0] if not CampaignData.act_ids().is_empty() else ""
	if new_act != act_id:
		act_id = new_act
		_build_cards()
	var chapters = CampaignData.act_chapters(act_id)
	var choice = ""
	if select_id in chapters and CampaignStore.is_unlocked(select_id):
		choice = select_id
	else:
		for chapter_id in chapters:
			if CampaignStore.is_unlocked(chapter_id):
				choice = chapter_id
				if not CampaignStore.is_won(chapter_id):
					break
	selected = choice
	refresh()

## Chooses tale `chapter_id`; a locked one is refused with a hint.
func select(chapter_id: String) -> bool:
	if not CampaignData.has_chapter(chapter_id):
		return false
	if not CampaignStore.is_unlocked(chapter_id):
		show_notice(locked_hint(chapter_id))
		return false
	if CampaignData.act_of(chapter_id) != act_id:
		show_act(CampaignData.act_of(chapter_id), chapter_id)
	else:
		selected = chapter_id
		refresh()
	return true

## What opens a locked tale.
static func locked_hint(chapter_id: String) -> String:
	var previous = CampaignData.previous_chapter(chapter_id)
	return UiKit.t("CAMPAIGN_LOCKED_HINT", {"chapter": CampaignData.title(previous)}) if not previous.is_empty() else ""

## A message over the trail for a few seconds.
func show_notice(text: String, seconds: float = 4.0) -> void:
	notice = text
	_notice_time = seconds
	queue_redraw()

## The newly opened tale `chapter_id` lifts its fog and gets its seal.
func play_unlock(chapter_id: String) -> void:
	if not CampaignData.has_chapter(chapter_id) or not CampaignStore.is_unlocked(chapter_id):
		return
	if CampaignData.act_of(chapter_id) != act_id:
		show_act(CampaignData.act_of(chapter_id), chapter_id)
	else:
		select(chapter_id)
	var first_of_act = CampaignData.act_chapters(act_id).find(chapter_id) == 0
	show_notice(UiKit.t("CAMPAIGN_ACT_UNLOCKED", {"act": CampaignData.act_text(act_id, "title")}) if first_of_act
		else UiKit.t("CAMPAIGN_UNLOCKED_TOAST", {"chapter": CampaignData.title(chapter_id)}), 5.0)
	if AnimationQueue.instant:
		return
	_unlock = {"chapter": chapter_id, "t": 0.0, "stamped": false}
	_sync_cards()

## The tale card of `chapter_id` in the book shown, or null.
func card_for(chapter_id: String) -> Control:
	for card in cards:
		if card.chapter_id == chapter_id:
			return card
	return null

func _build_cards() -> void:
	for card in cards:
		UiKit.discard(card)
	cards = []
	for chapter_id in CampaignData.act_chapters(act_id):
		var card = ChapterCard.new()
		card.name = "Chapter_" + chapter_id
		card.chapter_id = chapter_id
		card.pressed.connect(_on_card_pressed)
		card.activated.connect(_on_card_activated)
		add_child(card)
		cards.append(card)
	_layout()

func refresh_text() -> void:
	refresh()

## Re-reads the progress and redraws.
func refresh() -> void:
	for action in buttons:
		buttons[action].text = UiKit.t(BUTTONS[action])
	var open_tale = not selected.is_empty() and CampaignStore.is_unlocked(selected)
	buttons.listen.disabled = not open_tale
	buttons.fight.disabled = not open_tale
	buttons.epilogue.visible = act_id == CampaignData.act_of(CampaignData.epilogue_unlock_after()) and CampaignStore.epilogue_unlocked()
	for tab in tabs:
		tab.title = CampaignData.act_text(tab.act_id, "title")
		tab.locked = not CampaignStore.act_unlocked(tab.act_id)
		tab.current = tab.act_id == act_id
		var chapters = CampaignData.act_chapters(tab.act_id)
		tab.won = chapters.filter(func(chapter_id): return CampaignStore.is_won(chapter_id)).size()
		tab.total = chapters.size()
		tab.queue_redraw()
	_sync_cards()
	if not selected.is_empty() and CampaignData.art(selected) != _backdrop:
		_backdrop_from = _backdrop
		_backdrop = CampaignData.art(selected)
		_backdrop_fade = 0.0 if not _backdrop_from.is_empty() and not AnimationQueue.instant else 1.0
	_layout()
	queue_redraw()

func _sync_cards() -> void:
	for card in cards:
		var chapter_id: String = card.chapter_id
		var index = CampaignData.index_of(chapter_id)
		card.number_text = UiKit.t("CAMPAIGN_PROLOGUE") if index == 0 else UiKit.t("CAMPAIGN_CHAPTER_N", {"n": index})
		card.year_text = str(CampaignData.year(chapter_id))
		card.locked = not CampaignStore.is_unlocked(chapter_id)
		card.won = CampaignStore.is_won(chapter_id)
		card.seals = CampaignStore.seals(chapter_id)
		card.attempts = CampaignStore.attempts(chapter_id)
		card.title_text = UiKit.t("CAMPAIGN_LOCKED_TITLE") if card.locked else CampaignData.title(chapter_id)
		card.art = CampaignData.art(chapter_id)
		if card.locked:
			card.status_text = UiKit.t("CAMPAIGN_LOCKED")
		elif card.won:
			card.status_text = ""
		elif card.attempts > 0:
			card.status_text = UiKit.t("CAMPAIGN_ATTEMPTS", {"n": card.attempts})
		else:
			card.status_text = UiKit.t("CAMPAIGN_NOT_FOUGHT")
		card.selected = chapter_id == selected
		card.unlock_t = float(_unlock.t) / UNLOCK_TIME if str(_unlock.get("chapter", "")) == chapter_id else 1.0
		card.queue_redraw()

# --- Input -------------------------------------------------------------------------

func _on_button(action: String) -> void:
	if action in ["listen", "fight"] and (selected.is_empty() or not CampaignStore.is_unlocked(selected)):
		return
	var chapter_id = CampaignData.EPILOGUE if action == "epilogue" else selected
	action_requested.emit(action, chapter_id)

func _on_tab(new_act: String) -> void:
	if new_act == act_id:
		return
	if sfx != null:
		sfx.play("switch-a")
	# A locked book shows its fogged tales; the panel says what opens it.
	show_act(new_act)

## What opens a locked book.
static func act_locked_hint(act_key: String) -> String:
	var index = CampaignData.act_ids().find(act_key)
	if index <= 0:
		return ""
	return UiKit.t("CAMPAIGN_ACT_LOCKED_HINT", {"act": CampaignData.act_text(CampaignData.act_ids()[index - 1], "title")})

func _on_card_pressed(chapter_id: String) -> void:
	if select(chapter_id) and sfx != null:
		sfx.play("tap-a")

func _on_card_activated(chapter_id: String) -> void:
	if select(chapter_id):
		action_requested.emit("listen", chapter_id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or input_blocked.call():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			_step(-1)
		KEY_RIGHT:
			_step(1)
		KEY_UP:
			_step_act(-1)
		KEY_DOWN:
			_step_act(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_on_button("listen")
		KEY_F:
			_on_button("fight")
		KEY_ESCAPE:
			_on_button("back")
		_:
			return
	get_viewport().set_input_as_handled()

## The next or previous open tale (into the next or previous book).
func _step(direction: int) -> void:
	var order = CampaignData.chapter_ids()
	var index = order.find(selected)
	if index == -1:
		var chapters = CampaignData.act_chapters(act_id)
		index = order.find(chapters[0]) - direction if not chapters.is_empty() else -1
	var target = index + direction
	if target >= 0 and target < order.size() and CampaignStore.is_unlocked(order[target]):
		select(order[target])
		if sfx != null:
			sfx.play("tap-a")

func _step_act(direction: int) -> void:
	var ids = CampaignData.act_ids()
	var index = ids.find(act_id) + direction
	if index >= 0 and index < ids.size():
		_on_tab(ids[index])

# --- Layout ------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		refresh()

func _layout() -> void:
	if buttons.is_empty():
		return
	_scale = clampf(size.y / 900.0, 0.85, 1.3)
	var s = _scale
	var count = maxi(1, cards.size())
	var card = CARD * s
	var gap = CARD_GAP * s
	var room = size.x - 96.0 * s
	var width = card.x * count + gap * (count - 1)
	if width > room:
		var shrink = room / width
		card *= shrink
		gap *= shrink
		width = room
	var left = (size.x - width) * 0.5
	var row_width = maxf(width, minf(room, CARD.x * 6.0 * s + CARD_GAP * 5.0 * s))
	var row_left = (size.x - row_width) * 0.5
	for button in buttons.values():
		button.size = button.get_combined_minimum_size()
	buttons.back.position = Vector2(row_left, 30.0 * s)
	# The book tabs.
	var tabs_top = 124.0 * s
	var tab_gap = 14.0 * s
	var tab_width = (row_width - tab_gap * (tabs.size() - 1)) / maxf(1.0, tabs.size())
	for index in range(tabs.size()):
		tabs[index].position = Vector2(row_left + index * (tab_width + tab_gap), tabs_top)
		tabs[index].size = Vector2(tab_width, 46.0 * s)
	_cards_top = tabs_top + 46.0 * s + 54.0 * s
	for index in range(cards.size()):
		cards[index].position = Vector2(left + index * (card.x + gap), _cards_top - 12.0 * s)
		cards[index].size = card + Vector2(0, 12.0 * s)
	_trail_y = _cards_top + card.y + 24.0 * s
	var detail_top = _trail_y + 22.0 * s
	_detail = Rect2(Vector2(row_left, detail_top), Vector2(row_width, maxf(220.0, size.y - detail_top - 26.0 * s)))
	var pad = 26.0 * s
	buttons.listen.position = Vector2(_detail.end.x - pad - buttons.listen.size.x, _detail.end.y - pad - buttons.listen.size.y)
	buttons.fight.position = Vector2(buttons.listen.position.x - 14.0 * s - buttons.fight.size.x, buttons.listen.position.y)
	buttons.epilogue.position = Vector2(buttons.fight.position.x - 14.0 * s - buttons.epilogue.size.x, buttons.listen.position.y)

## The rects of every tale card, tab and button (tests: all on screen).
func layout_rects() -> Array:
	var rects: Array = []
	for card in cards:
		rects.append(card.get_global_rect())
	for tab in tabs:
		rects.append(tab.get_global_rect())
	for button in buttons.values():
		if button.visible:
			rects.append(button.get_global_rect())
	rects.append(Rect2(get_global_transform() * _detail.position, _detail.size))
	return rects

# --- Drawing -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	# Only what moves is redrawn: the notice fading, the backdrop's
	# crossfade and a tale opening.
	var moving = false
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0:
			notice = ""
		moving = true
	if _backdrop_fade < 1.0:
		_backdrop_fade = minf(1.0, _backdrop_fade + delta / 0.45)
		moving = true
	if not _unlock.is_empty():
		_unlock.t = float(_unlock.t) + delta * maxf(0.1, AnimationQueue.speed)
		if not _unlock.stamped and float(_unlock.t) >= UNLOCK_TIME * 0.62:
			_unlock.stamped = true
			if sfx != null:
				sfx.play("ready")
		if float(_unlock.t) >= UNLOCK_TIME:
			_unlock = {}
		_sync_cards()
		moving = true
	if moving:
		queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.03, 0.025, 0.022))
	if _backdrop_fade < 1.0 and not _backdrop_from.is_empty():
		_draw_backdrop(_backdrop_from, 1.0)
	if not _backdrop.is_empty():
		_draw_backdrop(_backdrop, _backdrop_fade)
	UiKit.draw_vgradient(self, Rect2(0, 0, size.x, size.y * 0.3), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.15))
	UiKit.draw_vgradient(self, Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color(0, 0, 0, 0.1), Color(0, 0, 0, 0.75))
	var s = _scale
	# The heading: the storyteller's title, the line under it and the progress.
	var title = CampaignData.campaign_text("title")
	UiKit.draw_text(self, UiKit.title_font(), title, Vector2(size.x * 0.5, 56.0 * s), int(44.0 * s), UiKit.GOLD_BRIGHT, size.x * 0.5, 5)
	# The line under it, or the warning that results here are not kept.
	UiKit.draw_text(self, UiKit.body_font(), header_note(), Vector2(size.x * 0.5, 98.0 * s), int(15.0 * s),
		UiKit.CINNABAR.lightened(0.35) if CampaignStore.read_only else UiKit.PAPER_DIM, minf(size.x * 0.62, _detail.size.x - 300.0 * s), 2)
	var progress = CampaignStore.progress()
	var right = _detail.end.x
	var line = UiKit.t("CAMPAIGN_PROGRESS", {"won": progress.won, "total": progress.total})
	var seals_line = UiKit.t("CAMPAIGN_SEALS_TOTAL", {"n": progress.seals, "max": progress.max_seals})
	var font = UiKit.title_font()
	var line_width = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20.0 * s)).x
	UiKit.draw_text_left(self, font, line, Vector2(right - line_width, 46.0 * s), int(20.0 * s), UiKit.PAPER, -1.0, 3)
	var seal_width = UiKit.body_font().get_string_size(seals_line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15.0 * s)).x
	UiKit.draw_text_left(self, UiKit.body_font(), seals_line, Vector2(right - seal_width, 74.0 * s), int(15.0 * s), UiKit.GOLD, -1.0, 2)
	# The book's subtitle.
	var subtitle = CampaignData.act_text(act_id, "subtitle")
	UiKit.draw_text(self, UiKit.title_font(), subtitle, Vector2(size.x * 0.5, 124.0 * s + 46.0 * s + 26.0 * s), int(18.0 * s),
		UiKit.PAPER_DIM, _detail.size.x, 2)
	_draw_trail()
	_draw_detail()
	if not notice.is_empty():
		var alpha = clampf(_notice_time / 0.5, 0.0, 1.0)
		var notice_font = UiKit.title_font()
		var notice_size = int(19.0 * s)
		var width = minf(notice_font.get_string_size(notice, HORIZONTAL_ALIGNMENT_LEFT, -1, notice_size).x + 48.0 * s, _detail.size.x)
		var pill = Rect2(Vector2(size.x * 0.5 - width * 0.5, _trail_y - 19.0 * s), Vector2(width, 38.0 * s))
		UiKit.draw_round_rect(self, pill, Color(0.06, 0.04, 0.03, 0.94 * alpha), 19.0 * s, Color(UiKit.GOLD, 0.9 * alpha), 1.5)
		UiKit.draw_text(self, notice_font, notice, pill.get_center(), notice_size, Color(UiKit.GOLD_BRIGHT, alpha), width - 32.0 * s, 2)

## The line under the heading: the campaign's description, or, while the
## progress is a newer version's (CampaignStore.read_only), that results
## here are not saved.
static func header_note() -> String:
	return UiKit.t("CAMPAIGN_READ_ONLY_MAP") if CampaignStore.read_only else CampaignData.campaign_text("description")

func _draw_backdrop(id: String, alpha: float) -> void:
	var texture = StoryPanel.soft_texture(id)
	if texture != null:
		UiKit.draw_cover(self, texture, Rect2(Vector2.ZERO, size), Vector2(0.5, 0.4), Color(0.3, 0.27, 0.25, alpha))

## The ink trail under the cards: solid up to the last open tale, dotted
## beyond, a knot under every tale (gold once won).
func _draw_trail() -> void:
	if cards.is_empty():
		return
	var s = _scale
	var points: Array = cards.map(func(card): return Vector2(card.position.x + card.size.x * 0.5, _trail_y))
	var start = Vector2(cards[0].position.x - 18.0 * s, _trail_y)
	var finish = Vector2(cards[-1].position.x + cards[-1].size.x + 18.0 * s, _trail_y)
	var stops: Array = [start] + points + [finish]
	for index in range(stops.size() - 1):
		var from: Vector2 = stops[index]
		var to: Vector2 = stops[index + 1]
		var card_index = mini(index, cards.size() - 1)
		var open_segment = not cards[card_index].locked and (index == 0 or index >= cards.size() or not cards[index].locked)
		if open_segment:
			draw_line(from, to, Color(UiKit.GOLD_DARK, 0.85), 3.0 * s, true)
			draw_line(from + Vector2(0, 2.0 * s), to + Vector2(0, 2.0 * s), Color(0, 0, 0, 0.35), 2.0 * s, true)
		else:
			var length = from.distance_to(to)
			var dash = 8.0 * s
			var steps = int(length / (dash * 2.0))
			for step in range(steps):
				var a = from.lerp(to, (step * dash * 2.0) / length)
				var b = from.lerp(to, (step * dash * 2.0 + dash) / length)
				draw_line(a, b, Color(UiKit.MUTED, 0.55), 2.0 * s, true)
	for index in range(cards.size()):
		var card = cards[index]
		var point: Vector2 = points[index]
		if card.won:
			draw_circle(point, 8.0 * s, UiKit.GOLD)
			draw_circle(point, 4.0 * s, Color("3a2a12"))
		elif not card.locked:
			draw_circle(point, 8.0 * s, Color(0.08, 0.06, 0.05))
			draw_arc(point, 8.0 * s, 0.0, TAU, 24, UiKit.GOLD_BRIGHT if card.selected else UiKit.GOLD, 2.0 * s, true)
		else:
			draw_circle(point, 4.5 * s, Color(UiKit.MUTED, 0.6))

func _draw_detail() -> void:
	var s = _scale
	var rect = _detail
	UiKit.draw_round_rect(self, rect, Color(0.035, 0.035, 0.042, 0.9), 8.0, Color(UiKit.GOLD_DARK, 0.9), 1.5)
	var pad = 28.0 * s
	if selected.is_empty():
		UiKit.draw_text(self, UiKit.title_font(), act_locked_hint(act_id), rect.get_center() + Vector2(0, -10.0 * s), int(22.0 * s),
			UiKit.PAPER_DIM, rect.size.x - pad * 2.0, 2)
		return
	var chapter_id = selected
	var split = rect.position.x + rect.size.x * 0.56
	var left = rect.position.x + pad
	var text_width = split - left - pad
	var y = rect.position.y + 38.0 * s
	var title_font = UiKit.title_font()
	var title_size = UiKit.fit_size(title_font, CampaignData.title(chapter_id), text_width, int(30.0 * s), int(20.0 * s))
	UiKit.draw_text_left(self, title_font, CampaignData.title(chapter_id), Vector2(left, y), title_size, UiKit.GOLD_BRIGHT, text_width, 3)
	y += 34.0 * s
	var era = CampaignData.chapter_text(chapter_id, "era")
	if CampaignData.defy_fate(chapter_id):
		era += "  ·  " + UiKit.t("CAMPAIGN_DEFY_FATE_TAG")
	UiKit.draw_text_left(self, UiKit.body_font(), era, Vector2(left, y), int(15.0 * s), UiKit.PAPER_DIM, text_width, 2)
	y += 20.0 * s
	var teaser = UiKit.paragraph(CampaignData.chapter_text(chapter_id, "teaser"), UiKit.body_font(), int(18.0 * s), text_width, HORIZONTAL_ALIGNMENT_LEFT)
	teaser.max_lines_visible = 3
	teaser.draw(get_canvas_item(), Vector2(left, y), UiKit.PAPER)
	y += teaser.get_size().y + 14.0 * s
	var caption = UiKit.t("CAMPAIGN_OBJECTIVE")
	var caption_size = int(16.0 * s)
	UiKit.draw_text_left(self, title_font, caption, Vector2(left, y + 10.0 * s), caption_size, UiKit.GOLD, -1.0, 2)
	var caption_width = title_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x + 14.0 * s
	var objective = UiKit.paragraph(CampaignData.chapter_text(chapter_id, "objective"), UiKit.body_font(), int(16.0 * s), text_width - caption_width,
		HORIZONTAL_ALIGNMENT_LEFT)
	objective.max_lines_visible = 2
	objective.draw(get_canvas_item(), Vector2(left + caption_width, y), UiKit.PAPER)
	y += objective.get_size().y + 18.0 * s
	# What is history and what is the novel, in the room left.
	var classic = Library.current_skin() != CampaignData.STORY_SKIN
	var bottom = rect.end.y - (40.0 if classic else 18.0) * s
	var note = CampaignData.chapter_text(chapter_id, "history_note")
	note_fit = {}
	if not note.is_empty() and bottom - y > 30.0 * s:
		# The note steps down to NOTE_MIN_SIZE to fit; only past that does its
		# last line end in "…" (the whole note is then the panel's tooltip).
		var area = Vector2(text_width, bottom - y)
		var paragraph = UiKit.fit_paragraph(UiKit.t("CAMPAIGN_HISTORY_NOTE", {"note": note}), UiKit.body_font(), area,
			int(NOTE_SIZE * s), int(NOTE_MIN_SIZE * s), HORIZONTAL_ALIGNMENT_LEFT)
		var lines = paragraph.get_line_count()
		var line_height = paragraph.get_size().y / maxf(1.0, lines)
		var visible_lines = mini(lines, maxi(1, int(area.y / maxf(1.0, line_height))))
		if visible_lines < lines:
			paragraph.max_lines_visible = visible_lines
			paragraph.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
		paragraph.draw(get_canvas_item(), Vector2(left, y), UiKit.MUTED)
		note_fit = {"chapter": chapter_id, "lines": lines, "visible": visible_lines, "text": note,
			"rect": Rect2(Vector2(left, y), Vector2(text_width, line_height * visible_lines))}
	if classic:
		UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("CAMPAIGN_SKIN_NOTE"), Vector2(left, rect.end.y - 20.0 * s), int(13.0 * s),
			UiKit.MUTED, text_width, 2)
	# The enemy: its army, commander and heroes; then the record.
	# The divider stops above the buttons (the Epilogue may reach past it).
	draw_line(Vector2(split, rect.position.y + pad), Vector2(split, buttons.listen.position.y - 16.0 * s), Color(UiKit.GOLD_DARK, 0.55), 1.0)
	var column = split + pad
	var column_width = rect.end.x - column - pad
	var ey = rect.position.y + 30.0 * s
	UiKit.draw_text_left(self, title_font, UiKit.t("CAMPAIGN_ENEMY"), Vector2(column, ey), int(16.0 * s), UiKit.GOLD, -1.0, 2)
	ey += 30.0 * s
	UiKit.draw_text_left(self, title_font, Library.preset_text(CampaignData.enemy_preset(chapter_id)), Vector2(column, ey), int(23.0 * s),
		UiKit.PAPER, column_width, 3)
	ey += 28.0 * s
	var commander = CampaignData.enemy_commander(chapter_id)
	UiKit.draw_text_left(self, UiKit.body_font(), UiKit.t("CAMPAIGN_COMMANDER", {"name": Library.loc(commander)}), Vector2(column, ey),
		int(15.0 * s), UiKit.PAPER_DIM, column_width, 2)
	ey += 18.0 * s
	var chip = Vector2(50, 68) * s
	var x = column
	for hero_id in CampaignData.enemy_heroes(chapter_id, library):
		var frame = Rect2(Vector2(x, ey), chip)
		var color = UiKit.card_color(str(Library.raw_definition(hero_id).get("color", "neutral")))
		UiKit.draw_round_rect(self, frame, color, 4.0)
		if not CardArt.draw_portrait(self, frame.grow(-2.0), hero_id):
			UiKit.draw_text(self, UiKit.title_font(), Library.loc(hero_id).left(1), frame.get_center(), int(20.0 * s), UiKit.PAPER)
		var lead = hero_id == commander
		UiKit.draw_round_rect(self, frame, Color.TRANSPARENT, 4.0, UiKit.GOLD_BRIGHT if lead else color.lightened(0.35), 2.0 if lead else 1.0)
		x += chip.x + 8.0 * s
	ey += chip.y + 24.0 * s
	var record = _record_text(chapter_id)
	var seals = CampaignStore.seals(chapter_id)
	if CampaignStore.is_won(chapter_id):
		for index in range(CampaignData.SEAL_BITS.size()):
			var earned = seals & CampaignData.SEAL_BITS[index]
			var center = Vector2(column + 9.0 * s + index * 24.0 * s, ey)
			if earned:
				draw_circle(center, 8.0 * s, UiKit.CINNABAR)
				draw_arc(center, 5.0 * s, 0.0, TAU, 20, Color(UiKit.PAPER, 0.85), 1.4 * s, true)
			else:
				draw_arc(center, 7.5 * s, 0.0, TAU, 20, Color(UiKit.MUTED, 0.9), 1.6 * s, true)
		UiKit.draw_text_left(self, UiKit.body_font(), record, Vector2(column + 80.0 * s, ey), int(15.0 * s), UiKit.PAPER_DIM,
			column_width - 80.0 * s, 2)
	else:
		UiKit.draw_text_left(self, UiKit.body_font(), record, Vector2(column, ey), int(15.0 * s), UiKit.PAPER_DIM, column_width, 2)

## A note cut short shows whole as the tooltip over it.
func _get_tooltip(at_position: Vector2) -> String:
	if note_fit.is_empty() or int(note_fit.visible) >= int(note_fit.lines) or not Rect2(note_fit.rect).has_point(at_position):
		return ""
	return UiKit.t("CAMPAIGN_HISTORY_NOTE", {"note": str(note_fit.text)})

## "Won · fought 3 times" and the like for the detail panel.
static func _record_text(chapter_id: String) -> String:
	var fought = CampaignStore.attempts(chapter_id)
	if fought == 0:
		return UiKit.t("CAMPAIGN_NOT_FOUGHT")
	var times = UiKit.t_n("CAMPAIGN_FOUGHT_N", fought)
	if not CampaignStore.is_won(chapter_id):
		return times
	var best = CampaignStore.best_rounds(chapter_id)
	return times + "  ·  " + UiKit.t("CAMPAIGN_BEST_ROUNDS", {"n": best}) if best > 0 else times

## A book's tab: its title, how many of its tales are won, a padlock while
## it is locked.
class ActTab:
	extends Control
	signal pressed
	var act_id: String = ""
	var title: String = ""
	var locked: bool = false
	var current: bool = false
	var won: int = 0
	var total: int = 0
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var rect = Rect2(Vector2.ZERO, size)
		var s = clampf(size.y / 46.0, 0.8, 1.4)
		if current:
			UiKit.draw_round_rect(self, rect, Color(0.12, 0.09, 0.06, 0.94), 6.0, UiKit.GOLD, 1.5)
			draw_line(Vector2(rect.position.x + 14.0, rect.end.y - 3.0), Vector2(rect.end.x - 14.0, rect.end.y - 3.0), UiKit.GOLD_BRIGHT, 2.0)
		else:
			UiKit.draw_round_rect(self, rect, Color(0.05, 0.05, 0.06, 0.7 if _hover else 0.5), 6.0, Color(UiKit.GOLD_DARK, 0.7), 1.0)
		var color = UiKit.GOLD_BRIGHT if current else (UiKit.MUTED if locked else (UiKit.PAPER if _hover else UiKit.PAPER_DIM))
		var count = "%d/%d" % [won, total]
		var count_width = UiKit.body_font().get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14.0 * s)).x
		var left = 16.0 * s
		if locked:
			UiKit.draw_icon(self, "lock_closed", Rect2(Vector2(left, size.y * 0.5 - 10.0 * s), Vector2(20, 20) * s), Color(UiKit.MUTED, 0.9))
			left += 28.0 * s
		var room = size.x - left - count_width - 28.0 * s
		UiKit.draw_text_left(self, UiKit.title_font(), title, Vector2(left, size.y * 0.5), int(20.0 * s), color, room, 2)
		UiKit.draw_text_left(self, UiKit.body_font(), count, Vector2(size.x - 14.0 * s - count_width, size.y * 0.5), int(14.0 * s),
			UiKit.GOLD if won == total and total > 0 else UiKit.MUTED, -1.0, 2)

## One tale on the map: its painting, number, year, title and standing.
class ChapterCard:
	extends Control
	signal pressed(chapter_id: String)
	signal activated(chapter_id: String)
	const TOP = 12.0
	var chapter_id: String = ""
	var art: String = ""
	var number_text: String = ""
	var year_text: String = ""
	var title_text: String = ""
	var status_text: String = ""
	var locked: bool = false
	var won: bool = false
	var seals: int = 0
	var attempts: int = 0
	var selected: bool = false
	## 0..1 while the tale opens (the fog lifts, then the seal stamps).
	var unlock_t: float = 1.0
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				activated.emit(chapter_id)
			else:
				pressed.emit(chapter_id)
			accept_event()

	## The card's face (it rises when chosen or hovered).
	func face() -> Rect2:
		var lift = 0.0
		if selected:
			lift = TOP
		elif _hover and not locked:
			lift = TOP * 0.5
		return Rect2(Vector2(0, TOP - lift), Vector2(size.x, size.y - TOP))

	func _draw() -> void:
		var card = face()
		var s = clampf(card.size.y / 300.0, 0.6, 1.5)
		var fog = 1.0 - clampf(unlock_t / 0.55, 0.0, 1.0)
		var dark = locked or fog > 0.0
		UiKit.draw_round_rect(self, Rect2(card.position + Vector2(3, 8) * s, card.size), Color(0, 0, 0, 0.55), 8.0)
		if selected:
			UiKit.draw_glow(self, card, 8.0, UiKit.GOLD_BRIGHT, 0.9)
		UiKit.draw_round_rect(self, card, Color(0.055, 0.05, 0.05, 0.97), 8.0)
		var art_rect = Rect2(card.position + Vector2(7, 7) * s, Vector2(card.size.x - 14.0 * s, card.size.y * 0.62))
		var entry = StoryPanel.art_entry(art)
		if not entry.is_empty():
			var shade = 0.3 if locked else lerpf(1.0, 0.3, fog)
			UiKit.draw_cover(self, entry.texture, art_rect, Vector2(0.5, 0.3), Color(shade, shade, shade * 1.05), entry.region)
		else:
			UiKit.draw_ink_wash(self, art_rect, UiKit.GOLD_DARK, chapter_id)
		if dark:
			var amount = 1.0 if locked else fog
			UiKit.draw_vgradient(self, art_rect, Color(0.1, 0.1, 0.13, 0.35 * amount), Color(0.04, 0.04, 0.06, 0.8 * amount))
			var lock_size = 46.0 * s * (1.0 if locked else 1.0 + (1.0 - fog) * 0.6)
			UiKit.draw_icon(self, "lock_closed", Rect2(art_rect.get_center() - Vector2(lock_size, lock_size) * 0.5, Vector2(lock_size, lock_size)),
				Color(UiKit.PAPER_DIM, 0.85 * amount))
		UiKit.draw_vgradient(self, Rect2(art_rect.position.x, art_rect.end.y - 40.0 * s, art_rect.size.x, 40.0 * s), Color(0, 0, 0, 0),
			Color(0.055, 0.05, 0.05, 0.95))
		# The tale's number on the painting.
		var number_size = int(13.0 * s)
		var number_width = UiKit.body_font().get_string_size(number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x + 16.0 * s
		var chip = Rect2(art_rect.position + Vector2(6, 6) * s, Vector2(number_width, 22.0 * s))
		UiKit.draw_round_rect(self, chip, Color(0.03, 0.03, 0.035, 0.82), 4.0, Color(UiKit.GOLD_DARK, 0.9), 1.0)
		UiKit.draw_text(self, UiKit.body_font(), number_text, chip.get_center(), number_size, UiKit.PAPER_DIM if dark else UiKit.GOLD)
		# The seal: won, new, or nothing (fought and lost).
		var seal_center = Vector2(art_rect.end.x - 20.0 * s, art_rect.position.y + 22.0 * s)
		if won:
			UiKit.draw_seal(self, seal_center, 30.0 * s, SEAL_WON)
		elif not locked and attempts == 0:
			var stamp = clampf((unlock_t - 0.62) / 0.2, 0.0, 1.0)
			if stamp > 0.0:
				var seal_size = 30.0 * s * (1.0 + (1.0 - stamp) * 1.2)
				UiKit.draw_seal(self, seal_center, seal_size, SEAL_NEW, Color(UiKit.CINNABAR, stamp))
		# Year, title and standing.
		var text_left = card.position.x + 12.0 * s
		var text_width = card.size.x - 24.0 * s
		var y = art_rect.end.y + 16.0 * s
		UiKit.draw_text_left(self, UiKit.body_font(), year_text, Vector2(text_left, y), int(14.0 * s), UiKit.MUTED if locked else UiKit.GOLD, text_width, 1)
		var title_area = Vector2(text_width, 52.0 * s)
		var paragraph = UiKit.fit_paragraph(title_text, UiKit.title_font(), title_area, int(19.0 * s), int(13.0 * s), HORIZONTAL_ALIGNMENT_LEFT)
		paragraph.draw(get_canvas_item(), Vector2(text_left, y + 12.0 * s), UiKit.MUTED if locked else UiKit.PAPER)
		var bottom = card.end.y - 20.0 * s
		if won:
			for index in range(CampaignData.SEAL_BITS.size()):
				var center = Vector2(text_left + 8.0 * s + index * 21.0 * s, bottom)
				if seals & CampaignData.SEAL_BITS[index]:
					draw_circle(center, 7.0 * s, UiKit.CINNABAR)
					draw_arc(center, 4.2 * s, 0.0, TAU, 18, Color(UiKit.PAPER, 0.85), 1.2 * s, true)
				else:
					draw_arc(center, 6.5 * s, 0.0, TAU, 18, Color(UiKit.MUTED, 0.9), 1.4 * s, true)
		elif not status_text.is_empty():
			var tint = UiKit.ENEMY_TINT.lightened(0.2) if attempts > 0 else (UiKit.MUTED if locked else UiKit.JADE)
			UiKit.draw_text_left(self, UiKit.body_font(), status_text, Vector2(text_left, bottom), int(14.0 * s), tint, text_width, 1)
		var rim = UiKit.GOLD_BRIGHT if won else (Color(0.32, 0.31, 0.3) if locked else UiKit.GOLD_DARK)
		if selected or (_hover and not locked):
			rim = UiKit.GOLD_BRIGHT
		UiKit.draw_round_rect(self, card, Color.TRANSPARENT, 8.0, rim, 2.0 if won or selected else 1.5)
