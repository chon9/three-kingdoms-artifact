extends Control
## An improvement in the row beside its tower (EFFECT_SYSTEM_SPEC.md §8.4): a
## 44x44 medallion with the card's art in a ring of its colour, a charges
## badge in the bottom-right corner, a dark cooldown overlay with the rounds
## left, a small book mark for an active ability, a pulsing glow while that
## ability can be used now, and the target stepper's cue (`target_state` 1 a
## candidate, 2 hovered). With `count` above 0 it is the "+n" overflow chip,
## or the overview's single count chip when `summary` is set.
##
## It takes no clicks itself (the board hit-tests chips like unit cards); its
## tooltip shows the card text. Its book mark and charges badge are drawn by
## the lane in a pass above every chip (draw_marks), so an overlapping
## neighbour never hides them.

signal changed

const Library = preload("res://scripts/core/card_library.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const SIZE = Vector2(44, 44)
const RADIUS = 21.0

var oid: int = -1
var card_id: String = ""
var own: bool = true
var charges: int = 0
var show_charges: bool = false
## Rounds left on its active ability's cooldown.
var cd: int = 0
var has_active: bool = false
## Its active ability is legal for the viewer right now.
var usable: bool = false
## 0 none, 1 candidate of the target stepper, 2 hovered candidate.
var target_state: int = 0
## Overflow ("+n") or count chip when above 0.
var count: int = 0
var summary: bool = false
var flash: float = 0.0
## Leaving the row: no longer hit-tested while it fades out.
var gone: bool = false
var _pulse: float = 0.0

func _init() -> void:
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(false)

## `model`: {oid, card, charges, cd, has_active, ready} (board_view).
func apply(model: Dictionary, is_own: bool) -> void:
	oid = int(model.get("oid", -1))
	card_id = str(model.get("card", ""))
	own = is_own
	charges = int(model.get("charges", 0))
	show_charges = charges > 0 or Library.raw_definition(card_id).has("charges")
	cd = int(model.get("cd", 0))
	has_active = model.get("has_active", false)
	usable = model.get("ready", false)
	count = 0
	summary = false
	tooltip_text = _tooltip()
	_update_processing()
	queue_redraw()
	changed.emit()

## The "+n" chip after the last shown chip (glowing while `ready`: an own
## chip it hides can be used now), or (summary) the overview's chip counting
## every improvement on that wall.
func apply_count(value: int, is_own: bool, is_summary: bool, ready: bool = false) -> void:
	oid = -1
	card_id = ""
	own = is_own
	count = value
	summary = is_summary
	usable = ready and not is_summary
	tooltip_text = UiKit.t("HUD_IMPROVEMENTS", {"n": value})
	_update_processing()
	queue_redraw()

func set_target_state(value: int) -> void:
	if target_state != value:
		target_state = value
		_update_processing()
		queue_redraw()

func refresh() -> void:
	tooltip_text = _tooltip() if count == 0 else UiKit.t("HUD_IMPROVEMENTS", {"n": count})
	queue_redraw()

func _tooltip() -> String:
	if card_id.is_empty():
		return ""
	var lines: Array = [Library.loc(card_id), Library.loc(card_id, "text")]
	if has_active:
		var ability = Library.loc(card_id, "ability_name")
		var state = UiKit.t_n("HUD_COOLDOWN", cd) if cd > 0 else UiKit.t("HUD_READY")
		lines.append(UiKit.t("CARD_ABILITY_LINE", {"label": ability if not ability.is_empty() else UiKit.t("CARD_ACTIVE_ABILITY"), "ability": state}))
	if show_charges:
		lines.append(UiKit.t("CARD_CHARGES", {"n": charges}))
	return "\n".join(lines)

func _update_processing() -> void:
	set_process(usable or target_state != 0)

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 3.0, TAU)
	queue_redraw()

func _draw() -> void:
	var center = SIZE * 0.5
	var tint = UiKit.ALLY_TINT if own else UiKit.ENEMY_TINT
	match target_state:
		1:
			draw_circle(center, RADIUS + 6.0 + 1.5 * sin(_pulse), Color(UiKit.TARGET, 0.28))
			draw_arc(center, RADIUS + 3.5, 0.0, TAU, 32, Color(UiKit.TARGET, 0.75 + 0.25 * sin(_pulse)), 2.5, true)
		2:
			draw_circle(center, RADIUS + 8.0, Color(UiKit.GOLD_BRIGHT, 0.4))
			draw_arc(center, RADIUS + 3.5, 0.0, TAU, 32, UiKit.GOLD_BRIGHT, 3.0, true)
	if usable and target_state == 0:
		draw_circle(center, RADIUS + 6.0 + 2.0 * sin(_pulse), Color(UiKit.PLAYABLE, 0.32 + 0.1 * sin(_pulse)))
		draw_arc(center, RADIUS + 3.0, 0.0, TAU, 32, Color(UiKit.PLAYABLE, 0.95), 2.5, true)
	draw_circle(center + Vector2(0, 3), RADIUS + 1.0, Color(0, 0, 0, 0.5))
	if count > 0:
		_draw_count(center, tint)
		return
	var color_id = str(Library.raw_definition(card_id).get("color", "neutral"))
	var rim = UiKit.card_color(color_id)
	draw_circle(center, RADIUS, rim.darkened(0.35))
	var inner = RADIUS - 4.0
	var points = PackedVector2Array()
	for step in range(32):
		points.append(center + Vector2.from_angle(TAU * step / 32.0) * inner)
	var entry = CardArt.art(card_id)
	var lettered = entry.is_empty()
	if not lettered:
		var box = Rect2(center - Vector2(inner, inner), Vector2(inner, inner) * 2.0)
		var region: Rect2 = entry.region
		# The upper-middle of the art (where the subject sits), square.
		var side = minf(region.size.x, region.size.y) * 0.62
		var crop = Rect2(region.position + Vector2((region.size.x - side) * 0.5, region.size.y * 0.12), Vector2(side, side))
		UiKit.draw_cover_polygon(self, points, box, entry.texture, Vector2(0.5, 0.5), Color.WHITE, crop)
	else:
		draw_colored_polygon(points, rim.darkened(0.55))
		var title = Library.loc(card_id)
		UiKit.draw_text(self, UiKit.kai_font() if UiKit.is_zh() else UiKit.title_font(), title.left(1), center, 22, UiKit.PAPER, -1.0, 3)
	draw_arc(center, inner + 1.0, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 2.0, true)
	draw_arc(center, RADIUS - 1.5, 0.0, TAU, 32, rim.lightened(0.25), 3.0, true)
	draw_arc(center, RADIUS + 0.5, 0.0, TAU, 32, Color(tint, 0.9), 1.5, true)
	if cd > 0:
		# Over a letter (no art) the dark disc is nearly opaque, so the number
		# never reads as part of the glyph.
		draw_circle(center, inner, Color(0.02, 0.02, 0.03, 0.94 if lettered else 0.62))
		UiKit.draw_text(self, UiKit.bold_font(), str(cd), center, 22, UiKit.PAPER, -1.0, 3)
	if flash > 0.0:
		draw_circle(center, RADIUS, Color(1, 0.93, 0.8, flash * 0.55))

## The book mark (active ability) and the charges badge, drawn on `canvas`
## (the lane's marks pass) through this chip's transform in its parent.
func draw_marks(canvas: CanvasItem, alpha: float) -> void:
	if count > 0 or (not has_active and not show_charges) or alpha <= 0.0:
		return
	canvas.draw_set_transform_matrix(get_transform())
	var center = SIZE * 0.5
	if has_active:
		var mark = center + Vector2(-RADIUS + 5.0, -RADIUS + 5.0)
		UiKit.draw_disc(canvas, mark, 7.5, Color(0.08, 0.13, 0.19, alpha), Color(UiKit.PLAYABLE if usable else Color(0.6, 0.6, 0.6), alpha), 1.5)
		UiKit.draw_icon(canvas, "book_open", Rect2(mark - Vector2(4.5, 4.5), Vector2(9, 9)), Color(1, 1, 1, (0.95 if cd == 0 else 0.45) * alpha))
	if show_charges:
		UiKit.draw_badge(canvas, "charges", charges, center + Vector2(RADIUS - 5.0, RADIUS - 5.0), 9.0, alpha)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_count(center: Vector2, tint: Color) -> void:
	draw_circle(center, RADIUS, Color(0.08, 0.08, 0.09, 0.96))
	UiKit.draw_icon(self, "structure_wall", Rect2(center - Vector2(13, 13), Vector2(26, 26)), Color(1, 1, 1, 0.16))
	draw_arc(center, RADIUS - 1.5, 0.0, TAU, 32, Color(UiKit.GOLD, 0.9), 2.5, true)
	draw_arc(center, RADIUS + 0.5, 0.0, TAU, 32, Color(tint, 0.9), 1.5, true)
	var text = str(count) if summary else "+%d" % count
	UiKit.draw_text(self, UiKit.bold_font(), text, center, 20 if text.length() <= 2 else 16, UiKit.PAPER, -1.0, 3)
	if flash > 0.0:
		draw_circle(center, RADIUS, Color(1, 0.93, 0.8, flash * 0.55))
