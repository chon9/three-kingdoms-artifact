extends Control
## The storyteller's pages, told like a picture book: the page's painting
## hangs in a gold frame over a soft, darkened copy of itself, slowly drifting
## (a gentle zoom and pan) and crossfading to the next page's painting; below
## it a sheet of rice paper holds the speaker's name in calligraphy, the
## chapter and its era, and the words, which appear a few dozen characters a
## second (at once in instant mode, tests). Used before a campaign battle
## (over the campaign map), after it (over the result) and for the epilogue.
##
## A click, Space, Enter or Right shows the whole page, then turns it;
## Backspace, Left or a right-click goes back a page; Skip or Esc ends the
## story at once. A language switch re-renders the page in place. Pages are
## the campaign file's raw pages (CampaignData.pages), localized as drawn.

## The story ended: on its last page, or skipped.
signal finished(skipped: bool)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const CampaignData = preload("res://scripts/core/campaign_data.gd")
const AnimationQueue = preload("res://scripts/game/animation_queue.gd")
## Characters per second at animation speed 1.
const REVEAL_RATE = 40.0
## Seconds a painting takes to crossfade into the next.
const FADE_TIME = 0.5
## A painting drifts this much larger over DRIFT_TIME seconds.
const DRIFT_ZOOM = 0.04
const DRIFT_TIME = 10.0
## Ink on the paper: the words, the speaker's name, the heading.
const INK_TEXT = Color("2a1e15")
const INK_NAME = Color("8a2a1e")
const INK_MUTED = Color("6a5643")
## Seal stamped on the painting after a battle (decorative, as on the result).
const SEALS = {"victory": "胜", "defeat": "败"}
const BUTTONS = {"skip": "STORY_SKIP", "back": "STORY_BACK", "next": "STORY_NEXT"}

var pages: Array = []
## The chapter told (CampaignData.EPILOGUE for the epilogue) and which pages:
## "intro", "victory", "defeat" or "epilogue".
var chapter_id: String = ""
var kind: String = ""
var page: int = 0
var playing: bool = false
## Characters of the current page shown so far.
var shown: float = 0.0
var body: Label
var buttons: Dictionary = {}
## The app's sound effects (main.gd sets it), or null.
var sfx: Node
## Stories told (tests count them).
var told_count: int = 0
## Seconds on the current page (its painting's drift).
var _t: float = 0.0
## Crossfade from the previous page's painting (1 when done).
var _fade: float = 1.0
var _from_art: String = ""
var _from_t: float = 0.0
## Which way the painting drifts (down or up it); it turns with every new
## painting, and the fading one keeps its own.
var _drift_down: bool = true
var _from_down: bool = true
var _stage: Rect2
var _box: Rect2
## Soft (blurred) copies of paintings for the backdrop, by art id.
static var _soft: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	body = Label.new()
	body.name = "Body"
	body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_color_override("font_color", INK_TEXT)
	body.add_theme_constant_override("line_spacing", 6)
	add_child(body)
	for action in BUTTONS:
		var button = Button.new()
		button.name = action.capitalize()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", UiKit.title_font())
		button.add_theme_font_size_override("font_size", 19 if action == "next" else 16)
		button.custom_minimum_size = Vector2(150 if action == "next" else 112, 44 if action == "next" else 38)
		button.pressed.connect(_on_button.bind(action))
		add_child(button)
		buttons[action] = button

## Tells `new_pages` (raw campaign pages) of `new_chapter`; `new_kind` is
## "intro", "victory", "defeat" or "epilogue". Returns at once; `finished`
## follows when the story ends.
func play(new_pages: Array, new_chapter: String, new_kind: String) -> void:
	pages = new_pages.filter(func(entry): return entry is Dictionary)
	chapter_id = new_chapter
	kind = new_kind
	page = 0
	playing = true
	visible = true
	told_count += 1
	_from_art = ""
	_fade = 1.0
	if pages.is_empty():
		_finish(false)
		return
	refresh_text()
	_show_page(0)
	set_process(true)

## Hides the story without ending it (a match started under it).
func stop() -> void:
	playing = false
	visible = false
	set_process(false)

## The whole page, then the next one (the end after the last).
func advance() -> void:
	if not playing:
		return
	if not page_complete():
		reveal_all()
		return
	if page + 1 < pages.size():
		_show_page(page + 1)
		_sound("switch-a")
	else:
		_finish(false)

## The previous page, shown whole.
func back() -> void:
	if not playing or page == 0:
		return
	_show_page(page - 1)
	reveal_all()
	_sound("switch-b")

## Ends the story at once.
func skip() -> void:
	if playing:
		_finish(true)

## Shows the rest of the current page at once.
func reveal_all() -> void:
	shown = float(body.text.length())
	body.visible_characters = -1
	_refresh_buttons()

## True once every character of the page shows.
func page_complete() -> bool:
	return body.visible_characters < 0 or shown >= float(body.text.length())

## The current page's text, speaker and art as shown (tests).
func page_text() -> String:
	return body.text

func speaker_text() -> String:
	return CampaignData.speaker_name(str(_page().get("speaker", "")))

func art_id() -> String:
	return str(_page().get("art", ""))

func _page() -> Dictionary:
	return pages[page] if page >= 0 and page < pages.size() else {}

func _finish(skipped: bool) -> void:
	playing = false
	visible = false
	set_process(false)
	_sound("tap-b")
	finished.emit(skipped)

func _sound(sound: String) -> void:
	if sfx != null:
		sfx.play(sound)

func _on_button(action: String) -> void:
	match action:
		"skip":
			skip()
		"back":
			back()
		"next":
			advance()

func _show_page(index: int) -> void:
	var previous_art = art_id() if playing and index != page else ""
	var previous_t = _t
	var previous_down = _drift_down
	page = clampi(index, 0, maxi(0, pages.size() - 1))
	if previous_art != art_id():
		# A new painting: it fades in over the old one and drifts the other way.
		_from_art = previous_art if not AnimationQueue.instant else ""
		_from_t = previous_t
		_from_down = previous_down
		_fade = 0.0 if not _from_art.is_empty() else 1.0
		_drift_down = not previous_down if not previous_art.is_empty() else true
		_t = 0.0
	body.text = CampaignData.page_text(_page())
	shown = 0.0
	body.visible_characters = 0
	if AnimationQueue.instant:
		reveal_all()
	_refresh_buttons()
	_layout()
	queue_redraw()

func refresh_text() -> void:
	for action in buttons:
		buttons[action].text = UiKit.t(BUTTONS[action])
	var chinese = UiKit.is_zh()
	# Kai for Chinese words; English reads better in the body font.
	body.add_theme_font_override("font", UiKit.title_font() if chinese else UiKit.body_font())
	body.add_theme_font_size_override("font_size", 27 if chinese else 22)
	body.language = UiKit.text_language()
	if playing:
		# The page in the new language, shown whole.
		body.text = CampaignData.page_text(_page())
		reveal_all()
	_refresh_buttons()
	_layout()
	queue_redraw()

func _refresh_buttons() -> void:
	if not buttons.has("next"):
		return
	var last = page + 1 >= pages.size()
	buttons.next.text = UiKit.t("STORY_DONE" if last and page_complete() else "STORY_NEXT")
	buttons.back.visible = page > 0
	_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()

## Size scale for the window height (1 at 900 px).
func _scale() -> float:
	return clampf(size.y / 900.0, 0.8, 1.3)

func _layout() -> void:
	if body == null:
		return
	var s = _scale()
	var box_width = minf(size.x - 96.0 * s, 1100.0 * s)
	var box_height = 250.0 * s
	_box = Rect2(Vector2((size.x - box_width) * 0.5, size.y - box_height - 30.0 * s), Vector2(box_width, box_height))
	var top = 34.0 * s
	_stage = Rect2(Vector2(48.0 * s, top), Vector2(size.x - 96.0 * s, _box.position.y - top - 26.0 * s))
	body.position = _box.position + Vector2(46.0, 66.0) * s
	body.size = Vector2(_box.size.x - 92.0 * s, _box.size.y - 66.0 * s - 56.0 * s)
	for action in buttons:
		var button: Button = buttons[action]
		button.size = button.get_combined_minimum_size()
	buttons.next.position = Vector2(_box.end.x - buttons.next.size.x - 30.0 * s, _box.end.y - buttons.next.size.y - 14.0 * s)
	buttons.back.position = Vector2(_box.position.x + 30.0 * s, _box.end.y - buttons.back.size.y - 17.0 * s)
	buttons.skip.position = Vector2(size.x - buttons.skip.size.x - 26.0 * s, 22.0 * s)

# --- Input -------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not playing:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			advance()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			back()
			accept_event()

func _input(event: InputEvent) -> void:
	if not playing or not is_visible_in_tree():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT:
			advance()
		KEY_BACKSPACE, KEY_LEFT:
			back()
		KEY_ESCAPE:
			skip()
		_:
			return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_t += delta
	_from_t += delta
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta / maxf(0.05, AnimationQueue.duration(FADE_TIME)))
	if not page_complete():
		shown += delta * REVEAL_RATE * maxf(0.1, AnimationQueue.speed)
		if shown >= float(body.text.length()):
			reveal_all()
		else:
			body.visible_characters = int(shown)
	queue_redraw()

# --- Drawing -----------------------------------------------------------------------

## A painting: {"texture", "region"} for a card id (its Three Kingdoms art)
## or "ui/<file>" (board and interface art), or {}.
static func art_entry(id: String) -> Dictionary:
	if id.begins_with(CampaignData.UI_ART_PREFIX):
		var texture = UiKit.tex(UiKit.UI_ART_DIR + id.substr(CampaignData.UI_ART_PREFIX.length()))
		return {"texture": texture, "region": Rect2(Vector2.ZERO, texture.get_size())} if texture != null else {}
	return CardArt.themed(id) if not id.is_empty() else {}

## A soft copy of a painting for the backdrop (the painting itself in
## headless runs).
static func soft_texture(id: String) -> Texture2D:
	if _soft.has(id):
		return _soft[id]
	var entry = art_entry(id)
	var texture: Texture2D = entry.get("texture")
	if texture != null and DisplayServer.get_name() != "headless":
		var image = texture.get_image()
		if image != null and not image.is_empty():
			image = image.duplicate()
			if image.is_compressed():
				image.decompress()
			image.clear_mipmaps()
			var aspect = float(image.get_width()) / float(maxi(1, image.get_height()))
			image.resize(maxi(4, int(round(24.0 * aspect))), 24, Image.INTERPOLATE_BILINEAR)
			image.resize(maxi(8, int(round(160.0 * aspect))), 160, Image.INTERPOLATE_CUBIC)
			texture = ImageTexture.create_from_image(image)
	_soft[id] = texture
	return texture

## Where a painting hangs: its own aspect, as large as the stage allows.
func _frame_for(id: String) -> Rect2:
	var entry = art_entry(id)
	var aspect = 2.0 / 3.0
	if entry.has("region") and entry.region.size.y > 0.0:
		aspect = entry.region.size.x / entry.region.size.y
	var height = _stage.size.y
	var width = minf(height * aspect, _stage.size.x)
	height = width / aspect
	return Rect2(_stage.get_center() - Vector2(width, height) * 0.5, Vector2(width, height))

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.02, 0.018, 0.016))
	var current = art_id()
	var fading = _fade < 1.0 and not _from_art.is_empty()
	if fading:
		_draw_backdrop(_from_art, 1.0)
	_draw_backdrop(current, _fade if fading else 1.0)
	UiKit.draw_vgradient(self, Rect2(0, 0, size.x, size.y * 0.25), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0))
	UiKit.draw_vgradient(self, Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color(0, 0, 0, 0), Color(0, 0, 0, 0.7))
	UiKit.draw_hgradient(self, Rect2(0, 0, size.x * 0.22, size.y), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0))
	UiKit.draw_hgradient(self, Rect2(size.x * 0.78, 0, size.x * 0.22, size.y), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55))
	if fading:
		_draw_painting(_from_art, 1.0 - _fade, _from_t, _from_down)
	_draw_painting(current, _fade if fading else 1.0, _t, _drift_down)
	_draw_box()

func _draw_backdrop(id: String, alpha: float) -> void:
	var texture = soft_texture(id)
	if texture == null:
		return
	UiKit.draw_cover(self, texture, Rect2(Vector2.ZERO, size), Vector2(0.5, 0.42), Color(0.34, 0.31, 0.29, alpha))

func _draw_painting(id: String, alpha: float, time: float, down: bool) -> void:
	if alpha <= 0.0:
		return
	var frame = _frame_for(id)
	var s = _scale()
	UiKit.draw_round_rect(self, frame.grow(16.0 * s), Color(0, 0, 0, 0.5 * alpha), 10.0)
	var entry = art_entry(id)
	if entry.is_empty():
		UiKit.draw_ink_wash(self, frame, UiKit.GOLD_DARK, id)
	else:
		var region: Rect2 = entry.region
		var drift = clampf(time / DRIFT_TIME, 0.0, 1.0)
		drift = 1.0 - pow(1.0 - drift, 2.0)
		var zoom = 1.0 + DRIFT_ZOOM * drift
		var fit = maxf(frame.size.x / region.size.x, frame.size.y / region.size.y) * zoom
		var visible_size = frame.size / fit
		var pan = lerpf(0.3, 0.7, drift) if down else lerpf(0.7, 0.3, drift)
		var origin = region.position + (region.size - visible_size) * Vector2(0.5, pan)
		draw_texture_rect_region(entry.texture, frame, Rect2(origin, visible_size), Color(1, 1, 1, alpha))
	UiKit.draw_round_rect(self, frame, Color.TRANSPARENT, 2.0, Color(UiKit.GOLD_DARK, alpha), 2.0)
	UiKit.draw_ornate(self, frame.grow(10.0 * s), 13, Color(UiKit.GOLD, 0.85 * alpha), 26.0 * s)
	if SEALS.has(kind) and id == art_id():
		var seal_size = 58.0 * s
		var center = Vector2(frame.end.x - seal_size * 0.35, frame.position.y + seal_size * 0.55)
		draw_set_transform(center, deg_to_rad(-8.0), Vector2.ONE)
		UiKit.draw_seal(self, Vector2.ZERO, seal_size, SEALS[kind], Color(UiKit.CINNABAR if kind == "victory" else Color("4a5868"), alpha))
		draw_set_transform(Vector2.ZERO)

func _draw_box() -> void:
	var s = _scale()
	UiKit.draw_round_rect(self, _box.grow(6.0 * s), Color(0, 0, 0, 0.55), 10.0)
	var paper = UiKit.ui_art("paper_tile")
	if paper != null:
		UiKit.draw_cover(self, paper, _box, Vector2(0.5, 0.3), Color(1.0, 0.98, 0.94))
	else:
		draw_rect(_box, UiKit.PAPER)
	UiKit.draw_vgradient(self, Rect2(_box.position, Vector2(_box.size.x, _box.size.y * 0.3)), Color(0.35, 0.22, 0.1, 0.12), Color(0, 0, 0, 0))
	UiKit.draw_ornate(self, _box.grow(-7.0 * s), 11, Color(0.42, 0.26, 0.14, 0.9), 24.0 * s)
	var left = _box.position.x + 46.0 * s
	var name_y = _box.position.y + 38.0 * s
	var speaker = speaker_text()
	var heading = _heading()
	var heading_size = int(16.0 * s)
	var heading_width = UiKit.body_font().get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_size).x
	var heading_room = _box.size.x * 0.48
	heading_width = minf(heading_width, heading_room)
	if not speaker.is_empty():
		var name_room = _box.size.x - 92.0 * s - heading_width - 24.0 * s
		UiKit.draw_text_left(self, UiKit.kai_font(), speaker, Vector2(left, name_y), int(30.0 * s), INK_NAME, name_room)
		var name_width = minf(name_room, UiKit.kai_font().get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30.0 * s)).x)
		draw_line(Vector2(left, name_y + 20.0 * s), Vector2(left + name_width + 18.0 * s, name_y + 20.0 * s), Color(INK_NAME, 0.45), 2.0 * s)
	if not heading.is_empty():
		UiKit.draw_text_left(self, UiKit.body_font(), heading, Vector2(_box.end.x - 46.0 * s - heading_width, name_y + 2.0 * s), heading_size,
			INK_MUTED, heading_room)
	# One dot per page, the current one filled.
	var count = pages.size()
	if count > 1:
		var step = 18.0 * s
		var y = _box.end.y - 36.0 * s
		var start = _box.get_center().x - step * (count - 1) * 0.5
		for index in range(count):
			var center = Vector2(start + step * index, y)
			if index == page:
				draw_circle(center, 5.5 * s, INK_NAME)
			else:
				draw_arc(center, 4.5 * s, 0.0, TAU, 20, Color(INK_MUTED, 0.8), 1.5 * s, true)
	if page_complete() and page + 1 < count:
		# A small brush mark says there is more.
		var mark = Vector2(buttons.next.position.x - 22.0 * s, buttons.next.position.y + buttons.next.size.y * 0.5)
		var bob = sin(_t * 4.0) * 2.0 * s
		draw_colored_polygon(PackedVector2Array([mark + Vector2(-6, -5 + bob) * s, mark + Vector2(6, -5 + bob) * s, mark + Vector2(0, 5 + bob) * s]),
			Color(INK_NAME, 0.7))

## "<chapter title> · <era>" (or the epilogue's).
func _heading() -> String:
	if chapter_id.is_empty():
		return ""
	var title = CampaignData.title(chapter_id)
	var era = CampaignData.chapter_text(chapter_id, "era")
	if era.is_empty() or era == title:
		return title
	return "%s · %s" % [title, era]
