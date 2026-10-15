extends Control
## A lane structure on its wall: mana (current over max) on the left, the
## building in the middle, health on the right, and the red pending-damage
## tag. It doubles as the Battlefield Control "tower" target.
##
## The building is the gate tower, intact above half health and damaged
## below; once it falls, the capital (the ancient) stands behind its ruins,
## burning below half health. The enemy's buildings are mirrored and drawn a
## little darker. Mana sits on the command gem. Without the art in
## assets/art/ui/ a calligraphy medallion and plain boxes are drawn instead.
## Derived armor, retaliate and regeneration (EFFECT_SYSTEM_SPEC.md §8.4)
## show as small badges under the health plate.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const SIZE = Vector2(250, 74)
## Medallion glyphs (Sanguo Kai) when the art is missing: a walled city for
## the tower, the capital for the ancient.
const TOWER_GLYPH = "城"
const ANCIENT_GLYPH = "都"
const TOWER_HEALTH = 40
const ANCIENT_HEALTH = 80
## Where the building sits in each sprite (0..1 of the image), measured from
## the masters. The three tower states share one frame, so the gatehouse
## stays in place as it is damaged and falls.
const FRAMES = {"tower": Rect2(0.048, 0.129, 0.911, 0.747), "ancient_capital": Rect2(0.199, 0.304, 0.613, 0.386),
	"ancient_capital_burning": Rect2(0.157, 0.301, 0.705, 0.444)}
## The building stands on the wall, rising above the plate.
const BUILDING_BOX = Rect2(-50, -54, 100, 90)

var own: bool = true
var health: int = 40
var ancient: bool = false
var destroyed: bool = false
var mana: int = 3
var max_mana: int = 3
var pending: int = 0
var will_fall: bool = false
## Derived tower values: {armor, retaliate, regeneration} (zeros are hidden).
var stats: Dictionary = {}
## 0 none, 1 legal target, 2 hovered target.
var target_state: int = 0
## Hides the pending-damage tag and the fall cross (the deployment reveal).
var preview_hidden: bool = false:
	set(value):
		preview_hidden = value
		queue_redraw()
var shake: float = 0.0
var flash: float = 0.0
var _pulse: float = 0.0

func _init() -> void:
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func apply(structure: Dictionary, lane_mana: int, lane_max_mana: int, damage: int, tower_stats: Dictionary = {}) -> void:
	stats = tower_stats
	health = int(structure.get("health", 40))
	ancient = structure.get("ancient", false)
	destroyed = structure.get("destroyed", false)
	mana = lane_mana
	max_mana = lane_max_mana
	pending = damage
	will_fall = damage > 0 and damage >= health
	queue_redraw()

func emblem_center() -> Vector2:
	return get_global_transform() * Vector2(SIZE.x * 0.5, SIZE.y * 0.5)

## The building sprite for the structure's state: [art name, frame key].
func building() -> Array:
	if not ancient:
		return ["tower_intact" if health * 2 > TOWER_HEALTH else "tower_damaged", "tower"]
	var burning = destroyed or health * 2 <= ANCIENT_HEALTH
	var art = "ancient_capital_burning" if burning else "ancient_capital"
	return [art, art]

func _process(delta: float) -> void:
	if target_state != 0:
		_pulse = fmod(_pulse + delta * 3.0, TAU)
		queue_redraw()

func _draw() -> void:
	var offset = Vector2(sin(shake * 40.0) * shake * 6.0, 0)
	draw_set_transform(offset)
	var center = SIZE * 0.5
	var tint = UiKit.ALLY_TINT if own else UiKit.ENEMY_TINT
	if target_state > 0:
		draw_circle(center, 44.0 + 3.0 * sin(_pulse), Color(UiKit.TARGET, 0.25 if target_state == 1 else 0.5))
	var sprite = building()
	var art = UiKit.ui_art(sprite[0])
	var mark_center = center
	if art != null:
		mark_center = _draw_building(center, art, FRAMES[sprite[1]])
	else:
		_draw_medallion(center, tint)
	_draw_mana(Rect2(center.x - 106, center.y - 31, 52, 62))
	# Health box.
	var health_rect = Rect2(center.x + 44, center.y - 31, 66, 62)
	_panel(health_rect, Color(UiKit.GOLD, 0.9) if ancient else Color(0.55, 0.52, 0.47))
	var health_color = UiKit.PAPER if not destroyed else UiKit.MUTED
	UiKit.draw_text(self, UiKit.bold_font(), str(health), health_rect.get_center(), 30, health_color, health_rect.size.x - 6, 3)
	_draw_badges(health_rect)
	if will_fall and not preview_hidden:
		draw_line(mark_center + Vector2(-22, -22), mark_center + Vector2(22, 22), Color("d42a22"), 6.0, true)
		draw_line(mark_center + Vector2(22, -22), mark_center + Vector2(-22, 22), Color("d42a22"), 6.0, true)
	if pending > 0 and not preview_hidden:
		var text = "-%d" % pending
		var width = maxf(34.0, UiKit.bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 12.0)
		var tag = Rect2(health_rect.end.x - 6, health_rect.position.y + 6, width, 28)
		UiKit.draw_round_rect(self, tag, Color("a3221b"), 3.0, Color("ff8a70"), 1.0)
		UiKit.draw_text(self, UiKit.bold_font(), text, tag.get_center(), 20, Color.WHITE)
	if flash > 0.0:
		draw_circle(center, 40.0, Color(1, 0.9, 0.7, flash * 0.6))
	draw_set_transform(Vector2.ZERO)

## The painted building, standing on the wall: a soft ground shadow, then
## (for the capital) the ruined gate in front of it. Returns the centre of
## the building for the fall cross.
func _draw_building(center: Vector2, art: Texture2D, frame: Rect2) -> Vector2:
	var box = Rect2(center + BUILDING_BOX.position, BUILDING_BOX.size)
	var shade = Color(0.88, 0.86, 0.86) if own else Color(0.74, 0.7, 0.7)
	if destroyed:
		shade = Color(0.42, 0.42, 0.42)
	_ground_shadow(Vector2(center.x, box.end.y - 2.0), 46.0)
	var landed = UiKit.draw_framed(self, art, frame, box, shade, not own)
	if ancient:
		var ruins = UiKit.ui_art("tower_destroyed")
		if ruins != null:
			var side = -1.0 if own else 1.0
			var small = Rect2(Vector2(center.x + side * 30.0 - 22.0, box.end.y - 34.0), Vector2(44, 36))
			UiKit.draw_framed(self, ruins, FRAMES.tower, small, shade.darkened(0.15), not own)
	return landed.get_center() if landed.size != Vector2.ZERO else center

func _ground_shadow(at: Vector2, half_width: float) -> void:
	var points = PackedVector2Array()
	for step in range(20):
		var angle = TAU * step / 20.0
		points.append(at + Vector2(cos(angle) * half_width, sin(angle) * half_width * 0.22))
	draw_colored_polygon(points, Color(0, 0, 0, 0.45))

## The calligraphy medallion used when the building art is missing.
func _draw_medallion(center: Vector2, tint: Color) -> void:
	draw_circle(center + Vector2(0, 3), 37.0, Color(0, 0, 0, 0.5))
	draw_circle(center, 36.0, Color(0.32, 0.3, 0.27))
	draw_circle(center, 33.0, tint.darkened(0.55))
	draw_arc(center, 33.0, 0.0, TAU, 40, Color(UiKit.GOLD, 0.9), 2.0, true)
	draw_arc(center, 27.0, 0.0, TAU, 40, Color(UiKit.GOLD_DARK, 0.6), 1.0, true)
	var glyph = ANCIENT_GLYPH if ancient else TOWER_GLYPH
	UiKit.draw_text(self, UiKit.kai_font(), glyph, center + Vector2(0, 2), 38, Color(0, 0, 0, 0.45))
	UiKit.draw_text(self, UiKit.kai_font(), glyph, center, 38, UiKit.GOLD_BRIGHT if not destroyed else UiKit.MUTED, -1.0, 3)

## Mana: the current amount on the command gem with the maximum below it
## (or both in a plain box without the art).
func _draw_mana(rect: Rect2) -> void:
	var gem = UiKit.ui_art("mana_command")
	if gem == null:
		_panel(rect)
		UiKit.draw_text(self, UiKit.bold_font(), str(mana), rect.position + Vector2(26, 16), 21, Color("cfe9ff"), -1.0, 2)
		draw_line(rect.position + Vector2(12, 31), rect.position + Vector2(40, 31), Color(1, 1, 1, 0.55), 2.0)
		UiKit.draw_text(self, UiKit.bold_font(), str(max_mana), rect.position + Vector2(26, 46), 21, Color("cfe9ff"), -1.0, 2)
		return
	var art_rect = Rect2(rect.get_center() - Vector2(31, 38), Vector2(62, 62))
	draw_texture_rect(gem, art_rect, false)
	UiKit.draw_text(self, UiKit.bold_font(), str(mana), art_rect.position + art_rect.size * Vector2(0.5, 0.47), 24, Color.WHITE, -1.0, 4,
		Color(0.02, 0.05, 0.16, 0.95))
	var plate = Rect2(Vector2(rect.get_center().x - 17, art_rect.end.y - 4), Vector2(34, 18))
	UiKit.draw_round_rect(self, plate, Color(0.06, 0.07, 0.1, 0.92), 8.0, Color(0.55, 0.62, 0.8, 0.7), 1.0)
	UiKit.draw_text(self, UiKit.bold_font(), "/%d" % max_mana, plate.get_center(), 14, Color("cfe9ff"))

## Armor, retaliate and regeneration badges in a row under the health plate.
func _draw_badges(health_rect: Rect2) -> void:
	var x = health_rect.position.x + 10.0
	for kind in ["armor", "retaliate", "regeneration"]:
		var value = int(stats.get(kind, 0))
		if value == 0:
			continue
		UiKit.draw_badge(self, kind, value, Vector2(x, health_rect.end.y + 13.0), 11.5)
		x += 26.0

## The badges drawn under the health plate, in order.
func badge_kinds() -> Array:
	var out: Array = []
	for kind in ["armor", "retaliate", "regeneration"]:
		if int(stats.get(kind, 0)) != 0:
			out.append(kind)
	return out

func _panel(rect: Rect2, rim: Color = Color(0.55, 0.52, 0.47)) -> void:
	draw_colored_polygon(UiKit.round_rect_points(Rect2(rect.position + Vector2(0, 3), rect.size), 7.0), Color(0, 0, 0, 0.45))
	UiKit.draw_round_rect(self, rect, Color(0.1, 0.1, 0.11, 0.95), 7.0, rim, 2.0)
	UiKit.draw_vgradient(self, Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, rect.size.y * 0.4)), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0))
